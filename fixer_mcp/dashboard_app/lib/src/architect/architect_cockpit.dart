import 'package:flutter/material.dart';

import '../dashboard_models.dart';
import '../dashboard_runtime_client.dart';

const _ink = Color(0xFF172033);
const _muted = Color(0xFF68738A);
const _border = Color(0xFFD9E0EC);
const _canvas = Color(0xFFF6F7FB);
const _codeBackground = Color(0xFF111827);

/// A weekly order shown in the Architect's consolidation queue.
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
    final isBuilding =
        session.workerState.hasRunning || session.status == 'in_progress';
    final buildStatus = isBuilding
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
      workerRunning: session.workerState.hasRunning,
    );
  }

  ArchitectOrderRecord copyWithStatus(String nextStatus) {
    final isBuilding = workerRunning || nextStatus == 'in_progress';
    return ArchitectOrderRecord(
      sessionId: sessionId,
      localSessionId: localSessionId,
      projectId: projectId,
      projectName: projectName,
      branchName: branchName,
      headline: headline,
      taskPreview: taskPreview,
      status: nextStatus,
      buildStatus: isBuilding
          ? 'Building'
          : nextStatus == 'pending'
          ? 'Queued'
          : 'Built',
      reviewerStatus: switch (nextStatus) {
        'review' => 'Awaiting review',
        'completed' => 'Merged',
        'pending' => 'Not started',
        _ => 'In progress',
      },
      workerRunning: workerRunning,
    );
  }
}

abstract interface class ArchitectCockpitRepository {
  Future<List<ArchitectOrderRecord>> loadWeeklyOrders();

  Future<NetrunnerDetailSnapshot> loadOrderDetail(int sessionId);

  Future<NetrunnerDetailSnapshot> setOrderStatus(int sessionId, String status);

  Future<NetrunnerDetailSnapshot> setProposalStatus(
    int proposalId,
    String status,
  );
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
    final home = HomeSnapshot.fromJson(
      await _runtimeClient.readDashboardJson('/api/home'),
    );
    final byProject = await Future.wait(
      home.projects.map((projectCard) async {
        final payload = await _runtimeClient.readDashboardJson(
          '/api/projects/${projectCard.project.id}/netrunners',
        );
        return _asList(payload['sessions'], NetrunnerSummaryRecord.fromJson)
            .map(
              (session) => ArchitectOrderRecord.fromSession(
                projectCard.project,
                session,
              ),
            )
            .toList(growable: false);
      }),
    );
    final orders = byProject.expand((items) => items).toList();
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
  Future<NetrunnerDetailSnapshot> setOrderStatus(int sessionId, String status) {
    return _postSessionAction('/api/actions/sessions/$sessionId/status', {
      'status': status,
    });
  }

  @override
  Future<NetrunnerDetailSnapshot> setProposalStatus(
    int proposalId,
    String status,
  ) {
    return _postSessionAction('/api/actions/proposals/$proposalId/status', {
      'status': status,
    });
  }

