import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'dashboard_models.dart';
import 'dashboard_runtime_client.dart';

const _cockpitBlue = Color(0xFF2A6CF0);
const _cockpitInk = Color(0xFF172033);
const _cockpitMuted = Color(0xFF68738A);
const _cockpitBorder = Color(0xFFD9E0EC);
const _cockpitCanvas = Color(0xFFF6F7FB);

/// A branch/session projected into the Architect's weekly consolidation queue.
class ArchitectOrderRecord {
  const ArchitectOrderRecord({
    required this.sessionId,
    required this.localSessionId,
    required this.projectId,
    required this.projectName,
    required this.branchName,
    required this.headline,
    required this.taskPreview,
    required this.status,
    required this.buildStatus,
    required this.reviewerStatus,
    required this.workerRunning,
  });

  final int sessionId;
  final int localSessionId;
  final int projectId;
  final String projectName;
  final String branchName;
  final String headline;
  final String taskPreview;
  final String status;
  final String buildStatus;
  final String reviewerStatus;
  final bool workerRunning;

  factory ArchitectOrderRecord.fromSession(
    ProjectBinding project,
    NetrunnerSummaryRecord session,
  ) {
    final running = session.workerState.hasRunning;
    final buildStatus = running || session.status == 'in_progress'
        ? 'Building'
        : session.status == 'pending'
        ? 'Queued'
        : 'Built';
    final reviewerStatus = switch (session.status) {
      'review' => 'Awaiting review',
      'completed' => 'Merged',
      'pending' => 'Not started',
      _ => 'In progress',
    };
    return ArchitectOrderRecord(
      sessionId: session.id,
      localSessionId: session.localId,
      projectId: project.id,
      projectName: project.name,
      branchName: 'session/${session.localId}',
      headline: session.headline,
      taskPreview: session.taskPreview,
      status: session.status,
      buildStatus: buildStatus,
      reviewerStatus: reviewerStatus,
      workerRunning: running,
    );
  }

  ArchitectOrderRecord copyWithStatus(String nextStatus) {
    final nextBuildStatus = workerRunning || nextStatus == 'in_progress'
        ? 'Building'
        : nextStatus == 'pending'
        ? 'Queued'
        : 'Built';
    final nextReviewerStatus = switch (nextStatus) {
      'review' => 'Awaiting review',
      'completed' => 'Merged',
      'pending' => 'Not started',
      _ => 'In progress',
    };
    return ArchitectOrderRecord(
      sessionId: sessionId,
      localSessionId: localSessionId,
      projectId: projectId,
      projectName: projectName,
      branchName: branchName,
      headline: headline,
      taskPreview: taskPreview,
      status: nextStatus,
      buildStatus: nextBuildStatus,
      reviewerStatus: nextReviewerStatus,
      workerRunning: workerRunning,
    );
  }
}

abstract interface class ArchitectCockpitRepository {
  Future<List<ArchitectOrderRecord>> loadWeeklyOrders();

  Future<NetrunnerDetailSnapshot> loadOrderDetail(int sessionId);

  Future<NetrunnerDetailSnapshot> setOrderStatus(int sessionId, String status);
}

class BridgeArchitectCockpitRepository implements ArchitectCockpitRepository {
  BridgeArchitectCockpitRepository({
    String? baseUrl,
    DashboardRuntimeClient? runtimeClient,
  }) : _runtimeClient =
           runtimeClient ?? DashboardRuntimeClient(dashboardBaseUrl: baseUrl);

  final DashboardRuntimeClient _runtimeClient;

  @override
  Future<List<ArchitectOrderRecord>> loadWeeklyOrders() async {
    final payload = await _runtimeClient.readDashboardJson(
      '/api/architect/orders',
    );
    final projects = {
      for (final project in _asList(
        payload['projects'],
        ProjectBinding.fromJson,
      ))
        project.id: project,
    };
    final orders = _asList(payload['sessions'], NetrunnerSummaryRecord.fromJson)
        .where((session) => projects.containsKey(session.projectId))
        .map(
          (session) => ArchitectOrderRecord.fromSession(
            projects[session.projectId]!,
            session,
          ),
        )
        .toList();
    orders.sort((a, b) {
      final projectOrder = a.projectName.compareTo(b.projectName);
      return projectOrder == 0
          ? b.localSessionId.compareTo(a.localSessionId)
          : projectOrder;
    });
    return orders;
  }

  @override
  Future<NetrunnerDetailSnapshot> loadOrderDetail(int sessionId) async {
    final payload = await _runtimeClient.readDashboardJson(
      '/api/sessions/$sessionId',
    );
    return NetrunnerDetailSnapshot.fromJson(payload);
  }

