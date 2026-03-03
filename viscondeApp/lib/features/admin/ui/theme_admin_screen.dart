import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/controller_disposer.dart';
import '../../auth/auth_controller.dart';
import '../models/admin_models.dart';

class ThemeAdminScreen extends ConsumerStatefulWidget {
  const ThemeAdminScreen({super.key});

  @override
  ConsumerState<ThemeAdminScreen> createState() => _ThemeAdminScreenState();
}

class _ThemeAdminScreenState extends ConsumerState<ThemeAdminScreen> {
  bool _loading = false;
  List<AdminThemeModel> _themes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadThemes();
    });
  }

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  Future<void> _loadThemes() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ref.read(adminApiProvider).listThemes(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _themes = result;
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

  Future<void> _openCreateThemeDialog() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconController = TextEditingController(text: 'theme-default');
    final sortOrderController = TextEditingController(text: '0');
    bool isActive = true;

    final created = await withControllersDisposed<bool?>(
      [
        nameController,
        descriptionController,
        iconController,
        sortOrderController,
      ],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Novo tema'),
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
                        decoration: const InputDecoration(
                          labelText: 'Icon key',
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
                            .createTheme(
                              token,
                              name: nameController.text.trim(),
                              shortDescription: descriptionController.text
                                  .trim(),
                              iconKey: iconController.text.trim(),
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
      await _loadThemes();
    }
  }

  Future<void> _openEditThemeDialog(AdminThemeModel theme) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final nameController = TextEditingController(text: theme.name);
    final descriptionController = TextEditingController(
      text: theme.shortDescription,
    );
    final iconController = TextEditingController(text: theme.iconKey);
    final sortOrderController = TextEditingController(
      text: theme.sortOrder.toString(),
    );
    bool isActive = theme.isActive;

    final updated = await withControllersDisposed<bool?>(
      [
        nameController,
        descriptionController,
        iconController,
        sortOrderController,
      ],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Editar tema'),
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
                        decoration: const InputDecoration(
                          labelText: 'Icon key',
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
                            .updateTheme(
                              token,
                              theme.id,
                              name: nameController.text.trim(),
                              shortDescription: descriptionController.text
                                  .trim(),
                              iconKey: iconController.text.trim(),
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
      await _loadThemes();
    }
  }

  Future<void> _toggleTheme(AdminThemeModel theme, bool value) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    try {
      await ref
          .read(adminApiProvider)
          .updateTheme(token, theme.id, isActive: value);
      await _loadThemes();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Temas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateThemeDialog,
        icon: const Icon(Icons.add),
        label: const Text('Novo tema'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadThemes,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Admin • Temas',
              subtitle: 'Catálogo visual de temas do app.',
              assetPath: ViscondeArtRegistry.resolve(ViscondeArtKey.heroForest),
              showMascot: true,
              mascotPose: ViscondeMascotPose.studyingDesk,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            if (!_loading && _themes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Nenhum tema cadastrado.'),
              ),
            ..._themes.map(
              (theme) => ViscondeGlassCard(
                child: ListTile(
                  title: Text(theme.name),
                  subtitle: Text(
                    '${theme.shortDescription}\nslug: ${theme.slug} · ordem: ${theme.sortOrder}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch.adaptive(
                        value: theme.isActive,
                        onChanged: (value) => _toggleTheme(theme, value),
                      ),
                      IconButton(
                        onPressed: () => _openEditThemeDialog(theme),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
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
