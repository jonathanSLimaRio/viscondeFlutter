import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_route.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
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
    final colors = context.viscondeColors;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const SizedBox(height: 12),
          _buildAvatarSection(context, user),
          const SizedBox(height: 16),
          _buildFormCard(context),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E-mail: ${user?.email ?? '-'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${user?.id ?? '-'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, dynamic user) {
    final colors = context.viscondeColors;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.3),
                colors.accent.withValues(alpha: 0.4),
                colors.secondary.withValues(alpha: 0.3),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: user?.imageUrl != null
                ? CircleAvatar(
                    radius: 56,
                    backgroundImage: NetworkImage(user!.imageUrl!),
                  )
                : CircleAvatar(
                    radius: 56,
                    backgroundColor: colors.parchment,
                    child: Icon(
                      Icons.person_pin_rounded,
                      size: 56,
                      color: colors.textMuted,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _loading ? null : _pickAndUploadPhoto,
          icon: Icon(
            Icons.camera_alt_outlined,
            size: 18,
            color: colors.textMuted,
          ),
          label: Text(
            'Alterar foto',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            UxAnalytics.log(
              'avatar_editor_opened',
              params: const <String, Object?>{
                'source': 'profile_tab',
                'target': 'family',
              },
            );
            context.push(AppRoute.avatarEditorPath(source: 'profile_tab'));
          },
          icon: Icon(Icons.palette_outlined, size: 18, color: colors.textMuted),
          label: Text(
            'Avatares da família',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return ViscondeGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabeledField(
            context: context,
            label: 'Nome',
            child: _buildPillInput(
              context: context,
              controller: _nameController,
              hintText: 'Digite seu nome',
            ),
          ),
          const SizedBox(height: 16),
          _buildLabeledField(
            context: context,
            label: 'Fuso horário',
            child: _buildPillInput(
              context: context,
              controller: _timezoneController,
              hintText: 'UTC-03:00 Brasilia',
              suffixIcon: Icons.keyboard_arrow_down_rounded,
            ),
          ),
          const SizedBox(height: 20),
          ViscondePrimaryCta(
            onPressed: _loading ? null : _saveProfile,
            label: _loading ? 'Salvando...' : 'Salvar perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required BuildContext context,
    required String label,
    required Widget child,
  }) {
    final colors = context.viscondeColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildPillInput({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    IconData? suffixIcon,
  }) {
    final colors = context.viscondeColors;

    return TextField(
      controller: controller,
      style: TextStyle(color: colors.textStrong, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 15),
        filled: true,
        fillColor: colors.parchmentSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(suffixIcon, color: colors.textMuted, size: 22),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}