  @override
  Future<NetrunnerDetailSnapshot> setOrderStatus(
    int sessionId,
    String status,
  ) async {
    final payload = await _runtimeClient.postDashboardJson(
      '/api/actions/sessions/$sessionId/status',
      {'status': status},
    );
    final session = payload['session'];
    if (session is Map<String, dynamic>) {
      return NetrunnerDetailSnapshot.fromJson({'session': session});
    }
    if (session is Map) {
      return NetrunnerDetailSnapshot.fromJson({
        'session': Map<String, dynamic>.from(session),
      });
    }
    throw StateError('Unexpected session action payload');
  }
}

class ArchitectCockpitScreen extends StatefulWidget {
  const ArchitectCockpitScreen({super.key, required this.repository});

  final ArchitectCockpitRepository repository;

  @override
  State<ArchitectCockpitScreen> createState() => _ArchitectCockpitScreenState();
}

class _ArchitectCockpitScreenState extends State<ArchitectCockpitScreen> {
  late Future<List<ArchitectOrderRecord>> _ordersFuture;
  final _details = <int, NetrunnerDetailSnapshot>{};
  final _detailFutures = <int, Future<NetrunnerDetailSnapshot>>{};
  int? _selectedSessionId;
  final _busySessions = <int>{};

  @override
  void initState() {
    super.initState();
    _ordersFuture = widget.repository.loadWeeklyOrders();
  }

  void _reload() {
    setState(() {
      _ordersFuture = widget.repository.loadWeeklyOrders();
      _details.clear();
      _detailFutures.clear();
    });
  }

  void _selectOrder(ArchitectOrderRecord order) {
    setState(() => _selectedSessionId = order.sessionId);
    _ensureDetail(order.sessionId);
  }

  Future<void> _ensureDetail(int sessionId) async {
    if (_details.containsKey(sessionId)) return;
    final future = _detailFutures.putIfAbsent(
      sessionId,
      () => widget.repository.loadOrderDetail(sessionId),
    );
    try {
      final detail = await future;
      if (mounted) setState(() => _details[sessionId] = detail);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _decide(ArchitectOrderRecord order, String status) async {
    setState(() => _busySessions.add(order.sessionId));
    try {
      final l10n = AppLocalizations.of(context);
      final detail = await widget.repository.setOrderStatus(
        order.sessionId,
        status,
      );
      _details[order.sessionId] = detail;
      final orders = await _ordersFuture;
      final index = orders.indexWhere(
        (item) => item.sessionId == order.sessionId,
      );
      if (index >= 0) {
        orders[index] = order.copyWithStatus(status);
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'completed'
                  ? (l10n.isRussian
                        ? 'Ветка объединена в консолидацию недели.'
                        : 'Branch merged into the weekly consolidation.')
                  : l10n.branchRejected,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busySessions.remove(order.sessionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_type_outlined, size: 21),
            SizedBox(width: 10),
            Text(l10n.architectCockpit),
          ],
        ),
        actions: [
          const LanguageSwitcher(compact: true),
          IconButton(
            onPressed: _reload,
            tooltip: l10n.refreshWeeklyOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ArchitectOrderRecord>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CockpitError(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final orders = snapshot.data ?? const <ArchitectOrderRecord>[];
          if (orders.isEmpty) return const _EmptyCockpit();
          if (_selectedSessionId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedSessionId == null) {
                _selectOrder(orders.first);
              }
            });
          }
          final selected = orders.firstWhere(
            (order) => order.sessionId == _selectedSessionId,
            orElse: () => orders.first,
          );
          return _CockpitLayout(
            orders: orders,
            selected: selected,
            details: _details,
            detailFutures: _detailFutures,
            busySessions: _busySessions,
            onSelect: _selectOrder,
            onDecide: _decide,
          );
        },
      ),
    );
  }
}

class _CockpitLayout extends StatelessWidget {
  const _CockpitLayout({
    required this.orders,
    required this.selected,
    required this.details,
    required this.detailFutures,
    required this.busySessions,
    required this.onSelect,
    required this.onDecide,
  });

  final List<ArchitectOrderRecord> orders;
  final ArchitectOrderRecord selected;
  final Map<int, NetrunnerDetailSnapshot> details;
  final Map<int, Future<NetrunnerDetailSnapshot>> detailFutures;
  final Set<int> busySessions;
  final ValueChanged<ArchitectOrderRecord> onSelect;
  final Future<void> Function(ArchitectOrderRecord, String) onDecide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final queue = _OrderQueue(
          orders: orders,
          selectedSessionId: selected.sessionId,
          onSelect: onSelect,
        );
        final detail = _OrderDetail(
          order: selected,
          detail: details[selected.sessionId],
          detailFuture: detailFutures[selected.sessionId],
          busy: busySessions.contains(selected.sessionId),
          onDecide: onDecide,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 390, child: queue),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(height: 500, child: queue),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 560),
              child: detail,
            ),
          ],
        );
      },
    );
  }
}

class _OrderQueue extends StatelessWidget {
  const _OrderQueue({
    required this.orders,
    required this.selectedSessionId,
    required this.onSelect,
  });

