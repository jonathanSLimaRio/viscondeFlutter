import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/visconde.dart';

class AdminAccessDeniedScreen extends StatelessWidget {
  const AdminAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ViscondeHeroBanner(
            title: 'Acesso Restrito',
            subtitle: 'Somente contas ADMIN podem abrir este painel.',
            assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroForest),
          ),
          const SizedBox(height: 12),
          ViscondeGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ViscondeSectionTitle(
                  title: 'Permissão insuficiente',
                  subtitle:
                      'Sua conta está no papel USER e não pode acessar administração.',
                ),
                const SizedBox(height: 8),
                ViscondePrimaryCta(
                  onPressed: () => context.go('/'),
                  icon: Icons.arrow_back,
                  label: 'Voltar ao início',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
