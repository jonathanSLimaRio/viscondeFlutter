import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';

class AdminHubScreen extends StatelessWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ViscondeHeroBanner(
            title: 'Painel Interno',
            subtitle: 'Gestão de conteúdos, templates e moderação.',
            assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroCastle),
            showMascot: true,
            mascotPose: ViscondeMascotPose.studyingDesk,
          ),
          const SizedBox(height: 12),
          const ViscondeGlassCard(
            child: ViscondeSectionTitle(
              title: 'Ferramentas Admin',
              subtitle: 'Selecione um módulo para editar o conteúdo do app.',
            ),
          ),
          const SizedBox(height: 10),
          _AdminMenuTile(
            icon: Icons.palette_outlined,
            title: 'Temas',
            subtitle: 'Gerencie catálogo de temas ativos/inativos.',
            onTap: () => context.push(AppRoute.adminThemes),
          ),
          _AdminMenuTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Virtudes e Dilemas',
            subtitle: 'Edite virtudes e templates por faixa etária.',
            onTap: () => context.push(AppRoute.adminVirtues),
          ),
          _AdminMenuTile(
            icon: Icons.lightbulb_outline,
            title: 'Prompts',
            subtitle: 'Gerencie prompts de ideia/fallback e narração.',
            onTap: () => context.push(AppRoute.adminPrompts),
          ),
          _AdminMenuTile(
            icon: Icons.account_tree_outlined,
            title: 'Templates de História',
            subtitle: 'Edite árvore de decisão e publique versões.',
            onTap: () => context.push(AppRoute.adminTemplates),
          ),
          _AdminMenuTile(
            icon: Icons.shield_outlined,
            title: 'Moderação',
            subtitle: 'Bloqueie termos impróprios por escopo.',
            onTap: () => context.push(AppRoute.adminModeration),
          ),
          _AdminMenuTile(
            icon: Icons.analytics_outlined,
            title: 'Funil UX',
            subtitle: 'Acompanhe sessões, abandono e erros de autenticação.',
            onTap: () => context.push(AppRoute.adminUxFunnel),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  const _AdminMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ViscondeGlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: context.viscondeColors.primaryDark),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
