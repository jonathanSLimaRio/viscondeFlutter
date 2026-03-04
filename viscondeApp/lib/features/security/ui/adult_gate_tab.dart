import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../parental_gate_controller.dart';

class AdultGateTab extends ConsumerStatefulWidget {
  const AdultGateTab({super.key});

  @override
  ConsumerState<AdultGateTab> createState() => _AdultGateTabState();
}

class _AdultGateTabState extends ConsumerState<AdultGateTab> {
  final _pinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hasPin = false;
  bool _loading = false;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pinController.dispose();
    _newPinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final hasPin = await ref.read(securityApiProvider).hasPin(token);
      if (!mounted) return;

      setState(() {
        _hasPin = hasPin;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{6}$').hasMatch(pin);
  }

  Future<void> _setPin() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    final pin = _newPinController.text.trim();
    if (!_isValidPin(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN deve conter 6 dígitos.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(securityApiProvider).setPin(token, pin);
      if (!mounted) return;

      setState(() {
        _hasPin = true;
      });
      ref.read(parentalGateControllerProvider.notifier).clear();
      _newPinController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN configurado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyPin() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    final pin = _pinController.text.trim();
    if (!_isValidPin(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN deve conter 6 dígitos.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final valid = await ref.read(securityApiProvider).verifyPin(token, pin);
      if (!mounted) return;

      if (valid.verified &&
          valid.parentalUnlockToken != null &&
          valid.parentalUnlockExpiresAt != null) {
        ref
            .read(parentalGateControllerProvider.notifier)
            .setUnlocked(
              token: valid.parentalUnlockToken!,
              expiresAt: valid.parentalUnlockExpiresAt!,
            );
      } else {
        ref.read(parentalGateControllerProvider.notifier).clear();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            valid.verified ? 'Área do pai liberada.' : 'PIN inválido.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPin() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    final newPin = _newPinController.text.trim();
    if (!_isValidPin(newPin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Novo PIN deve conter 6 dígitos.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(securityApiProvider)
          .resetPin(
            token,
            newPin: newPin,
            currentPassword: _passwordController.text,
          );
      if (!mounted) return;

      _newPinController.clear();
      _passwordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN redefinido com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _lockNow() async {
    await ref
        .read(parentalUnlockServiceProvider)
        .lockNow(source: 'adult_gate_lock_now');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Área do pai bloqueada agora.')),
    );
  }

  String _unlockStatusLabel(ParentalGateState gate) {
    if (!gate.isUnlocked) {
      return 'Área do pai bloqueada.';
    }

    final minutes = gate.remainingWholeMinutesAt(DateTime.now()) ?? 0;
    return 'Área do pai desbloqueada por $minutes min.';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final gate = ref.watch(parentalGateControllerProvider);
    final isUnlocked = gate.isUnlocked;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ViscondeGlassCard(
          child: Row(
            children: [
              Expanded(
                child: ViscondeSectionTitle(
                  title: 'Área do pai protegida',
                  subtitle:
                      'Gerencie PIN e recursos sensíveis com proteção extra.',
                ),
              ),
              SizedBox(width: 8),
              ViscondeMascot(
                pose: ViscondeMascotPose.seriousController,
                size: 72,
                glow: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _hasPin ? 'PIN configurado' : 'Configure seu PIN adulto',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (!_hasPin) ...[
          TextField(
            controller: _newPinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Novo PIN (6 dígitos)',
            ),
          ),
          FilledButton(onPressed: _setPin, child: const Text('Definir PIN')),
        ] else ...[
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PIN atual'),
          ),
          FilledButton(
            onPressed: _verifyPin,
            child: const Text('Desbloquear área do pai'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Senha atual (para reset do PIN)',
            ),
          ),
          TextField(
            controller: _newPinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Novo PIN'),
          ),
          OutlinedButton(
            onPressed: _resetPin,
            child: const Text('Redefinir PIN'),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          _unlockStatusLabel(gate),
          style: TextStyle(
            color: isUnlocked ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isUnlocked) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _lockNow,
            icon: const Icon(Icons.lock_clock_outlined),
            label: const Text('Bloquear agora'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.push(AppRoute.adultVirtueReports),
          icon: const Icon(Icons.insights_outlined),
          label: const Text('Relatório de virtudes'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoute.adultInteractions),
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Interações remotas'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.push(AppRoute.adultVoices),
          icon: const Icon(Icons.record_voice_over_outlined),
          label: const Text('Voz inesquecível'),
        ),
        if (auth.user?.isAdmin ?? false) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: isUnlocked
                ? () => context.push(AppRoute.adminHub)
                : null,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Administração'),
          ),
        ],
      ],
    );
  }
}
