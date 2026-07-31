import 'package:flutter/material.dart';

import 'netrunner_models.dart';
import 'netrunner_repository.dart';

const _ink = Color(0xFF172033);
const _muted = Color(0xFF68738A);
const _border = Color(0xFFD9E0EC);
const _surfaceMuted = Color(0xFFF4F6FA);

const _knownStatuses = <String>[
  'pending',
  'in_progress',
  'review',
  'completed',
];

class NetrunnerExplorerScreen extends StatefulWidget {
  const NetrunnerExplorerScreen({
    super.key,
    required this.projectId,
    required this.repository,
    this.onSessionSelected,
  });

  final int projectId;
  final NetrunnerExplorerRepository repository;
  final ValueChanged<NetrunnerExplorerRecord>? onSessionSelected;

  @override
  State<NetrunnerExplorerScreen> createState() =>
      _NetrunnerExplorerScreenState();
}

class _NetrunnerExplorerScreenState extends State<NetrunnerExplorerScreen> {
  late Future<NetrunnerExplorerSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = widget.repository.loadProjectNetrunners(widget.projectId);
  }

  void _reload() {
    setState(() {
      _snapshotFuture = widget.repository.loadProjectNetrunners(
        widget.projectId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NetrunnerExplorerSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load Netrunners'),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return NetrunnerExplorer(
          snapshot: snapshot.requireData,
          onSessionSelected: widget.onSessionSelected,
        );
      },
    );
  }
}

class NetrunnerExplorer extends StatefulWidget {
  const NetrunnerExplorer({
    super.key,
    required this.snapshot,
    this.onSessionSelected,
  });

  final NetrunnerExplorerSnapshot snapshot;
  final ValueChanged<NetrunnerExplorerRecord>? onSessionSelected;

  @override
  State<NetrunnerExplorer> createState() => _NetrunnerExplorerState();
}

class _NetrunnerExplorerState extends State<NetrunnerExplorer> {
  final _visibleStatuses = _knownStatuses.toSet();

