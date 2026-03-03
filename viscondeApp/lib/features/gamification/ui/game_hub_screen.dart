import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
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
  bool _loading = false;
  WalletModel? _wallet;
  List<AchievementModel> _achievements = const [];
  List<ChildProfile> _children = const [];
  ChildProgressionModel? _progression;
  List<CatalogItemModel> _catalog = const [];
  List<ChildInventoryModel> _childInventory = const [];
  String? _selectedChildId;
  CatalogItemType? _selectedCatalogType;
  String? _loadError;
  bool _gameHubOpenedLogged = false;

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

    setState(() => _loading = true);
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
        _loadError = null;
      });
      _logGameHubOpenedIfNeeded();

      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = parseDioError(error);
      setState(() => _loadError = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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

  Future<void> _loadData() async {
    final token = _accessToken();
    final childId = _selectedChildId;

    if (token == null || childId == null) {
      return;
    }

    setState(() => _loading = true);
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
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = parseDioError(error);
      setState(() => _loadError = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _resolveUnlockToken({bool showSuccessMessage = false}) async {
    final gate = ref.read(parentalGateControllerProvider);
    if (gate.isUnlocked && gate.unlockToken != null) {
      return gate.unlockToken;
    }

    UxAnalytics.log('pin_prompt_shown');
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('PIN adulto'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Digite seu PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(pinController.text.trim()),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    pinController.dispose();

    if (pin == null || pin.length != 6) {
      UxAnalytics.log(
        'pin_prompt_abandon',
        params: <String, Object?>{'reason': 'cancel_or_invalid_length'},
      );
      return null;
    }

    final token = _accessToken();
    if (token == null) {
      return null;
    }

    try {
      final verified = await ref
          .read(securityApiProvider)
          .verifyPin(token, pin);
      if (!verified.verified ||
          verified.parentalUnlockToken == null ||
          verified.parentalUnlockExpiresAt == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PIN inválido.')));
        }
        UxAnalytics.log(
          'pin_prompt_abandon',
          params: const <String, Object?>{'reason': 'invalid_pin'},
        );
        return null;
      }

      ref
          .read(parentalGateControllerProvider.notifier)
          .setUnlocked(
            token: verified.parentalUnlockToken!,
            expiresAt: verified.parentalUnlockExpiresAt!,
          );

      UxAnalytics.log(
        'pin_prompt_success',
        params: <String, Object?>{
          'expires_at': verified.parentalUnlockExpiresAt!.toIso8601String(),
        },
      );

      if (showSuccessMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Área adulta liberada por alguns minutos para compras e ações protegidas.',
            ),
          ),
        );
      }

      return verified.parentalUnlockToken!;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
      }
      UxAnalytics.log(
        'pin_prompt_abandon',
        params: const <String, Object?>{'reason': 'verification_error'},
      );
      return null;
    }
  }

  Future<void> _unlockItem(CatalogItemModel item) async {
    final token = _accessToken();
    final childId = _selectedChildId;
    if (token == null || childId == null) {
      return;
    }

    final unlockToken = await _resolveUnlockToken();
    if (unlockToken == null) {
      return;
    }

    setState(() => _loading = true);
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleEquip(CatalogItemModel item) async {
    final token = _accessToken();
    final childId = _selectedChildId;
    if (token == null || childId == null) {
      return;
    }

    setState(() => _loading = true);
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
        setState(() => _loading = false);
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
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ViscondeHeroBanner(
            title: 'Game',
            subtitle: 'Progresso saudável, missões e cosméticos.',
            assetPath: ViscondeArtRegistry.resolve(
              ViscondeArtKey.heroUnderwater,
            ),
            showMascot: true,
            mascotPose: ViscondeMascotPose.thumbsUpController,
          ),
          const SizedBox(height: 12),
          if (_loadError != null)
            ViscondeGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Não foi possível atualizar os dados agora.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_loadError!),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          if (_loadError != null) const SizedBox(height: 12),
          ViscondeGlassCard(
            child: ListTile(
              leading: Icon(
                unlockActive ? Icons.verified_user : Icons.lock_clock_outlined,
                color: unlockActive ? Colors.green : null,
              ),
              title: Text(
                unlockActive ? 'Área adulta liberada' : 'Área adulta bloqueada',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                unlockActive
                    ? 'Liberada até ${dateFormat.format(gate.expiresAt!)} para compras e ações protegidas.'
                    : 'Desbloqueie com PIN para evitar interrupções durante as compras.',
              ),
              trailing: OutlinedButton(
                onPressed: () {
                  _resolveUnlockToken(showSuccessMessage: true);
                },
                child: Text(unlockActive ? 'Renovar' : 'Desbloquear'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (primaryMission != null)
            ViscondeGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta da semana',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
          if (primaryMission != null) const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (_children.isNotEmpty)
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
          ViscondeGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Carteira',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text('Moedas: ${wallet?.coins ?? 0}'),
                  Text('Estrelas: ${wallet?.stars ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ViscondeGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Streak',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text('Atual: ${progression?.streak.currentDays ?? 0} dias'),
                  Text('Melhor: ${progression?.streak.bestDays ?? 0} dias'),
                  Text('Escudos: ${progression?.streak.shieldCount ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const ViscondeSectionTitle(
            title: 'Missões Semanais',
            subtitle: 'Objetivos da semana por criança.',
          ),
          const SizedBox(height: 6),
          ...?progression?.weeklyMissions.map(
            (mission) => ViscondeGlassCard(
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
          const SizedBox(height: 12),
          const ViscondeSectionTitle(
            title: 'Conquistas',
            subtitle: 'Marcos já desbloqueados na conta.',
          ),
          const SizedBox(height: 6),
          ..._achievements.map(
            (achievement) => ViscondeGlassCard(
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
          const SizedBox(height: 12),
          const ViscondeSectionTitle(
            title: 'O Colecionador',
            subtitle: 'Seus itens e companheiros de aventura.',
          ),
          const SizedBox(height: 6),
          if (_childInventory.isEmpty)
            const ViscondeGlassCard(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Você ainda não encontrou nenhum item. Continue lendo histórias!',
                ),
              ),
            ),
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
          const SizedBox(height: 12),
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
          ..._catalog.map(
            (item) => ViscondeGlassCard(
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
          const SizedBox(height: 12),
          ViscondeGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Itens equipados',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if ((progression?.inventorySummary.equippedItems.length ??
                          0) ==
                      0)
                    const Text('Nenhum item equipado.'),
                  ...?progression?.inventorySummary.equippedItems.map(
                    (item) => Text('- ${item.name} (${item.type.name})'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
