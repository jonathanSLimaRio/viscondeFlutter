import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../../story_room/models/story_models.dart';
import '../parental_gate_controller.dart';

class VirtueReportsScreen extends ConsumerStatefulWidget {
  const VirtueReportsScreen({super.key});

  @override
  ConsumerState<VirtueReportsScreen> createState() =>
      _VirtueReportsScreenState();
}

class _VirtueReportsScreenState extends ConsumerState<VirtueReportsScreen> {
  VirtueReportOverviewResult? _overview;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOverview();
    });
  }

  Future<void> _loadOverview() async {
    final token = ref.read(authControllerProvider).accessToken;
    final gate = ref.read(parentalGateControllerProvider);

    if (token == null || !gate.isUnlocked || gate.unlockToken == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final overview = await ref
          .read(storyApiProvider)
          .fetchVirtueReportOverview(
            token,
            parentalUnlockToken: gate.unlockToken!,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _overview = overview;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (error is DioException && error.response?.statusCode == 401) {
        ref.read(parentalGateControllerProvider.notifier).clear();
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

  Future<void> _openChildSummary(String childId) async {
    final token = ref.read(authControllerProvider).accessToken;
    final gate = ref.read(parentalGateControllerProvider);

    if (token == null || !gate.isUnlocked || gate.unlockToken == null) {
      return;
    }

    try {
      final summary = await ref
          .read(storyApiProvider)
          .fetchVirtueChildSummary(
            token,
            childId: childId,
            parentalUnlockToken: gate.unlockToken!,
          );

      if (!mounted) {
        return;
      }

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'Resumo de ${summary.child.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Histórias publicadas: ${summary.totals['publishedStories'] ?? 0}',
                ),
                Text(
                  'Com virtude: ${summary.totals['storiesWithVirtue'] ?? 0}',
                ),
                Text(
                  'Sem virtude: ${summary.totals['storiesWithoutVirtue'] ?? 0}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Virtudes mais trabalhadas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...summary.virtueStats.map(
                  (stat) => ListTile(
                    dense: true,
                    title: Text((stat['name'] as String?) ?? '-'),
                    trailing: Text('${(stat['count'] as num?)?.toInt() ?? 0}x'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Capítulos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...summary.stories.map(
                  (story) => Card(
                    child: ListTile(
                      title: Text((story['title'] as String?) ?? '-'),
                      subtitle: Text(
                        '${((story['virtue'] as Map<String, dynamic>?)?['name'] as String?) ?? 'Sem virtude'}'
                        '${(story['dilemmaText'] as String?) != null ? '\nDilema: ${story['dilemmaText']}' : ''}'
                        '${(story['endQuestionText'] as String?) != null ? '\nPergunta: ${story['endQuestionText']}' : ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is DioException && error.response?.statusCode == 401) {
        ref.read(parentalGateControllerProvider.notifier).clear();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseDioError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(parentalGateControllerProvider);

    if (!gate.isUnlocked || gate.unlockToken == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relatório de Virtudes')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ViscondeGlassCard(
              child: ViscondeSectionTitle(
                title: 'Área protegida',
                subtitle:
                    'Volte para a área adulta, desbloqueie via PIN e abra novamente os relatórios.',
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de Virtudes')),
      body: RefreshIndicator(
        onRefresh: _loadOverview,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Relatórios de Virtudes',
              subtitle: 'Acompanhe evolução por criança e por capítulo.',
              assetPath: ViscondeArtRegistry.resolve(
                ViscondeArtKey.heroTreasure,
              ),
              showMascot: true,
              mascotPose: ViscondeMascotPose.seriousController,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_overview != null) ...[
              ViscondeGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Totais da conta',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Publicadas: ${_overview!.totals['publishedStories'] ?? 0}',
                      ),
                      Text(
                        'Com virtude: ${_overview!.totals['storiesWithVirtue'] ?? 0}',
                      ),
                      Text(
                        'Sem virtude: ${_overview!.totals['storiesWithoutVirtue'] ?? 0}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Resumo por criança',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._overview!.children.map(
                (item) => ViscondeGlassCard(
                  child: ListTile(
                    title: Text(item.childName),
                    subtitle: Text(
                      'Publicadas: ${item.publishedStories} · Com virtude: ${item.storiesWithVirtue}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openChildSummary(item.childId),
                  ),
                ),
              ),
            ],
            if (!_loading && _overview == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Nenhum dado de virtudes disponivel ainda.'),
              ),
          ],
        ),
      ),
    );
  }
}