  void _toggleStatus(String status, bool selected) {
    setState(() {
      if (selected) {
        _visibleStatuses.add(status);
      } else {
        _visibleStatuses.remove(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.snapshot.waveGroups
        .map(
          (group) => (
            group: group,
            sessions: group.sessions
                .where((session) => _visibleStatuses.contains(session.status))
                .toList(growable: false),
          ),
        )
        .where((entry) => entry.sessions.isNotEmpty)
        .toList(growable: false);
    final ungrouped = widget.snapshot.ungroupedSessions
        .where((session) => _visibleStatuses.contains(session.status))
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 1024 ? 32.0 : 16.0;
        return ListView(
          key: const ValueKey('netrunner-explorer'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          children: [
            const Text(
              'Netrunners',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Wave workers, reviewers, and Architect-launched sessions.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            _StatusFilters(
              visibleStatuses: _visibleStatuses,
              onChanged: _toggleStatus,
            ),
            const SizedBox(height: 20),
            if (groups.isEmpty && ungrouped.isEmpty)
              const _EmptyState()
            else ...[
              for (final entry in groups) ...[
                _WaveGroupCard(
                  group: entry.group,
                  sessions: entry.sessions,
                  onSessionSelected: widget.onSessionSelected,
                ),
                const SizedBox(height: 12),
              ],
              if (ungrouped.isNotEmpty)
                _LegacyGroupCard(
                  sessions: ungrouped,
                  onSessionSelected: widget.onSessionSelected,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.visibleStatuses,
    required this.onChanged,
  });

  final Set<String> visibleStatuses;
  final void Function(String status, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in _knownStatuses)
          FilterChip(
            key: ValueKey('netrunner-filter-$status'),
            selected: visibleStatuses.contains(status),
            showCheckmark: false,
            avatar: _StatusDot(status: status),
            label: Text(_statusLabel(status)),
            onSelected: (selected) => onChanged(status, selected),
          ),
      ],
    );
  }
}

class _WaveGroupCard extends StatelessWidget {
  const _WaveGroupCard({
    required this.group,
    required this.sessions,
    required this.onSessionSelected,
  });

  final NetrunnerWaveGroupRecord group;
  final List<NetrunnerExplorerRecord> sessions;
  final ValueChanged<NetrunnerExplorerRecord>? onSessionSelected;

  @override
  Widget build(BuildContext context) {
    return _OutlinedSection(
      key: ValueKey('netrunner-wave-${group.waveId}'),
      header: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(
            'Wave ${group.waveId}',
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          _Badge(
            label: _statusLabel(group.status),
            color: _statusColor(group.status),
          ),
          _Badge(
            label: '${group.workerCount} workers',
            color: const Color(0xFF2563EB),
          ),
          if (group.reviewerCount > 0)
            _Badge(
              label: '${group.reviewerCount} reviewer',
              color: const Color(0xFF7C3AED),
            ),
          if (group.manualCount > 0)
            _Badge(
              label: '${group.manualCount} manual',
              color: const Color(0xFFB45309),
            ),
        ],
      ),
      trailing: group.updatedAt.isEmpty
          ? null
          : Text(
              _compactTimestamp(group.updatedAt),
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
      sessions: sessions,
      onSessionSelected: onSessionSelected,
    );
  }
}

class _LegacyGroupCard extends StatelessWidget {
  const _LegacyGroupCard({
    required this.sessions,
    required this.onSessionSelected,
  });

  final List<NetrunnerExplorerRecord> sessions;
  final ValueChanged<NetrunnerExplorerRecord>? onSessionSelected;

  @override
  Widget build(BuildContext context) {
    return _OutlinedSection(
      key: const ValueKey('netrunner-legacy-group'),
      header: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ungrouped sessions',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Legacy sessions without wave linkage',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
      sessions: sessions,
      onSessionSelected: onSessionSelected,
    );
  }
}

class _OutlinedSection extends StatelessWidget {
  const _OutlinedSection({
    super.key,
    required this.header,
    required this.sessions,
    required this.onSessionSelected,
    this.trailing,
  });

  final Widget header;
  final Widget? trailing;
  final List<NetrunnerExplorerRecord> sessions;
  final ValueChanged<NetrunnerExplorerRecord>? onSessionSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: header),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < sessions.length; index++) ...[
            _NetrunnerRow(
              session: sessions[index],
              onTap: onSessionSelected == null
                  ? null
                  : () => onSessionSelected!(sessions[index]),
            ),
            if (index != sessions.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _NetrunnerRow extends StatelessWidget {
  const _NetrunnerRow({required this.session, this.onTap});

  final NetrunnerExplorerRecord session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _kindColor(session.kind);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final details = <Widget>[
      _Badge(label: _kindLabel(session.kind), color: accent),
      _Badge(
        label: _statusLabel(session.status),
        color: _statusColor(session.status),
      ),
      if (session.membershipStatus.isNotEmpty &&
          session.membershipStatus != session.status)
        Text(
          session.membershipStatus.replaceAll('_', ' '),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      if (session.hasLaunchDetails)
        Text(
          [
            session.backend,
            if (session.model.isNotEmpty) session.model,
            if (session.reasoning.isNotEmpty) session.reasoning,
          ].join(' · '),
          key: ValueKey('netrunner-backend-${session.id}'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
    ];
    return InkWell(
      key: ValueKey('netrunner-session-${session.id}'),
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NetrunnerDescription(session: session),
                          const SizedBox(height: 8),
                          Wrap(spacing: 7, runSpacing: 7, children: details),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _NetrunnerDescription(session: session),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 7,
                              runSpacing: 7,
                              children: details,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetrunnerDescription extends StatelessWidget {
  const _NetrunnerDescription({required this.session});

  final NetrunnerExplorerRecord session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${session.localId}  ${session.headline}',
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        if (session.taskPreview.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            session.taskPreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _statusColor(status),
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: 8),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        children: [
          Icon(Icons.filter_alt_off_outlined, color: _muted),
          SizedBox(height: 8),
          Text('No Netrunners match these filters.'),
        ],
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'pending' => 'Pending',
  'in_progress' => 'In progress',
  'review' => 'Review',
  'completed' => 'Completed',
  '' => 'Unknown',
  _ => status.replaceAll('_', ' '),
};

String _kindLabel(String kind) => switch (kind) {
  'worker' => 'Worker',
  'reviewer' => 'Reviewer',
  'manual' => 'Manual',
  _ => 'Legacy',
};

Color _statusColor(String status) => switch (status) {
  'pending' => const Color(0xFF64748B),
  'in_progress' => const Color(0xFF2563EB),
  'review' => const Color(0xFF7C3AED),
  'completed' => const Color(0xFF15803D),
  _ => _muted,
};

Color _kindColor(String kind) => switch (kind) {
  'worker' => const Color(0xFF2563EB),
  'reviewer' => const Color(0xFF7C3AED),
  'manual' => const Color(0xFFB45309),
  _ => const Color(0xFF64748B),
};

String _compactTimestamp(String value) {
  if (value.length >= 16) return value.substring(0, 16).replaceFirst('T', ' ');
  return value;
}
