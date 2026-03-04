import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../session_persona_controller.dart';

class SessionPersonaScreen extends ConsumerWidget {
  const SessionPersonaScreen({super.key, this.from});

  final String? from;

  String _resolveNextPath(SessionPersona persona) {
    final candidate = from?.trim();
    if (candidate == null || candidate.isEmpty) {
      return AppRoute.home;
    }

    final parsed = Uri.tryParse(candidate);
    final path = parsed?.path ?? candidate;
    if (!path.startsWith('/')) {
      return AppRoute.home;
    }

    if (path == AppRoute.loading ||
        AppRoute.isAuthRoute(path) ||
        AppRoute.isSessionPersonaRoute(path)) {
      return AppRoute.home;
    }

    if (persona == SessionPersona.child && AppRoute.isAdultAreaRoute(path)) {
      return AppRoute.home;
    }

    return candidate;
  }

  void _selectPersona(
    BuildContext context,
    WidgetRef ref,
    SessionPersona persona,
  ) {
    final controller = ref.read(sessionPersonaControllerProvider.notifier);
    if (persona == SessionPersona.child) {
      controller.selectChild();
    } else {
      controller.selectParent();
    }

    context.go(_resolveNextPath(persona));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  child: _PersonaHalf(
                    key: const ValueKey<String>('persona_child_half'),
                    title: 'FILHO',
                    subtitle: 'Explorar histórias com segurança e foco.',
                    icon: Icons.child_care_rounded,
                    accentLabel: 'Entrar como filho',
                    mascot: ViscondeArtRegistry.resolve(
                      ViscondeArtKey.avatarChild,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9ED8F5), Color(0xFFCAEFFF)],
                    ),
                    onTap: () =>
                        _selectPersona(context, ref, SessionPersona.child),
                  ),
                ),
                Expanded(
                  child: _PersonaHalf(
                    key: const ValueKey<String>('persona_parent_half'),
                    title: 'PAI',
                    subtitle: 'Gerenciar jornada, perfil e área protegida.',
                    icon: Icons.shield_rounded,
                    accentLabel: 'Entrar como pai',
                    mascot: ViscondeArtRegistry.resolve(
                      ViscondeArtKey.avatarParent,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF0D3A4), Color(0xFFF8E8C8)],
                    ),
                    onTap: () =>
                        _selectPersona(context, ref, SessionPersona.parent),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.paddingOf(context).top + 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Quem está usando o app agora?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Escolha o perfil para adaptar menus e permissões.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaHalf extends StatelessWidget {
  const _PersonaHalf({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentLabel,
    required this.mascot,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String accentLabel;
  final String mascot;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  ViscondeArtRegistry.resolve(ViscondeArtKey.paperTexture),
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation<double>(0.12),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(icon, size: 30, color: const Color(0xFF2A1C12)),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  color: const Color(0xFF2A1C12),
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: const Color(
                                    0xFF2A1C12,
                                  ).withValues(alpha: 0.86),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                                width: 1.3,
                              ),
                            ),
                            child: Text(
                              accentLabel,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2A1C12),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Image.asset(
                      mascot,
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
