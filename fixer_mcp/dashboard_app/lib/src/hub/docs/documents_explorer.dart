import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// A dashboard-ready project document with its canonical tree metadata.
class HubDocument {
  const HubDocument({
    required this.id,
    required this.title,
    required this.docType,
    required this.level,
    required this.slug,
    required this.path,
    required this.status,
    required this.content,
    this.parentDocId,
    this.children = const <HubDocument>[],
  });

  final int id;
  final int? parentDocId;
  final int level;
  final String slug;
  final String path;
  final String status;
  final String title;
  final String docType;
  final String content;
  final List<HubDocument> children;

  String get contentPreview {
    final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 160) return normalized;
    return '${normalized.substring(0, 157)}...';
  }

  factory HubDocument.fromJson(Map<String, dynamic> json) {
    return HubDocument(
      id: _asInt(json['id']),
      parentDocId: json['parent_doc_id'] == null
          ? null
          : _asInt(json['parent_doc_id']),
      level: _asInt(json['level']),
      slug: _asString(json['slug']),
      path: _asString(json['path']),
      status: _asString(json['status'], fallback: 'current'),
      title: _asString(json['title']),
      docType: _asString(json['doc_type'], fallback: 'documentation'),
      content: _asString(json['content']),
      children: _asList(
        json['children'],
      ).map((item) => HubDocument.fromJson(item)).toList(growable: false),
    );
  }
}

class ProjectDocumentsSnapshot {
  const ProjectDocumentsSnapshot({
    required this.projectName,
    required this.totalDocs,
    required this.roots,
  });

  final String projectName;
  final int totalDocs;
  final List<HubDocument> roots;

  factory ProjectDocumentsSnapshot.fromJson(Map<String, dynamic> json) {
    final project = json['project'];
    final projectMap = project is Map
        ? Map<String, dynamic>.from(project)
        : const <String, dynamic>{};
    return ProjectDocumentsSnapshot(
      projectName: _asString(projectMap['name']),
      totalDocs: _asInt(json['total_docs']),
      roots: _asList(
        json['roots'],
      ).map((item) => HubDocument.fromJson(item)).toList(growable: false),
    );
  }
}

/// An isolated project-docs surface. The parent dashboard can mount it from
/// any project tab without changing shared routing or dashboard models.
class DocumentsExplorer extends StatefulWidget {
  const DocumentsExplorer({
    super.key,
    required this.snapshot,
    this.onDocumentSelected,
  });

  final ProjectDocumentsSnapshot snapshot;
  final ValueChanged<HubDocument>? onDocumentSelected;

  @override
  State<DocumentsExplorer> createState() => _DocumentsExplorerState();
}

class _DocumentsExplorerState extends State<DocumentsExplorer> {
  HubDocument? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = _selected ?? _firstDocument(widget.snapshot.roots);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final tree = _DocumentTree(
          roots: widget.snapshot.roots,
          selectedId: selected?.id,
          onSelected: _selectDocument,
        );
        final detail = selected == null
            ? const _EmptyDocumentDetail()
            : DocumentMarkdownView(document: selected);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 320, child: tree),
              const SizedBox(width: 16),
              Expanded(child: detail),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: 360, child: tree),
            const SizedBox(height: 16),
            detail,
          ],
        );
      },
    );
  }

  void _selectDocument(HubDocument document) {
    setState(() => _selected = document);
    widget.onDocumentSelected?.call(document);
    showDialog<void>(
      context: context,
      builder: (_) => DocumentMarkdownDialog(document: document),
    );
  }
}

class _DocumentTree extends StatelessWidget {
  const _DocumentTree({
    required this.roots,
    required this.selectedId,
    required this.onSelected,
  });

  final List<HubDocument> roots;
  final int? selectedId;
  final ValueChanged<HubDocument> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        children: [
          Text(
            'Project documents',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_countDocuments(roots)} canonical documents',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final root in roots) ...[
            _DocumentSection(
              document: root,
              selectedId: selectedId,
              onSelected: onSelected,
            ),
            const SizedBox(height: 10),
          ],
          if (roots.isEmpty) const _EmptyTree(),
        ],
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.document,
    required this.selectedId,
    required this.onSelected,
  });

  final HubDocument document;
  final int? selectedId;
  final ValueChanged<HubDocument> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocumentTile(
            document: document,
            selected: document.id == selectedId,
            onTap: () => onSelected(document),
            root: true,
          ),
          for (final child in document.children)
            _DocumentBranch(
              document: child,
              selectedId: selectedId,
              onSelected: onSelected,
            ),
        ],
      ),
    );
  }
}

class _DocumentBranch extends StatelessWidget {
  const _DocumentBranch({
    required this.document,
    required this.selectedId,
    required this.onSelected,
  });

  final HubDocument document;
  final int? selectedId;
  final ValueChanged<HubDocument> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        children: [
          _DocumentTile(
            document: document,
            selected: document.id == selectedId,
            onTap: () => onSelected(document),
          ),
          for (final child in document.children)
            _DocumentBranch(
              document: child,
              selectedId: selectedId,
              onSelected: onSelected,
            ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.selected,
    required this.onTap,
    this.root = false,
  });

  final HubDocument document;
  final bool selected;
  final VoidCallback onTap;
  final bool root;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      leading: Icon(
        root ? Icons.folder_outlined : Icons.description_outlined,
        size: 20,
      ),
      title: Text(
        document.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${document.docType} · ${document.status}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class DocumentMarkdownView extends StatelessWidget {
  const DocumentMarkdownView({super.key, required this.document});

  final HubDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle =
        theme.textTheme.bodyMedium?.copyWith(height: 1.5) ??
        TextStyle(color: theme.colorScheme.onSurface, height: 1.5);
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(document.docType)),
                Chip(label: Text(document.status)),
                if (document.path.isNotEmpty) Chip(label: Text(document.path)),
              ],
            ),
            const Divider(height: 28),
            MarkdownWidget(
              data: document.content,
              shrinkWrap: true,
              selectable: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              config: MarkdownConfig.defaultConfig.copy(
                configs: [
                  PConfig(textStyle: bodyStyle),
                  H1Config(style: theme.textTheme.headlineSmall ?? bodyStyle),
                  H2Config(style: theme.textTheme.titleLarge ?? bodyStyle),
                  H3Config(style: theme.textTheme.titleMedium ?? bodyStyle),
                  CodeConfig(
                    style: bodyStyle.copyWith(
                      fontFamily: 'monospace',
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentMarkdownDialog extends StatelessWidget {
  const DocumentMarkdownDialog({super.key, required this.document});

  final HubDocument document;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: DocumentMarkdownView(document: document),
      ),
    );
  }
}

class _EmptyDocumentDetail extends StatelessWidget {
  const _EmptyDocumentDetail();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Center(
        child: Text(
          'Select a document to read its Markdown content.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _EmptyTree extends StatelessWidget {
  const _EmptyTree();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'No canonical documents yet.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

HubDocument? _firstDocument(List<HubDocument> documents) {
  if (documents.isEmpty) return null;
  return documents.first;
}

int _countDocuments(List<HubDocument> documents) {
  return documents.fold<int>(
    0,
    (total, document) => total + 1 + _countDocuments(document.children),
  );
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _asString(dynamic value, {String fallback = ''}) {
  return value == null ? fallback : '$value';
}
