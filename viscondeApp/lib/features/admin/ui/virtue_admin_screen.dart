import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../models/admin_models.dart';

class VirtueAdminScreen extends ConsumerStatefulWidget {
  const VirtueAdminScreen({super.key});

  @override
  ConsumerState<VirtueAdminScreen> createState() => _VirtueAdminScreenState();
}

class _VirtueAdminScreenState extends ConsumerState<VirtueAdminScreen> {
  static const _ageBands = <String>['AGE_4_5', 'AGE_6_8', 'AGE_9_10'];

  bool _loading = false;
  List<AdminVirtueModel> _virtues = const [];
  List<AdminVirtueTemplateModel> _templates = const [];

  String? _templateVirtueFilter;
  String? _templateAgeBandFilter;

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
    await _loadVirtues();
    await _loadTemplates();
  }

  Future<void> _loadVirtues() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final virtues = await ref.read(adminApiProvider).listVirtues(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _virtues = virtues;
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

  Future<void> _loadTemplates() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final templates = await ref
          .read(adminApiProvider)
          .listVirtueTemplates(
            token,
            virtueId: _templateVirtueFilter,
            ageBand: _templateAgeBandFilter,
          );
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openCreateVirtueDialog() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconController = TextEditingController(text: 'virtue-default');
    final sortOrderController = TextEditingController(text: '0');
    bool isActive = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nova virtude'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descricao curta',
                      ),
                    ),
                    TextField(
                      controller: iconController,
                      decoration: const InputDecoration(labelText: 'Icon key'),
                    ),
                    TextField(
                      controller: sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ordem'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ativa'),
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
                          .createVirtue(
                            token,
                            name: nameController.text.trim(),
                            shortDescription: descriptionController.text.trim(),
                            iconKey: iconController.text.trim(),
                            sortOrder:
                                int.tryParse(sortOrderController.text.trim()) ??
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
    );

    if (created == true) {
      await _loadVirtues();
    }
  }

  Future<void> _openEditVirtueDialog(AdminVirtueModel virtue) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final nameController = TextEditingController(text: virtue.name);
    final descriptionController = TextEditingController(
      text: virtue.shortDescription,
    );
    final iconController = TextEditingController(text: virtue.iconKey);
    final sortOrderController = TextEditingController(
      text: virtue.sortOrder.toString(),
    );
    bool isActive = virtue.isActive;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar virtude'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descricao curta',
                      ),
                    ),
                    TextField(
                      controller: iconController,
                      decoration: const InputDecoration(labelText: 'Icon key'),
                    ),
                    TextField(
                      controller: sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ordem'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ativa'),
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
                          .updateVirtue(
                            token,
                            virtue.id,
                            name: nameController.text.trim(),
                            shortDescription: descriptionController.text.trim(),
                            iconKey: iconController.text.trim(),
                            sortOrder:
                                int.tryParse(sortOrderController.text.trim()) ??
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
    );

    if (updated == true) {
      await _loadVirtues();
      await _loadTemplates();
    }
  }

  Future<void> _toggleVirtue(AdminVirtueModel virtue, bool active) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    try {
      await ref
          .read(adminApiProvider)
          .updateVirtue(token, virtue.id, isActive: active);
      await _loadVirtues();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    }
  }

  Future<void> _openCreateTemplateDialog() async {
    final token = _accessToken();
    if (token == null || _virtues.isEmpty) {
      return;
    }

    final dilemmaController = TextEditingController();
    final questionController = TextEditingController();
    final sortOrderController = TextEditingController(text: '0');
    String selectedVirtueId = _templateVirtueFilter ?? _virtues.first.id;
    String selectedAgeBand = _templateAgeBandFilter ?? _ageBands.first;
    bool isActive = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Novo template de virtude'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedVirtueId,
                      decoration: const InputDecoration(labelText: 'Virtude'),
                      items: _virtues
                          .map(
                            (virtue) => DropdownMenuItem<String>(
                              value: virtue.id,
                              child: Text(virtue.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedVirtueId = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAgeBand,
                      decoration: const InputDecoration(
                        labelText: 'Faixa etaria',
                      ),
                      items: _ageBands
                          .map(
                            (band) => DropdownMenuItem<String>(
                              value: band,
                              child: Text(band),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedAgeBand = value);
                        }
                      },
                    ),
                    TextField(
                      controller: dilemmaController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Dilema'),
                    ),
                    TextField(
                      controller: questionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Pergunta final',
                      ),
                    ),
                    TextField(
                      controller: sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ordem'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() => isActive = value);
                      },
                      title: const Text('Ativo'),
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
                          .createVirtueTemplate(
                            token,
                            virtueId: selectedVirtueId,
                            ageBand: selectedAgeBand,
                            dilemmaText: dilemmaController.text.trim(),
                            endQuestionText: questionController.text.trim(),
                            sortOrder:
                                int.tryParse(sortOrderController.text.trim()) ??
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
    );

    if (created == true) {
      await _loadTemplates();
    }
  }

  Future<void> _openEditTemplateDialog(
    AdminVirtueTemplateModel template,
  ) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final dilemmaController = TextEditingController(text: template.dilemmaText);
    final questionController = TextEditingController(
      text: template.endQuestionText,
    );
    final sortOrderController = TextEditingController(
      text: template.sortOrder.toString(),
    );
    bool isActive = template.isActive;

    final updated = await showDialog<bool>(
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
                    Text(
                      'Faixa: ${template.ageBand}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dilemmaController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Dilema'),
                    ),
                    TextField(
                      controller: questionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Pergunta final',
                      ),
                    ),
                    TextField(
                      controller: sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ordem'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() => isActive = value);
                      },
                      title: const Text('Ativo'),
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
                          .updateVirtueTemplate(
                            token,
                            template.id,
                            dilemmaText: dilemmaController.text.trim(),
                            endQuestionText: questionController.text.trim(),
                            sortOrder:
                                int.tryParse(sortOrderController.text.trim()) ??
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
    );

    if (updated == true) {
      await _loadTemplates();
    }
  }

  String _virtueName(String virtueId) {
    return _virtues
        .firstWhere(
          (value) => value.id == virtueId,
          orElse: () => const AdminVirtueModel(
            id: '',
            slug: '',
            name: 'Virtude',
            shortDescription: '',
            iconKey: '',
            sortOrder: 0,
            isActive: true,
          ),
        )
        .name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Virtudes')),
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Admin • Virtudes',
              subtitle: 'Virtudes ativas e dilemas por faixa etária.',
              assetPath: ViscondeArtRegistry.resolve(
                ViscondeArtKey.heroTreasure,
              ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Virtudes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openCreateVirtueDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._virtues.map(
              (virtue) => ViscondeGlassCard(
                child: ListTile(
                  title: Text(virtue.name),
                  subtitle: Text(
                    '${virtue.shortDescription}\nslug: ${virtue.slug} · ordem: ${virtue.sortOrder}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch.adaptive(
                        value: virtue.isActive,
                        onChanged: (value) => _toggleVirtue(virtue, value),
                      ),
                      IconButton(
                        onPressed: () => _openEditVirtueDialog(virtue),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Templates por virtude',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _virtues.isEmpty
                      ? null
                      : _openCreateTemplateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _templateVirtueFilter,
                    decoration: const InputDecoration(labelText: 'Virtude'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._virtues.map(
                        (virtue) => DropdownMenuItem<String?>(
                          value: virtue.id,
                          child: Text(virtue.name),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      setState(() => _templateVirtueFilter = value);
                      await _loadTemplates();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _templateAgeBandFilter,
                    decoration: const InputDecoration(
                      labelText: 'Faixa etaria',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._ageBands.map(
                        (band) => DropdownMenuItem<String?>(
                          value: band,
                          child: Text(band),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      setState(() => _templateAgeBandFilter = value);
                      await _loadTemplates();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._templates.map(
              (item) => ViscondeGlassCard(
                child: ListTile(
                  title: Text(_virtueName(item.virtueId)),
                  subtitle: Text(
                    '${item.ageBand} · ordem ${item.sortOrder}'
                    '\nDilema: ${item.dilemmaText}'
                    '\nPergunta: ${item.endQuestionText}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isActive
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                      ),
                      IconButton(
                        onPressed: () => _openEditTemplateDialog(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_loading && _templates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Nenhum template para os filtros atuais.'),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
