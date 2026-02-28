// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/loading_screen.dart';
import '../auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _googleSignIn = GoogleSignIn(scopes: <String>['email']);

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

  Future<void> _googleLogin() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return;

    final auth = await account.authentication;
    final idToken = auth.idToken;

    if (idToken == null || idToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel obter token do Google.'),
          ),
        );
      }
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .loginWithGoogleToken(idToken);
  }

  Future<void> _appleLogin() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel obter token da Apple.'),
          ),
        );
      }
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .loginWithAppleToken(idToken);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (authState.status == AuthStatus.loading) {
      return const LoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ViscondeScaffoldBackground(
        safeArea: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ──────────────────────────────────────────────────────
                Center(
                  child: Image.asset(
                    ViscondeArtRegistry.resolve(ViscondeArtKey.logoVisconde),
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(height: 80),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Title ────────────────────────────────────────────────────
                _buildTitle(context),
                const SizedBox(height: 24),

                // ── Hero Banner ──────────────────────────────────────────────
                ViscondeHeroBanner(
                  title: 'Criando com o Papai!',
                  subtitle: 'Transforme tempo em\nmemórias mágicas.',
                  assetPath: ViscondeArtRegistry.resolve(
                    ViscondeArtKey.heroTreasure,
                  ),
                  trailing: ViscondeAvatarBadge(
                    imageAsset: ViscondeArtRegistry.resolve(
                      ViscondeArtKey.avatarParent,
                    ),
                  ),
                  height: 160,
                ),
                const SizedBox(height: 16),

                // ── Login Card ───────────────────────────────────────────────
                ViscondeGlassCard(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card header
                        const ViscondeSectionTitle(
                          title: 'Acessar conta',
                          subtitle: 'Continue a próxima aventura.',
                        ),
                        const SizedBox(height: 20),

                        // Email field
                        _buildEmailField(context),
                        const SizedBox(height: 12),

                        // Password field
                        _buildPasswordField(context),
                        const SizedBox(height: 20),

                        // Entrar button
                        ViscondePrimaryCta(
                          onPressed: _submit,
                          label: 'Entrar',
                          icon: Icons.arrow_forward_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Forgot password ──────────────────────────────────────────
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.viscondeColors.primaryDark,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Esqueci minha senha'),
                ),

                const SizedBox(height: 8),

                // ── Divider "ou" ─────────────────────────────────────────────
                _buildOrDivider(context),

                const SizedBox(height: 16),

                // ── Google button ────────────────────────────────────────────
                _buildSocialButton(
                  context: context,
                  onPressed: _googleLogin,
                  icon: _GoogleIcon(),
                  label: 'Continuar com Google',
                ),
                const SizedBox(height: 12),

                // ── Apple button ─────────────────────────────────────────────
                _buildSocialButton(
                  context: context,
                  onPressed: _appleLogin,
                  icon: const Icon(
                    Icons.apple,
                    size: 22,
                    color: Colors.black87,
                  ),
                  label: 'Continuar com Apple',
                ),

                // ── Error message ────────────────────────────────────────────
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.error!,
                    style: TextStyle(
                      color: context.viscondeColors.warning,
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
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildTitle(BuildContext context) {
    final colors = context.viscondeColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Entrar no ',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colors.textStrong.withOpacity(0.8),
            letterSpacing: -0.3,
          ),
        ),
        Text(
          'Visconde',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: colors.textStrong,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final colors = context.viscondeColors;
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: colors.textStrong, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'E-mail',
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 15),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(
            Icons.mail_outline_rounded,
            color: colors.primary,
            size: 22,
          ),
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
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Informe seu e-mail';
        }
        if (!value.contains('@')) {
          return 'E-mail invalido';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final colors = context.viscondeColors;
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      style: TextStyle(color: colors.textStrong, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Senha',
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 15),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(
            Icons.lock_outline_rounded,
            color: colors.primary,
            size: 22,
          ),
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
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe sua senha';
        }
        return null;
      },
    );
  }

  Widget _buildOrDivider(BuildContext context) {
    final colors = context.viscondeColors;
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: colors.textMuted.withOpacity(0.25),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'ou',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: colors.textMuted.withOpacity(0.25),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required Widget icon,
    required String label,
  }) {
    final colors = context.viscondeColors;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFFBF7F0),
        foregroundColor: colors.textStrong,
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
