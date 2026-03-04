import 'package:flutter/material.dart';

import '../../../design_system/visconde.dart';
import '../../children/ui/children_tab.dart';
import '../../security/ui/adult_gate_tab.dart';
import 'profile_tab.dart';

enum ProfileHubSection { account, children, adult }

class ProfileHubTab extends StatefulWidget {
  const ProfileHubTab({super.key});

  @override
  State<ProfileHubTab> createState() => _ProfileHubTabState();
}

class _ProfileHubTabState extends State<ProfileHubTab> {
  ProfileHubSection _section = ProfileHubSection.account;

  late final List<Widget> _sections = <Widget>[
    const ProfileTab(),
    const ChildrenTab(),
    const AdultGateTab(),
  ];

  int _sectionIndex(ProfileHubSection section) {
    switch (section) {
      case ProfileHubSection.account:
        return 0;
      case ProfileHubSection.children:
        return 1;
      case ProfileHubSection.adult:
        return 2;
    }
  }

  String _sectionDescription(ProfileHubSection section) {
    switch (section) {
      case ProfileHubSection.account:
        return 'Dados da conta e preferências do responsável.';
      case ProfileHubSection.children:
        return 'Cadastre e edite perfis das crianças em um só lugar.';
      case ProfileHubSection.adult:
        return 'Gerencie PIN e acessos protegidos da área do pai.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ViscondeGlassCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Central do Perfil',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ProfileHubSection>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ProfileHubSection>(
                        value: ProfileHubSection.account,
                        icon: Icon(Icons.account_circle_outlined),
                        label: Text('Conta'),
                      ),
                      ButtonSegment<ProfileHubSection>(
                        value: ProfileHubSection.children,
                        icon: Icon(Icons.child_care_outlined),
                        label: Text('Crianças'),
                      ),
                      ButtonSegment<ProfileHubSection>(
                        value: ProfileHubSection.adult,
                        icon: Icon(Icons.lock_outline),
                        label: Text('Área do pai'),
                      ),
                    ],
                    selected: <ProfileHubSection>{_section},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _section = selection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: Text(
                    _sectionDescription(_section),
                    key: ValueKey<ProfileHubSection>(_section),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _sectionIndex(_section),
            children: _sections,
          ),
        ),
      ],
    );
  }
}
