import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final _nameController = TextEditingController();
  final _timezoneController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final profileApi = ref.read(profileApiProvider);
      final user = await profileApi.getMe(token);
      ref.read(authControllerProvider.notifier).updateUser(user);

      _nameController.text = user.name ?? '';
      _timezoneController.text = user.timezone;
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

  Future<void> _saveProfile() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final profileApi = ref.read(profileApiProvider);
      final updated = await profileApi.updateMe(
        token,
        name: _nameController.text.trim(),
        timezone: _timezoneController.text.trim(),
      );
      ref.read(authControllerProvider.notifier).updateUser(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
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

  Future<void> _pickAndUploadPhoto() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.accessToken;
    if (token == null) return;

    final imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _loading = true);
    try {
      final profileApi = ref.read(profileApiProvider);
      final updated = await profileApi.updatePhoto(token, filePath: image.path);

      ref.read(authControllerProvider.notifier).updateUser(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto atualizada.')));
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user?.imageUrl != null)
            CircleAvatar(
              radius: 42,
              backgroundImage: NetworkImage(user!.imageUrl!),
            )
          else
            const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _loading ? null : _pickAndUploadPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Alterar foto'),
            ),
          ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timezoneController,
            decoration: const InputDecoration(labelText: 'Fuso horario'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _saveProfile,
            child: Text(_loading ? 'Salvando...' : 'Salvar perfil'),
          ),
          const SizedBox(height: 20),
          Text('E-mail: ${user?.email ?? '-'}'),
          Text('ID: ${user?.id ?? '-'}'),
        ],
      ),
    );
  }
}
