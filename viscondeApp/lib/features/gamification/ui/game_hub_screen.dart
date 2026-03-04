import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/ui_state_copy.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';
import '../../security/parental_gate_controller.dart';
import '../models/gamification_models.dart';

enum _GameHubLowerTab { missions, achievements }

class GameHubScreen extends ConsumerStatefulWidget {
  const GameHubScreen({super.key});

  @override
  ConsumerState<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends ConsumerState<GameHubScreen> {
  bool _loadingInitial = true;
  bool _loadingData = false;
  WalletModel? _wallet;
  List<AchievementModel> _achievements = const [];
  List<ChildProfile> _children = const [];
  ChildProgressionModel? _progression;
  String? _selectedChildId;
  String? _blockingError;
  String? _inlineError;
  bool _gameHubOpenedLogged = false;
  String? _lastTrackedState;
  final Set<String> _trackedSectionStates = <String>{};
  _GameHubLowerTab _selectedLowerTab = _GameHubLowerTab.missions;

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  WeeklyMissionModel? _primaryMission(ChildProgressionModel? progression) {
    if (progression == null || progression.weeklyMissions.isEmpty) {
      return null;
    }

    double progressRatio(WeeklyMissionModel mission) {
      if (mission.targetValue <= 0) {
        return 0;
      }
      return mission.progressValue / mission.targetValue;
    }

    final activeMissions = progression.weeklyMissions
        .where((mission) => mission.status == WeeklyMissionStatus.active)
        .toList();
    if (activeMissions.isNotEmpty) {
      activeMissions.sort(
        (a, b) => progressRatio(b).compareTo(progressRatio(a)),
      );
      return activeMissions.first;
    }

    return progression.weeklyMissions.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() {
      _loadingInitial = true;
      _blockingError = null;
      _inlineError = null;
    });
    _trackGameState('loading');
    try {
      final children = await ref.read(childrenApiProvider).listChildren(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _children = children;
        _selectedChildId =
            _selectedChildId ??
            (children.isNotEmpty ? children.first.id : null);
        _blockingError = null;
        _inlineError = null;
      });
      _logGameHubOpenedIfNeeded();

      await _loadData(isInitial: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = parseDioError(error);
      setState(() => _blockingError = message);
      _trackGameState('error_blocking');
    } finally {
      if (mounted) {
        setState(() => _loadingInitial = false);
        _trackGameState(_computeGlobalState());
      }
    }
  }

  void _logGameHubOpenedIfNeeded() {
    if (_gameHubOpenedLogged) {
      return;
    }

    _gameHubOpenedLogged = true;
    final childId = _selectedChildId;
    UxAnalytics.log(
      'game_hub_opened',
      params: <String, Object?>{
        'child_id': childId,
        'selected_child': childId,
        'source': 'game_hub_screen',
      },
    );
  }

