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
        if (presentation.kind != null) 'error_kind': presentation.kind!.name,
        if (presentation.statusCode != null)
          'status_code': presentation.statusCode!,
        if (presentation.code != null && presentation.code!.trim().isNotEmpty)
          'code': presentation.code!.trim(),
        'source': 'app_feedback',
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
