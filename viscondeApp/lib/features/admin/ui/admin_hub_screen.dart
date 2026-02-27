import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminHubScreen extends StatelessWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administracao')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminMenuTile(
            icon: Icons.palette_outlined,
            title: 'Temas',
            subtitle: 'Gerencie catalogo de temas ativos/inativos.',
            onTap: () => context.push('/adult/admin/themes'),
          ),
          _AdminMenuTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Virtudes e Dilemas',
            subtitle: 'Edite virtudes e templates por faixa etaria.',
            onTap: () => context.push('/adult/admin/virtues'),
          ),
          _AdminMenuTile(
            icon: Icons.lightbulb_outline,
            title: 'Prompts',
            subtitle: 'Gerencie prompts de ideia/fallback e narracao.',
            onTap: () => context.push('/adult/admin/prompts'),
          ),
          _AdminMenuTile(
            icon: Icons.account_tree_outlined,
            title: 'Templates de Historia',
            subtitle: 'Edite arvore de decisao e publique versoes.',
            onTap: () => context.push('/adult/admin/templates'),
          ),
          _AdminMenuTile(
            icon: Icons.shield_outlined,
            title: 'Moderacao',
            subtitle: 'Bloqueie termos improprios por escopo.',
            onTap: () => context.push('/adult/admin/moderation'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
