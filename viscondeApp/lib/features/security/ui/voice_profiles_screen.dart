import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../models/voice_models.dart';
import '../parental_gate_controller.dart';

class VoiceProfilesScreen extends ConsumerStatefulWidget {
  const VoiceProfilesScreen({super.key});

  @override
  ConsumerState<VoiceProfilesScreen> createState() =>
      _VoiceProfilesScreenState();
}

class _VoiceProfilesScreenState extends ConsumerState<VoiceProfilesScreen> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  List<VoiceProfileModel> _profiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfiles();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final token = ref.read(authControllerProvider).accessToken;
    final gate = ref.read(parentalGateControllerProvider);
    if (token == null || !gate.isUnlocked || gate.unlockToken == null) return;

    setState(() => _loading = true);
    try {
      final list = await ref
          .read(voiceApiProvider)
          .listProfiles(parentalUnlockToken: gate.unlockToken!);
      if (!mounted) return;
      setState(() => _profiles = list);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _ensureUnlocked({required String source}) async {
    return ref
        .read(parentalUnlockServiceProvider)
        .ensureUnlocked(context, source: source);
  }

  Future<void> _unlockAndLoad() async {
    final unlockToken = await _ensureUnlocked(source: 'adult_voices_unlock');
    if (unlockToken == null || !mounted) {
      return;
    }
    await _loadProfiles();
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    final unlockToken = await _ensureUnlocked(
      source: 'adult_voices_create_profile',
    );
    if (unlockToken == null) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(voiceApiProvider)
          .createProfile(
            name: name,
            relationship: _relationController.text.trim(),
            parentalUnlockToken: unlockToken,
          );
      _nameController.clear();
      _relationController.clear();
      await _loadProfiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
      setState(() => _loading = false);
    }
  }

  Future<void> _trainProfile(String id) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    final unlockToken = await _ensureUnlocked(
      source: 'adult_voices_train_profile',
    );
    if (unlockToken == null) return;

    setState(() => _loading = true);
    try {
      // MVP de treinamento (mock endpoint no backend muda o status pra READY).
      await ref
          .read(voiceApiProvider)
          .trainProfile(id, parentalUnlockToken: unlockToken);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voz treinada com sucesso!')),
      );
      await _loadProfiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(parentalGateControllerProvider);

    if (!gate.isUnlocked || gate.unlockToken == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voz Inesquecível')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ViscondeSectionTitle(
                    title: 'Área protegida',
                    subtitle:
                        'Desbloqueie via PIN para acessar vozes da família.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _unlockAndLoad,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Desbloquear agora'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_loading && _profiles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voz Inesquecível')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Voz Inesquecível')),
      body: RefreshIndicator(
        onRefresh: _loadProfiles,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'A voz da sua família',
              subtitle:
                  'Crie perfis e guarde para sempre a voz de quem você ama na narração.',
              assetPath: ViscondeArtRegistry.resolve(
                ViscondeArtKey.heroTreasure,
              ),
              showMascot: true,
              mascotPose: ViscondeMascotPose.seriousController,
            ),
            const SizedBox(height: 12),
            ViscondeGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nova Voz',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome (Ex: João)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _relationController,
                      decoration: const InputDecoration(
                        labelText: 'Parentesco (Ex: Vovô)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _createProfile,
                      child: const Text('Criar perfil de voz'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vozes Criadas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_loading && _profiles.isNotEmpty)
              const LinearProgressIndicator(),
            if (_profiles.isEmpty) const Text('Nenhuma voz encontrada.'),
            ..._profiles.map(
              (p) => Card(
                child: ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    'Status: ${p.status}\nParentesco: ${p.relationship ?? '-'}',
                  ),
                  trailing: p.status == 'PENDING'
                      ? OutlinedButton(
                          onPressed: () => _trainProfile(p.id),
                          child: const Text('Simular Treino'),
                        )
                      : const Icon(
                          Icons.record_voice_over,
                          color: Colors.green,
                        ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
