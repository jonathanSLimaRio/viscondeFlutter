import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/child_profile.dart';
import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/avatar_presets.dart';
import '../../../shared/providers.dart';
import '../../../shared/ux_analytics.dart';
import '../../auth/auth_controller.dart';

class FamilyAvatarScreen extends ConsumerStatefulWidget {
  const FamilyAvatarScreen({
    super.key,
    this.source = 'unknown',
    this.preferredChildId,
  });

  final String source;
  final String? preferredChildId;

  @override
  ConsumerState<FamilyAvatarScreen> createState() => _FamilyAvatarScreenState();
}

class _AvatarDraft {
  const _AvatarDraft({
    required this.presetKey,
    required this.variant,
    required this.accent,
  });

  final String presetKey;
  final int variant;
  final String accent;

  _AvatarDraft copyWith({String? presetKey, int? variant, String? accent}) {
    return _AvatarDraft(
      presetKey: presetKey ?? this.presetKey,
      variant: variant ?? this.variant,
      accent: accent ?? this.accent,
    );
  }
}

class _FamilyAvatarScreenState extends ConsumerState<FamilyAvatarScreen> {
  bool _loadingChildren = false;
  bool _savingParent = false;
  bool _savingChild = false;
  List<ChildProfile> _children = const <ChildProfile>[];
  String? _selectedChildId;
  late _AvatarDraft _parentDraft;
  final Map<String, _AvatarDraft> _childDraftById = <String, _AvatarDraft>{};

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _parentDraft = _AvatarDraft(
      presetKey: user?.avatarPresetKey ?? 'guardian',
      variant: normalizeAvatarVariant(user?.avatarVariant),
      accent: user?.avatarAccent ?? 'amber',
    );

