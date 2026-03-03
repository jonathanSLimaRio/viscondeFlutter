import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../design_system/visconde.dart';
import '../../../shared/api_error.dart';
import '../../../shared/providers.dart';
import '../../auth/auth_controller.dart';
import '../models/admin_models.dart';

class UxFunnelAdminScreen extends ConsumerStatefulWidget {
  const UxFunnelAdminScreen({super.key});

  @override
  ConsumerState<UxFunnelAdminScreen> createState() =>
      _UxFunnelAdminScreenState();
}

class _UxFunnelAdminScreenState extends ConsumerState<UxFunnelAdminScreen> {
  late DateTime _dateTo;
  late DateTime _dateFrom;
  bool _loading = false;
  String? _error;
  AdminUxFunnelOverviewModel? _overview;

  @override
  void initState() {
    super.initState();
    _dateTo = DateTime.now();
    _dateFrom = _dateTo.subtract(const Duration(days: 6));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(adminApiProvider)
          .fetchUxFunnel(
            token,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            timezone: DateTime.now().timeZoneName,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _overview = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = parseDioError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDateFrom() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: _dateTo,
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _dateFrom = selected;
    });
    await _load();
  }

  Future<void> _pickDateTo() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: _dateFrom,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _dateTo = selected;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Funil UX')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ViscondeHeroBanner(
              title: 'Métricas de Jornada',
              subtitle: 'Acompanhe abandono por etapa e cobertura de sessão.',
              assetPath: ViscondeArtRegistry.resolve(
                ViscondeArtKey.heroTreasure,
              ),
              showMascot: true,
              mascotPose: ViscondeMascotPose.studyingDesk,
            ),
            const SizedBox(height: 12),
            ViscondeGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ViscondeSectionTitle(
                    title: 'Período',
                    subtitle: 'Filtro aplicado ao funil e à cobertura.',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateFrom,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('De ${formatter.format(_dateFrom)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateTo,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('Até ${formatter.format(_dateTo)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ViscondeGlassCard(child: Text(_error!)),
              ),
            if (!_loading && _overview != null) ...[
              const SizedBox(height: 12),
              _CoverageCard(coverage: _overview!.coverage),
              const SizedBox(height: 12),
              _FunnelCard(funnel: _overview!.funnel),
              const SizedBox(height: 12),
              _AuthErrorsCard(authErrors: _overview!.authErrors),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.coverage});

  final AdminUxCoverageModel coverage;

  @override
  Widget build(BuildContext context) {
    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ViscondeSectionTitle(
            title: 'Cobertura de Sessões Novas',
            subtitle: 'Sessões autenticadas detectadas vs rastreadas.',
          ),
          const SizedBox(height: 8),
          Text('Novas sessões auth: ${coverage.newAuthSessions}'),
          Text('Sessões rastreadas: ${coverage.trackedNewAuthSessions}'),
          Text('Cobertura: ${coverage.coveragePct.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.funnel});

  final AdminUxFunnelModel funnel;

  @override
  Widget build(BuildContext context) {
    final dropoff = funnel.dropoffByProgression;
    final abandoned = funnel.explicitAbandonedByStep;

    Widget metric(String label, int value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('$label: $value'),
      );
    }

    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ViscondeSectionTitle(
            title: 'Funil de Criação e Publicação',
            subtitle: 'Conversão por etapa e perdas no percurso.',
          ),
          const SizedBox(height: 8),
          metric('Iniciou criação', funnel.started),
          metric('Concluiu passo 1', funnel.step1),
          metric('Concluiu passo 2', funnel.step2),
          metric('Concluiu passo 3', funnel.step3),
          metric('Publicou', funnel.published),
          metric('Abriu game hub', funnel.gameHubOpened),
          const SizedBox(height: 12),
          Text(
            'Drop-off',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          metric('Início -> Passo 1', dropoff.startedToStep1),
          metric('Passo 1 -> Passo 2', dropoff.step1ToStep2),
          metric('Passo 2 -> Passo 3', dropoff.step2ToStep3),
          metric('Passo 3 -> Publicação', dropoff.step3ToPublished),
          metric('Publicação -> Game', dropoff.publishedToGameHubOpened),
          const SizedBox(height: 12),
          Text(
            'Abandono explícito',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          metric('Passo 1', abandoned.step1),
          metric('Passo 2', abandoned.step2),
          metric('Passo 3', abandoned.step3),
          metric('Sem etapa', abandoned.unknown),
        ],
      ),
    );
  }
}

class _AuthErrorsCard extends StatelessWidget {
  const _AuthErrorsCard({required this.authErrors});

  final AdminUxAuthErrorsModel authErrors;

  @override
  Widget build(BuildContext context) {
    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ViscondeSectionTitle(
            title: 'Erros de Auth',
            subtitle: 'Distribuição dos erros mostrados ao usuário.',
          ),
          const SizedBox(height: 8),
          Text('Total: ${authErrors.total}'),
          const SizedBox(height: 6),
          ...authErrors.breakdown.map(
            (item) => Text('${item.type}: ${item.count}'),
          ),
        ],
      ),
    );
  }
}
