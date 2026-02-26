import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../story_room/models/story_models.dart';

class RemoteJoinScreen extends ConsumerStatefulWidget {
  const RemoteJoinScreen({super.key, this.prefilledCode});

  final String? prefilledCode;

  @override
  ConsumerState<RemoteJoinScreen> createState() => _RemoteJoinScreenState();
}

class _RemoteJoinScreenState extends ConsumerState<RemoteJoinScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _codeController.text = (widget.prefilledCode ?? '').trim();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    final displayName = _nameController.text.trim();

    if (code.isEmpty || displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe codigo e nome para entrar.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await ref
          .read(storyApiProvider)
          .joinRemoteRoomByCode(code: code, displayName: displayName);

      if (!mounted) {
        return;
      }

      final bundle = RemoteJoinBundle(
        participantToken: result.participantToken,
        remoteRoom: result.remoteRoom,
        storySnapshot: result.storySnapshot,
        signalingWsUrl: result.signalingWsUrl,
        rtcConfig: result.rtcConfig,
        isGuest: true,
      );

      context.go('/remote/room', extra: bundle);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar na sala remota')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Codigo da sala'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Seu nome'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _join,
            icon: const Icon(Icons.meeting_room_outlined),
            label: Text(_loading ? 'Entrando...' : 'Entrar na sala'),
          ),
          const SizedBox(height: 8),
          const Text(
            'No MVP remoto 1:1, apenas um convidado entra por codigo.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
