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
        const ViscondeSkeletonCard(lines: 4),
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
    final wallet = _wallet;
    final progression = _progression;
    final primaryMission = _primaryMission(progression);
    final gate = ref.watch(parentalGateControllerProvider);
    final unlockActive =
        gate.isUnlocked && gate.expiresAt != null && gate.unlockToken != null;
    final dateFormat = DateFormat('dd/MM HH:mm');

    return RefreshIndicator(
      onRefresh: _retryGameLoad,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Hero Banner with "Loja" pill ──
          _buildGameHubHero(context),
          const SizedBox(height: 12),

          if (_loadingInitial) _buildInitialSkeleton(),
          if (_loadingInitial) const SizedBox(height: 12),
          if (!_loadingInitial && _blockingError != null && !_hasCoreData) ...[
            ViscondeContentState.error(
              title: UiStateCopy.genericErrorTitle,
              description:
                  _blockingError ?? UiStateCopy.genericErrorDescription,
              primaryActionLabel: 'Tentar novamente',
              onPrimaryAction: _retryGameLoad,
              secondaryActionLabel: 'Ir para Histórias',
              onSecondaryAction: _openStoriesHome,
            ),
            const SizedBox(height: 12),
          ],
          if (!_loadingInitial && _inlineError != null && _hasCoreData) ...[
            ViscondeContentState.error(
              title: UiStateCopy.genericErrorTitle,
              description: _inlineError!,
              primaryActionLabel: 'Tentar novamente',
              onPrimaryAction: _retryGameLoad,
            ),
            const SizedBox(height: 12),
          ],
          if (_loadingData)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),

          if (_loadingInitial || (_blockingError != null && !_hasCoreData))
            const SizedBox.shrink()
          else ...[
            // ── Adult gate card ──
            ViscondeGlassCard(
              child: ListTile(
                leading: Icon(
                  unlockActive
                      ? Icons.verified_user
                      : Icons.lock_clock_outlined,
                  color: unlockActive ? Colors.green : null,
                ),
                title: Text(
                  unlockActive
                      ? 'Área adulta liberada'
                      : 'Área adulta bloqueada',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  unlockActive
                      ? 'Liberada até ${dateFormat.format(gate.expiresAt!)} para compras e ações protegidas.'
                      : 'Desbloqueie com PIN para evitar interrupções durante as compras.',
                ),
                trailing: OutlinedButton(
                  onPressed: () {
                    ref
                        .read(parentalUnlockServiceProvider)
                        .ensureUnlocked(
                          context,
                          forcePrompt: unlockActive,
                          showSuccessMessage: true,
                          source: unlockActive
                              ? 'game_hub_unlock_renew'
                              : 'game_hub_unlock_manual',
                        );
                  },
                  child: Text(unlockActive ? 'Renovar' : 'Desbloquear'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Weekly mission highlight ──
            if (primaryMission != null) ...[
              ViscondeGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta da semana',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        primaryMission.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(primaryMission.description),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: primaryMission.targetValue == 0
                            ? 0
                            : (primaryMission.progressValue /
                                      primaryMission.targetValue)
                                  .clamp(0, 1)
                                  .toDouble(),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${primaryMission.progressValue}/${primaryMission.targetValue} • ${_missionStatusLabel(primaryMission.status)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Child selector ──
            if (_children.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedChildId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Criança'),
                items: _children
                    .map(
                      (child) => DropdownMenuItem<String>(
                        value: child.id,
                        child: Text(child.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _selectedChildId = value);
                  await _loadData();
                },
              ),
              const SizedBox(height: 12),
            ],

            // ── Wallet Card (illustrated) ──
            _buildWalletCard(context, wallet),
            const SizedBox(height: 12),

            // ── Streak Card (illustrated) ──
            _buildStreakCard(context, progression),
            const SizedBox(height: 12),

            // ── Weekly Missions Section ──
            _buildWeeklyMissionsSection(context, progression),
            const SizedBox(height: 12),

            // ── Achievements Section ──
            _buildAchievementsSection(context, dateFormat),
            const SizedBox(height: 12),

            // ── Collector Section ──
            _buildCollectorSection(context),
            const SizedBox(height: 12),

            // ── Shop & Catalog ──
            _buildShopSection(context),
            const SizedBox(height: 12),

            // ── Equipped Items ──
            _buildEquippedItemsCard(context, progression),
          ],
        ],
      ),
    );
  }

  // ── Hero banner with "Loja" pill button ──
  Widget _buildGameHubHero(BuildContext context) {
    return ViscondeHeroBanner(
      title: 'Game Hub',
      subtitle: 'Progresso saudável,\nmissões e cosméticos.',
      assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroUnderwater),
      showMascot: true,
      mascotPose: ViscondeMascotPose.thumbsUpController,
    );
  }

  // ── Wallet Card with illustration ──
  Widget _buildWalletCard(BuildContext context, WalletModel? wallet) {
    final colors = context.viscondeColors;

    return ViscondeGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carteira',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: const Color(0xFFDAA520),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Coin: ${wallet?.coins ?? 0}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: const Color(0xFFDAA520),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Estrelas: ${wallet?.stars ?? 0}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            height: 90,
            child: Image.asset(
              ViscondeArtRegistry.resolve(ViscondeArtKey.heroTreasure),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Streak Card with illustration ──
  Widget _buildStreakCard(
    BuildContext context,
    ChildProgressionModel? progression,
  ) {
    final colors = context.viscondeColors;

    return ViscondeGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streak',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Atual: ${progression?.streak.currentDays ?? 0} dias',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Melhor: ${progression?.streak.bestDays ?? 0} dias',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Escudos: ${progression?.streak.shieldCount ?? 0}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 80,
            height: 80,
            child: ViscondeMascot(
              pose: ViscondeMascotPose.pointingScroll,
              glow: true,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Missions Section ──
  Widget _buildWeeklyMissionsSection(
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Objetivos da semana por criança.',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                  Icon(
                    Icons.star_rounded,
                    color: const Color(0xFFDAA520),
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
        ] else
          ...missions.map(
            (mission) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ViscondeGlassCard(
                child: ListTile(
                  title: Text(mission.title),
                  subtitle: Text(
                    '${mission.description}\n${mission.progressValue}/${mission.targetValue} · ${_missionStatusLabel(mission.status)}',
                  ),
                  trailing: Text(
                    '+${mission.rewardCoins} / +${mission.rewardStars}⭐',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ),
      ],
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

  // ── Achievements Section ──
  Widget _buildAchievementsSection(
    BuildContext context,
    DateFormat dateFormat,
  ) {
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
              Icon(
                Icons.emoji_events_rounded,
                color: const Color(0xFFDAA520),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conquistas',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
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
        const SizedBox(height: 8),
        if (showEmpty) ...[
          ViscondeContentState.empty(
            title: UiStateCopy.gameAchievementsEmptyTitle,
            description: UiStateCopy.gameAchievementsEmptyDescription,
            primaryActionLabel: 'Criar história',
            onPrimaryAction: _openCreateStory,
            mascotPose: ViscondeMascotPose.enchantedHearts,
          ),
        ] else
          ..._achievements.map(
            (achievement) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ViscondeGlassCard(
                child: ListTile(
                  leading: Icon(
                    achievement.unlocked
                        ? Icons.emoji_events
                        : Icons.lock_outline,
                    color: achievement.unlocked ? Colors.amber.shade700 : null,
                  ),
                  title: Text(achievement.title),
                  subtitle: Text(
                    '${achievement.description}\n+${achievement.rewardCoins} moedas / +${achievement.rewardStars}⭐'
                    '${achievement.unlockedAt != null ? '\nDesbloqueada em ${dateFormat.format(achievement.unlockedAt!)}' : ''}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ),
      ],
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
        const SizedBox(height: 6),
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
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.icon,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.rarity} · Qtd: ${inv.qty}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
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
  Widget _buildShopSection(BuildContext context) {
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
        const SizedBox(height: 8),
        if (showEmpty) ...[
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
        ] else
          ..._catalog.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ViscondeGlassCard(
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.description}\n${item.priceCoins} moedas / ${item.priceStars}⭐ · ${item.type.name.toUpperCase()}',
                  ),
                  trailing: item.unlocked
                      ? OutlinedButton(
                          onPressed: () => _toggleEquip(item),
                          child: Text(item.equipped ? 'Desequipar' : 'Equipar'),
                        )
                      : FilledButton(
                          onPressed: () => _unlockItem(item),
                          child: const Text('Desbloquear'),
                        ),
                  isThreeLine: true,
                ),
              ),
            ),
          ),
      ],
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
                (item) => Text('- ${item.name} (${item.type.name})'),
              ),
          ],
        ),
      ),
    );
  }
}
