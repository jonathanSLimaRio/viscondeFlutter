import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/controller_disposer.dart';
import '../../auth/auth_controller.dart';
import '../models/admin_models.dart';

class PromptAdminScreen extends ConsumerStatefulWidget {
  const PromptAdminScreen({super.key});

  @override
  ConsumerState<PromptAdminScreen> createState() => _PromptAdminScreenState();
}

class _PromptAdminScreenState extends ConsumerState<PromptAdminScreen> {
  static const _ageBands = <String>['AGE_4_5', 'AGE_6_8', 'AGE_9_10'];
  static const _modes = <String>['PARENT_NARRATOR', 'CHILD_CHOOSER'];

  bool _loading = false;
  List<AdminPromptModel> _prompts = const [];
  List<AdminThemeModel> _themes = const [];
  List<AdminVirtueModel> _virtues = const [];

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
        ref.read(adminApiProvider).listPrompts(token),
        ref.read(adminApiProvider).listThemes(token),
        ref.read(adminApiProvider).listVirtues(token),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _prompts = result[0] as List<AdminPromptModel>;
        _themes = result[1] as List<AdminThemeModel>;
        _virtues = result[2] as List<AdminVirtueModel>;
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

  String _kindLabel(AdminPromptKind kind) {
    switch (kind) {
      case AdminPromptKind.ideaSystem:
        return 'IDEA_SYSTEM';
      case AdminPromptKind.narratorHint:
        return 'NARRATOR_HINT';
      case AdminPromptKind.ideaFallback:
        return 'IDEA_FALLBACK';
    }
  }

  Future<void> _openCreatePromptDialog() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final keyController = TextEditingController();
    final titleController = TextEditingController();
    final textController = TextEditingController();
    final sortOrderController = TextEditingController(text: '0');

    AdminPromptKind kind = AdminPromptKind.ideaFallback;
    String? themeId;
    String? virtueId;
    String? ageBand;
    String? mode;
    bool isActive = true;

    final created = await withControllersDisposed<bool?>(
      [keyController, titleController, textController, sortOrderController],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Novo prompt'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: keyController,
                        decoration: const InputDecoration(
                          labelText: 'Key unica',
                        ),
                      ),
                      DropdownButtonFormField<AdminPromptKind>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: AdminPromptKind.values
                            .map(
                              (value) => DropdownMenuItem<AdminPromptKind>(
                                value: value,
                                child: Text(_kindLabel(value)),
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
                        decoration: const InputDecoration(labelText: 'Titulo'),
                      ),
                      TextField(
                        controller: textController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Texto'),
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: themeId,
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
                          setDialogState(() => themeId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: virtueId,
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
                          setDialogState(() => virtueId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: ageBand,
                        decoration: const InputDecoration(
                          labelText: 'Faixa etaria (opcional)',
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
                          setDialogState(() => ageBand = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: mode,
                        decoration: const InputDecoration(
                          labelText: 'Modo (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Qualquer'),
                          ),
                          ..._modes.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item,
                              child: Text(item),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => mode = value);
                        },
                      ),
                      TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ordem'),
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
                            .createPrompt(
                              token,
                              key: keyController.text.trim(),
                              kind: kind,
                              title: titleController.text.trim(),
                              text: textController.text.trim(),
                              themeId: themeId,
                              virtueId: virtueId,
                              ageBand: ageBand,
                              mode: mode,
                              sortOrder:
                                  int.tryParse(
                                    sortOrderController.text.trim(),
                                  ) ??
                                  0,
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

    if (created == true) {
      await _bootstrap();
    }
  }

  Future<void> _openEditPromptDialog(AdminPromptModel prompt) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final keyController = TextEditingController(text: prompt.key);
    final titleController = TextEditingController(text: prompt.title);
    final textController = TextEditingController(text: prompt.text);
    final sortOrderController = TextEditingController(
      text: prompt.sortOrder.toString(),
    );

    AdminPromptKind kind = prompt.kind;
    String? themeId = prompt.theme?.id;
    String? virtueId = prompt.virtue?.id;
    String? ageBand = prompt.ageBand;
    String? mode = prompt.mode;
    bool isActive = prompt.isActive;

    final updated = await withControllersDisposed<bool?>(
      [keyController, titleController, textController, sortOrderController],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Editar prompt'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: keyController,
                        decoration: const InputDecoration(
                          labelText: 'Key unica',
                        ),
                      ),
                      DropdownButtonFormField<AdminPromptKind>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: AdminPromptKind.values
                            .map(
                              (value) => DropdownMenuItem<AdminPromptKind>(
                                value: value,
                                child: Text(_kindLabel(value)),
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
                        decoration: const InputDecoration(labelText: 'Titulo'),
                      ),
                      TextField(
                        controller: textController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Texto'),
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: themeId,
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
                          setDialogState(() => themeId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: virtueId,
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
                          setDialogState(() => virtueId = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: ageBand,
                        decoration: const InputDecoration(
                          labelText: 'Faixa etaria (opcional)',
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
                          setDialogState(() => ageBand = value);
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: mode,
                        decoration: const InputDecoration(
                          labelText: 'Modo (opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Qualquer'),
                          ),
                          ..._modes.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item,
                              child: Text(item),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => mode = value);
                        },
                      ),
                      TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ordem'),
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
                            .updatePrompt(
                              token,
                              prompt.id,
                              key: keyController.text.trim(),
                              kind: kind,
                              title: titleController.text.trim(),
                              text: textController.text.trim(),
                              themeId: themeId,
                              virtueId: virtueId,
                              ageBand: ageBand,
                              mode: mode,
                              sortOrder:
                                  int.tryParse(
                                    sortOrderController.text.trim(),
                                  ) ??
                                  0,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Prompts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePromptDialog,
        icon: const Icon(Icons.add),
        label: const Text('Novo prompt'),
      ),
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Admin • Prompts',
              subtitle: 'Prompts de ideia, fallback e narração.',
              assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroSpace),
              showMascot: true,
              mascotPose: ViscondeMascotPose.studyingDesk,
              trailing: ViscondeAvatarBadge(
                imageAsset: ViscondeArtRegistry.resolve(
                  ViscondeArtKey.avatarParent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            if (!_loading && _prompts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Nenhum prompt cadastrado.'),
              ),
            ..._prompts.map(
              (prompt) => ViscondeGlassCard(
                child: ListTile(
                  title: Text(prompt.title),
                  subtitle: Text(
                    '${_kindLabel(prompt.kind)} · key: ${prompt.key}'
                    '\n${prompt.text}'
                    '${prompt.theme != null ? '\nTema: ${prompt.theme!.name}' : ''}'
                    '${prompt.virtue != null ? ' · Virtude: ${prompt.virtue!.name}' : ''}'
                    '${prompt.ageBand != null ? '\nFaixa: ${prompt.ageBand}' : ''}'
                    '${prompt.mode != null ? ' · Modo: ${prompt.mode}' : ''}'
                    '\nOrdem: ${prompt.sortOrder} · ${prompt.isActive ? 'Ativo' : 'Inativo'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _openEditPromptDialog(prompt),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
