import 'package:flutter/material.dart';

class AdminAccessDeniedScreen extends StatelessWidget {
  const AdminAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administracao')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Acesso negado. Esta area e exclusiva para contas ADMIN.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
