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
import '../inventory_models.dart';

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
  List<CatalogItemModel> _catalog = const [];
  List<ChildInventoryModel> _childInventory = const [];
  String? _selectedChildId;
  CatalogItemType? _selectedCatalogType;
  String? _blockingError;
  String? _inlineError;
  bool _gameHubOpenedLogged = false;
  String? _lastTrackedState;
  final Set<String> _trackedSectionStates = <String>{};

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
        ref
            .read(gamificationApiProvider)
            .listCatalog(
              token,
              childProfileId: childId,
              type: _selectedCatalogType,
            ),
        ref.read(inventoryApiProvider).getChildInventory(childId, token),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _wallet = results[0] as WalletModel;
        _achievements = results[1] as List<AchievementModel>;
        _progression = results[2] as ChildProgressionModel;
        _catalog = results[3] as List<CatalogItemModel>;
        _childInventory = results[4] as List<ChildInventoryModel>;
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

  Future<void> _unlockItem(CatalogItemModel item) async {
    final token = _accessToken();
    final childId = _selectedChildId;
    if (token == null || childId == null) {
      return;
    }

    final unlockToken = await ref
        .read(parentalUnlockServiceProvider)
        .ensureUnlocked(context, source: 'game_hub_unlock_item');
    if (unlockToken == null) {
      return;
    }

    setState(() => _loadingData = true);
    try {
      final result = await ref
          .read(gamificationApiProvider)
          .unlockItem(
            token,
            childId: childId,
            itemId: item.id,
            parentalUnlockToken: unlockToken,
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item desbloqueado! -${result.spentCoins} moedas / -${result.spentStars} estrelas',
          ),
        ),
      );

      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loadingData = false);
      }
    }
  }

  Future<void> _toggleEquip(CatalogItemModel item) async {
    final token = _accessToken();
    final childId = _selectedChildId;
    if (token == null || childId == null) {
      return;
    }

    setState(() => _loadingData = true);
    try {
      await ref
          .read(gamificationApiProvider)
          .equipItem(
            token,
            childId: childId,
            itemId: item.id,
            equipped: !item.equipped,
          );
      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loadingData = false);
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
          // ── Compact Gamified Header ──
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
            // ── Main Quest (Primary Mission) ──
            if (primaryMission != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: _buildMainQuestCard(context, primaryMission),
                ),
              ),

            // ── Weekly Missions ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildWeeklyMissionsHeader(context, progression),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildWeeklyMissionsSliverList(progression),
            ),

            // ── Achievements ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildAchievementsHeader(context, dateFormat),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildAchievementsSliverList(dateFormat),
            ),

            // ── Collector / Shop ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _buildCollectorSection(context),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(child: _buildShopHeader(context)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildShopSliverGrid(),
            ),

            // ── Equipped Items ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              sliver: SliverToBoxAdapter(
                child: _buildEquippedItemsCard(context, progression),
              ),
            ),
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
          // ── Stats Bar ──
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
              // Compact Adult Gate Indicator
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
          // ── Visual Child Switcher ──
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

  // ── Weekly Missions ──
  Widget _buildWeeklyMissionsHeader(
    BuildContext context,
    ChildProgressionModel? progression,
  ) {
    final colors = context.viscondeColors;
    final missions =
        progression?.weeklyMissions ?? const <WeeklyMissionModel>[];
    final showEmpty = missions.isEmpty;
    if (showEmpty) {
      _trackGameSectionState('empty_missions');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ViscondeGlassCard(
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
        ),
        if (showEmpty) ...[
          const SizedBox(height: 8),
          ViscondeContentState.empty(
            title: UiStateCopy.gameMissionsEmptyTitle,
            description: UiStateCopy.gameMissionsEmptyDescription,
            primaryActionLabel: 'Ler histórias',
            onPrimaryAction: _openStoriesHome,
            mascotPose: ViscondeMascotPose.pointingScroll,
          ),
        ],
      ],
    );
  }

  Widget _buildWeeklyMissionsSliverList(ChildProgressionModel? progression) {
    final missions =
        progression?.weeklyMissions ?? const <WeeklyMissionModel>[];
    if (missions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final mission = missions[index];
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ViscondeGlassCard(
            child: ListTile(
              title: Text(mission.title),
              subtitle: Text(
                '${mission.description}\n${mission.progressValue}/${mission.targetValue} · ${_missionStatusLabel(mission.status)}',
              ),
              trailing: Text(
                '+${mission.rewardCoins} / +${mission.rewardStars}⭐',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              isThreeLine: true,
            ),
          ),
        );
      }, childCount: missions.length),
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

  // ── Achievements ──
  Widget _buildAchievementsHeader(BuildContext context, DateFormat dateFormat) {
    final colors = context.viscondeColors;
    final showEmpty = _achievements.isEmpty;
    if (showEmpty) {
      _trackGameSectionState('empty_achievements');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFDAA520),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conquistas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textStrong,
                      ),
                    ),
                    Text(
                      'Marcos já desbloqueados na conta.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showEmpty) ...[
          const SizedBox(height: 8),
          ViscondeContentState.empty(
            title: UiStateCopy.gameAchievementsEmptyTitle,
            description: UiStateCopy.gameAchievementsEmptyDescription,
            primaryActionLabel: 'Criar história',
            onPrimaryAction: _openCreateStory,
            mascotPose: ViscondeMascotPose.enchantedHearts,
          ),
        ],
      ],
    );
  }

  Widget _buildAchievementsSliverList(DateFormat dateFormat) {
    if (_achievements.isEmpty) {
      {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final achievement = _achievements[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ViscondeGlassCard(
            child: ListTile(
              leading: Icon(
                achievement.unlocked ? Icons.emoji_events : Icons.lock_outline,
                color: achievement.unlocked ? Colors.amber.shade700 : null,
              ),
              title: Text(
                achievement.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${achievement.description}\n+${achievement.rewardCoins} moedas / +${achievement.rewardStars}⭐'
                '${achievement.unlockedAt != null ? '\nDesbloqueada em ${dateFormat.format(achievement.unlockedAt!)}' : ''}',
              ),
              isThreeLine: true,
            ),
          ),
        );
      }, childCount: _achievements.length),
    );
  }

  // ── Collector Section ──
  Widget _buildCollectorSection(BuildContext context) {
    final showEmpty = _childInventory.isEmpty;
    if (showEmpty) {
      _trackGameSectionState('empty_collector');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ViscondeSectionTitle(
          title: 'O Colecionador',
          subtitle: 'Seus itens e companheiros de aventura.',
        ),
        const SizedBox(height: 8),
        if (showEmpty) ...[
          ViscondeContentState.empty(
            title: UiStateCopy.gameCollectorEmptyTitle,
            description: UiStateCopy.gameCollectorEmptyDescription,
            primaryActionLabel: 'Ler histórias',
            onPrimaryAction: _openStoriesHome,
            mascotPose: ViscondeMascotPose.readingBook,
          ),
        ],
        if (_childInventory.isNotEmpty)
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _childInventory.length,
              itemBuilder: (context, index) {
                final inv = _childInventory[index];
                final item = inv.item;
                if (item == null) return const SizedBox.shrink();

                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  child: ViscondeGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.icon,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Text(
                            '${item.rarity} · Qtd: ${inv.qty}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Shop & Catalog Section ──
  Widget _buildShopHeader(BuildContext context) {
    final showEmpty = _catalog.isEmpty;
    if (showEmpty) {
      _trackGameSectionState('empty_catalog');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ViscondeSectionTitle(
          title: 'Loja e Inventário',
          subtitle: 'Desbloqueie e equipe itens cosméticos.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _selectedCatalogType == null,
              onSelected: (_) async {
                setState(() => _selectedCatalogType = null);
                await _loadData();
              },
            ),
            ...CatalogItemType.values.map(
              (type) => ChoiceChip(
                label: Text(type.name.toUpperCase()),
                selected: _selectedCatalogType == type,
                onSelected: (_) async {
                  setState(() => _selectedCatalogType = type);
                  await _loadData();
                },
              ),
            ),
          ],
        ),
        if (showEmpty) ...[
          const SizedBox(height: 8),
          ViscondeContentState.empty(
            title: UiStateCopy.gameCatalogEmptyTitle,
            description: UiStateCopy.gameCatalogEmptyDescription,
            primaryActionLabel: 'Tentar novamente',
            onPrimaryAction: () {
              _trackGameEmptyCta('retry_catalog');
              _retryGameLoad();
            },
            mascotPose: ViscondeMascotPose.thumbsUpController,
          ),
        ],
      ],
    );
  }

  Widget _buildShopSliverGrid() {
    if (_catalog.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 220,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = _catalog[index];
        return _buildCatalogItemCard(context, item);
      }, childCount: _catalog.length),
    );
  }

  Widget _buildCatalogItemCard(BuildContext context, CatalogItemModel item) {
    final colors = context.viscondeColors;
    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(
                  item.iconKey.isNotEmpty ? item.iconKey : '✨',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.priceCoins} 💰 / ${item.priceStars} ⭐',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                item.unlocked
                    ? OutlinedButton(
                        onPressed: () => _toggleEquip(item),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Text(item.equipped ? 'Desequipar' : 'Equipar'),
                      )
                    : FilledButton(
                        onPressed: () => _unlockItem(item),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Comprar'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Equipped Items Card ──
  Widget _buildEquippedItemsCard(
    BuildContext context,
    ChildProgressionModel? progression,
  ) {
    final equipped = progression?.inventorySummary.equippedItems ?? const [];
    final showEmpty = equipped.isEmpty;
    if (showEmpty) {
      _trackGameSectionState('empty_equipped');
    }

    return ViscondeGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ViscondeSectionTitle(
              title: 'Itens equipados',
              subtitle: 'Veja o que já está ativo para a criança.',
            ),
            const SizedBox(height: 6),
            if (showEmpty) ...[
              ViscondeContentState.empty(
                title: UiStateCopy.gameEquippedEmptyTitle,
                description: UiStateCopy.gameEquippedEmptyDescription,
                primaryActionLabel: 'Abrir loja',
                onPrimaryAction: () {
                  _trackGameEmptyCta('open_shop');
                  _retryGameLoad();
                },
                mascotPose: ViscondeMascotPose.studyingDesk,
              ),
            ] else
              ...equipped.map(
                (item) => Text(
                  '- ${item.name} (${item.type.name})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
