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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Entrar no ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: context.viscondeColors.textStrong,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Image.asset(
                  ViscondeArtRegistry.resolve(ViscondeArtKey.logoVisconde),
                  height: 40,
                  width: 120, // Add constraint to image to help layout
                  fit: BoxFit.contain, // ensure it scales correctly
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 40,
                      width: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.viscondeColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Visconde',
                        style: TextStyle(
                          color: context.viscondeColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            ViscondeHeroBanner(
              title: 'Criando com o Papai!',
              subtitle: 'Transforme tempo em memórias mágicas.',
              assetPath: ViscondeArtRegistry.resolve(
                ViscondeArtKey.heroTreasure,
              ),
              trailing: ViscondeAvatarBadge(
                imageAsset: ViscondeArtRegistry.resolve(
                  ViscondeArtKey.avatarParent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ViscondeGlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const ViscondeSectionTitle(
                      title: 'Acessar conta',
                      subtitle: 'Continue a próxima aventura.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined, color: context.viscondeColors.primary),
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
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline, color: context.viscondeColors.primary),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe sua senha';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ViscondePrimaryCta(
                      onPressed: _submit,
                      label: 'Entrar',
                      icon: Icons.login,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/forgot-password'),
              style: TextButton.styleFrom(
                foregroundColor: context.viscondeColors.primaryDark,
              ),
              child: const Text('Esqueci minha senha'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: context.viscondeColors.borderSoft)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'ou',
                    style: TextStyle(color: context.viscondeColors.textMuted),
                  ),
                ),
                Expanded(child: Divider(color: context.viscondeColors.borderSoft)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _googleLogin,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Continuar com Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: context.viscondeColors.textStrong,
                elevation: 1,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _appleLogin,
              icon: const Icon(Icons.apple, size: 24),
              label: const Text('Continuar com Apple'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: context.viscondeColors.textStrong,
                elevation: 1,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/signup'),
              child: const Text('Criar conta'),
            ),
            if (authState.error != null) ...[
              const SizedBox(height: 12),
              Text(authState.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
