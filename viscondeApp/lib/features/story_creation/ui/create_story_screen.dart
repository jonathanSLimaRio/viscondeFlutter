import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/child_profile.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/story_models.dart';
import '../../story_room/story_room_controller.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _titleController = TextEditingController();
  final _themeController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _charactersController = TextEditingController();

  List<ChildProfile> _children = const [];
  List<VirtueModel> _virtues = const [];
  String? _selectedChildId;
  String? _selectedVirtueId;
  String? _suggestionReason;
  StoryMode _mode = StoryMode.parentNarrator;
  bool _loadingChildren = false;
  bool _loadingVirtues = false;
  bool _suggestingVirtue = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChildren();
      _loadVirtues();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _themeController.dispose();
    _scenarioController.dispose();
    _objectiveController.dispose();
    _charactersController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    setState(() => _loadingChildren = true);

    try {
      final children = await ref.read(childrenApiProvider).listChildren(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _children = children;
        _selectedChildId = children.isNotEmpty ? children.first.id : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loadingChildren = false);
      }
    }
  }

  Future<void> _loadVirtues() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    setState(() => _loadingVirtues = true);

    try {
      final virtues = await ref.read(storyApiProvider).listVirtues(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _virtues = virtues;
        _selectedVirtueId = virtues.isNotEmpty ? virtues.first.id : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loadingVirtues = false);
      }
    }
  }

  Future<void> _suggestVirtueAutomatically() async {
    final token = ref.read(authControllerProvider).accessToken;
    final childId = _selectedChildId;

    if (token == null || childId == null) {
      return;
    }

    setState(() => _suggestingVirtue = true);

    try {
      final suggestion = await ref
          .read(storyApiProvider)
          .suggestVirtue(token, childProfileId: childId);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedVirtueId = suggestion.virtue.id;
        _suggestionReason = suggestion.reason;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sugestao: ${suggestion.virtue.name}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _suggestingVirtue = false);
      }
    }
  }

  Future<void> _createStory() async {
    final childId = _selectedChildId;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma crianca para iniciar.')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final theme = _themeController.text.trim();
    final scenario = _scenarioController.text.trim();
    final objective = _objectiveController.text.trim();
    final charactersRaw = _charactersController.text.trim();

    if (title.isEmpty ||
        theme.isEmpty ||
        scenario.isEmpty ||
        objective.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha titulo, tema, cenario e objetivo.'),
        ),
      );
      return;
    }

    final characters = charactersRaw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(8)
        .map((name) => <String, String?>{'name': name, 'role': null})
        .toList();

    if (characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe ao menos um personagem (separados por virgula).',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final created = await ref
        .read(storyRoomControllerProvider.notifier)
        .createSession(
          childProfileId: childId,
          titleDraft: title,
          theme: theme,
          scenario: scenario,
          characters: characters,
          objective: objective,
          startMode: _mode,
          virtueId: _selectedVirtueId,
        );

    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);

    if (created == null) {
      final error = ref.read(storyRoomControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Falha ao criar sessao.')),
      );
      return;
    }

    context.go('/stories/${created.id}/room');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Sala de Historia')),
      body: _loadingChildren
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_children.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Cadastre ao menos uma crianca na aba Criancas antes de iniciar.',
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedChildId,
                  items: _children
                      .map(
                        (child) => DropdownMenuItem(
                          value: child.id,
                          child: Text(child.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedChildId = value);
                  },
                  decoration: const InputDecoration(labelText: 'Crianca'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titulo provisiorio',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _themeController,
                  decoration: const InputDecoration(labelText: 'Tema'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scenarioController,
                  decoration: const InputDecoration(labelText: 'Cenario'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _objectiveController,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo da aventura',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _charactersController,
                  decoration: const InputDecoration(
                    labelText: 'Personagens (separe por virgula)',
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingVirtues)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVirtueId,
                  items: _virtues
                      .map(
                        (virtue) => DropdownMenuItem(
                          value: virtue.id,
                          child: Text(virtue.name),
                        ),
                      )
                      .toList(),
                  onChanged: _virtues.isEmpty
                      ? null
                      : (value) {
                          setState(() => _selectedVirtueId = value);
                        },
                  decoration: const InputDecoration(
                    labelText: 'Virtude principal',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: (_suggestingVirtue || _selectedChildId == null)
                      ? null
                      : _suggestVirtueAutomatically,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    _suggestingVirtue
                        ? 'Sugerindo...'
                        : 'Sugerir automaticamente por idade',
                  ),
                ),
                if (_suggestionReason != null && _suggestionReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _suggestionReason!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                SegmentedButton<StoryMode>(
                  segments: const [
                    ButtonSegment<StoryMode>(
                      value: StoryMode.parentNarrator,
                      label: Text('Pai narrador'),
                    ),
                    ButtonSegment<StoryMode>(
                      value: StoryMode.childChooser,
                      label: Text('Crianca escolhe'),
                    ),
                  ],
                  selected: <StoryMode>{_mode},
                  onSelectionChanged: (values) {
                    setState(() => _mode = values.first);
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: (_submitting || _children.isEmpty)
                      ? null
                      : _createStory,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    _submitting ? 'Criando...' : 'Abrir Sala de Historia',
                  ),
                ),
              ],
            ),
    );
  }
}
