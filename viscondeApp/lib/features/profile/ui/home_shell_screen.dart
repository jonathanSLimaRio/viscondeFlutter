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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      StoryVaultScreen(),
      GameHubScreen(),
      ChildrenTab(),
      ProfileTab(),
      AdultGateTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          ViscondeArtRegistry.resolve(ViscondeArtKey.logoVisconde),
          height: 36,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: tabs[_index],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.viscondeRadii.xl),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) {
              setState(() => _index = value);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Historias',
              ),
              NavigationDestination(
                icon: Icon(Icons.videogame_asset_outlined),
                selectedIcon: Icon(Icons.videogame_asset),
                label: 'Game',
              ),
              NavigationDestination(
                icon: Icon(Icons.child_care_outlined),
                selectedIcon: Icon(Icons.child_care),
                label: 'Criancas',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_circle_outlined),
                selectedIcon: Icon(Icons.account_circle),
                label: 'Perfil',
              ),
              NavigationDestination(
                icon: Icon(Icons.lock_outline),
                selectedIcon: Icon(Icons.lock),
                label: 'Area adulta',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
