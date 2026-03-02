import 'package:flutter/material.dart';

import '../api_error.dart';

extension AppFeedbackContext on BuildContext {
  void showMessage(String message) {
    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void showError(Object error, {String? fallback}) {
    final message = parseDioError(error);
    if (message.trim().isEmpty &&
        fallback != null &&
        fallback.trim().isNotEmpty) {
      showMessage(fallback.trim());
      return;
    }
    showMessage(message);
  }
}
