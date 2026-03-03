import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/loading_screen.dart';
import '../auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool get _shouldPrefillDevCredentials =>
      kDebugMode && devLoginPrefillEnabled && hasExplicitDevCredentials;

  final _emailController = TextEditingController(
    text: kDebugMode && devLoginPrefillEnabled && hasExplicitDevCredentials
        ? devAdminEmail
        : '',
  );
  final _passwordController = TextEditingController(
    text: kDebugMode && devLoginPrefillEnabled && hasExplicitDevCredentials
        ? devAdminPassword
        : '',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (authState.status == AuthStatus.loading) {
      return const LoadingScreen();
    }

    final colors = context.viscondeColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildHeroCard(context),
              const SizedBox(height: 18),
              _buildFormCard(context),
              if (kDebugMode && !_shouldPrefillDevCredentials) ...[
                const SizedBox(height: 8),
                Text(
                  'Dica dev: use --dart-define=DEV_LOGIN_PREFILL=true com DEV_ADMIN_EMAIL/DEV_ADMIN_PASSWORD para autopreencher.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push(AppRoute.forgotPassword),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primaryDark,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Esqueci minha senha'),
              ),
              const SizedBox(height: 8),
              _buildOrDivider(context),
              const SizedBox(height: 12),
              _buildSocialButton(
                context: context,
                onPressed: null,
                icon: const _GoogleIcon(),
                label: 'Continuar com Google',
              ),
              const SizedBox(height: 10),
              _buildSocialButton(
                context: context,
                onPressed: null,
                icon: const Icon(Icons.apple, size: 22, color: Colors.black87),
                label: 'Continuar com Apple',
              ),
              if (authState.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  authState.error!,
                  style: TextStyle(
                    color: colors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.viscondeColors;

    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Entrar no   ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w500,
                fontSize: 20,
              ),
            ),
            TextSpan(
              text: 'Visconde',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colors = context.viscondeColors;
    final radius = BorderRadius.circular(context.viscondeRadii.xl);

    return Container(
      constraints: const BoxConstraints(minHeight: 188),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF5E3B8).withValues(alpha: 0.88),
            const Color(0xFFEDDBB4).withValues(alpha: 0.8),
            const Color(0xFFEFD9AE).withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 2,
        ),
        boxShadow: context.viscondeElevations.card,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: Image.asset(
                ViscondeArtRegistry.resolve(ViscondeArtKey.paperTexture),
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation<double>(0.28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 146, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Criando com o Papai!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transforme tempo em\nmemórias mágicas.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textStrong.withValues(alpha: 0.9),
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 4,
            child: const SizedBox(
              width: 132,
              height: 132,
              child: ViscondeMascot(
                pose: ViscondeMascotPose.wavingControllerBook,
                glow: true,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final colors = context.viscondeColors;

    return ViscondeGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ViscondeSectionTitle(
              title: 'Acessar conta',
              subtitle: 'Continue a próxima aventura.',
            ),
            const SizedBox(height: 20),
            _buildInputField(
              context: context,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              hintText: 'E-mail',
              prefixIcon: Icons.mail_outline_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe seu e-mail';
                }
                if (!value.contains('@')) {
                  return 'E-mail inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildInputField(
              context: context,
              controller: _passwordController,
              hintText: 'Senha',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe sua senha';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ViscondePrimaryCta(
              onPressed: _submit,
              label: 'Entrar',
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push(AppRoute.signup),
              style: TextButton.styleFrom(
                foregroundColor: colors.primaryDark,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Não tem conta? Criar conta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrDivider(BuildContext context) {
    final color = context.viscondeColors.textMuted.withValues(alpha: 0.56);

    return Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'ou',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.viscondeColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: color, thickness: 1.2)),
      ],
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    final colors = context.viscondeColors;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textStrong, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 15),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(prefixIcon, color: colors.primary, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFFBF7F0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colors.warning, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colors.warning, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) {
    final colors = context.viscondeColors;
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFBF7F0),
          disabledBackgroundColor: const Color(0xFFFBF7F0),
          foregroundColor: colors.textStrong,
          disabledForegroundColor: colors.textStrong.withValues(alpha: 0.78),
          side: BorderSide.none,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [icon, const SizedBox(width: 8), Text(label)],
        ),
      ),
    );
  }
}

/// Google "G" logo painted with the four brand colors.
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(22, 22), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    // Draw circular clip
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // White background circle
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Draw letter G segments using arcs and rects
    // Blue (top-left arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      _toRad(225),
      _toRad(135),
      true,
      paint,
    );

    // Red (top-right to right arc)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      _toRad(315),
      _toRad(90),
      true,
      paint,
    );
    // also cover the white gap
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      _toRad(270),
      _toRad(45),
      true,
      paint,
    );

    // Yellow (bottom-right)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      _toRad(0),
      _toRad(90),
      true,
      paint,
    );

    // Green (bottom-left)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      _toRad(90),
      _toRad(135),
      true,
      paint,
    );

    // White inner circle (donut hole)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.46, paint);

    // "G" horizontal bar — right side extension
    paint.color = const Color(0xFF4285F4);
    final barTop = cy - r * 0.11;
    final barBottom = cy + r * 0.11;
    canvas.drawRect(Rect.fromLTRB(cx, barTop, cx + r * 0.72, barBottom), paint);

    // Redraw white donut to clean up
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.46, paint);
  }

  double _toRad(double deg) => deg * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
