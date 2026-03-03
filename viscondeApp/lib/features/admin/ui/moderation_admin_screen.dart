import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ui/controller_disposer.dart';
import '../../auth/auth_controller.dart';
import '../models/admin_models.dart';

class ModerationAdminScreen extends ConsumerStatefulWidget {
  const ModerationAdminScreen({super.key});

  @override
  ConsumerState<ModerationAdminScreen> createState() =>
      _ModerationAdminScreenState();
}

class _ModerationAdminScreenState extends ConsumerState<ModerationAdminScreen> {
  bool _loading = false;
  List<AdminModerationTermModel> _terms = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTerms();
    });
  }

  String? _accessToken() {
    return ref.read(authControllerProvider).accessToken;
  }

  Future<void> _loadTerms() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final terms = await ref.read(adminApiProvider).listModerationTerms(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _terms = terms;
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

  String _policyLabel(AdminModerationPolicy value) {
    switch (value) {
      case AdminModerationPolicy.block:
        return 'BLOCK';
      case AdminModerationPolicy.sanitize:
        return 'SANITIZE';
    }
  }

  String _scopeLabel(AdminModerationScope value) {
    switch (value) {
      case AdminModerationScope.userName:
        return 'USER_NAME';
      case AdminModerationScope.childName:
        return 'CHILD_NAME';
      case AdminModerationScope.storyText:
        return 'STORY_TEXT';
      case AdminModerationScope.chatText:
        return 'CHAT_TEXT';
      case AdminModerationScope.templateText:
        return 'TEMPLATE_TEXT';
    }
  }

  Future<void> _openCreateTermDialog() async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final displayTermController = TextEditingController();
    final replacementController = TextEditingController();
    AdminModerationPolicy policy = AdminModerationPolicy.block;
    AdminModerationScope scope = AdminModerationScope.templateText;
    bool isActive = true;

    final created = await withControllersDisposed<bool?>(
      [displayTermController, replacementController],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Novo termo'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: displayTermController,
                        decoration: const InputDecoration(
                          labelText: 'Termo (display)',
                        ),
                      ),
                      DropdownButtonFormField<AdminModerationPolicy>(
                        initialValue: policy,
                        decoration: const InputDecoration(
                          labelText: 'Politica',
                        ),
                        items: AdminModerationPolicy.values
                            .map(
                              (item) => DropdownMenuItem<AdminModerationPolicy>(
                                value: item,
                                child: Text(_policyLabel(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => policy = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<AdminModerationScope>(
                        initialValue: scope,
                        decoration: const InputDecoration(labelText: 'Escopo'),
                        items: AdminModerationScope.values
                            .map(
                              (item) => DropdownMenuItem<AdminModerationScope>(
                                value: item,
                                child: Text(_scopeLabel(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => scope = value);
                          }
                        },
                      ),
                      TextField(
                        controller: replacementController,
                        decoration: const InputDecoration(
                          labelText: 'Replacement (opcional)',
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
                            .createModerationTerm(
                              token,
                              displayTerm: displayTermController.text.trim(),
                              policy: policy,
                              scope: scope,
                              replacement: replacementController.text.trim(),
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
      await _loadTerms();
    }
  }

  Future<void> _openEditTermDialog(AdminModerationTermModel term) async {
    final token = _accessToken();
    if (token == null) {
      return;
    }

    final displayTermController = TextEditingController(text: term.displayTerm);
    final replacementController = TextEditingController(
      text: term.replacement ?? '',
    );
    AdminModerationPolicy policy = term.policy;
    AdminModerationScope scope = term.scope;
    bool isActive = term.isActive;

    final updated = await withControllersDisposed<bool?>(
      [displayTermController, replacementController],
      () => showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Editar termo'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: displayTermController,
                        decoration: const InputDecoration(
                          labelText: 'Termo (display)',
                        ),
                      ),
                      DropdownButtonFormField<AdminModerationPolicy>(
                        initialValue: policy,
                        decoration: const InputDecoration(
                          labelText: 'Politica',
                        ),
                        items: AdminModerationPolicy.values
                            .map(
                              (item) => DropdownMenuItem<AdminModerationPolicy>(
                                value: item,
                                child: Text(_policyLabel(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => policy = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<AdminModerationScope>(
                        initialValue: scope,
                        decoration: const InputDecoration(labelText: 'Escopo'),
                        items: AdminModerationScope.values
                            .map(
                              (item) => DropdownMenuItem<AdminModerationScope>(
                                value: item,
                                child: Text(_scopeLabel(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => scope = value);
                          }
                        },
                      ),
                      TextField(
                        controller: replacementController,
                        decoration: const InputDecoration(
                          labelText: 'Replacement (opcional)',
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
                            .updateModerationTerm(
                              token,
                              term.id,
                              displayTerm: displayTermController.text.trim(),
                              policy: policy,
                              scope: scope,
                              replacement: replacementController.text.trim(),
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
      await _loadTerms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Moderação')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTermDialog,
        icon: const Icon(Icons.add),
        label: const Text('Novo termo'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTerms,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Admin • Moderação',
              subtitle: 'Termos bloqueados e políticas por escopo.',
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
            if (!_loading && _terms.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Nenhum termo de moderação cadastrado.'),
              ),
            ..._terms.map(
              (term) => ViscondeGlassCard(
                child: ListTile(
                  title: Text(term.displayTerm),
                  subtitle: Text(
                    '${_scopeLabel(term.scope)} · ${_policyLabel(term.policy)}'
                    '${term.replacement != null && term.replacement!.isNotEmpty ? '\nreplacement: ${term.replacement}' : ''}'
                    '\nnormalizado: ${term.termNormalized} · ${term.isActive ? 'Ativo' : 'Inativo'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _openEditTermDialog(term),
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