  Future<void> _loadData({bool isInitial = false}) async {
    final token = _accessToken();
    final childId = _selectedChildId;

    if (token == null || childId == null) {
      return;
    }

    _trackedSectionStates.clear();
    setState(() => _loadingData = true);
    try {
      final results = await Future.wait([
        ref.read(gamificationApiProvider).fetchWallet(token),
        ref.read(gamificationApiProvider).listAchievements(token),
        ref
            .read(gamificationApiProvider)
            .fetchChildProgression(token, childId: childId),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _wallet = results[0] as WalletModel;
        _achievements = results[1] as List<AchievementModel>;
        _progression = results[2] as ChildProgressionModel;
        _blockingError = null;
        _inlineError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = parseDioError(error);
      setState(() {
        if ((isInitial || _hasCoreData == false) && _blockingError == null) {
          _blockingError = message;
        } else {
          _inlineError = message;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingData = false);
        _trackGameState(_computeGlobalState());
      }
    }
  }

  String _missionStatusLabel(WeeklyMissionStatus value) {
    switch (value) {
      case WeeklyMissionStatus.completed:
        return 'Concluída';
      case WeeklyMissionStatus.expired:
        return 'Expirada';
      case WeeklyMissionStatus.active:
        return 'Ativa';
    }
  }

  Color _missionStatusColor(BuildContext context, WeeklyMissionStatus value) {
    final colors = context.viscondeColors;
    switch (value) {
      case WeeklyMissionStatus.completed:
        return Colors.green.shade700;
      case WeeklyMissionStatus.expired:
        return colors.textMuted;
      case WeeklyMissionStatus.active:
        return colors.primaryDark;
    }
  }

  bool get _hasCoreData {
    return _wallet != null || _progression != null;
  }

  String _computeGlobalState() {
    if (_loadingInitial) {
      return 'loading';
    }

    if (_blockingError != null && !_hasCoreData) {
      return 'error_blocking';
    }

    if (_hasCoreData == false) {
      return 'empty';
    }

    return 'content';
  }

  void _trackGameState(String state) {
    if (_lastTrackedState == state) {
      return;
    }
    _lastTrackedState = state;
    UxAnalytics.log(
      'game_state_shown',
      params: <String, Object?>{
        'screen': 'game',
        'state': state,
        'source': 'game_hub_screen',
      },
    );
  }

  void _trackGameSectionState(String state) {
    if (_trackedSectionStates.contains(state)) {
      return;
    }
    _trackedSectionStates.add(state);
    UxAnalytics.log(
      'game_state_shown',
      params: <String, Object?>{
        'screen': 'game',
        'state': state,
        'source': 'game_hub_screen',
      },
    );
  }

  void _trackLowerTabSwitched(_GameHubLowerTab tab) {
    final childId = _selectedChildId;
    UxAnalytics.log(
      'game_hub_tab_switched',
      params: <String, Object?>{
        'tab': tab == _GameHubLowerTab.missions ? 'missions' : 'achievements',
        'child_id': childId,
        'source': 'game_hub_screen',
      },
    );
  }

  Future<void> _retryGameLoad() async {
    UxAnalytics.log(
      'game_retry_tapped',
      params: const <String, Object?>{
        'screen': 'game',
        'source': 'game_hub_screen',
      },
    );
    if (_hasCoreData == false) {
      await _bootstrap();
      return;
    }
    await _loadData();
  }

  void _openStoriesHome() {
    _trackGameEmptyCta('open_stories');
    context.go(AppRoute.home);
  }

  void _openCreateStory() {
    _trackGameEmptyCta('create_story');
    context.push(AppRoute.storyCreate);
  }

  void _trackGameEmptyCta(String cta) {
    UxAnalytics.log(
      'game_empty_cta_tapped',
      params: <String, Object?>{
        'screen': 'game',
        'cta': cta,
        'state': _computeGlobalState(),
        'source': 'game_hub_screen',
      },
    );
  }

  Widget _buildInitialSkeleton() {
    return Column(
      children: [
        const ViscondeSkeletonCard(lines: 3),
        const SizedBox(height: 10),
        const ViscondeSkeletonCard(lines: 4),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: ViscondeSkeletonCard(lines: 4)),
            SizedBox(width: 12),
            Expanded(child: ViscondeSkeletonCard(lines: 4)),
          ],
        ),
        const SizedBox(height: 10),
        ...List<Widget>.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: ViscondeSkeletonCard(lines: 3),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progression = _progression;
    final primaryMission = _primaryMission(progression);
    final gate = ref.watch(parentalGateControllerProvider);
    final dateFormat = DateFormat('dd/MM HH:mm');

    return RefreshIndicator(
      onRefresh: _retryGameLoad,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildCompactGamifiedHeader(context, gate)),

          if (_loadingInitial)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: _buildInitialSkeleton()),
            ),

          if (!_loadingInitial && _blockingError != null && !_hasCoreData)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: ViscondeContentState.error(
                  title: UiStateCopy.genericErrorTitle,
                  description:
                      _blockingError ?? UiStateCopy.genericErrorDescription,
                  primaryActionLabel: 'Tentar novamente',
                  onPrimaryAction: _retryGameLoad,
                  secondaryActionLabel: 'Ir para Histórias',
                  onSecondaryAction: _openStoriesHome,
                ),
              ),
            ),

          if (!_loadingInitial && _inlineError != null && _hasCoreData)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ViscondeContentState.error(
                    title: UiStateCopy.genericErrorTitle,
                    description: _inlineError!,
                    primaryActionLabel: 'Tentar novamente',
                    onPrimaryAction: _retryGameLoad,
                  ),
                ),
              ),
            ),

          if (_loadingData)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: LinearProgressIndicator(),
              ),
            ),

          if (!_loadingInitial && (_blockingError == null || _hasCoreData)) ...[
            if (primaryMission != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: _buildMainQuestCard(context, primaryMission),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildWeeklyMissionsHeader(context),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildLowerTabsSwitcher(context),
              ),
            ),

            if (_selectedLowerTab == _GameHubLowerTab.missions)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _buildWeeklyMissionsSliverList(progression),
              ),

            if (_selectedLowerTab == _GameHubLowerTab.achievements)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildAchievementsTabHeader(context),
                ),
              ),

            if (_selectedLowerTab == _GameHubLowerTab.achievements)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _buildAchievementsSliverList(dateFormat),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactGamifiedHeader(
    BuildContext context,
    ParentalGateState gate,
  ) {
    final colors = context.viscondeColors;
    final wallet = _wallet;
    final progression = _progression;
    final unlockActive = gate.isUnlocked;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.parchment, colors.parchment.withValues(alpha: 0)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem(
                context,
                icon: Icons.monetization_on_rounded,
                value: '${wallet?.coins ?? 0}',
                color: const Color(0xFFDAA520),
              ),
              const SizedBox(width: 8),
              _buildStatItem(
                context,
                icon: Icons.star_rounded,
                value: '${wallet?.stars ?? 0}',
                color: const Color(0xFFDAA520),
              ),
              const Spacer(),
              _buildStatItem(
                context,
                icon: Icons.local_fire_department_rounded,
                value: '${progression?.streak.currentDays ?? 0}d',
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ref
                      .read(parentalUnlockServiceProvider)
                      .ensureUnlocked(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: unlockActive
                        ? colors.primary.withValues(alpha: 0.1)
                        : colors.parchmentSoft.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    unlockActive ? Icons.verified_user : Icons.lock_outline,
                    size: 16,
                    color: unlockActive ? Colors.green : colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_children.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: _children.map((child) {
                  final isSelected = child.id == _selectedChildId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _selectedChildId = child.id);
                        await _loadData();
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: colors.parchmentSoft,
                              backgroundImage: child.avatarUrl != null
                                  ? NetworkImage(child.avatarUrl!)
                                  : null,
                              child: child.avatarUrl == null
                                  ? Icon(Icons.person, color: colors.textMuted)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            child.name,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colors.textStrong
                                      : colors.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final colors = context.viscondeColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.parchment,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.viscondeElevations.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: colors.textStrong,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainQuestCard(BuildContext context, WeeklyMissionModel mission) {
    final colors = context.viscondeColors;
    final progress = mission.targetValue == 0
        ? 0.0
        : (mission.progressValue / mission.targetValue).clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.viscondeGradients.glass,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.viscondeElevations.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'META DA SEMANA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primaryDark,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: colors.textStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mission.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: colors.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 14, color: colors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${mission.progressValue}/${mission.targetValue}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textMuted,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.monetization_on_rounded,
                size: 14,
                color: Color(0xFFDAA520),
              ),
              const SizedBox(width: 4),
              Text(
                '+${mission.rewardCoins}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.textStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyMissionsHeader(BuildContext context) {
    final colors = context.viscondeColors;
    return ViscondeGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missões Semanais',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Objetivos da semana por criança.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMiniBox(context),
              const SizedBox(width: 4),
              _buildMiniBox(context),
              const SizedBox(width: 6),
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFDAA520),
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBox(BuildContext context) {
    return Container(
      width: 18,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.viscondeColors.textMuted.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
    );
  }

  Widget _buildLowerTabsSwitcher(BuildContext context) {
    final colors = context.viscondeColors;
    return ViscondeGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_GameHubLowerTab>(
          key: const Key('game_hub_lower_tabs'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<_GameHubLowerTab>(
              value: _GameHubLowerTab.missions,
              label: Text('Missões'),
              icon: Icon(Icons.flag_rounded, size: 18),
            ),
            ButtonSegment<_GameHubLowerTab>(
              value: _GameHubLowerTab.achievements,
              label: Text('Conquistas'),
              icon: Icon(Icons.emoji_events_rounded, size: 18),
            ),
          ],
          selected: <_GameHubLowerTab>{_selectedLowerTab},
          onSelectionChanged: (values) {
            if (values.isEmpty) {
              return;
            }
            final next = values.first;
            if (next == _selectedLowerTab) {
              return;
            }
            setState(() => _selectedLowerTab = next);
            _trackLowerTabSwitched(next);
          },
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
            textStyle: WidgetStateProperty.all(
              Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textStrong,
              ),
            ),
          ),
        ),
      ),
    );
  }

  SliverMultiBoxAdaptorWidget _buildWeeklyMissionsSliverList(
    ChildProgressionModel? progression,
  ) {
    final missions =
        progression?.weeklyMissions ?? const <WeeklyMissionModel>[];
    if (missions.isEmpty) {
      _trackGameSectionState('empty_missions');
      return SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 8),
          ViscondeContentState.empty(
            title: UiStateCopy.gameMissionsEmptyTitle,
            description: UiStateCopy.gameMissionsEmptyDescription,
            primaryActionLabel: 'Ler histórias',
            onPrimaryAction: _openStoriesHome,
            mascotPose: ViscondeMascotPose.pointingScroll,
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final mission = missions[index];
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildWeeklyMissionCard(context, mission),
        );
      }, childCount: missions.length),
    );
  }

  Widget _buildWeeklyMissionCard(
    BuildContext context,
    WeeklyMissionModel mission,
  ) {
    final colors = context.viscondeColors;
    final safeTarget = mission.targetValue <= 0 ? 1 : mission.targetValue;
    final progress = (mission.progressValue / safeTarget).clamp(0.0, 1.0);
    final progressPercent = (progress * 100).toInt();
    final statusColor = _missionStatusColor(context, mission.status);

    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.textStrong,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _missionStatusLabel(mission.status),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mission.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${mission.progressValue}/${mission.targetValue}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progressPercent%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _buildRewardChip(
                context,
                icon: Icons.monetization_on_rounded,
                label: '+${mission.rewardCoins}',
              ),
              const SizedBox(width: 6),
              _buildRewardChip(
                context,
                icon: Icons.star_rounded,
                label: '+${mission.rewardStars}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final colors = context.viscondeColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.parchment,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFDAA520)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textStrong,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTabHeader(BuildContext context) {
    final colors = context.viscondeColors;
    return ViscondeGlassCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDAA520).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFDAA520),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conquistas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                Text(
                  'Marcos desbloqueados e progresso atual.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverMultiBoxAdaptorWidget _buildAchievementsSliverList(
    DateFormat dateFormat,
  ) {
    if (_achievements.isEmpty) {
      _trackGameSectionState('empty_achievements');
      return SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 8),
          ViscondeContentState.empty(
            title: UiStateCopy.gameAchievementsEmptyTitle,
            description: UiStateCopy.gameAchievementsEmptyDescription,
            primaryActionLabel: 'Criar história',
            onPrimaryAction: _openCreateStory,
            mascotPose: ViscondeMascotPose.enchantedHearts,
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final achievement = _achievements[index];
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildAchievementCard(context, achievement, dateFormat),
        );
      }, childCount: _achievements.length),
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    AchievementModel achievement,
    DateFormat dateFormat,
  ) {
    final colors = context.viscondeColors;
    final unlocked = achievement.unlocked;
    final statusLabel = unlocked ? 'Desbloqueada' : 'Em progresso';
    final statusColor = unlocked ? Colors.green.shade700 : colors.textMuted;

    return ViscondeGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unlocked
                  ? const Color(0xFFDAA520).withValues(alpha: 0.16)
                  : colors.parchmentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              unlocked ? Icons.workspace_premium_rounded : Icons.lock_outline,
              color: unlocked ? const Color(0xFFDAA520) : colors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colors.textStrong,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildRewardChip(
                      context,
                      icon: Icons.monetization_on_rounded,
                      label: '+${achievement.rewardCoins}',
                    ),
                    const SizedBox(width: 6),
                    _buildRewardChip(
                      context,
                      icon: Icons.star_rounded,
                      label: '+${achievement.rewardStars}',
                    ),
                  ],
                ),
                if (achievement.unlockedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Desbloqueada em ${dateFormat.format(achievement.unlockedAt!)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
