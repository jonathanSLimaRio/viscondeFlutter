import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/illustration_models.dart';
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
  List<ContentStoryTemplateModel> _templates = const [];
  List<ArtStyleModel> _artStyles = const [];
  String? _selectedChildId;
  String? _selectedVirtueId;
  String? _selectedTemplateId;
  String? _selectedArtStyleId;
  String? _suggestionReason;
  StoryMode _mode = StoryMode.parentNarrator;
  bool _loadingChildren = false;
  bool _loadingVirtues = false;
  bool _loadingTemplates = false;
  bool _loadingArtStyles = false;
  bool _applyingTemplate = false;
  bool _suggestingVirtue = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChildren();
      _loadVirtues();
      _loadTemplates();
      _loadArtStyles();
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

  Future<void> _loadTemplates() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    setState(() => _loadingTemplates = true);

    try {
      final templates = await ref
          .read(storyApiProvider)
          .listPublishedStoryTemplates(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _templates = templates;
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
        setState(() => _loadingTemplates = false);
      }
    }
  }

  Future<void> _loadArtStyles() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    setState(() => _loadingArtStyles = true);
    try {
      final styles = await ref
          .read(illustrationApiProvider)
          .listArtStyles(token);
      if (!mounted) return;
      setState(() {
        _artStyles = styles;
        _selectedArtStyleId = styles.isNotEmpty ? styles.first.id : null;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingArtStyles = false);
    }
  }

  Future<void> _applyTemplatePrefill(String templateId) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    setState(() => _applyingTemplate = true);
    try {
      final prefill = await ref
          .read(storyApiProvider)
          .getStoryTemplatePrefill(token, templateId);
      if (!mounted) {
        return;
      }

      final charactersText = prefill.characters
          .map((item) => (item['name'] ?? '').trim())
          .where((item) => item.isNotEmpty)
          .join(', ');

      setState(() {
        if (_titleController.text.trim().isEmpty && prefill.title.isNotEmpty) {
          _titleController.text = prefill.title;
        }
        if (prefill.theme.trim().isNotEmpty) {
          _themeController.text = prefill.theme.trim();
        }
        if (prefill.scenario.trim().isNotEmpty) {
          _scenarioController.text = prefill.scenario.trim();
        }
        if (prefill.objective.trim().isNotEmpty) {
          _objectiveController.text = prefill.objective.trim();
        }
        if (charactersText.isNotEmpty) {
          _charactersController.text = charactersText;
        }
        if (prefill.virtueId != null &&
            prefill.virtueId!.isNotEmpty &&
            _virtues.any((virtue) => virtue.id == prefill.virtueId)) {
          _selectedVirtueId = prefill.virtueId;
        }
        _suggestionReason = 'Template aplicado: ${prefill.title}.';
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
        setState(() => _applyingTemplate = false);
      }
    }
  }

  Future<void> _onTemplateSelected(String? templateId) async {
    setState(() {
      _selectedTemplateId = templateId;
      _suggestionReason = null;
    });
    if (templateId == null || templateId.isEmpty) {
      return;
    }
    await _applyTemplatePrefill(templateId);
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
          sourceTemplateId: _selectedTemplateId,
          artStyleId: _selectedArtStyleId,
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
                ViscondeHeroBanner(
                  title: 'Criando com o Papai!',
                  subtitle: 'Monte tema, cenário e heróis da aventura.',
                  assetPath: ViscondeArtRegistry.resolve(
                    ViscondeArtKey.heroUnderwater,
                  ),
                  showMascot: true,
                  mascotPose: ViscondeMascotPose.observingSpyglass,
                  trailing: ViscondeAvatarBadge(
                    imageAsset: ViscondeArtRegistry.resolve(
                      ViscondeArtKey.avatarParent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ViscondeGlassCard(
                  child: Column(
                    children: [
                      const ViscondeSectionTitle(
                        title: 'Configuração da História',
                        subtitle: 'Escolha criança, virtude e modo de sessão.',
                      ),
                      const SizedBox(height: 12),
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
                      if (_loadingTemplates || _applyingTemplate)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedTemplateId,
                        decoration: const InputDecoration(
                          labelText: 'Template publicado (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sem template'),
                          ),
                          ..._templates.map(
                            (template) => DropdownMenuItem<String?>(
                              value: template.id,
                              child: Text(template.title),
                            ),
                          ),
                        ],
                        onChanged: _loadingTemplates || _applyingTemplate
                            ? null
                            : (value) {
                                _onTemplateSelected(value);
                              },
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
                        onPressed:
                            (_suggestingVirtue || _selectedChildId == null)
                            ? null
                            : _suggestVirtueAutomatically,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                          _suggestingVirtue
                              ? 'Sugerindo...'
                              : 'Sugerir automaticamente por idade',
                        ),
                      ),
                      if (_suggestionReason != null &&
                          _suggestionReason!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _suggestionReason!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_loadingArtStyles)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                      if (_artStyles.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedArtStyleId,
                          decoration: const InputDecoration(
                            labelText: 'Estilo de Ilustracao (Nova Aventura)',
                          ),
                          items: _artStyles
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedArtStyleId = val),
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
                      ViscondePrimaryCta(
                        onPressed: (_submitting || _children.isEmpty)
                            ? null
                            : _createStory,
                        icon: Icons.play_arrow,
                        label: _submitting
                            ? 'Criando...'
                            : 'Abrir Sala de Historia',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
