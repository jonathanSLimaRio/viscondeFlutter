import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../features/auth/auth_controller.dart';
import '../../children/ui/children_tab.dart';
import '../../gamification/ui/game_hub_screen.dart';
import '../../security/ui/adult_gate_tab.dart';
import '../../story_vault/ui/story_vault_screen.dart';
import 'profile_tab.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  static const _menuAnimationDuration = Duration(milliseconds: 260);

  int _index = 0;
  final Map<int, Widget> _tabCache = <int, Widget>{0: const StoryVaultScreen()};

  Widget _tabForIndex(int index) {
    switch (index) {
      case 0:
        return const StoryVaultScreen();
      case 1:
        return const GameHubScreen();
      case 2:
        return const ChildrenTab();
      case 3:
        return const ProfileTab();
      case 4:
        return const AdultGateTab();
      default:
        return const SizedBox.shrink();
    }
  }

  String _tabLabel(int index) {
    switch (index) {
      case 0:
        return 'Histórias';
      case 1:
        return 'Game Hub';
      case 2:
        return 'Crianças';
      case 3:
        return 'Perfil';
      case 4:
        return 'Área adulta';
      default:
        return '';
    }
  }

  Widget _buildAnimatedBody() {
    return Stack(
      children: List<Widget>.generate(5, (index) {
        final tab = _tabCache[index];
        if (tab == null) {
          return const SizedBox.shrink();
        }

        final selected = _index == index;
        return Positioned.fill(
          child: IgnorePointer(
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
          ),
        );
      }, growable: false),
    );
  }

  NavigationDestination _destination({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = _index == index;

    return NavigationDestination(
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
    final currentTabLabel = _tabLabel(_index);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              ViscondeArtRegistry.resolve(ViscondeArtKey.logoVisconde),
              height: 30,
              fit: BoxFit.contain,
            ),
            AnimatedSwitcher(
              duration: _menuAnimationDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.16),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                currentTabLabel,
                key: ValueKey<String>(currentTabLabel),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: context.viscondeGradients.glass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderSoft, width: 1),
              ),
              child: IconButton(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout),
                tooltip: 'Sair',
              ),
            ),
          ),
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
            onDestinationSelected: (value) {
              setState(() {
                _index = value;
                _tabCache.putIfAbsent(value, () => _tabForIndex(value));
              });
            },
            destinations: [
              _destination(
                index: 0,
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book,
                label: 'Histórias',
              ),
              _destination(
                index: 1,
                icon: Icons.videogame_asset_outlined,
                selectedIcon: Icons.videogame_asset,
                label: 'Game',
              ),
              _destination(
                index: 2,
                icon: Icons.child_care_outlined,
                selectedIcon: Icons.child_care,
                label: 'Crianças',
              ),
              _destination(
                index: 3,
                icon: Icons.account_circle_outlined,
                selectedIcon: Icons.account_circle,
                label: 'Perfil',
              ),
              _destination(
                index: 4,
                icon: Icons.lock_outline,
                selectedIcon: Icons.lock,
                label: 'Área adulta',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
