import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../../shared/logging/app_logger.dart';
import '../../auth/auth_controller.dart';
import '../../call/remote_call_controller.dart';
import '../../realtime/realtime_socket_client.dart';
import '../../story_room/models/story_models.dart';
import '../../story_room/story_room_controller.dart';
import '../../story_room/ui/child_choice_panel.dart';
import 'create_remote_session_sheet.dart';

class RemoteRoomScreen extends ConsumerStatefulWidget {
  const RemoteRoomScreen.host({super.key, required this.storyId})
    : joinBundle = null;

  const RemoteRoomScreen.guest({super.key, required this.joinBundle})
    : storyId = null;

  final String? storyId;
  final RemoteJoinBundle? joinBundle;

  bool get isGuest => joinBundle?.isGuest ?? false;

  @override
  ConsumerState<RemoteRoomScreen> createState() => _RemoteRoomScreenState();
}

class _RemoteRoomScreenState extends ConsumerState<RemoteRoomScreen> {
  final _chatController = TextEditingController();
  final _clientId =
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  RealtimeSocketClient? _socket;
  StreamSubscription<RealtimeSocketEvent>? _socketEventsSub;
  StreamSubscription<String>? _socketErrorsSub;

  StorySessionModel? _story;
  RemoteRoomModel? _remoteRoom;
  List<StoryInteractionModel> _interactions = const [];
  RemoteCallController? _callController;

  String? _participantToken;
  Map<String, String> _participantVotes = {}; // participantId -> optionId
  String? _myVoteOptionId;
  String? _signalingWsUrl;
  Map<String, dynamic>? _rtcConfig;
  String? _joinCode;
  String? _joinLink;
  DateTime? _joinExpiresAt;

