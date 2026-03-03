import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/controller_disposer.dart';
import '../../auth/auth_controller.dart';
import '../models/admin_models.dart';

class TemplateAdminScreen extends ConsumerStatefulWidget {
  const TemplateAdminScreen({super.key});

  @override
  ConsumerState<TemplateAdminScreen> createState() =>
      _TemplateAdminScreenState();
}

class _TemplateAdminScreenState extends ConsumerState<TemplateAdminScreen> {
  static const _ageBands = <String>['AGE_4_5', 'AGE_6_8', 'AGE_9_10'];

  bool _loading = false;
  List<AdminStoryTemplateListItem> _templates = const [];
  List<AdminThemeModel> _themes = const [];
  List<AdminVirtueModel> _virtues = const [];

  String? _selectedTemplateId;
  AdminStoryTemplateDetail? _detail;
  AdminTemplateValidationResult? _lastValidation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  Future<void> _bootstrap() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await Future.wait([
        ref.read(adminApiProvider).listStoryTemplates(token),
        ref.read(adminApiProvider).listThemes(token),
        ref.read(adminApiProvider).listVirtues(token),
      ]);

      if (!mounted) {
        return;
      }

      final templates = result[0] as List<AdminStoryTemplateListItem>;
      setState(() {
        _templates = templates;
        _themes = result[1] as List<AdminThemeModel>;
        _virtues = result[2] as List<AdminVirtueModel>;
        if (_selectedTemplateId == null && templates.isNotEmpty) {
          _selectedTemplateId = templates.first.id;
        }
      });

      if (_selectedTemplateId != null) {
        await _loadDetail(_selectedTemplateId!);
      }
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

  Future<void> _loadDetail(String templateId) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final detail = await ref
          .read(adminApiProvider)
          .getStoryTemplate(token, templateId);
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _lastValidation = null;
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openCreateTemplateDialog() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final slugController = TextEditingController();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final scenarioController = TextEditingController();
    final objectiveController = TextEditingController();

    String? selectedThemeId;
    String? selectedVirtueId;
    String? selectedAgeBand;
    bool isActive = true;

