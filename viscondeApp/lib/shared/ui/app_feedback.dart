import 'package:flutter/material.dart';

import '../api_error.dart';
import '../ux_analytics.dart';

extension AppFeedbackContext on BuildContext {
  void showMessage(String message) {
    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void showError(Object error, {String? fallback}) {
    final presentation = describeApiError(error);
    final message = presentation.message;
    UxAnalytics.log(
      'auth_error_shown',
      params: <String, Object?>{
        'session_expired': presentation.sessionExpired,
        'message': message,
      },
    );
    if (message.trim().isEmpty &&
        fallback != null &&
        fallback.trim().isNotEmpty) {
      showMessage(fallback.trim());
      return;
    }
    showMessage(message);
  }
}