  final List<ArchitectOrderRecord> orders;
  final int selectedSessionId;
  final ValueChanged<ArchitectOrderRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    final reviewCount = orders
        .where((order) => order.status == 'review')
        .length;
    final l10n = AppLocalizations.of(context);
    return Container(
      color: _cockpitCanvas,
      padding: const EdgeInsets.fromLTRB(18, 20, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.isRussian ? 'Консолидация недели' : 'Weekly consolidation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _cockpitInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.weeklyConsolidation(orders.length, reviewCount),
            style: const TextStyle(color: _cockpitMuted),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OrderQueueTile(
                  key: ValueKey('architect-order-${order.sessionId}'),
                  order: order,
                  selected: order.sessionId == selectedSessionId,
                  onTap: () => onSelect(order),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderQueueTile extends StatelessWidget {
  const _OrderQueueTile({
    super.key,
    required this.order,
    required this.selected,
    required this.onTap,
  });

  final ArchitectOrderRecord order;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _statusColor(order.status, Theme.of(context).colorScheme);
    return Card(
      color: selected ? color.withAlpha(14) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: selected ? color : _cockpitBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _cockpitInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: l10n.status(_statusLabel(order.status)),
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.projectName} · ${order.branchName}',
                style: const TextStyle(color: _cockpitMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _MiniStatus(
                    label: l10n.isRussian ? 'Сборка' : 'Build',
                    value: l10n.status(order.buildStatus),
                  ),
                  _MiniStatus(
                    label: l10n.isRussian ? 'Проверка' : 'Reviewer',
                    value: l10n.status(order.reviewerStatus),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.order,
    required this.detail,
    required this.detailFuture,
    required this.busy,
    required this.onDecide,
  });

  final ArchitectOrderRecord order;
  final NetrunnerDetailSnapshot? detail;
  final Future<NetrunnerDetailSnapshot>? detailFuture;
  final bool busy;
  final Future<void> Function(ArchitectOrderRecord, String) onDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = detail == null
        ? detailFuture == null
              ? Center(child: Text(l10n.selectBranch))
              : FutureBuilder<NetrunnerDetailSnapshot>(
                  future: detailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    }
                    return _DiffViewer(detail: snapshot.data!);
                  },
                )
        : _DiffViewer(detail: detail!);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.headline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _cockpitInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(order.taskPreview, style: const TextStyle(color: _cockpitMuted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(
                label: l10n.buildStatus(order.buildStatus),
                color: _cockpitBlue,
              ),
              _StatusBadge(
                label: l10n.reviewStatus(order.reviewerStatus),
                color: _statusColor(
                  order.status,
                  Theme.of(context).colorScheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: 290, child: body),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => onDecide(order, 'completed'),
                icon: const Icon(Icons.merge_type),
                label: Text(l10n.merge),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => onDecide(order, 'pending'),
                icon: const Icon(Icons.undo),
                label: Text(l10n.reject),
              ),
              if (busy) ...[
                const SizedBox(width: 14),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.isRussian
                ? 'Отклонение возвращает ветку в очередь для повторной сборки.'
                : 'Reject sends the branch back to pending for another build pass.',
            style: TextStyle(color: _cockpitMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DiffViewer extends StatelessWidget {
  const _DiffViewer({required this.detail});

  final NetrunnerDetailSnapshot detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = detail.session.structuredFinalReport;
    final files = report?.filesChanged ?? const <String>[];
    final content = files.isEmpty
        ? (l10n.isRussian
              ? 'Сохранённого patch пока нет.\n\nЗдесь появится diff воркера.'
              : 'No captured patch is available yet.\n\nThis placeholder is ready for the worker diff artifact.')
        : files.map((file) => '+ $file').join('\n');
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.difference_outlined, color: Color(0xFF93C5FD)),
                SizedBox(width: 8),
                Text(
                  l10n.basicDiffViewer,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label · ',
            style: const TextStyle(color: _cockpitMuted, fontSize: 12),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: _cockpitInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CockpitError extends StatelessWidget {
  const _CockpitError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCockpit extends StatelessWidget {
  const _EmptyCockpit();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_type_outlined, size: 42),
            SizedBox(height: 12),
            Text(
              l10n.isRussian
                  ? 'На этой неделе ветки не создавались.'
                  : 'No branches were created this week.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              l10n.isRussian
                  ? 'Новые заказы клиента появятся здесь после добавления в очередь сборки.'
                  : 'New client orders will appear here when they enter the build queue.',
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'in_progress' => 'Building',
    'review' => 'Review',
    'completed' => 'Merged',
    _ => 'Queued',
  };
}

Color _statusColor(String status, ColorScheme scheme) {
  return switch (status) {
    'review' => const Color(0xFFB56A00),
    'completed' => const Color(0xFF16845B),
    'in_progress' => scheme.primary,
    _ => scheme.outline,
  };
}

List<T> _asList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return <T>[];
  return value.map((item) {
    if (item is Map<String, dynamic>) return fromJson(item);
    return fromJson(Map<String, dynamic>.from(item as Map));
  }).toList();
}
