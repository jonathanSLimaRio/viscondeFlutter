import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/story_models.dart';
import '../story_room_controller.dart';

class StorySummaryScreen extends ConsumerStatefulWidget {
  const StorySummaryScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StorySummaryScreen> createState() => _StorySummaryScreenState();
}

class _StorySummaryScreenState extends ConsumerState<StorySummaryScreen> {
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(storyRoomControllerProvider).session;
      if (session == null || session.id != widget.storyId) {
        ref
            .read(storyRoomControllerProvider.notifier)
            .loadSession(widget.storyId);
      } else {
        _titleController.text = session.title;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _finalize() async {
    final controller = ref.read(storyRoomControllerProvider.notifier);
    final finalized = await controller.finalize(
      titleFinal: _titleController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (finalized == null) {
      final error = ref.read(storyRoomControllerProvider).error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Falha ao publicar.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historia publicada com sucesso.')),
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyRoomControllerProvider);
    final story = state.session;

    if (state.loading && story == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumo da Historia')),
        body: const Center(child: Text('Historia nao encontrada.')),
      );
    }

    if (_titleController.text.isEmpty) {
      _titleController.text = story.title;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo e Publicacao')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titulo final'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crianca: ${story.child.name}'),
                  Text('Tema: ${story.theme}'),
                  Text('Cenario: ${story.scenario}'),
                  Text('Objetivo: ${story.objective}'),
                  if (story.virtue != null)
                    Text(
                      'Virtude: ${story.virtue!.name} (faixa ${ageBandLabel(story.ageBand)})',
                    ),
                  if (story.dilemmaText != null &&
                      story.dilemmaText!.trim().isNotEmpty)
                    Text('Dilema: ${story.dilemmaText}'),
                  if (story.endQuestionText != null &&
                      story.endQuestionText!.trim().isNotEmpty)
                    Text('Pergunta do fim: ${story.endQuestionText}'),
                  Text('Etapas salvas: ${story.steps.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Trechos da aventura',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...story.steps.map(
            (step) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(step.stepIndex.toString())),
                title: Text(
                  step.selectedOptionLabel ?? step.narratorText ?? '-',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.finalizing ? null : _finalize,
            icon: const Icon(Icons.publish),
            label: Text(
              state.finalizing ? 'Publicando...' : 'Publicar capitulo',
            ),
          ),
        ],
      ),
    );
  }
}
