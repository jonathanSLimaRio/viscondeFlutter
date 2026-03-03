import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api_error.dart';
import '../../shared/providers.dart';
import '../auth/auth_controller.dart';
import '../story_sync/story_sync_queue.dart';
import 'models/story_models.dart';
import 'story_api.dart';

enum StorySyncStatus { synced, pending, reconnecting }

abstract interface class ConnectivityMonitor {
  Stream<dynamic> get changes;
}

class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<dynamic> get changes => _connectivity.onConnectivityChanged;
}

class StoryRoomState {
  const StoryRoomState({
    this.loading = false,
    this.submittingStep = false,
    this.finalizing = false,
    this.session,
    this.ideas = const [],
    this.ideasSource,
    this.ideasSafetyAdjusted = false,
    this.pendingCount = 0,
    this.syncStatus = StorySyncStatus.synced,
    this.participantToken,
    this.error,
  });

  final bool loading;
  final bool submittingStep;
  final bool finalizing;
  final StorySessionModel? session;
  final List<String> ideas;
  final String? ideasSource;
  final bool ideasSafetyAdjusted;
  final int pendingCount;
  final StorySyncStatus syncStatus;
  final String? participantToken;
  final String? error;

  StoryRoomState copyWith({
    bool? loading,
    bool? submittingStep,
    bool? finalizing,
    StorySessionModel? session,
    List<String>? ideas,
    String? ideasSource,
    bool? ideasSafetyAdjusted,
    int? pendingCount,
    StorySyncStatus? syncStatus,
    String? participantToken,
    String? error,
    bool clearError = false,
    bool clearIdeas = false,
  }) {
    return StoryRoomState(
      loading: loading ?? this.loading,
      submittingStep: submittingStep ?? this.submittingStep,
      finalizing: finalizing ?? this.finalizing,
      session: session ?? this.session,
      ideas: clearIdeas ? const [] : (ideas ?? this.ideas),
      ideasSource: clearIdeas ? null : (ideasSource ?? this.ideasSource),
      ideasSafetyAdjusted: ideasSafetyAdjusted ?? this.ideasSafetyAdjusted,
      pendingCount: pendingCount ?? this.pendingCount,
      syncStatus: syncStatus ?? this.syncStatus,
      participantToken: participantToken ?? this.participantToken,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final storyRoomControllerProvider =
    StateNotifierProvider<StoryRoomController, StoryRoomState>((ref) {
      return StoryRoomController(
        ref: ref,
        api: ref.watch(storyApiProvider),
        syncQueue: ref.watch(storySyncQueueProvider),
        connectivity: ConnectivityPlusMonitor(Connectivity()),
      );
    });

class StoryRoomController extends StateNotifier<StoryRoomState> {
  StoryRoomController({
    required Ref ref,
    required StoryApi api,
    required StorySyncQueue syncQueue,
    required ConnectivityMonitor connectivity,
  }) : _ref = ref,
       _api = api,
       _syncQueue = syncQueue,
       _connectivity = connectivity,
       super(const StoryRoomState()) {
    _bootstrap();
  }

  final Ref _ref;
  final StoryApi _api;
  final StorySyncQueue _syncQueue;
  final ConnectivityMonitor _connectivity;

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _syncingQueue = false;

  Future<void> _bootstrap() async {
    await _refreshPendingCount();
    _connectivitySubscription = _connectivity.changes.listen((event) {
      if (_isOnline(event)) {
        syncPending();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  String? _accessToken() {
    return _ref.read(authControllerProvider).accessToken;
  }

  bool _isOnline(dynamic event) {
    if (event is List<ConnectivityResult>) {
      return !event.contains(ConnectivityResult.none);
    }

    if (event is ConnectivityResult) {
      return event != ConnectivityResult.none;
    }

    return true;
  }

  bool _isNetworkError(Object error) {
    if (error is! DioException) {
      return false;
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return true;
    }

    return error.response == null;
  }

  int? _statusCode(Object error) {
    if (error is DioException) {
      return error.response?.statusCode;
    }
    return null;
  }

  Duration _retryBackoff({required int attempt, int? statusCode}) {
    final normalizedAttempt = attempt <= 0 ? 1 : attempt;
    final seconds = min(300, 5 * (1 << min(normalizedAttempt - 1, 6)));

    if (statusCode == 401 || statusCode == 403) {
      return const Duration(minutes: 2);
    }

    if (statusCode == 429) {
      return const Duration(minutes: 1);
    }

    if (statusCode != null && statusCode >= 500) {
      return Duration(seconds: max(15, seconds));
    }

    return Duration(seconds: seconds);
  }

  void setParticipantToken(String? token) {
    state = state.copyWith(participantToken: token);
  }

  StorySyncStatus _deriveSyncStatus(
    int pendingCount, {
    bool reconnecting = false,
  }) {
    if (reconnecting) {
      return StorySyncStatus.reconnecting;
    }

    if (pendingCount > 0) {
      return StorySyncStatus.pending;
    }

    return StorySyncStatus.synced;
  }

  Future<void> _refreshPendingCount({bool reconnecting = false}) async {
    final session = state.session;
    final count = await _syncQueue.pendingCount(storyId: session?.id);
    state = state.copyWith(
      pendingCount: count,
      syncStatus: _deriveSyncStatus(count, reconnecting: reconnecting),
    );
  }

  String _nextLocalEventId() {
    final random = Random().nextInt(1 << 32);
    return '${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  List<StoryChoiceOption> _fallbackOptions(StorySessionModel session) {
    return const [
      StoryChoiceOption(id: 'opt-1', label: 'Conversar com calma'),
      StoryChoiceOption(id: 'opt-2', label: 'Pedir ajuda a um amigo'),
      StoryChoiceOption(id: 'opt-3', label: 'Tentar um plano criativo'),
    ];
  }

  void _applyOptimisticStep(Map<String, dynamic> payload) {
    final session = state.session;
    if (session == null) {
      return;
    }

    final kind = storyStepKindFromApi(
      (payload['kind'] as String?) ?? 'NARRATION',
    );
    final stepIndex =
        (payload['stepIndex'] as num?)?.toInt() ?? session.currentStepIndex + 1;

    final step = StoryStepModel(
      id: 'local-${payload['localEventId'] ?? _nextLocalEventId()}',
      stepIndex: stepIndex,
      kind: kind,
      modeUsed: session.currentMode,
      localEventId: (payload['localEventId'] as String?) ?? _nextLocalEventId(),
      narratorPrompt: payload['narratorPrompt'] as String?,
      childOptions: kind == StoryStepKind.childChoice
          ? _fallbackOptions(session)
          : const <StoryChoiceOption>[],
      selectedOptionId: payload['selectedOptionId'] as String?,
      selectedOptionLabel: payload['selectedOptionLabel'] as String?,
      narratorText: payload['narratorText'] as String?,
    );

    final nextSteps = <StoryStepModel>[
      ...session.steps.where((item) => item.stepIndex != step.stepIndex),
      step,
    ]..sort((a, b) => a.stepIndex.compareTo(b.stepIndex));

    final updated = session.copyWith(
      currentStepIndex: max(session.currentStepIndex, step.stepIndex),
      steps: nextSteps,
    );

    state = state.copyWith(session: updated);
  }

  Future<StorySessionModel?> createSession({
    required String childProfileId,
    required String titleDraft,
    required String theme,
    required String scenario,
    required List<Map<String, String?>> characters,
    required String objective,
    required StoryMode startMode,
    String? virtueId,
    String? sourceTemplateId,
    String? artStyleId,
  }) async {
    final token = _accessToken();
    if (token == null) {
      state = state.copyWith(error: 'Sessão expirada. Faça login novamente.');
      return null;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await _api.createStorySession(
        token,
        childProfileId: childProfileId,
        titleDraft: titleDraft,
        theme: theme,
        scenario: scenario,
        characters: characters,
        objective: objective,
        startMode: startMode,
        virtueId: virtueId,
        sourceTemplateId: sourceTemplateId,
        artStyleId: artStyleId,
      );

      await _refreshPendingCount();
      state = state.copyWith(
        loading: false,
        session: session,
        clearIdeas: true,
      );

      return session;
    } catch (error) {
      state = state.copyWith(loading: false, error: parseDioError(error));
      return null;
    }
  }

  Future<StorySessionModel?> updateSessionSetup({
    required String titleDraft,
    required String theme,
    required String scenario,
    required List<Map<String, String?>> characters,
    required String objective,
    String? virtueId,
    StoryMode? mode,
    bool applyAutoVirtue = false,
  }) async {
    final token = _accessToken();
    final session = state.session;
    if (token == null || session == null) {
      state = state.copyWith(error: 'Sessão expirada. Faça login novamente.');
      return null;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final updated = await _api.updateStorySessionSetup(
        token,
        session.id,
        titleDraft: titleDraft,
        theme: theme,
        scenario: scenario,
        objective: objective,
        characters: characters,
        virtueId: virtueId,
        mode: mode,
        applyAutoVirtue: applyAutoVirtue,
      );

      await _refreshPendingCount();
      state = state.copyWith(loading: false, session: updated);
      return updated;
    } catch (error) {
      state = state.copyWith(loading: false, error: parseDioError(error));
      return null;
    }
  }

  Future<void> loadSession(String storyId) async {
    final token = _accessToken();
    if (token == null) {
      state = state.copyWith(error: 'Sessão expirada. Faça login novamente.');
      return;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await _api.getStorySession(token, storyId);
      state = state.copyWith(loading: false, session: session);
      await _refreshPendingCount();
      await syncPending();
    } catch (error) {
      state = state.copyWith(loading: false, error: parseDioError(error));
    }
  }

  Future<void> changeMode(StoryMode mode) async {
    final token = _accessToken();
    final session = state.session;

    if (token == null || session == null) {
      return;
    }

    try {
      final updated = await _api.updateMode(token, session.id, mode);
      state = state.copyWith(session: updated);
    } catch (error) {
      state = state.copyWith(error: parseDioError(error));
    }
  }

  Future<void> requestIdeas({String? contextHint}) async {
    final token = _accessToken();
    final session = state.session;

    if (token == null || session == null) {
      return;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final ideas = await _api.requestIdeas(
        token,
        session.id,
        contextHint: contextHint,
      );

      state = state.copyWith(
        loading: false,
        ideas: ideas.ideas,
        ideasSource: ideas.source,
        ideasSafetyAdjusted: ideas.safetyAdjusted,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: parseDioError(error));
    }
  }

  Future<void> addNarrationStep({required String narratorText}) {
    return _submitStep(
      kind: StoryStepKind.narration,
      narratorText: narratorText,
    );
  }

  Future<void> addChildChoiceStep({
    required String selectedOptionLabel,
    String? selectedOptionId,
  }) async {
    final session = state.session;
    final remoteToken = state.session?.remote?.isOpen == true
        ? state.participantToken
        : null;

    if (session?.remote?.callMode == RemoteCallMode.coop &&
        remoteToken != null) {
      state = state.copyWith(submittingStep: true, clearError: true);
      try {
        final result = await _api.createCoopVote(
          remoteToken,
          session!.id,
          stepIndex: session.currentStepIndex + 1,
          selectedOptionLabel: selectedOptionLabel,
          selectedOptionId: selectedOptionId ?? '',
        );

        if (result.stepResult?.story != null) {
          state = state.copyWith(
            submittingStep: false,
            session: result.stepResult!.story,
          );
        } else {
          state = state.copyWith(submittingStep: false);
          // Voto registrado. Poderiamos mostrar feedback local.
        }
      } catch (error) {
        state = state.copyWith(
          submittingStep: false,
          error: parseDioError(error),
        );
      }
      return;
    }

    return _submitStep(
      kind: StoryStepKind.childChoice,
      selectedOptionLabel: selectedOptionLabel,
      selectedOptionId: selectedOptionId,
    );
  }

  Future<void> _submitStep({
    required StoryStepKind kind,
    String? narratorText,
    String? selectedOptionLabel,
    String? selectedOptionId,
  }) async {
    final token = _accessToken();
    final session = state.session;
    if (token == null || session == null) {
      return;
    }

    final payload = <String, dynamic>{
      'kind': storyStepKindToApi(kind),
      'stepIndex': session.currentStepIndex + 1,
      if (narratorText != null && narratorText.trim().isNotEmpty)
        'narratorText': narratorText.trim(),
      if (selectedOptionLabel != null && selectedOptionLabel.trim().isNotEmpty)
        'selectedOptionLabel': selectedOptionLabel.trim(),
      if (selectedOptionId != null && selectedOptionId.trim().isNotEmpty)
        'selectedOptionId': selectedOptionId.trim(),
      'localEventId': _nextLocalEventId(),
    };

    state = state.copyWith(submittingStep: true, clearError: true);

    try {
      final result = await _api.createStep(
        token,
        session.id,
        kind: kind,
        stepIndex: payload['stepIndex'] as int,
        narratorText: payload['narratorText'] as String?,
        selectedOptionId: payload['selectedOptionId'] as String?,
        selectedOptionLabel: payload['selectedOptionLabel'] as String?,
        localEventId: payload['localEventId'] as String,
      );

      state = state.copyWith(submittingStep: false, session: result.story);
      await _refreshPendingCount();
      return;
    } catch (error) {
      if (_isNetworkError(error)) {
        await _syncQueue.enqueueStep(storyId: session.id, payload: payload);
        _applyOptimisticStep(payload);
        await _refreshPendingCount();

        state = state.copyWith(
          submittingStep: false,
          error:
              'Sem internet: etapa salva localmente e pendente de sincronização.',
        );
        return;
      }

      if (error is DioException && error.response?.statusCode == 409) {
        try {
          final refreshed = await _api.getStorySession(token, session.id);
          state = state.copyWith(submittingStep: false, session: refreshed);
          await _refreshPendingCount();
          return;
        } catch (_) {
          // Keep original error below.
        }
      }

      state = state.copyWith(
        submittingStep: false,
        error: parseDioError(error),
      );
    }
  }

  Future<void> syncPending() async {
    final token = _accessToken();
    final session = state.session;

    if (token == null || session == null || _syncingQueue) {
      return;
    }

    final pending = await _syncQueue.pendingCount(storyId: session.id);
    if (pending == 0) {
      await _refreshPendingCount();
      return;
    }

    _syncingQueue = true;
    state = state.copyWith(syncStatus: StorySyncStatus.reconnecting);

    try {
      final events = await _syncQueue.listRetryable(storyId: session.id);
      bool shouldRefreshSession = false;

      for (final event in events) {
        try {
          final kind = storyStepKindFromApi(
            (event.payload['kind'] as String?) ?? 'NARRATION',
          );

          await _api.createStep(
            token,
            session.id,
            kind: kind,
            stepIndex: (event.payload['stepIndex'] as num?)?.toInt() ?? 1,
            narratorText: event.payload['narratorText'] as String?,
            selectedOptionId: event.payload['selectedOptionId'] as String?,
            selectedOptionLabel:
                event.payload['selectedOptionLabel'] as String?,
            localEventId:
                (event.payload['localEventId'] as String?) ??
                _nextLocalEventId(),
          );
          await _syncQueue.markSynced(event.id);
          shouldRefreshSession = true;
        } catch (error) {
          final statusCode = _statusCode(error);
          if (statusCode == 409) {
            await _syncQueue.markConflict(
              id: event.id,
              reason: parseDioError(error),
              httpStatus: statusCode,
            );
            shouldRefreshSession = true;
            continue;
          }

          await _syncQueue.markFailed(
            id: event.id,
            reason: parseDioError(error),
            httpStatus: statusCode,
            retryAfter: _retryBackoff(
              attempt: event.retryCount + 1,
              statusCode: statusCode,
            ),
          );

          if (_isNetworkError(error) ||
              statusCode == null ||
              statusCode >= 500 ||
              statusCode == 429 ||
              statusCode == 401 ||
              statusCode == 403) {
            break;
          }

          // Erro 4xx sem conflito: mantém evento como failed para observabilidade.
          break;
        }
      }

      if (shouldRefreshSession) {
        final refreshed = await _api.getStorySession(token, session.id);
        state = state.copyWith(session: refreshed);
      }
      await _syncQueue.purgeSynced(
        olderThan: DateTime.now().subtract(const Duration(days: 7)),
      );
    } catch (error) {
      state = state.copyWith(error: parseDioError(error));
    } finally {
      _syncingQueue = false;
      await _refreshPendingCount();
    }
  }

  Future<StoryFinalizeResult?> finalize({String? titleFinal}) async {
    final token = _accessToken();
    final session = state.session;

    if (token == null || session == null) {
      return null;
    }

    state = state.copyWith(finalizing: true, clearError: true);

    try {
      await syncPending();
      final finalized = await _api.finalizeStory(
        token,
        session.id,
        titleFinal: titleFinal,
      );

      state = state.copyWith(finalizing: false, session: finalized.story);
      return finalized;
    } catch (error) {
      state = state.copyWith(finalizing: false, error: parseDioError(error));
      return null;
    }
  }

  List<StoryChoiceOption> currentChoiceOptions() {
    final session = state.session;
    if (session == null) {
      return const <StoryChoiceOption>[];
    }

    for (final step in session.steps.reversed) {
      if (step.childOptions.isNotEmpty) {
        return step.childOptions;
      }
    }

    return _fallbackOptions(session);
  }

  String syncLabel() {
    switch (state.syncStatus) {
      case StorySyncStatus.synced:
        return 'Sincronizado';
      case StorySyncStatus.pending:
        return 'Pendente';
      case StorySyncStatus.reconnecting:
        return 'Reconectando';
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
