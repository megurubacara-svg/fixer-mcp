import 'package:flutter/material.dart';

/// The small, explicit data contract needed by the home project rail.
///
/// This model intentionally does not expose the legacy status-count metrics.
/// The downstream dashboard composition can map bridge responses into this
/// self-contained module without coupling the card to the larger dashboard
/// model tree.
class HubProjectCard {
  const HubProjectCard({
    required this.projectId,
    required this.name,
    required this.cwd,
    required this.activeWaveCount,
    required this.lastActivityAt,
  });

  final int projectId;
  final String name;
  final String cwd;
  final int activeWaveCount;
  final String lastActivityAt;

  factory HubProjectCard.fromJson(Map<String, dynamic> json) {
    final project = _asMap(json['project']);
    return HubProjectCard(
      projectId: _asInt(project['id'] ?? json['project_id']),
      name: _asString(project['name'] ?? json['project_name']),
      cwd: _asString(project['cwd'] ?? json['cwd']),
      activeWaveCount: _asInt(
        json['active_wave_count'] ?? json['active_waves'],
      ),
      lastActivityAt: _asString(
        json['last_activity_at'] ??
            json['latest_activity_at'] ??
            json['activity_timestamp'],
      ),
    );
  }

  static List<HubProjectCard> sortByActivity(Iterable<HubProjectCard> cards) {
    final sorted = cards.toList();
    sorted.sort((left, right) {
      final leftActivity = left.lastActivityAt.trim();
      final rightActivity = right.lastActivityAt.trim();
      if (leftActivity.isEmpty && rightActivity.isNotEmpty) return 1;
      if (leftActivity.isNotEmpty && rightActivity.isEmpty) return -1;
      final byActivity = rightActivity.compareTo(leftActivity);
      if (byActivity != 0) return byActivity;
      return left.projectId.compareTo(right.projectId);
    });
    return sorted;
  }
}

class ProjectCards extends StatelessWidget {
  const ProjectCards({
    super.key,
    required this.projects,
    required this.onProjectTap,
    this.emptyLabel = 'No projects available',
  });

  final List<HubProjectCard> projects;
  final ValueChanged<int> onProjectTap;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final sorted = HubProjectCard.sortByActivity(projects);
    if (sorted.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final project = sorted[index];
        return ProjectCardTile(
          project: project,
          onTap: () => onProjectTap(project.projectId),
        );
      },
    );
  }
}

class ProjectCardTile extends StatelessWidget {
  const ProjectCardTile({
    super.key,
    required this.project,
    required this.onTap,
  });

  final HubProjectCard project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActivity = project.lastActivityAt.trim().isNotEmpty;
    final waveLabel = project.activeWaveCount == 1
        ? '1 active wave'
        : '${project.activeWaveCount} active waves';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                project.cwd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.alt_route, size: 16),
                    label: Text(waveLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(
                      hasActivity ? project.lastActivityAt : 'No activity yet',
                    ),
                    visualDensity: VisualDensity.compact,
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

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _asString(Object? value) => value is String ? value : '${value ?? ''}';
