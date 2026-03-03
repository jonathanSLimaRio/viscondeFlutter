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
              _PostPublishCard(postPublish: _overview!.postPublish),
              const SizedBox(height: 12),
              _AuthErrorsCard(authErrors: _overview!.authErrors),
              const SizedBox(height: 12),
              _ScreenStatesCard(screenStates: _overview!.screenStates),
              const SizedBox(height: 12),
              _PinFrictionCard(pinFriction: _overview!.pinFriction),
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
    final rates = funnel.completionRates;
    final avgDuration = funnel.avgDurationMs;

    Widget metric(String label, Object value) {
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
          const SizedBox(height: 12),
          Text(
            'Taxa de conclusão',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          metric(
            'Passo 1 / início',
            '${rates.step1FromStartedPct.toStringAsFixed(2)}%',
          ),
          metric(
            'Passo 2 / passo 1',
            '${rates.step2FromStep1Pct.toStringAsFixed(2)}%',
          ),
          metric(
            'Passo 3 / passo 2',
            '${rates.step3FromStep2Pct.toStringAsFixed(2)}%',
          ),
          metric(
            'Publicado / passo 3',
            '${rates.publishedFromStep3Pct.toStringAsFixed(2)}%',
          ),
          const SizedBox(height: 12),
          Text(
            'Tempo médio por passo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          metric('Passo 1', '${avgDuration.step1} ms'),
          metric('Passo 2', '${avgDuration.step2} ms'),
          metric('Passo 3', '${avgDuration.step3} ms'),
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

class _PostPublishCard extends StatelessWidget {
  const _PostPublishCard({required this.postPublish});

  final AdminUxPostPublishModel postPublish;

  @override
  Widget build(BuildContext context) {
    final continueRate = postPublish.continueSagaClickRatePct;
    final reachedGoal = continueRate >= 30;
    final statusLabel = reachedGoal ? 'Meta atingida' : 'Abaixo da meta';

    Widget metric(String label, String value) {
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
            title: 'Pós-publicação',
            subtitle: 'Celebração e continuidade após publicar capítulo.',
          ),
          const SizedBox(height: 8),
          metric('Publicações', '${postPublish.publishedTotal}'),
          metric('Modais abertos', '${postPublish.modalOpenedTotal}'),
          metric(
            'Taxa de abertura do modal',
            '${postPublish.modalOpenRatePct.toStringAsFixed(2)}%',
          ),
          metric('Cliques em CTA', '${postPublish.ctaClicksTotal}'),
          const SizedBox(height: 8),
          Text(
            'Distribuição de CTA',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          metric(
            'Continuar saga',
            '${postPublish.ctaClicksByTarget.continueSaga}',
          ),
          metric('Ir para Game', '${postPublish.ctaClicksByTarget.goGame}'),
          metric(
            'Voltar ao baú',
            '${postPublish.ctaClicksByTarget.backToVault}',
          ),
          const SizedBox(height: 8),
          metric(
            'Taxa de clique em Continuar saga',
            '${continueRate.toStringAsFixed(2)}%',
          ),
          metric(
            'Conversão para próxima ação',
            '${postPublish.nextActionConversionPct.toStringAsFixed(2)}%',
          ),
          const SizedBox(height: 6),
          Text(
            'Meta de continuidade (>= 30%): $statusLabel',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ScreenStatesCard extends StatelessWidget {
  const _ScreenStatesCard({required this.screenStates});

  final AdminUxScreenStatesModel screenStates;

  @override
  Widget build(BuildContext context) {
    Widget metricRow(String label, int value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('$label: $value'),
      );
    }

    Widget section(String title, AdminUxScreenStateMetricsModel metrics) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          metricRow('Loading', metrics.loadingShown),
          metricRow('Empty', metrics.emptyShown),
          metricRow('Erro', metrics.errorShown),
          metricRow('Conteúdo', metrics.contentShown),
          metricRow('Retry tocado', metrics.retryTapped),
          metricRow('CTA no vazio', metrics.emptyCtaTapped),
        ],
      );
    }

    return ViscondeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ViscondeSectionTitle(
            title: 'Saúde Baú/Game',
            subtitle: 'Estados exibidos e interações de recuperação.',
          ),
          const SizedBox(height: 8),
          section('Baú', screenStates.vault),
          const SizedBox(height: 12),
          section('Game', screenStates.game),
        ],
      ),
    );
  }
}

class _PinFrictionCard extends StatelessWidget {
  const _PinFrictionCard({required this.pinFriction});

  final AdminUxPinFrictionModel pinFriction;

  @override
  Widget build(BuildContext context) {
    Widget metric(String label, String value) {
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
            title: 'Fricção de PIN Adulto',
            subtitle: 'Acompanha prompts, sucesso e abandono do desbloqueio.',
          ),
          const SizedBox(height: 8),
          metric('Prompts exibidos', '${pinFriction.promptShownTotal}'),
          metric('Prompts com sucesso', '${pinFriction.promptSuccessTotal}'),
          metric('Prompts abandonados', '${pinFriction.promptAbandonTotal}'),
          metric('Bloquear agora', '${pinFriction.lockNowTotal}'),
          metric(
            'Taxa de sucesso',
            '${pinFriction.successRatePct.toStringAsFixed(2)}%',
          ),
          metric(
            'Taxa de abandono',
            '${pinFriction.abandonRatePct.toStringAsFixed(2)}%',
          ),
          if (pinFriction.abandonByReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Abandono por motivo',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ...pinFriction.abandonByReason.map(
              (item) => Text('${item.reason}: ${item.count}'),
            ),
          ],
        ],
      ),
    );
  }
}
