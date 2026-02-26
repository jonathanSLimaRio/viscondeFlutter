import 'package:flutter/material.dart';

class CreateRemoteSessionSheet extends StatelessWidget {
  const CreateRemoteSessionSheet({
    super.key,
    required this.loading,
    required this.hasRoom,
    required this.onOpen,
    required this.onRegenerate,
    required this.onEnterRoom,
    this.joinCode,
    this.joinLink,
    this.expiresAt,
  });

  final bool loading;
  final bool hasRoom;
  final String? joinCode;
  final String? joinLink;
  final DateTime? expiresAt;
  final VoidCallback onOpen;
  final VoidCallback onRegenerate;
  final VoidCallback onEnterRoom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sala remota',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie um codigo de entrada para o outro dispositivo. Requer PIN adulto valido.',
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (joinCode != null && joinCode!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Codigo: $joinCode',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (expiresAt != null) ...[
                        const SizedBox(height: 4),
                        Text('Expira em: ${expiresAt!.toLocal()}'),
                      ],
                      if (joinLink != null && joinLink!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          joinLink!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: loading ? null : onOpen,
                    icon: const Icon(Icons.link),
                    label: Text(hasRoom ? 'Reabrir sala' : 'Abrir sala'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onRegenerate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Gerar novo codigo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onEnterRoom,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Entrar na sala remota'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
