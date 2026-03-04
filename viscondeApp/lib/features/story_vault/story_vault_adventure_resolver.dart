import '../../shared/api_error.dart';
import '../story_room/models/story_models.dart';
import '../story_room/story_api.dart';

enum StoryVaultAdventureOutcome {
  draftOpened,
  continuedOpened,
  noEpisodes,
  failed,
}

class StoryVaultAdventureResult {
  const StoryVaultAdventureResult({
    required this.outcome,
    this.storyId,
    this.message,
    this.code,
    this.recoveredFromConflict = false,
  });

  final StoryVaultAdventureOutcome outcome;
  final String? storyId;
  final String? message;
  final String? code;
  final bool recoveredFromConflict;

  bool get hasStoryTarget => storyId != null && storyId!.trim().isNotEmpty;
}

class StoryVaultAdventureResolver {
  const StoryVaultAdventureResolver(this._storyApi);

  final StoryApi _storyApi;

  Future<StoryVaultAdventureResult> resolve({
    required String accessToken,
    required String collectionId,
    StoryVaultCollectionItem? collectionItem,
  }) async {
    StoryVaultCollectionDetail? cachedDetail;

    Future<StoryVaultCollectionDetail> loadDetail() async {
      cachedDetail ??= await _storyApi.getStoryVaultCollection(
        accessToken,
        collectionId,
      );
      return cachedDetail!;
    }

    if ((collectionItem?.draftCount ?? 0) > 0) {
      final latestEpisode = collectionItem?.latestEpisode;
      if (latestEpisode != null &&
          latestEpisode.status == StoryStatus.draft &&
          latestEpisode.storyId.trim().isNotEmpty) {
        return StoryVaultAdventureResult(
          outcome: StoryVaultAdventureOutcome.draftOpened,
          storyId: latestEpisode.storyId,
        );
      }

      try {
        final detail = await loadDetail();
        final latestDraft = _latestDraftEpisode(detail);
        if (latestDraft != null) {
          return StoryVaultAdventureResult(
            outcome: StoryVaultAdventureOutcome.draftOpened,
            storyId: latestDraft.storyId,
          );
        }
      } catch (_) {
        // Segue para o fallback de continuação.
      }
    }

    var sourceStoryId = collectionItem?.latestEpisode?.storyId;
    if (sourceStoryId == null || sourceStoryId.trim().isEmpty) {
      try {
        final detail = await loadDetail();
        sourceStoryId = _latestEpisode(detail)?.storyId;
      } catch (_) {
        sourceStoryId = null;
      }
    }

    if (sourceStoryId == null || sourceStoryId.trim().isEmpty) {
      return const StoryVaultAdventureResult(
        outcome: StoryVaultAdventureOutcome.noEpisodes,
        message: 'Esta saga ainda não possui capítulos para continuar.',
      );
    }

    try {
      final created = await _storyApi.continueStory(accessToken, sourceStoryId);
      return StoryVaultAdventureResult(
        outcome: StoryVaultAdventureOutcome.continuedOpened,
        storyId: created.id,
      );
    } catch (error) {
      final presentation = describeApiError(error);
      if (presentation.code == 'STORY_COLLECTION_DRAFT_EXISTS') {
        try {
          final detail = await loadDetail();
          final latestDraft = _latestDraftEpisode(detail);
          if (latestDraft != null) {
            return StoryVaultAdventureResult(
              outcome: StoryVaultAdventureOutcome.draftOpened,
              storyId: latestDraft.storyId,
              recoveredFromConflict: true,
            );
          }
        } catch (_) {
          // Sem recuperação possível pelo detalhe: retorna erro abaixo.
        }
      }

      return StoryVaultAdventureResult(
        outcome: StoryVaultAdventureOutcome.failed,
        message: presentation.message,
        code: presentation.code,
      );
    }
  }

  StoryVaultEpisodeDetail? _latestEpisode(StoryVaultCollectionDetail detail) {
    if (detail.episodes.isEmpty) {
      return null;
    }
    return detail.episodes.last;
  }

  StoryVaultEpisodeDetail? _latestDraftEpisode(
    StoryVaultCollectionDetail detail,
  ) {
    for (final episode in detail.episodes.reversed) {
      if (episode.status == StoryStatus.draft) {
        return episode;
      }
    }
    return null;
  }
}
