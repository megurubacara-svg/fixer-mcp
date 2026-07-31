import 'package:flutter/material.dart';

import 'backlog_models.dart';
import 'backlog_repository.dart';

class BacklogPanel extends StatefulWidget {
  const BacklogPanel({
    super.key,
    required this.repository,
    required this.projectId,
  });

  final BacklogRepository repository;
  final int projectId;

  @override
  State<BacklogPanel> createState() => _BacklogPanelState();
}

typedef ProjectBacklogPanel = BacklogPanel;

class _BacklogPanelState extends State<BacklogPanel> {
  late Future<ProjectBacklogSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadProjectBacklog(widget.projectId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadProjectBacklog(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FutureBuilder<ProjectBacklogSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _BacklogMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load backlog',
              message: snapshot.error.toString(),
              action: OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            );
          }

          final backlog = snapshot.data;
          if (backlog == null) {
            return const _BacklogMessage(
              icon: Icons.inbox_outlined,
              title: 'Backlog is unavailable',
              message: 'The project did not return a backlog payload.',
            );
          }
          if (backlog.items.isEmpty && backlog.documents.isEmpty) {
            return _BacklogMessage(
              icon: Icons.inbox_outlined,
              title: 'No backlog yet',
              message:
                  'This project has no structured backlog items or canonical backlog documents.',
              action: OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PanelHeader(
                  title: 'Backlog',
                  subtitle: backlog.project.name,
                  count: backlog.items.length + backlog.documents.length,
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: Icons.checklist_outlined,
                  title: 'Structured backlog items',
                  count: backlog.items.length,
                ),
                const SizedBox(height: 8),
                if (backlog.items.isEmpty)
                  const _InlineEmptyState(
                    message: 'No structured items in this project.',
                  )
                else
                  ...backlog.items.map(_BacklogItemCard.new),
                const SizedBox(height: 24),
                _SectionHeader(
                  icon: Icons.account_tree_outlined,
                  title: 'Canonical backlog documents',
                  count: backlog.documents.length,
                ),
                const SizedBox(height: 8),
                if (backlog.documents.isEmpty)
                  const _InlineEmptyState(
                    message: 'No canonical backlog documents in this project.',
                  )
                else
                  ...backlog.documents.map(_BacklogDocumentTile.new),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        Chip(label: Text('$count total')),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text('$count'),
      ],
    );
  }
}

class _BacklogItemCard extends StatelessWidget {
  const _BacklogItemCard(this.item);

  final BacklogItemRecord item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleSmall),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.description),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetadataChip(label: 'Status', value: item.status),
                if (item.priority.isNotEmpty)
                  _MetadataChip(label: 'Priority', value: item.priority),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklogDocumentTile extends StatelessWidget {
  const _BacklogDocumentTile(this.document);

  final BacklogDocumentRecord document;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: document.level * 20.0),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(document.title),
          subtitle: Text(
            [
              if (document.status.isNotEmpty) document.status,
              if (document.path.isNotEmpty) document.path,
            ].join(' · '),
          ),
          children: [
            if (document.contentPreview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(document.contentPreview),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('This document has no preview.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _BacklogMessage extends StatelessWidget {
  const _BacklogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
