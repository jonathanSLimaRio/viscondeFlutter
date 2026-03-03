import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api_error.dart';
import '../../shared/ux_analytics.dart';
import '../auth/auth_controller.dart';
import 'parental_gate_controller.dart';
import 'security_api.dart';

class ParentalUnlockService {
  ParentalUnlockService(this._ref, {required SecurityApi securityApi})
    : _securityApi = securityApi;

  final Ref _ref;
  final SecurityApi _securityApi;
  Future<String?>? _unlockInFlight;

  String? readValidToken({bool forcePrompt = false}) {
    if (forcePrompt) {
      return null;
    }

    final state = _ref.read(parentalGateControllerProvider);
    if (!state.isUnlockedAt(
      DateTime.now(),
      expiryBuffer: ParentalGateState.expirySafetyBuffer,
    )) {
      return null;
    }

    return state.unlockToken;
  }

  Future<void> lockNow({String source = 'manual_lock'}) async {
    _ref.read(parentalGateControllerProvider.notifier).clear();
    UxAnalytics.log(
      'pin_lock_now_clicked',
      params: <String, Object?>{'source': source},
    );
  }

  Future<String?> ensureUnlocked(
    BuildContext context, {
    bool forcePrompt = false,
    bool showSuccessMessage = false,
    String source = 'unknown',
  }) {
    final currentToken = readValidToken(forcePrompt: forcePrompt);
    if (currentToken != null) {
      return Future<String?>.value(currentToken);
    }

    final inFlight = _unlockInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final next = _promptAndVerify(
      context,
      source: source,
      showSuccessMessage: showSuccessMessage,
    );
    _unlockInFlight = next;

    return next.whenComplete(() {
      if (identical(_unlockInFlight, next)) {
        _unlockInFlight = null;
      }
    });
  }

  Future<String?> _promptAndVerify(
    BuildContext context, {
    required String source,
    required bool showSuccessMessage,
  }) async {
    final accessToken = _ref.read(authControllerProvider).accessToken;
    if (accessToken == null) {
      UxAnalytics.log(
        'pin_prompt_abandon',
        params: <String, Object?>{
          'reason': 'missing_access_token',
          'source': source,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sua sessão expirou. Faça login novamente.'),
          ),
        );
      }
      return null;
    }

    UxAnalytics.log(
      'pin_prompt_shown',
      params: <String, Object?>{'source': source},
    );

    var pinValue = '';
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('PIN adulto'),
          content: TextField(
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Digite seu PIN'),
            onChanged: (value) {
              pinValue = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(pinValue.trim()),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (pin == null || pin.length != 6) {
      UxAnalytics.log(
        'pin_prompt_abandon',
        params: <String, Object?>{
          'reason': 'cancel_or_invalid_length',
          'source': source,
        },
      );
      return null;
    }

    try {
      final verified = await _securityApi.verifyPin(accessToken, pin);
      if (!verified.verified ||
          verified.parentalUnlockToken == null ||
          verified.parentalUnlockExpiresAt == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PIN inválido.')));
        }
        UxAnalytics.log(
          'pin_prompt_abandon',
          params: <String, Object?>{'reason': 'invalid_pin', 'source': source},
        );
        return null;
      }

      _ref
          .read(parentalGateControllerProvider.notifier)
          .setUnlocked(
            token: verified.parentalUnlockToken!,
            expiresAt: verified.parentalUnlockExpiresAt!,
          );

      UxAnalytics.log(
        'pin_prompt_success',
        params: <String, Object?>{
          'expires_at': verified.parentalUnlockExpiresAt!.toIso8601String(),
          'source': source,
        },
      );

      if (showSuccessMessage && context.mounted) {
        final minutes = verified.unlockTtlMinutes;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Área adulta liberada por $minutes minutos para ações protegidas.',
            ),
          ),
        );
      }

      return verified.parentalUnlockToken!;
    } catch (error) {
      UxAnalytics.log(
        'pin_prompt_abandon',
        params: <String, Object?>{
          'reason': 'verification_error',
          'source': source,
          'message': parseDioError(error),
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
      }
      return null;
    }
  }
}
