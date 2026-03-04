import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../auth/session_persona_controller.dart';
import '../../children/ui/children_tab.dart';
import '../../security/ui/adult_gate_tab.dart';
import 'profile_tab.dart';

enum ProfileHubSection { account, children, adult }

class ProfileHubTab extends ConsumerStatefulWidget {
  const ProfileHubTab({super.key});

  @override
  ConsumerState<ProfileHubTab> createState() => _ProfileHubTabState();
}

class _ProfileHubTabState extends ConsumerState<ProfileHubTab> {
  ProfileHubSection _section = ProfileHubSection.account;

  late final Map<ProfileHubSection, Widget> _sections =
      <ProfileHubSection, Widget>{
        ProfileHubSection.account: const ProfileTab(),
        ProfileHubSection.children: const ChildrenTab(),
        ProfileHubSection.adult: const AdultGateTab(),
      };

  List<ProfileHubSection> _availableSections({required bool isChildMode}) {
    if (isChildMode) {
      return const <ProfileHubSection>[
        ProfileHubSection.account,
        ProfileHubSection.children,
      ];
    }

    return const <ProfileHubSection>[
      ProfileHubSection.account,
      ProfileHubSection.children,
      ProfileHubSection.adult,
    ];
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

  String _sectionLabel(ProfileHubSection section) {
    switch (section) {
      case ProfileHubSection.account:
        return 'Conta';
      case ProfileHubSection.children:
        return 'Crianças';
      case ProfileHubSection.adult:
        return 'Área do pai';
    }
  }

  IconData _sectionIcon(ProfileHubSection section) {
    switch (section) {
      case ProfileHubSection.account:
        return Icons.account_circle_outlined;
      case ProfileHubSection.children:
        return Icons.child_care_outlined;
      case ProfileHubSection.adult:
        return Icons.lock_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final personaState = ref.watch(sessionPersonaControllerProvider);
    final isChildMode = personaState.persona == SessionPersona.child;
    final availableSections = _availableSections(isChildMode: isChildMode);
    final currentSection = availableSections.contains(_section)
        ? _section
        : ProfileHubSection.account;
    if (_section != currentSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _section = currentSection;
          });
        }
      });
    }

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
                    segments: availableSections
                        .map(
                          (section) => ButtonSegment<ProfileHubSection>(
                            value: section,
                            icon: Icon(_sectionIcon(section)),
                            label: Text(_sectionLabel(section)),
                          ),
                        )
                        .toList(growable: false),
                    selected: <ProfileHubSection>{currentSection},
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
                    _sectionDescription(currentSection),
                    key: ValueKey<ProfileHubSection>(currentSection),
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
            index: availableSections.indexOf(currentSection),
            children: availableSections
                .map((section) => _sections[section]!)
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