  Future<NetrunnerDetailSnapshot> _postSessionAction(
    String path,
    Map<String, dynamic> body,
  ) async {
    final payload = await _runtimeClient.postDashboardJson(path, body);
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
  final _busyActions = <String>{};
  final _orderOverrides = <int, ArchitectOrderRecord>{};
  int? _selectedSessionId;

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
      _orderOverrides.clear();
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

  Future<void> _setOrderStatus(
    ArchitectOrderRecord order,
    String status,
  ) async {
    final actionKey = 'session:${order.sessionId}';
    await _runAction(
      actionKey,
      () => widget.repository.setOrderStatus(order.sessionId, status),
      successMessage: status == 'completed'
          ? 'Code merged into main.'
          : 'Branch rejected and sent back for rework.',
      onSuccess: (detail) {
        _details[order.sessionId] = detail;
        _orderOverrides[order.sessionId] = order.copyWithStatus(status);
      },
    );
  }

  Future<void> _setProposalStatus(
    ArchitectOrderRecord order,
    DocProposalSummaryRecord proposal,
    String status,
  ) async {
    final actionKey = 'proposal:${proposal.id}';
    await _runAction(
      actionKey,
      () => widget.repository.setProposalStatus(proposal.id, status),
      successMessage: status == 'approved'
          ? 'Doc proposal approved into main.'
          : 'Doc proposal rejected.',
      onSuccess: (detail) => _details[order.sessionId] = detail,
    );
  }

  Future<void> _runAction(
    String actionKey,
    Future<NetrunnerDetailSnapshot> Function() action, {
    required String successMessage,
    required void Function(NetrunnerDetailSnapshot detail) onSuccess,
  }) async {
    setState(() => _busyActions.add(actionKey));
    try {
      final detail = await action();
      onSuccess(detail);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyActions.remove(actionKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_type_outlined, size: 21),
            SizedBox(width: 10),
            Text('Architect cockpit'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Refresh weekly orders',
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
          final orders = (snapshot.data ?? const <ArchitectOrderRecord>[])
              .map((order) => _orderOverrides[order.sessionId] ?? order)
              .toList(growable: false);
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
            busyActions: _busyActions,
            onSelect: _selectOrder,
            onSetOrderStatus: _setOrderStatus,
            onSetProposalStatus: _setProposalStatus,
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
    required this.busyActions,
    required this.onSelect,
    required this.onSetOrderStatus,
    required this.onSetProposalStatus,
  });

  final List<ArchitectOrderRecord> orders;
  final ArchitectOrderRecord selected;
  final Map<int, NetrunnerDetailSnapshot> details;
  final Map<int, Future<NetrunnerDetailSnapshot>> detailFutures;
  final Set<String> busyActions;
  final ValueChanged<ArchitectOrderRecord> onSelect;
  final Future<void> Function(ArchitectOrderRecord, String) onSetOrderStatus;
  final Future<void> Function(
    ArchitectOrderRecord,
    DocProposalSummaryRecord,
    String,
  )
  onSetProposalStatus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final queue = _OrderQueue(
          orders: orders,
          selectedSessionId: selected.sessionId,
          onSelect: onSelect,
        );
        final detail = _OrderDetail(
          order: selected,
          detail: details[selected.sessionId],
          detailFuture: detailFutures[selected.sessionId],
          busyActions: busyActions,
          onSetOrderStatus: onSetOrderStatus,
          onSetProposalStatus: onSetProposalStatus,
        );
        if (constraints.maxWidth >= 980) {
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
              constraints: const BoxConstraints(minHeight: 650),
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
    final reviews = orders.where((order) => order.status == 'review').length;
    return Container(
      color: _canvas,
      padding: const EdgeInsets.fromLTRB(18, 20, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly consolidation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${orders.length} branches · $reviews awaiting review',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OrderTile(
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

class _OrderTile extends StatelessWidget {
  const _OrderTile({
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
    final color = _statusColor(order.status, Theme.of(context).colorScheme);
    return Card(
      color: selected ? color.withAlpha(14) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: selected ? color : _border),
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
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: _statusLabel(order.status), color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.projectName} · ${order.branchName}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _MiniStatus(label: 'Build', value: order.buildStatus),
                  _MiniStatus(
                    label: 'Review-netrunner',
                    value: order.reviewerStatus,
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
    required this.busyActions,
    required this.onSetOrderStatus,
    required this.onSetProposalStatus,
  });

  final ArchitectOrderRecord order;
  final NetrunnerDetailSnapshot? detail;
  final Future<NetrunnerDetailSnapshot>? detailFuture;
  final Set<String> busyActions;
  final Future<void> Function(ArchitectOrderRecord, String) onSetOrderStatus;
  final Future<void> Function(
    ArchitectOrderRecord,
    DocProposalSummaryRecord,
    String,
  )
  onSetProposalStatus;

  @override
  Widget build(BuildContext context) {
    final loadedDetail = detail;
    final content = loadedDetail == null
        ? detailFuture == null
              ? const Center(
                  child: Text('Select a branch to inspect its diff.'),
                )
              : FutureBuilder<NetrunnerDetailSnapshot>(
                  future: detailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    }
                    final snapshotDetail = snapshot.data;
                    return snapshotDetail == null
                        ? const Center(
                            child: Text('No branch detail returned.'),
                          )
                        : _DetailBody(
                            order: order,
                            detail: snapshotDetail,
                            busyActions: busyActions,
                            onSetOrderStatus: onSetOrderStatus,
                            onSetProposalStatus: onSetProposalStatus,
                          );
                  },
                )
        : _DetailBody(
            order: order,
            detail: loadedDetail,
            busyActions: busyActions,
            onSetOrderStatus: onSetOrderStatus,
            onSetProposalStatus: onSetProposalStatus,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 28, 28),
      child: content,
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.order,
    required this.detail,
    required this.busyActions,
    required this.onSetOrderStatus,
    required this.onSetProposalStatus,
  });

  final ArchitectOrderRecord order;
  final NetrunnerDetailSnapshot detail;
  final Set<String> busyActions;
  final Future<void> Function(ArchitectOrderRecord, String) onSetOrderStatus;
  final Future<void> Function(
    ArchitectOrderRecord,
    DocProposalSummaryRecord,
    String,
  )
  onSetProposalStatus;

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    final sessionBusy = busyActions.contains('session:${order.sessionId}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.headline,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(order.taskPreview, style: const TextStyle(color: _muted)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(
              label: 'Build · ${order.buildStatus}',
              color: _statusColor(order.status, Theme.of(context).colorScheme),
            ),
            _StatusBadge(
              label: 'Review-netrunner · ${order.reviewerStatus}',
              color: _statusColor(order.status, Theme.of(context).colorScheme),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(height: 290, child: _DiffViewer(detail: detail)),
        const SizedBox(height: 20),
        Row(
          children: [
            FilledButton.icon(
              onPressed: sessionBusy
                  ? null
                  : () => onSetOrderStatus(order, 'completed'),
              icon: const Icon(Icons.merge_type),
              label: const Text('Merge'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: sessionBusy
                  ? null
                  : () => onSetOrderStatus(order, 'pending'),
              icon: const Icon(Icons.undo),
              label: const Text('Reject'),
            ),
            if (sessionBusy) ...[
              const SizedBox(width: 14),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        _ProposalList(
          order: order,
          proposals: session.proposals,
          busyActions: busyActions,
          onSetProposalStatus: onSetProposalStatus,
        ),
      ],
    );
  }
}

class _ProposalList extends StatelessWidget {
  const _ProposalList({
    required this.order,
    required this.proposals,
    required this.busyActions,
    required this.onSetProposalStatus,
  });

  final ArchitectOrderRecord order;
  final List<DocProposalSummaryRecord> proposals;
  final Set<String> busyActions;
  final Future<void> Function(
    ArchitectOrderRecord,
    DocProposalSummaryRecord,
    String,
  )
  onSetProposalStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Doc proposals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Approve documentation changes into main independently of code.',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (proposals.isEmpty)
              const Text('No doc proposals recorded.')
            else
              ...proposals.map(
                (proposal) => _ProposalRow(
                  order: order,
                  proposal: proposal,
                  busy: busyActions.contains('proposal:${proposal.id}'),
                  onSetProposalStatus: onSetProposalStatus,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({
    required this.order,
    required this.proposal,
    required this.busy,
    required this.onSetProposalStatus,
  });

  final ArchitectOrderRecord order;
  final DocProposalSummaryRecord proposal;
  final bool busy;
  final Future<void> Function(
    ArchitectOrderRecord,
    DocProposalSummaryRecord,
    String,
  )
  onSetProposalStatus;

  @override
  Widget build(BuildContext context) {
    final pending = proposal.status == 'pending';
    return Container(
      key: ValueKey('architect-proposal-${proposal.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${proposal.localId} ${proposal.proposedDocType}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(
                label: proposal.status,
                color: pending ? const Color(0xFFB56A00) : _muted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(proposal.proposedContent),
          if (pending) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => onSetProposalStatus(order, proposal, 'approved'),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => onSetProposalStatus(order, proposal, 'rejected'),
                  child: const Text('Reject proposal'),
                ),
              ],
            ),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
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
    final report = detail.session.structuredFinalReport;
    final files = report?.filesChanged ?? const <String>[];
    final reportRaw = detail.session.reportRaw.trim();
    final lines = <String>[
      if (files.isNotEmpty) ...files.map((file) => '+ $file'),
      if (files.isEmpty && reportRaw.isNotEmpty) reportRaw,
      if (files.isEmpty && reportRaw.isEmpty)
        'No captured patch is available yet.',
    ];
    return Card(
      color: _codeBackground,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.difference_outlined, color: Color(0xFF93C5FD)),
                SizedBox(width: 8),
                Text(
                  'Basic diff viewer',
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
                  lines.join('\n'),
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
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: _ink,
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
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_type_outlined, size: 42),
            SizedBox(height: 12),
            Text(
              'No branches were created this week.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'New client orders will appear here when they enter the build queue.',
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
