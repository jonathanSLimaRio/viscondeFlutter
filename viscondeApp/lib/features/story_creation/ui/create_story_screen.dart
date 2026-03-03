import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_route.dart';
import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/app_feedback.dart';
import '../../../shared/ux_analytics.dart';
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
  bool _showAdvancedOptions = false;
  bool _storyCreated = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UxAnalytics.log(
        'story_create_started',
        params: const <String, Object?>{'source': 'create_story_screen'},
      );
      _loadChildren();
      _loadVirtues();
      _loadTemplates();
      _loadArtStyles();
    });
  }

  @override
  void dispose() {
    if (!_storyCreated) {
      UxAnalytics.log(
        'story_create_abandoned',
        params: <String, Object?>{
          'step': _currentStep + 1,
          'child_id': _selectedChildId,
          'source': 'create_story_screen',
        },
      );
    }
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

      context.showError(error);
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
      context.showError(error);
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
      context.showError(error);
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
      final styles = await ref.read(illustrationApiProvider).listArtStyles();
      if (!mounted) return;
      setState(() {
        _artStyles = styles;
        _selectedArtStyleId = styles.isNotEmpty ? styles.first.id : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showError(error);
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
      context.showError(error);
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

      context.showMessage('Sugestão: ${suggestion.virtue.name}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      context.showError(error);
    } finally {
      if (mounted) {
        setState(() => _suggestingVirtue = false);
      }
    }
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_selectedChildId == null) {
          context.showMessage('Selecione uma criança para continuar.');
          return false;
        }
        return true;
      case 1:
        return true;
      case 2:
        final title = _titleController.text.trim();
        final theme = _themeController.text.trim();
        final scenario = _scenarioController.text.trim();
        final objective = _objectiveController.text.trim();
        final charactersRaw = _charactersController.text.trim();

        if (title.isEmpty ||
            theme.isEmpty ||
            scenario.isEmpty ||
            objective.isEmpty) {
          context.showMessage('Preencha título, tema, cenário e objetivo.');
          return false;
        }

        final characters = charactersRaw
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();

        if (characters.isEmpty) {
          context.showMessage(
            'Informe ao menos um personagem (separados por vírgula).',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _goNextStep() {
    if (!_validateStep(_currentStep)) {
      return;
    }
    if (_currentStep >= 2) {
      return;
    }

    final next = _currentStep + 1;
    UxAnalytics.log(
      'story_create_step_completed',
      params: <String, Object?>{
        'step': _currentStep + 1,
        'child_id': _selectedChildId,
        'source': 'create_story_screen',
      },
    );
    setState(() => _currentStep = next);
  }

  void _goPreviousStep() {
    if (_currentStep == 0) {
      return;
    }
    setState(() => _currentStep -= 1);
  }

  Future<void> _createStory() async {
    final childId = _selectedChildId;
    if (childId == null) {
      context.showMessage('Selecione uma criança para iniciar.');
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
      context.showMessage('Preencha título, tema, cenário e objetivo.');
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
      context.showMessage(
        'Informe ao menos um personagem (separados por vírgula).',
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
      context.showMessage(error ?? 'Falha ao criar sessão.');
      return;
    }

    _storyCreated = true;
    UxAnalytics.log(
      'story_create_step_completed',
      params: <String, Object?>{
        'step': 3,
        'child_id': childId,
        'source': 'create_story_screen',
      },
    );
    context.go(AppRoute.storyRoom(created.id));
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / 3;

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Sala de História')),
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
                ),
                const SizedBox(height: 12),
                ViscondeGlassCard(
                  child: Column(
                    children: [
                      const ViscondeSectionTitle(
                        title: 'Configuração da História',
                        subtitle: 'Fluxo guiado em 3 passos para criar rápido.',
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(
                        'Passo ${_currentStep + 1} de 3',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Stepper(
                        currentStep: _currentStep,
                        margin: EdgeInsets.zero,
                        controlsBuilder: (context, details) {
                          final isLast = _currentStep == 2;
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed:
                                        (_submitting || _children.isEmpty)
                                        ? null
                                        : () {
                                            if (isLast) {
                                              if (_validateStep(2)) {
                                                _createStory();
                                              }
                                            } else {
                                              _goNextStep();
                                            }
                                          },
                                    icon: Icon(
                                      isLast
                                          ? Icons.play_arrow
                                          : Icons.arrow_forward,
                                    ),
                                    label: Text(
                                      isLast
                                          ? (_submitting
                                                ? 'Criando...'
                                                : 'Abrir Sala de História')
                                          : 'Continuar',
                                    ),
                                  ),
                                ),
                                if (_currentStep > 0) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _goPreviousStep,
                                      child: const Text('Voltar'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                        onStepTapped: (value) {
                          if (value <= _currentStep) {
                            setState(() => _currentStep = value);
                            return;
                          }
                          if (value == _currentStep + 1 &&
                              _validateStep(_currentStep)) {
                            setState(() => _currentStep = value);
                          }
                        },
                        steps: [
                          Step(
                            title: const Text('Criança e modo'),
                            subtitle: const Text(
                              'Quem vai participar desta aventura',
                            ),
                            isActive: _currentStep >= 0,
                            content: Column(
                              children: [
                                if (_children.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Cadastre ao menos uma criança na aba Crianças antes de iniciar.',
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
                                  decoration: const InputDecoration(
                                    labelText: 'Criança',
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
                                      label: Text('Criança escolhe'),
                                    ),
                                  ],
                                  selected: <StoryMode>{_mode},
                                  onSelectionChanged: (values) {
                                    setState(() => _mode = values.first);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Step(
                            title: const Text('Personalização'),
                            subtitle: const Text(
                              'Virtude, estilo e opções extras',
                            ),
                            isActive: _currentStep >= 1,
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_loadingVirtues ||
                                    _loadingArtStyles ||
                                    _loadingTemplates ||
                                    _applyingTemplate)
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
                                          setState(
                                            () => _selectedVirtueId = value,
                                          );
                                        },
                                  decoration: const InputDecoration(
                                    labelText: 'Virtude principal',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed:
                                      (_suggestingVirtue ||
                                          _selectedChildId == null)
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
                                if (_artStyles.isNotEmpty)
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedArtStyleId,
                                    decoration: const InputDecoration(
                                      labelText: 'Estilo de Ilustração',
                                    ),
                                    items: _artStyles
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(s.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setState(
                                      () => _selectedArtStyleId = val,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _showAdvancedOptions,
                                  onChanged: (value) {
                                    setState(() {
                                      _showAdvancedOptions = value;
                                    });
                                  },
                                  title: const Text('Mostrar opções extras'),
                                ),
                                if (_showAdvancedOptions)
                                  DropdownButtonFormField<String?>(
                                    initialValue: _selectedTemplateId,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Template publicado (opcional)',
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
                                    onChanged:
                                        _loadingTemplates || _applyingTemplate
                                        ? null
                                        : (value) {
                                            _onTemplateSelected(value);
                                          },
                                  ),
                              ],
                            ),
                          ),
                          Step(
                            title: const Text('Detalhes da história'),
                            subtitle: const Text('Título, tema e personagens'),
                            isActive: _currentStep >= 2,
                            content: Column(
                              children: [
                                TextField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Título provisório',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _themeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tema',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _scenarioController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cenário',
                                  ),
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
                                    labelText:
                                        'Personagens (separe por vírgula)',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
