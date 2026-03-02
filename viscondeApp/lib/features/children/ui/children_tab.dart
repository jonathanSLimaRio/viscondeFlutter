import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';

class ChildrenTab extends ConsumerStatefulWidget {
  const ChildrenTab({super.key});

  @override
  ConsumerState<ChildrenTab> createState() => _ChildrenTabState();
}

class _ChildrenTabState extends ConsumerState<ChildrenTab> {
  List<ChildProfile> _children = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChildren();
    });
  }

  Future<void> _loadChildren() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final childrenApi = ref.read(childrenApiProvider);
      final children = await childrenApi.listChildren(token);

      if (!mounted) return;
      setState(() {
        _children = children;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openChildForm({ChildProfile? child}) async {
    final nameController = TextEditingController(text: child?.name ?? '');
    final themesController = TextEditingController(
      text: child?.favoriteThemes.join(', ') ?? '',
    );
    DateTime birthDate = child?.birthDate ?? DateTime(2018, 1, 1);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    child == null ? 'Nova crianca' : 'Editar crianca',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: themesController,
                    decoration: const InputDecoration(
                      labelText: 'Temas favoritos (separados por virgula)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nascimento: ${DateFormat('dd/MM/yyyy').format(birthDate)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: birthDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );

                          if (selected != null) {
                            setModalState(() => birthDate = selected);
                          }
                        },
                        child: const Text('Escolher'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        return;
                      }

                      final token = ref
                          .read(authControllerProvider)
                          .accessToken;
                      if (token == null) return;

                      final themes = themesController.text
                          .split(',')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList();

                      try {
                        final childrenApi = ref.read(childrenApiProvider);
                        if (child == null) {
                          await childrenApi.createChild(
                            token,
                            name: name,
                            birthDate: birthDate,
                            favoriteThemes: themes,
                          );
                        } else {
                          await childrenApi.updateChild(
                            token,
                            child.id,
                            name: name,
                            birthDate: birthDate,
                            favoriteThemes: themes,
                          );
                        }

                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(parseDioError(error))),
                          );
                        }
                      }
                    },
                    child: Text(child == null ? 'Criar' : 'Salvar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    themesController.dispose();

    if (result == true) {
      await _loadChildren();
    }
  }

  Future<void> _deleteChild(ChildProfile child) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref.read(childrenApiProvider).deleteChild(token, child.id);
      await _loadChildren();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    }
  }

  Future<void> _uploadAvatar(ChildProfile child) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      await ref
          .read(childrenApiProvider)
          .uploadAvatar(token, child.id, filePath: image.path);
      await _loadChildren();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadChildren,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: () => _openChildForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar crianca'),
                ),
                const SizedBox(height: 12),
                if (_children.isEmpty)
                  ViscondeGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: const [
                          ViscondeMascot(
                            pose: ViscondeMascotPose.readingBookClose,
                            size: 180,
                            glow: true,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Nenhuma criança cadastrada ainda.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Cadastre uma criança para começar novas aventuras.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ..._children.map(
                  (child) => Card(
                    child: ListTile(
                      leading: child.avatarUrl != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(child.avatarUrl!),
                            )
                          : const CircleAvatar(child: Icon(Icons.child_care)),
                      title: Text(child.name),
                      subtitle: Text(
                        'Nascimento: ${DateFormat('dd/MM/yyyy').format(child.birthDate)}\nTemas: ${child.favoriteThemes.join(', ')}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openChildForm(child: child);
                            return;
                          }
                          if (value == 'avatar') {
                            _uploadAvatar(child);
                            return;
                          }
                          if (value == 'delete') {
                            _deleteChild(child);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'avatar',
                            child: Text('Trocar avatar'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Arquivar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