    UxAnalytics.log(
      'avatar_editor_opened',
      params: <String, Object?>{
        'source': widget.source,
        'target': 'family',
        if (widget.preferredChildId != null)
          'child_id': widget.preferredChildId,
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChildren();
    });
  }

  _AvatarDraft _draftForChild(ChildProfile child) {
    return _childDraftById[child.id] ??
        _AvatarDraft(
          presetKey: child.avatarPresetKey,
          variant: normalizeAvatarVariant(child.avatarVariant),
          accent: child.avatarAccent,
        );
  }

  ChildProfile? get _selectedChild {
    if (_children.isEmpty || _selectedChildId == null) {
      return null;
    }
    for (final child in _children) {
      if (child.id == _selectedChildId) {
        return child;
      }
    }
    return null;
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

      final preferred = widget.preferredChildId;
      String? selected;
      if (preferred != null && children.any((child) => child.id == preferred)) {
        selected = preferred;
      } else {
        final existing = _selectedChildId;
        if (existing != null && children.any((child) => child.id == existing)) {
          selected = existing;
        } else if (children.isNotEmpty) {
          selected = children.first.id;
        }
      }

      for (final child in children) {
        _childDraftById.putIfAbsent(
          child.id,
          () => _AvatarDraft(
            presetKey: child.avatarPresetKey,
            variant: normalizeAvatarVariant(child.avatarVariant),
            accent: child.avatarAccent,
          ),
        );
      }

      setState(() {
        _children = children;
        _selectedChildId = selected;
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

  Future<void> _saveParent() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null || _savingParent) {
      return;
    }

    setState(() => _savingParent = true);
    try {
      final updated = await ref
          .read(profileApiProvider)
          .updateAvatarPreset(
            token,
            avatarPresetKey: _parentDraft.presetKey,
            avatarVariant: _parentDraft.variant,
            avatarAccent: _parentDraft.accent,
          );
      ref.read(authControllerProvider.notifier).updateUser(updated);

      UxAnalytics.log(
        'avatar_saved',
        params: <String, Object?>{
          'source': widget.source,
          'target': 'parent',
          'avatar_preset_key': _parentDraft.presetKey,
          'avatar_variant': _parentDraft.variant,
          'avatar_accent': _parentDraft.accent,
        },
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar do pai atualizado.')),
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
        setState(() => _savingParent = false);
      }
    }
  }

  Future<void> _saveChild() async {
    final token = ref.read(authControllerProvider).accessToken;
    final child = _selectedChild;
    if (token == null || child == null || _savingChild) {
      return;
    }

    final draft = _draftForChild(child);

    setState(() => _savingChild = true);
    try {
      final updated = await ref
          .read(childrenApiProvider)
          .updateAvatarPreset(
            token,
            child.id,
            avatarPresetKey: draft.presetKey,
            avatarVariant: draft.variant,
            avatarAccent: draft.accent,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _children = _children
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
        _childDraftById[updated.id] = _AvatarDraft(
          presetKey: updated.avatarPresetKey,
          variant: normalizeAvatarVariant(updated.avatarVariant),
          accent: updated.avatarAccent,
        );
      });

      UxAnalytics.log(
        'avatar_saved',
        params: <String, Object?>{
          'source': widget.source,
          'target': 'child',
          'child_id': child.id,
          'avatar_preset_key': draft.presetKey,
          'avatar_variant': draft.variant,
          'avatar_accent': draft.accent,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar de ${updated.name} atualizado.')),
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
        setState(() => _savingChild = false);
      }
    }
  }

  Widget _buildAvatarPreview({
    required String label,
    required bool isParent,
    required String presetKey,
    required int variant,
    required String accent,
  }) {
    final asset = resolveAvatarAsset(
      isParent: isParent,
      avatarPresetKey: presetKey,
      avatarVariant: variant,
    );
    final accentColor = resolveAvatarAccentColor(accent);

    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 3),
          ),
          child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Preset ${presetKey.toUpperCase()} · Variação $variant',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.viscondeColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetEditor({
    required bool isParent,
    required _AvatarDraft draft,
    required ValueChanged<_AvatarDraft> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preset',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: avatarPresetOptions
              .map((preset) {
                return ChoiceChip(
                  selected: draft.presetKey == preset.key,
                  label: Text(preset.label),
                  onSelected: (_) =>
                      onChanged(draft.copyWith(presetKey: preset.key)),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Text(
          'Variação',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <int>[1, 2, 3]
              .map((variant) {
                final asset = resolveAvatarAsset(
                  isParent: isParent,
                  avatarPresetKey: draft.presetKey,
                  avatarVariant: variant,
                );
                return ChoiceChip(
                  selected: draft.variant == variant,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: AssetImage(asset),
                      ),
                      const SizedBox(width: 6),
                      Text('V$variant'),
                    ],
                  ),
                  onSelected: (_) =>
                      onChanged(draft.copyWith(variant: variant)),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Text(
          'Cor',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: avatarAccentOptions
              .map((accent) {
                return ChoiceChip(
                  selected: draft.accent == accent.key,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: accent.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(accent.label),
                    ],
                  ),
                  onSelected: (_) =>
                      onChanged(draft.copyWith(accent: accent.key)),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedChild = _selectedChild;

    return Scaffold(
      appBar: AppBar(title: const Text('Avatares da Família')),
      body: RefreshIndicator(
        onRefresh: _loadChildren,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            ViscondeGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ViscondeSectionTitle(
                    title: 'Avatar do Pai',
                    subtitle: 'Escolha rápida para o modo aventura.',
                  ),
                  const SizedBox(height: 12),
                  _buildAvatarPreview(
                    label: 'Pai narrador',
                    isParent: true,
                    presetKey: _parentDraft.presetKey,
                    variant: _parentDraft.variant,
                    accent: _parentDraft.accent,
                  ),
                  const SizedBox(height: 12),
                  _buildPresetEditor(
                    isParent: true,
                    draft: _parentDraft,
                    onChanged: (value) => setState(() => _parentDraft = value),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _savingParent ? null : _saveParent,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_savingParent ? 'Salvando...' : 'Salvar pai'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ViscondeGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ViscondeSectionTitle(
                    title: 'Avatar da Criança',
                    subtitle: 'Configure um avatar para cada criança.',
                  ),
                  const SizedBox(height: 12),
                  if (_loadingChildren)
                    const LinearProgressIndicator()
                  else if (_children.isEmpty)
                    Text(
                      'Cadastre uma criança em Perfil > Crianças para montar o avatar infantil.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedChildId,
                      decoration: const InputDecoration(labelText: 'Criança'),
                      items: _children
                          .map(
                            (child) => DropdownMenuItem<String>(
                              value: child.id,
                              child: Text(child.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        setState(() => _selectedChildId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedChild != null) ...[
                      _buildAvatarPreview(
                        label: selectedChild.name,
                        isParent: false,
                        presetKey: _draftForChild(selectedChild).presetKey,
                        variant: _draftForChild(selectedChild).variant,
                        accent: _draftForChild(selectedChild).accent,
                      ),
                      const SizedBox(height: 12),
                      _buildPresetEditor(
                        isParent: false,
                        draft: _draftForChild(selectedChild),
                        onChanged: (value) {
                          setState(() {
                            _childDraftById[selectedChild.id] = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _savingChild ? null : _saveChild,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _savingChild ? 'Salvando...' : 'Salvar criança',
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
