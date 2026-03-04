import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/avatar_presets.dart';
import '../../../shared/providers.dart';
import '../auth_controller.dart';
import '../session_persona_controller.dart';

final _sessionPersonaChildPreviewProvider =
    FutureProvider.autoDispose<ChildProfile?>((ref) async {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null || token.trim().isEmpty) {
        return null;
      }

      try {
        final children = await ref
            .read(childrenApiProvider)
            .listChildren(token);
        for (final child in children) {
          if (!child.isArchived) {
            return child;
          }
        }
      } catch (_) {
        return null;
      }

      return null;
    });

class SessionPersonaScreen extends ConsumerWidget {
  const SessionPersonaScreen({super.key, this.from});

  final String? from;

  String _resolveNextPath(
    SessionPersona persona,
    SessionPresenceMode presenceMode,
  ) {
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
    SessionPersona persona, {
    SessionPresenceMode presenceMode = SessionPresenceMode.separated,
  }) {
    final controller = ref.read(sessionPersonaControllerProvider.notifier);
    if (persona == SessionPersona.child) {
      controller.selectChild();
    } else if (presenceMode == SessionPresenceMode.together) {
      controller.selectParentTogether();
    } else {
      controller.selectParent();
    }

    context.go(_resolveNextPath(persona, presenceMode));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final parentUser = authState.user;
    final childPreview = ref
        .watch(_sessionPersonaChildPreviewProvider)
        .valueOrNull;

    final parentAvatarImageUrl = parentUser?.imageUrl;
    final parentAvatarFallback = resolveAvatarAsset(
      isParent: true,
      avatarPresetKey: parentUser?.avatarPresetKey,
      avatarVariant: parentUser?.avatarVariant,
    );

    final childAvatarImageUrl = childPreview?.avatarUrl;
    final childAvatarFallback = resolveAvatarAsset(
      isParent: false,
      avatarPresetKey: childPreview?.avatarPresetKey,
      avatarVariant: childPreview?.avatarVariant,
    );

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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7EC9F0),
                        Color(0xFFAEE2FB),
                        Color(0xFFE0F6FF),
                      ],
                    ),
                    avatarImageUrl: childAvatarImageUrl,
                    avatarFallbackAsset: childAvatarFallback,
                    avatarBadgeIcon: Icons.auto_stories_rounded,
                    avatarSquareKey: const ValueKey<String>(
                      'persona_child_avatar_square',
                    ),
                    avatarImageKey: const ValueKey<String>(
                      'persona_child_avatar_image',
                    ),
                    avatarSourceKey: ValueKey<String>(
                      childAvatarImageUrl != null &&
                              childAvatarImageUrl.trim().isNotEmpty
                          ? 'persona_child_avatar_source_network'
                          : 'persona_child_avatar_source_asset',
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE6C58F),
                        Color(0xFFF0D8AE),
                        Color(0xFFF8EAD1),
                      ],
                    ),
                    avatarImageUrl: parentAvatarImageUrl,
                    avatarFallbackAsset: parentAvatarFallback,
                    avatarBadgeIcon: Icons.shield_rounded,
                    avatarSquareKey: const ValueKey<String>(
                      'persona_parent_avatar_square',
                    ),
                    avatarImageKey: const ValueKey<String>(
                      'persona_parent_avatar_image',
                    ),
                    avatarSourceKey: ValueKey<String>(
                      parentAvatarImageUrl != null &&
                              parentAvatarImageUrl.trim().isNotEmpty
                          ? 'persona_parent_avatar_source_network'
                          : 'persona_parent_avatar_source_asset',
                    ),
                    onTap: () =>
                        _selectPersona(context, ref, SessionPersona.parent),
                  ),
                ),
              ],
            ),
            Positioned(
              top: (MediaQuery.sizeOf(context).height / 2) - 68,
              left: 0,
              right: 0,
              child: Center(
                child: _TogetherPersonaButton(
                  onTap: () => _selectPersona(
                    context,
                    ref,
                    SessionPersona.parent,
                    presenceMode: SessionPresenceMode.together,
                  ),
                ),
              ),
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

class _TogetherPersonaButton extends StatelessWidget {
  const _TogetherPersonaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('persona_together_button'),
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5FA07D), Color(0xFF3A6D52)],
            ),
            border: Border.all(color: Colors.white, width: 2.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.family_restroom_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(height: 6),
                Text(
                  'Pai e Filho',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Juntos no mesmo celular',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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
    required this.gradient,
    required this.avatarImageUrl,
    required this.avatarFallbackAsset,
    required this.avatarBadgeIcon,
    required this.avatarSquareKey,
    required this.avatarImageKey,
    required this.avatarSourceKey,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String accentLabel;
  final Gradient gradient;
  final String? avatarImageUrl;
  final String avatarFallbackAsset;
  final IconData avatarBadgeIcon;
  final Key avatarSquareKey;
  final Key avatarImageKey;
  final Key avatarSourceKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;

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
                  opacity: const AlwaysStoppedAnimation<double>(0.07),
                ),
              ),
              Positioned(
                top: -72,
                left: -46,
                child: _PersonaGlowOrb(
                  color: Colors.white.withValues(alpha: 0.28),
                  size: 220,
                ),
              ),
              Positioned(
                bottom: -92,
                right: -58,
                child: _PersonaGlowOrb(
                  color: colors.primary.withValues(alpha: 0.18),
                  size: 230,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0, 0.55, 1],
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.transparent,
                        Colors.transparent,
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
                    const SizedBox(width: 16),
                    _PersonaAvatarSquare(
                      key: avatarSquareKey,
                      imageUrl: avatarImageUrl,
                      fallbackAsset: avatarFallbackAsset,
                      badgeIcon: avatarBadgeIcon,
                      avatarImageKey: avatarImageKey,
                      avatarSourceKey: avatarSourceKey,
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

class _PersonaAvatarSquare extends StatelessWidget {
  const _PersonaAvatarSquare({
    super.key,
    required this.imageUrl,
    required this.fallbackAsset,
    required this.badgeIcon,
    required this.avatarImageKey,
    required this.avatarSourceKey,
  });

  final String? imageUrl;
  final String fallbackAsset;
  final IconData badgeIcon;
  final Key avatarImageKey;
  final Key avatarSourceKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.viscondeColors;
    final hasNetworkImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Transform.rotate(
      angle: -0.022,
      child: Container(
        width: 108,
        height: 108,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.78),
              Colors.white.withValues(alpha: 0.44),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(key: avatarSourceKey, width: 0, height: 0),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.parchment.withValues(alpha: 0.84),
                      colors.parchmentSoft.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primaryDark.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasNetworkImage
                      ? Image.network(
                          imageUrl!.trim(),
                          key: avatarImageKey,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              fallbackAsset,
                              key: avatarImageKey,
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : Image.asset(
                          fallbackAsset,
                          key: avatarImageKey,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.98),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    badgeIcon,
                    size: 16,
                    color: const Color(0xFF2A1C12),
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

class _PersonaGlowOrb extends StatelessWidget {
  const _PersonaGlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.02), Colors.transparent],
        ),
      ),
    );
  }
}
