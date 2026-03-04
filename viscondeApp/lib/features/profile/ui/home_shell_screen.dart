import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../features/auth/auth_controller.dart';
import '../../../features/auth/session_persona_controller.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
import '../../gamification/game_adventure_session_controller.dart';
import '../../gamification/ui/game_blank_screen.dart';
import '../../gamification/ui/game_hub_screen.dart';
import '../../security/parental_gate_controller.dart';
import '../../story_vault/ui/story_vault_screen.dart';
import 'profile_hub_tab.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key, this.initialTab = HomeTab.stories});

  final HomeTab initialTab;

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  static const _menuAnimationDuration = Duration(milliseconds: 260);
  static const _tabCount = 4;
  static const _gameTabIndex = 1;
  static const _avatarFooterIndex = 4;

  int _index = 0;
  final Map<int, Widget> _tabCache = <int, Widget>{0: const StoryVaultScreen()};
  Timer? _unlockTicker;

  @override
  void initState() {
    super.initState();
    _index = _indexFromTab(widget.initialTab);
    _tabCache.putIfAbsent(_index, () => _tabForIndex(_index));
    _unlockTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _unlockTicker?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) {
      return;
    }

    final nextIndex = _indexFromTab(widget.initialTab);
    if (nextIndex == _index) {
      return;
    }

    setState(() {
      _index = nextIndex;
      _tabCache.putIfAbsent(_index, () => _tabForIndex(_index));
    });
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair do app'),
          content: const Text('Deseja encerrar a sessão neste dispositivo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await ref.read(authControllerProvider.notifier).logout();
  }

  Widget _tabForIndex(int index) {
    switch (index) {
      case 0:
        return const StoryVaultScreen();
      case 1:
        return const GameBlankScreen();
      case 2:
        return const GameHubScreen();
      case 3:
        return const ProfileHubTab();
      default:
        return const SizedBox.shrink();
    }
  }

  int _indexFromTab(HomeTab tab) {
    switch (tab) {
      case HomeTab.stories:
        return 0;
      case HomeTab.game:
        return 1;
      case HomeTab.achievements:
        return 2;
      case HomeTab.profile:
        return 3;
    }
  }

  void _onMenuTabSelected(int index) {
    _selectTab(index);
    Navigator.of(context).pop(); // Close drawer
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _tabCache.putIfAbsent(index, () => _tabForIndex(index));
    });
  }

  void _openAvatarsFromFooter() {
    UxAnalytics.log(
      'avatar_editor_opened',
      params: const <String, Object?>{
        'source': 'home_footer',
        'target': 'family',
      },
    );
    context.push(AppRoute.avatarEditorPath(source: 'home_footer'));
  }

  void _handleFooterDestinationSelection(int value) {
    if (value == _avatarFooterIndex) {
      _openAvatarsFromFooter();
      return;
    }

    if (value == _gameTabIndex) {
      final lastStoryId =
          ref.read(gameAdventureSessionControllerProvider).storyId?.trim() ??
          '';
      if (lastStoryId.isNotEmpty) {
        _selectTab(_gameTabIndex);
        context.push(AppRoute.storyRoom(lastStoryId));
        return;
      }
    }

    _selectTab(value);
  }

  Widget _buildAnimatedBody() {
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(_tabCount, (index) {
        final tab = _tabCache[index] ?? const SizedBox.expand();
        final selected = _index == index;

        return IgnorePointer(
          ignoring: !selected,
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: _menuAnimationDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedSlide(
              offset: selected ? Offset.zero : const Offset(0.03, 0),
              duration: _menuAnimationDuration,
              curve: Curves.easeOutCubic,
              child: KeyedSubtree(key: ValueKey<int>(index), child: tab),
            ),
          ),
        );
      }, growable: false),
    );
  }

  NavigationDestination _destination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required String keyValue,
  }) {
    final selected = _index == index;

    return NavigationDestination(
      key: ValueKey<String>(keyValue),
      icon: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: _menuAnimationDuration,
        curve: Curves.easeOutBack,
        child: Icon(icon),
      ),
      selectedIcon: AnimatedScale(
        scale: selected ? 1.1 : 1,
        duration: _menuAnimationDuration,
        curve: Curves.easeOutBack,
        child: Icon(selectedIcon),
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final gate = ref.watch(parentalGateControllerProvider);
    final personaState = ref.watch(sessionPersonaControllerProvider);
    final isChildMode = personaState.persona == SessionPersona.child;
    final isAdultUnlocked = gate.isUnlocked;
    final remainingMinutes = gate.remainingWholeMinutesAt(DateTime.now()) ?? 0;

    return Scaffold(
      key: const ValueKey('home_scaffold'), // Optional, for testing
      drawer: _HomeDrawer(
        index: _index,
        showParentArea: !isChildMode,
        onTabSelected: _onMenuTabSelected,
        onOpenAvatars: () {
          Navigator.of(context).pop();
          UxAnalytics.log(
            'avatar_editor_opened',
            params: const <String, Object?>{
              'source': 'home_drawer',
              'target': 'family',
            },
          );
          context.push(AppRoute.avatarEditorPath(source: 'home_drawer'));
        },
        onLogout: () {
          Navigator.of(context).pop();
          _confirmLogout();
        },
      ),
      appBar: AppBar(
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                ViscondeArtRegistry.resolve(ViscondeArtKey.logoVisconde),
                key: const ValueKey<String>('home_header_logo'),
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                'Visconde',
                key: const ValueKey<String>('home_header_title'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        bottom: !isChildMode && isAdultUnlocked
            ? PreferredSize(
                preferredSize: const Size.fromHeight(42),
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 10,
                    left: 16,
                    right: 16,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: ShapeDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: colors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: colors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Área do pai: ${remainingMinutes}min restantes',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.primaryDark,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(parentalUnlockServiceProvider)
                                .lockNow(source: 'home_appbar_lock_now');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'BLOQUEAR',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 8,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
        actions: const [
          SizedBox(width: 48), // Spacer to balance leading menu icon
        ],
      ),
      body: _buildAnimatedBody(),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.viscondeRadii.xl),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _handleFooterDestinationSelection,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _destination(
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book,
                label: 'Histórias',
                index: 0,
                keyValue: 'home_footer_stories',
              ),
              _destination(
                icon: Icons.videogame_asset_outlined,
                selectedIcon: Icons.videogame_asset,
                label: 'Game',
                index: 1,
                keyValue: 'home_footer_game',
              ),
              _destination(
                icon: Icons.emoji_events_outlined,
                selectedIcon: Icons.emoji_events,
                label: 'Conquistas',
                index: 2,
                keyValue: 'home_footer_achievements',
              ),
              _destination(
                icon: Icons.account_circle_outlined,
                selectedIcon: Icons.account_circle,
                label: 'Perfil',
                index: 3,
                keyValue: 'home_footer_profile',
              ),
              _destination(
                icon: Icons.palette_outlined,
                selectedIcon: Icons.palette,
                label: 'Avatares',
                index: _avatarFooterIndex,
                keyValue: 'home_footer_avatars',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer({
    required this.index,
    required this.showParentArea,
    required this.onTabSelected,
    required this.onOpenAvatars,
    required this.onLogout,
  });

  final int index;
  final bool showParentArea;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onOpenAvatars;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.viscondeColors;
    final user = ref.watch(authControllerProvider).user;

    return Drawer(
      backgroundColor: colors.parchment,
      child: Column(
        children: [
          _buildHeader(context, user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildItem(
                  context: context,
                  index: 0,
                  icon: Icons.menu_book_rounded,
                  label: 'Histórias',
                ),
                _buildItem(
                  context: context,
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  label: 'Meu Perfil',
                ),
                ListTile(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: colors.textMuted,
                  ),
                  title: Text(
                    'Avatares',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: onOpenAvatars,
                ),
                if (showParentArea)
                  _buildItem(
                    context: context,
                    index: 3, // Perfil tab, will then navigate to adult gate
                    icon: Icons.security_rounded,
                    label: 'Área do pai',
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Divider(),
                ),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: colors.warning),
                  title: Text(
                    'Sair do App',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: onLogout,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Visconde App v1.0.0',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    final colors = context.viscondeColors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: context.viscondeGradients.glass,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary, width: 2),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: colors.parchment,
              backgroundImage: user?.imageUrl != null
                  ? NetworkImage(user.imageUrl!)
                  : null,
              child: user?.imageUrl == null
                  ? Icon(Icons.person, size: 32, color: colors.textMuted)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'Viajante',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: colors.textStrong,
            ),
          ),
          Text(
            user?.email ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = this.index == index;
    final colors = context.viscondeColors;

    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colors.primaryDark : colors.textMuted,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: selected ? colors.primaryDark : colors.textStrong,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: colors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => onTabSelected(index),
    );
  }
}
