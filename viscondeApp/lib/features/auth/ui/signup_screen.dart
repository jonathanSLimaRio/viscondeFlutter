import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/loading_screen.dart';
import '../auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authControllerProvider.notifier)
        .signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          timezone: DateTime.now().timeZoneName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (authState.status == AuthStatus.loading) {
      return const LoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Criar conta no Visconde',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.viscondeColors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _buildHeroCard(context),
              const SizedBox(height: 16),
              ViscondeGlassCard(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ViscondeSectionTitle(
                        title: 'Cadastro',
                        subtitle: 'Dados do responsável',
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        context: context,
                        controller: _nameController,
                        hintText: 'Nome',
                        prefixIcon: Icons.badge_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe seu nome';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        context: context,
                        controller: _emailController,
                        hintText: 'E-mail',
                        keyboardType: TextInputType.emailAddress,
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
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe uma senha';
                          }
                          if (value.length < 8) {
                            return 'Mínimo de 8 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        context: context,
                        controller: _confirmPasswordController,
                        hintText: 'Confirmar senha',
                        obscureText: true,
                        prefixIcon: Icons.lock_reset_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirme sua senha';
                          }
                          if (value != _passwordController.text) {
                            return 'As senhas não conferem';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ViscondePrimaryCta(
                        onPressed: _submit,
                        label: 'Cadastrar',
                        icon: Icons.auto_awesome,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go(AppRoute.login),
                        style: TextButton.styleFrom(
                          foregroundColor: context.viscondeColors.primaryDark,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Já tem conta? Entrar'),
                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colors = context.viscondeColors;
    final radius = BorderRadius.circular(context.viscondeRadii.xl);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF4E2BC).withValues(alpha: 0.9),
            const Color(0xFFEEDCB7).withValues(alpha: 0.82),
            const Color(0xFFE8D6AE).withValues(alpha: 0.94),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 2,
        ),
        boxShadow: context.viscondeElevations.card,
      ),
      child: SizedBox(
        height: 188,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 146, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nova Jornada',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie sua conta e comece\nas histórias mágicas.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textStrong.withValues(alpha: 0.9),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 4,
              child: const SizedBox(
                width: 132,
                height: 132,
                child: ViscondeMascot(
                  pose: ViscondeMascotPose.pointingScroll,
                  glow: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
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
}
