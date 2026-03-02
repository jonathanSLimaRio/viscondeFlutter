import 'package:flutter/material.dart';

Future<T> withControllersDisposed<T>(
  List<TextEditingController> controllers,
  Future<T> Function() run,
) async {
  try {
    return await run();
  } finally {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