  bool _loading = false;
  bool _sendingChat = false;
  String? _error;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  void _appendInteractionIfMissing(StoryInteractionModel interaction) {
    final exists = _interactions.any((item) {
      if (item.id.isNotEmpty && interaction.id.isNotEmpty) {
        return item.id == interaction.id;
      }

      return item.type == interaction.type &&
          item.authorDisplayName == interaction.authorDisplayName &&
          item.messageText == interaction.messageText &&
          item.emoji == interaction.emoji &&
          item.createdAt.millisecondsSinceEpoch ==
              interaction.createdAt.millisecondsSinceEpoch;
    });

    if (exists) {
      return;
    }

    setState(() {
      _interactions = [..._interactions, interaction];
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _chatController.dispose();
    _socketEventsSub?.cancel();
    _socketErrorsSub?.cancel();
    _socket?.dispose();
    unawaited(_disposeCallController());
    super.dispose();
  }

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  Future<void> _bootstrap() async {
    if (widget.isGuest) {
      final bundle = widget.joinBundle;
      if (bundle == null) {
        setState(() {
          _error = 'Dados da sala remota não encontrados.';
        });
        return;
      }

      setState(() {
        _story = bundle.storySnapshot;
        _remoteRoom = bundle.remoteRoom;
        _participantToken = bundle.participantToken;
        _signalingWsUrl = bundle.signalingWsUrl;
        _rtcConfig = bundle.rtcConfig;
      });

      ref
          .read(storyRoomControllerProvider.notifier)
          .setParticipantToken(bundle.participantToken);

      await _connectRealtime();
      return;
    }

    await _loadHostState();
  }

  Future<void> _loadHostState() async {
    final token = _accessToken();
    final storyId = widget.storyId;
    if (token == null || storyId == null || storyId.isEmpty) {
      setState(() {
        _error = 'Sessão expirada. Faça login novamente.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await ref
          .read(storyApiProvider)
          .getStorySession(token, storyId);

      setState(() {
        _story = session;
        _remoteRoom = session.remote;
      });

      if (session.remote != null && session.remote!.isOpen) {
        final state = await ref
            .read(storyApiProvider)
            .getRemoteRoomState(token, storyId);
        setState(() {
          _remoteRoom = state.remoteRoom;
          _story = state.storySnapshot;
          _participantToken = state.participantToken;
          _signalingWsUrl = state.signalingWsUrl;
          _rtcConfig = state.rtcConfig;
        });

        ref
            .read(storyRoomControllerProvider.notifier)
            .setParticipantToken(state.participantToken);

        await _connectRealtime();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = parseDioError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _connectRealtime() async {
    final token = _participantToken;
    final wsUrl = _signalingWsUrl;

    if (token == null || token.isEmpty || wsUrl == null || wsUrl.isEmpty) {
      return;
    }

    await _socketEventsSub?.cancel();
    await _socketErrorsSub?.cancel();
    await _socket?.dispose();
    await _disposeCallController();

    final socket = RealtimeSocketClient();
    _socket = socket;

    _socketEventsSub = socket.events.listen(_onRealtimeEvent);
    _socketErrorsSub = socket.errors.listen((message) {
      if (!mounted) {
        return;
      }
      _scheduleReconnect();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    try {
      await socket.connect(
        wsUrl: wsUrl,
        participantToken: token,
        clientId: _clientId,
      );
      _reconnectTimer?.cancel();
      _reconnectAttempt = 0;
      await _initCallController();
      await _refreshRemoteStateAfterReconnect();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _scheduleReconnect();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao conectar realtime.')));
    }
  }

  Future<void> _refreshRemoteStateAfterReconnect() async {
    if (widget.isGuest) {
      return;
    }

    final accessToken = _accessToken();
    final story = _story;
    if (accessToken == null || story == null) {
      return;
    }

    try {
      final state = await ref
          .read(storyApiProvider)
          .getRemoteRoomState(accessToken, story.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteRoom = state.remoteRoom;
        _story = state.storySnapshot;
        _participantToken = state.participantToken;
        _signalingWsUrl = state.signalingWsUrl;
        _rtcConfig = state.rtcConfig;
      });
      ref
          .read(storyRoomControllerProvider.notifier)
          .setParticipantToken(state.participantToken);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao atualizar estado da sala remota em background.',
        error: error,
        stackTrace: stackTrace,
        scope: 'remote_room',
      );
      // Falha de refresh não bloqueia a sessão já conectada.
    }
  }

  void _scheduleReconnect() {
    if (!mounted || (_remoteRoom?.isOpen != true)) {
      return;
    }

    final wsUrl = _signalingWsUrl;
    final token = _participantToken;
    if (wsUrl == null || wsUrl.isEmpty || token == null || token.isEmpty) {
      return;
    }

    if (_reconnectTimer?.isActive == true) {
      return;
    }

    final backoffSeconds = min(30, 1 << min(_reconnectAttempt, 5));
    _reconnectAttempt = min(_reconnectAttempt + 1, 10);
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      if (!mounted) {
        return;
      }
      unawaited(_connectRealtime());
    });
  }

  void _onRealtimeEvent(RealtimeSocketEvent event) {
    if (!mounted) {
      return;
    }

    unawaited(_callController?.handleRealtimeEvent(event));

    switch (event.event) {
      case 'story.step.created':
        final storyRaw = event.payload['story'];
        if (storyRaw is Map<String, dynamic>) {
          setState(() {
            _story = StorySessionModel.fromJson(storyRaw);
            _participantVotes = {};
            _myVoteOptionId = null;
          });
        }
        break;
      case 'vote.registered':
        final participantId = event.payload['participantId'] as String?;
        final optionId = event.payload['optionId'] as String?;
        if (participantId != null && optionId != null) {
          setState(() {
            _participantVotes[participantId] = optionId;
          });
        }
        break;
      case 'story.mode.changed':
        final modeRaw = event.payload['mode'] as String?;
        final current = _story;
        if (modeRaw != null && current != null) {
          setState(() {
            _story = current.copyWith(currentMode: storyModeFromApi(modeRaw));
          });
        }
        break;
      case 'chat.created':
      case 'reaction.created':
        final interactionRaw = event.payload['interaction'];
        if (interactionRaw is Map<String, dynamic>) {
          final interaction = StoryInteractionModel.fromJson(interactionRaw);
          _appendInteractionIfMissing(interaction);
        }
        break;
      case 'presence.updated':
        final room = _remoteRoom;
        final participantsRaw = event.payload['participants'];
        if (room != null && participantsRaw is List<dynamic>) {
          final nextParticipants = participantsRaw
              .whereType<Map<String, dynamic>>()
              .map((item) {
                final participantId =
                    (item['id'] as String?) ??
                    (item['participantId'] as String?) ??
                    '';
                RemoteParticipantModel? existing;
                for (final candidate in room.participants) {
                  if (candidate.id == participantId) {
                    existing = candidate;
                    break;
                  }
                }

                return RemoteParticipantModel(
                  id: participantId,
                  role: remoteParticipantRoleFromApi(
                    (item['role'] as String?) ??
                        (existing?.role == RemoteParticipantRole.guestChild
                            ? 'GUEST_CHILD'
                            : 'HOST_PARENT'),
                  ),
                  displayName:
                      (item['displayName'] as String?) ??
                      existing?.displayName ??
                      'Participante',
                  status: (item['status'] as String?) ?? 'CONNECTED',
                  lastSeenAt:
                      DateTime.tryParse(item['lastSeenAt'] as String? ?? '') ??
                      existing?.lastSeenAt ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                  joinedAt:
                      DateTime.tryParse(item['joinedAt'] as String? ?? '') ??
                      existing?.joinedAt ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                  leftAt: DateTime.tryParse(item['leftAt'] as String? ?? ''),
                );
              })
              .toList();

          setState(() {
            _remoteRoom = room.copyWith(participants: nextParticipants);
          });
          unawaited(
            _callController?.ensureHostOfferIfNeeded(
              participantCount: nextParticipants.length,
            ),
          );
        }
        break;
      case 'call.mode.changed':
        final room = _remoteRoom;
        if (room == null) {
          break;
        }

        final mode = remoteCallModeFromApi(event.payload['mode'] as String?);
        setState(() {
          _remoteRoom = room.copyWith(callMode: mode);
        });
        unawaited(_callController?.setMode(mode));
        break;
      case 'remote.closed':
        final room = _remoteRoom;
        if (room != null) {
          setState(() {
            _remoteRoom = room.copyWith(
              status: RemoteRoomStatus.closed,
              isOpen: false,
            );
          });
        }
        context.showMessage('Sala remota foi encerrada pelo host.');
        unawaited(_callController?.hangup(sendSignalEvent: false));
        break;
      default:
        break;
    }
  }

  Future<void> _openRemoteRoom() async {
    final story = _story;
    final accessToken = _accessToken();

    if (story == null || accessToken == null) {
      return;
    }

    final unlockToken = await ref
        .read(parentalUnlockServiceProvider)
        .ensureUnlocked(context, source: 'remote_room_open');
    if (unlockToken == null) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final opened = await ref
          .read(storyApiProvider)
          .openRemoteRoom(
            accessToken,
            story.id,
            parentalUnlockToken: unlockToken,
            callMode: RemoteCallMode.audio,
          );

      final refreshed = await ref
          .read(storyApiProvider)
          .getStorySession(accessToken, story.id);

      setState(() {
        _joinCode = opened.joinCode;
        _joinLink = opened.joinLink;
        _joinExpiresAt = opened.expiresAt;
        _participantToken = opened.participantToken;
        _signalingWsUrl = opened.signalingWsUrl;
        _rtcConfig = opened.rtcConfig;
        _remoteRoom = opened.remoteRoom;
        _story = refreshed;
      });

      ref
          .read(storyRoomControllerProvider.notifier)
          .setParticipantToken(opened.participantToken);

      await _connectRealtime();
    } catch (error) {
      if (!mounted) {
        return;
      }

      context.showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _regenerateCode() async {
    final story = _story;
    final accessToken = _accessToken();

    if (story == null || accessToken == null) {
      return;
    }

    final unlockToken = await ref
        .read(parentalUnlockServiceProvider)
        .ensureUnlocked(context, source: 'remote_room_regenerate_code');
    if (unlockToken == null) {
      return;
    }

    setState(() => _loading = true);

    try {
      final regenerated = await ref
          .read(storyApiProvider)
          .regenerateRemoteCode(
            accessToken,
            story.id,
            parentalUnlockToken: unlockToken,
          );

      setState(() {
        _joinCode = regenerated.joinCode;
        _joinLink = regenerated.joinLink;
        _joinExpiresAt = regenerated.expiresAt;
        _participantToken = regenerated.participantToken;
        _signalingWsUrl = regenerated.signalingWsUrl;
        _rtcConfig = regenerated.rtcConfig;
        _remoteRoom = regenerated.remoteRoom;
      });

      ref
          .read(storyRoomControllerProvider.notifier)
          .setParticipantToken(regenerated.participantToken);

      await _connectRealtime();
    } catch (error) {
      if (!mounted) {
        return;
      }

      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _closeRemoteRoom() async {
    final story = _story;
    final accessToken = _accessToken();

    if (story == null || accessToken == null) {
      return;
    }

    setState(() => _loading = true);

    try {
      await ref.read(storyApiProvider).closeRemoteRoom(accessToken, story.id);
      await _socket?.disconnect();
      await _disposeCallController();

      final refreshed = await ref
          .read(storyApiProvider)
          .getStorySession(accessToken, story.id);

      setState(() {
        _remoteRoom = null;
        _participantToken = null;
        _signalingWsUrl = null;
        _rtcConfig = null;
        _joinCode = null;
        _joinLink = null;
        _joinExpiresAt = null;
        _story = refreshed;
      });

      ref.read(storyRoomControllerProvider.notifier).setParticipantToken(null);
    } catch (error) {
      if (!mounted) {
        return;
      }

      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    final story = _story;

    if (text.isEmpty || story == null) {
      return;
    }

    final bearerToken = widget.isGuest ? _participantToken : _accessToken();
    if (bearerToken == null) {
      return;
    }

    setState(() => _sendingChat = true);

    try {
      final interaction = await ref
          .read(storyApiProvider)
          .createRemoteChat(bearerToken, story.id, messageText: text);

      setState(() {
        _chatController.clear();
      });
      _appendInteractionIfMissing(interaction);
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _sendingChat = false);
      }
    }
  }

  Future<void> _sendReaction(String emoji) async {
    final story = _story;
    if (story == null) {
      return;
    }

    final bearerToken = widget.isGuest ? _participantToken : _accessToken();
    if (bearerToken == null) {
      return;
    }

    try {
      final interaction = await ref
          .read(storyApiProvider)
          .createRemoteReaction(bearerToken, story.id, emoji: emoji);

      _appendInteractionIfMissing(interaction);
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showError(error);
    }
  }

  Future<void> _changeStoryMode(StoryMode mode) async {
    final story = _story;
    final accessToken = _accessToken();
    if (story == null || accessToken == null || widget.isGuest) {
      return;
    }

    try {
      final updated = await ref
          .read(storyApiProvider)
          .updateMode(accessToken, story.id, mode);

      setState(() {
        _story = updated;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showError(error);
    }
  }

  Future<void> _sendGuestChoice(StoryChoiceOption option) async {
    if (!widget.isGuest) {
      return;
    }

    final story = _story;
    final participantToken = _participantToken;

    if (story == null || participantToken == null) {
      return;
    }

    try {
      if (_remoteRoom?.callMode == RemoteCallMode.coop) {
        final result = await ref
            .read(storyApiProvider)
            .createCoopVote(
              participantToken,
              story.id,
              stepIndex: story.currentStepIndex + 1,
              selectedOptionLabel: option.label,
              selectedOptionId: option.id,
            );
        setState(() {
          _myVoteOptionId = option.id;
          if (result.stepResult?.story != null) {
            _story = result.stepResult!.story;
            _participantVotes = {};
            _myVoteOptionId = null;
          } else {
            // Vote registered locally for feedback
            _participantVotes[result.participantId ?? 'me'] = option.id;
          }
        });
        return;
      }

      final result = await ref
          .read(storyApiProvider)
          .createRemoteGuestStep(
            participantToken,
            story.id,
            stepIndex: story.currentStepIndex + 1,
            selectedOptionLabel: option.label,
            selectedOptionId: option.id,
            localEventId:
                '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
          );

      setState(() {
        _story = result.story;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      context.showError(error);
    }
  }

  void _setCallMode(RemoteCallMode mode) {
    if (widget.isGuest) {
      context.showMessage('Somente o host pode alterar o modo da chamada.');
      return;
    }

    final room = _remoteRoom;
    if (room == null) {
      return;
    }

    _socket?.send('call.mode.set', {'mode': remoteCallModeToApi(mode)});
    setState(() {
      _remoteRoom = room.copyWith(callMode: mode);
    });
    unawaited(_callController?.setMode(mode));
  }

  Future<void> _disposeCallController() async {
    final call = _callController;
    if (call == null) {
      return;
    }

    _callController = null;
    call.removeListener(_onCallControllerChanged);
    await call.disposeController();
  }

  void _onCallControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _initCallController() async {
    final rtcConfig = _rtcConfig;
    if (rtcConfig == null || rtcConfig.isEmpty || _socket == null) {
      return;
    }

    await _disposeCallController();

    final call = RemoteCallController(
      isHost: !widget.isGuest,
      rtcConfig: rtcConfig,
      sendSignal: (event, payload) {
        _socket?.send(event, payload);
      },
    );
    call.addListener(_onCallControllerChanged);
    _callController = call;

    await call.initialize();
    await call.setMode(_remoteRoom?.callMode ?? RemoteCallMode.audio);
    await call.ensureHostOfferIfNeeded(
      participantCount: _remoteRoom?.participants.length ?? 0,
    );
  }

  List<StoryChoiceOption> _currentOptions() {
    final story = _story;
    if (story == null) {
      return const [];
    }

    for (final step in story.steps.reversed) {
      if (step.childOptions.isNotEmpty) {
        return step.childOptions;
      }
    }

    return const [
      StoryChoiceOption(id: 'opt-1', label: 'Conversar com calma'),
      StoryChoiceOption(id: 'opt-2', label: 'Pedir ajuda a um amigo'),
      StoryChoiceOption(id: 'opt-3', label: 'Tentar um plano criativo'),
    ];
  }

  Map<String, List<String>> _getVotesByOption() {
    final result = <String, List<String>>{};
    _participantVotes.forEach((pid, oid) {
      result.putIfAbsent(oid, () => []).add(pid);
    });
    return result;
  }

  Future<void> _showCreateRemoteSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return CreateRemoteSessionSheet(
          loading: _loading,
          hasRoom: _remoteRoom != null,
          joinCode: _joinCode,
          joinLink: _joinLink,
          expiresAt: _joinExpiresAt,
          onOpen: () async {
            Navigator.of(context).pop();
            await _openRemoteRoom();
          },
          onRegenerate: () async {
            Navigator.of(context).pop();
            await _regenerateCode();
          },
          onEnterRoom: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;

    if (_loading && story == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sala remota')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error ?? 'Sessão remota não encontrada.'),
          ),
        ),
      );
    }

    final room = _remoteRoom;
    final options = _currentOptions();
    final call = _callController;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sala remota · ${story.title}'),
        actions: [
          if (!widget.isGuest)
            IconButton(
              onPressed: _showCreateRemoteSheet,
              icon: const Icon(Icons.link),
              tooltip: 'Criar/gerenciar código',
            ),
          if (!widget.isGuest && room != null)
            IconButton(
              onPressed: _loading ? null : _closeRemoteRoom,
              icon: const Icon(Icons.call_end),
              tooltip: 'Encerrar sala remota',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.isGuest ? () async {} : _loadHostState,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: widget.isGuest ? 'Convidado Online' : 'Sala Remota',
              subtitle: 'Sincronização em tempo real da aventura.',
              assetPath: ViscondeArtRegistry.resolve(
                ViscondeArtKey.heroUnderwater,
              ),
              showMascot: true,
              mascotPose: ViscondeMascotPose.winkingWavingController,
            ),
            const SizedBox(height: 12),
            ViscondeGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isGuest ? 'Convidado conectado' : 'Host conectado',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('História: ${story.title}'),
                    Text('Etapa atual: ${story.currentStepIndex}/12'),
                    if (room != null) ...[
                      Text('Status sala: ${room.status.name.toUpperCase()}'),
                      Text('Participantes online: ${room.participants.length}'),
                    ] else ...[
                      const Text('Sala remota ainda não aberta.'),
                    ],
                    if (_joinCode != null && _joinCode!.isNotEmpty)
                      Text('Código ativo: $_joinCode'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.isGuest)
              SegmentedButton<StoryMode>(
                segments: const [
                  ButtonSegment(
                    value: StoryMode.parentNarrator,
                    label: Text('Pai narrador'),
                  ),
                  ButtonSegment(
                    value: StoryMode.childChooser,
                    label: Text('Criança escolhe'),
                  ),
                ],
                selected: <StoryMode>{story.currentMode},
                onSelectionChanged: (values) {
                  _changeStoryMode(values.first);
                },
              ),
            const SizedBox(height: 12),
            ViscondeGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo de chamada (MVP)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Sem chamada'),
                          selected: room?.callMode == RemoteCallMode.none,
                          onSelected: widget.isGuest
                              ? null
                              : (_) => _setCallMode(RemoteCallMode.none),
                        ),
                        ChoiceChip(
                          label: const Text('Áudio'),
                          selected: room?.callMode == RemoteCallMode.audio,
                          onSelected: widget.isGuest
                              ? null
                              : (_) => _setCallMode(RemoteCallMode.audio),
                        ),
                        ChoiceChip(
                          label: const Text('Vídeo'),
                          selected: room?.callMode == RemoteCallMode.video,
                          onSelected: widget.isGuest
                              ? null
                              : (_) => _setCallMode(RemoteCallMode.video),
                        ),
                        ChoiceChip(
                          label: const Text('Co-op / Votação'),
                          selected: room?.callMode == RemoteCallMode.coop,
                          onSelected: widget.isGuest
                              ? null
                              : (_) => _setCallMode(RemoteCallMode.coop),
                        ),
                      ],
                    ),
                    if (call != null) ...[
                      const SizedBox(height: 8),
                      Text('RTC: ${call.connectionState}'),
                      if (call.errorMessage != null &&
                          call.errorMessage!.trim().isNotEmpty)
                        Text(
                          call.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      if (room?.callMode == RemoteCallMode.audio)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Áudio ativo (vídeo opcional).'),
                        ),
                      if (room?.callMode == RemoteCallMode.video)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child:
                                          call.remoteRenderer.srcObject != null
                                          ? RTCVideoView(
                                              call.remoteRenderer,
                                              objectFit: RTCVideoViewObjectFit
                                                  .RTCVideoViewObjectFitCover,
                                            )
                                          : const Center(
                                              child: Text(
                                                'Aguardando vídeo remoto...',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  width: 110,
                                  height: 150,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child:
                                          call.localRenderer.srcObject != null
                                          ? RTCVideoView(
                                              call.localRenderer,
                                              mirror: true,
                                              objectFit: RTCVideoViewObjectFit
                                                  .RTCVideoViewObjectFitCover,
                                            )
                                          : const Center(
                                              child: Text(
                                                'Sem câmera',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.isGuest && story.currentMode == StoryMode.childChooser)
              ChildChoicePanel(
                enabled: _myVoteOptionId == null,
                options: options,
                onSelect: _sendGuestChoice,
                selectedOptionId: _myVoteOptionId,
                participants: room?.participants ?? [],
                votesByOption: _getVotesByOption(),
              )
            else
              ViscondeGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    story.currentMode == StoryMode.childChooser
                        ? 'Aguardando escolha do convidado.'
                        : 'Host em modo narrador. O convidado acompanha em tempo real.',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Chat e reações',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ..._interactions.map(
              (item) => ViscondeGlassCard(
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    child: Text(
                      item.authorRole == RemoteParticipantRole.hostParent
                          ? 'H'
                          : 'C',
                    ),
                  ),
                  title: Text(item.authorDisplayName),
                  subtitle: Text(item.messageText ?? item.emoji ?? '-'),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      labelText: 'Mensagem (max 160)',
                    ),
                    maxLength: 160,
                  ),
                ),
                const SizedBox(width: 8),
                ViscondePrimaryCta(
                  onPressed: _sendingChat ? null : _sendChat,
                  label: 'Enviar',
                  fullWidth: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['👍', '👏', '❤️', '😂', '😮', '🎉', '💡', '🌟']
                  .map(
                    (emoji) => ActionChip(
                      label: Text(emoji),
                      onPressed: () => _sendReaction(emoji),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