    final created = await withControllersDisposed<bool?>(
      [
        slugController,
        titleController,
        descriptionController,
        scenarioController,
        objectiveController,
      ],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Novo template'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: slugController,
                        decoration: const InputDecoration(
                          labelText: 'Slug (opcional)',
                        ),
                      ),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                        ),
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedThemeId,
                        decoration: const InputDecoration(
                          labelText: 'Tema (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Nenhum'),
                          ),
                          ..._themes.map(
                            (theme) => DropdownMenuItem<String?>(
                              value: theme.id,
                              child: Text(theme.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedThemeId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedVirtueId,
                        decoration: const InputDecoration(
                          labelText: 'Virtude (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Nenhuma'),
                          ),
                          ..._virtues.map(
                            (virtue) => DropdownMenuItem<String?>(
                              value: virtue.id,
                              child: Text(virtue.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedVirtueId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedAgeBand,
                        decoration: const InputDecoration(
                          labelText: 'Faixa etária (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Qualquer'),
                          ),
                          ..._ageBands.map(
                            (band) => DropdownMenuItem<String?>(
                              value: band,
                              child: Text(band),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedAgeBand = value);
                        },
                      ),
                      TextField(
                        controller: scenarioController,
                        decoration: const InputDecoration(
                          labelText: 'Cenário padrão',
                        ),
                      ),
                      TextField(
                        controller: objectiveController,
                        decoration: const InputDecoration(
                          labelText: 'Objetivo padrão',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ativo'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() => isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        final createdTemplate = await ref
                            .read(adminApiProvider)
                            .createStoryTemplate(
                              token,
                              slug: slugController.text.trim(),
                              title: titleController.text.trim(),
                              description: descriptionController.text.trim(),
                              themeId: selectedThemeId,
                              virtueId: selectedVirtueId,
                              ageBand: selectedAgeBand,
                              defaultScenario: scenarioController.text.trim(),
                              defaultObjective: objectiveController.text.trim(),
                              isActive: isActive,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        setState(
                          () => _selectedTemplateId = createdTemplate.id,
                        );
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parseDioError(error))),
                        );
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (created == true) {
      await _bootstrap();
    }
  }

  Future<void> _openEditTemplateDialog(AdminStoryTemplateDetail detail) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final slugController = TextEditingController(text: detail.slug);
    final titleController = TextEditingController(text: detail.title);
    final descriptionController = TextEditingController(
      text: detail.description,
    );
    final scenarioController = TextEditingController(
      text: detail.defaultScenario,
    );
    final objectiveController = TextEditingController(
      text: detail.defaultObjective,
    );

    String? selectedThemeId = detail.theme?.id;
    String? selectedVirtueId = detail.virtue?.id;
    String? selectedAgeBand = detail.ageBand;
    bool isActive = detail.isActive;

    final updated = await withControllersDisposed<bool?>(
      [
        slugController,
        titleController,
        descriptionController,
        scenarioController,
        objectiveController,
      ],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Editar template'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                        ),
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedThemeId,
                        decoration: const InputDecoration(
                          labelText: 'Tema (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Nenhum'),
                          ),
                          ..._themes.map(
                            (theme) => DropdownMenuItem<String?>(
                              value: theme.id,
                              child: Text(theme.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedThemeId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedVirtueId,
                        decoration: const InputDecoration(
                          labelText: 'Virtude (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Nenhuma'),
                          ),
                          ..._virtues.map(
                            (virtue) => DropdownMenuItem<String?>(
                              value: virtue.id,
                              child: Text(virtue.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedVirtueId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedAgeBand,
                        decoration: const InputDecoration(
                          labelText: 'Faixa etária (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Qualquer'),
                          ),
                          ..._ageBands.map(
                            (band) => DropdownMenuItem<String?>(
                              value: band,
                              child: Text(band),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedAgeBand = value);
                        },
                      ),
                      TextField(
                        controller: scenarioController,
                        decoration: const InputDecoration(
                          labelText: 'Cenário padrão',
                        ),
                      ),
                      TextField(
                        controller: objectiveController,
                        decoration: const InputDecoration(
                          labelText: 'Objetivo padrão',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ativo'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() => isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(adminApiProvider)
                            .updateStoryTemplate(
                              token,
                              detail.id,
                              slug: slugController.text.trim(),
                              title: titleController.text.trim(),
                              description: descriptionController.text.trim(),
                              themeId: selectedThemeId,
                              virtueId: selectedVirtueId,
                              ageBand: selectedAgeBand,
                              defaultScenario: scenarioController.text.trim(),
                              defaultObjective: objectiveController.text.trim(),
                              isActive: isActive,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parseDioError(error))),
                        );
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (updated == true) {
      await _bootstrap();
      final selectedId = _selectedTemplateId;
      if (selectedId != null) {
        await _loadDetail(selectedId);
      }
    }
  }

  Future<void> _addCharacter(AdminStoryTemplateDetail detail) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final nameController = TextEditingController();
    final roleController = TextEditingController();

    final created = await withControllersDisposed<bool?>(
      [nameController, roleController],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Adicionar personagem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'Papel'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(adminApiProvider)
                        .addStoryTemplateCharacter(
                          token,
                          detail.id,
                          name: nameController.text.trim(),
                          role: roleController.text.trim(),
                        );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop(true);
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(parseDioError(error))),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (created == true) {
      await _loadDetail(detail.id);
    }
  }

  Future<void> _addNode(AdminStoryTemplateDetail detail) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final keyController = TextEditingController();
    final titleController = TextEditingController();
    final narratorTextController = TextEditingController();
    final promptHintController = TextEditingController();
    final sortOrderController = TextEditingController(text: '0');
    AdminStoryTemplateNodeKind kind = AdminStoryTemplateNodeKind.narration;

    final created = await withControllersDisposed<bool?>(
      [
        keyController,
        titleController,
        narratorTextController,
        promptHintController,
        sortOrderController,
      ],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Adicionar no'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: keyController,
                        decoration: const InputDecoration(
                          labelText: 'Node key',
                        ),
                      ),
                      DropdownButtonFormField<AdminStoryTemplateNodeKind>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: AdminStoryTemplateNodeKind.values
                            .map(
                              (item) =>
                                  DropdownMenuItem<AdminStoryTemplateNodeKind>(
                                    value: item,
                                    child: Text(item.name.toUpperCase()),
                                  ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => kind = value);
                          }
                        },
                      ),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      TextField(
                        controller: narratorTextController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Texto narrador (opcional)',
                        ),
                      ),
                      TextField(
                        controller: promptHintController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Prompt hint (opcional)',
                        ),
                      ),
                      TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ordem'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(adminApiProvider)
                            .addStoryTemplateNode(
                              token,
                              detail.id,
                              nodeKey: keyController.text.trim(),
                              kind: kind,
                              title: titleController.text.trim(),
                              narratorText: narratorTextController.text.trim(),
                              promptHint: promptHintController.text.trim(),
                              sortOrder:
                                  int.tryParse(
                                    sortOrderController.text.trim(),
                                  ) ??
                                  0,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parseDioError(error))),
                        );
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (created == true) {
      await _loadDetail(detail.id);
    }
  }

  Future<void> _editNode(
    AdminStoryTemplateDetail detail,
    AdminStoryTemplateNodeModel node,
  ) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final keyController = TextEditingController(text: node.nodeKey);
    final titleController = TextEditingController(text: node.title);
    final narratorTextController = TextEditingController(
      text: node.narratorText ?? '',
    );
    final promptHintController = TextEditingController(
      text: node.promptHint ?? '',
    );
    final sortOrderController = TextEditingController(
      text: node.sortOrder.toString(),
    );
    AdminStoryTemplateNodeKind kind = node.kind;

    final updated = await withControllersDisposed<bool?>(
      [
        keyController,
        titleController,
        narratorTextController,
        promptHintController,
        sortOrderController,
      ],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Editar no'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: keyController,
                        decoration: const InputDecoration(
                          labelText: 'Node key',
                        ),
                      ),
                      DropdownButtonFormField<AdminStoryTemplateNodeKind>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: AdminStoryTemplateNodeKind.values
                            .map(
                              (item) =>
                                  DropdownMenuItem<AdminStoryTemplateNodeKind>(
                                    value: item,
                                    child: Text(item.name.toUpperCase()),
                                  ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => kind = value);
                          }
                        },
                      ),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      TextField(
                        controller: narratorTextController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Texto narrador (opcional)',
                        ),
                      ),
                      TextField(
                        controller: promptHintController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Prompt hint (opcional)',
                        ),
                      ),
                      TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ordem'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(adminApiProvider)
                            .updateStoryTemplateNode(
                              token,
                              detail.id,
                              node.id,
                              nodeKey: keyController.text.trim(),
                              kind: kind,
                              title: titleController.text.trim(),
                              narratorText: narratorTextController.text.trim(),
                              promptHint: promptHintController.text.trim(),
                              sortOrder:
                                  int.tryParse(
                                    sortOrderController.text.trim(),
                                  ) ??
                                  0,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parseDioError(error))),
                        );
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (updated == true) {
      await _loadDetail(detail.id);
    }
  }

  Future<void> _addOption(
    AdminStoryTemplateDetail detail, {
    String? initialNodeId,
  }) async {
    final token = _accessToken();
    if (token == null || detail.nodes.isEmpty) {
      return;
    }

    String selectedNodeId = initialNodeId ?? detail.nodes.first.id;
    String selectedNextNodeId = detail.nodes.first.id;
    final optionKeyController = TextEditingController();
    final labelController = TextEditingController();
    final sortOrderController = TextEditingController(text: '0');

    final created = await withControllersDisposed<bool?>(
      [optionKeyController, labelController, sortOrderController],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Adicionar opção'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedNodeId,
                        decoration: const InputDecoration(
                          labelText: 'No origem',
                        ),
                        items: detail.nodes
                            .map(
                              (node) => DropdownMenuItem<String>(
                                value: node.id,
                                child: Text('${node.nodeKey} · ${node.title}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedNodeId = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedNextNodeId,
                        decoration: const InputDecoration(
                          labelText: 'Proximo no',
                        ),
                        items: detail.nodes
                            .map(
                              (node) => DropdownMenuItem<String>(
                                value: node.id,
                                child: Text('${node.nodeKey} · ${node.title}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedNextNodeId = value);
                          }
                        },
                      ),
                      TextField(
                        controller: optionKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Option key',
                        ),
                      ),
                      TextField(
                        controller: labelController,
                        decoration: const InputDecoration(labelText: 'Label'),
                      ),
                      TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ordem'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(adminApiProvider)
                            .addStoryTemplateOption(
                              token,
                              detail.id,
                              nodeId: selectedNodeId,
                              optionKey: optionKeyController.text.trim(),
                              label: labelController.text.trim(),
                              nextNodeId: selectedNextNodeId,
                              sortOrder:
                                  int.tryParse(
                                    sortOrderController.text.trim(),
                                  ) ??
                                  0,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parseDioError(error))),
                        );
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (created == true) {
      await _loadDetail(detail.id);
    }
  }

  Future<void> _editOption(
    AdminStoryTemplateDetail detail,
    AdminStoryTemplateOptionModel option,
  ) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final optionKeyController = TextEditingController(text: option.optionKey);
    final labelController = TextEditingController(text: option.label);
    final sortOrderController = TextEditingController(
      text: option.sortOrder.toString(),
    );
    String selectedNextNodeId = option.nextNodeId;

    final updated = await withControllersDisposed<bool?>(
      [optionKeyController, labelController, sortOrderController],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Editar opção'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: optionKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Option key',
                        ),
                      ),
                      TextField(
                        controller: labelController,
                        decoration: const InputDecoration(labelText: 'Label'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedNextNodeId,
                        decoration: const InputDecoration(
                          labelText: 'Proximo no',
                        ),
                        items: detail.nodes
                            .map(
                              (node) => DropdownMenuItem<String>(
                                value: node.id,
                                child: Text('${node.nodeKey} · ${node.title}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedNextNodeId = value);
                          }
                        },
                      ),
                      TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ordem'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(adminApiProvider)
                            .updateStoryTemplateOption(
                              token,
                              detail.id,
                              option.id,
                              optionKey: optionKeyController.text.trim(),
                              label: labelController.text.trim(),
                              nextNodeId: selectedNextNodeId,
                              sortOrder:
                                  int.tryParse(
                                    sortOrderController.text.trim(),
                                  ) ??
                                  0,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parseDioError(error))),
                        );
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (updated == true) {
      await _loadDetail(detail.id);
    }
  }

  Future<void> _validateTemplate(AdminStoryTemplateDetail detail) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final validation = await ref
          .read(adminApiProvider)
          .validateStoryTemplate(token, detail.id);
      if (!mounted) {
        return;
      }
      setState(() => _lastValidation = validation);
      if (validation.valid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Template válido.')));
      }
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

  Future<void> _publishTemplate(AdminStoryTemplateDetail detail) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(adminApiProvider).publishStoryTemplate(token, detail.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Template publicado.')));
      await _bootstrap();
      await _loadDetail(detail.id);
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

  String _nodeTitle(AdminStoryTemplateDetail detail, String nodeId) {
    for (final node in detail.nodes) {
      if (node.id == nodeId) {
        return '${node.nodeKey} · ${node.title}';
      }
    }
    return nodeId;
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Templates')),
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Admin • Templates',
              subtitle: 'Árvore de decisão e publicação versionada.',
              assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroCastle),
              showMascot: true,
              mascotPose: ViscondeMascotPose.studyingDesk,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedTemplateId,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Selecione'),
                      ),
                      ..._templates.map(
                        (template) => DropdownMenuItem<String?>(
                          value: template.id,
                          child: Text(template.title),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedTemplateId = value);
                      if (value != null) {
                        _loadDetail(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _openCreateTemplateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail == null)
              const Text('Selecione um template para editar.'),
            if (detail != null) ...[
              ViscondeGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'slug: ${detail.slug} · v${detail.version} · ${detail.isPublished ? 'PUBLICADO' : 'RASCUNHO'}',
                      ),
                      Text(
                        'tema: ${detail.theme?.name ?? '-'} · virtude: ${detail.virtue?.name ?? '-'} · faixa: ${detail.ageBand ?? '-'}',
                      ),
                      const SizedBox(height: 8),
                      Text('Descrição: ${detail.description}'),
                      Text('Cenário padrão: ${detail.defaultScenario}'),
                      Text('Objetivo padrão: ${detail.defaultObjective}'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openEditTemplateDialog(detail),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar base'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _validateTemplate(detail),
                            icon: const Icon(Icons.rule_outlined),
                            label: const Text('Validar'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _publishTemplate(detail),
                            icon: const Icon(Icons.publish_outlined),
                            label: const Text('Publicar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_lastValidation != null)
                ViscondeGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lastValidation!.valid
                              ? 'Validação OK'
                              : 'Validação com erros',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _lastValidation!.valid
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_lastValidation!.issues.isEmpty)
                          const Text('Nenhum problema encontrado.'),
                        ..._lastValidation!.issues.map(
                          (issue) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '- ${issue.code}: ${issue.message}${issue.nodeId != null ? ' (node: ${issue.nodeId})' : ''}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Personagens (${detail.characters.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addCharacter(detail),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              ...detail.characters.map(
                (character) => ViscondeGlassCard(
                  child: ListTile(
                    title: Text(character.name),
                    subtitle: Text(
                      'role: ${character.role ?? '-'} · ordem ${character.sortOrder}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nos (${detail.nodes.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addNode(detail),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar no'),
                  ),
                ],
              ),
              ...detail.nodes.map(
                (node) => ViscondeGlassCard(
                  child: ExpansionTile(
                    title: Text('${node.nodeKey} · ${node.title}'),
                    subtitle: Text(
                      '${node.kind.name.toUpperCase()} · ordem ${node.sortOrder} · opções ${node.options.length}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      if ((node.narratorText ?? '').isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Narrador: ${node.narratorText}'),
                        ),
                      if ((node.promptHint ?? '').isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Hint: ${node.promptHint}'),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _editNode(detail, node),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar no'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _addOption(detail, initialNodeId: node.id),
                            icon: const Icon(Icons.add_link_outlined),
                            label: const Text('Nova opção'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (node.options.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Sem opções.'),
                        ),
                      ...node.options.map(
                        (option) => ViscondeGlassCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(option.label),
                            subtitle: Text(
                              'key: ${option.optionKey} · ordem ${option.sortOrder}\nproximo: ${_nodeTitle(detail, option.nextNodeId)}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              onPressed: () => _editOption(detail, option),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
