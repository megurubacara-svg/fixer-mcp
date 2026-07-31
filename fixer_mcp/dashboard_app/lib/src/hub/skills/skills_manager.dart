import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'skills_models.dart';
import 'skills_repository.dart';

class SkillsManagerScreen extends StatefulWidget {
  const SkillsManagerScreen({
    super.key,
    required this.projectId,
    required this.repository,
  });

  final int projectId;
  final SkillsRepository repository;

  @override
  State<SkillsManagerScreen> createState() => _SkillsManagerScreenState();
}

class _SkillsManagerScreenState extends State<SkillsManagerScreen> {
  final _editor = TextEditingController();
  ProjectSkillsCatalog? _catalog;
  ManagedSkillDetail? _detail;
  String? _selectedName;
  Object? _error;
  bool _loadingCatalog = true;
  bool _loadingDetail = false;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final catalog = await widget.repository.loadSkills(widget.projectId);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadingCatalog = false;
      });
      if (catalog.skills.isNotEmpty) {
        await _selectSkill(catalog.skills.first);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _selectSkill(ManagedSkillSummary skill) async {
    if (skill.locations.isEmpty) return;
    setState(() {
      _selectedName = skill.name;
      _loadingDetail = true;
      _editing = false;
      _error = null;
    });
    final location = skill.locations.first;
    try {
      final detail = await widget.repository.loadSkill(
        widget.projectId,
        location.rootId,
        skill.name,
      );
      if (!mounted || _selectedName != skill.name) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (error) {
      if (!mounted || _selectedName != skill.name) return;
      setState(() {
        _error = error;
        _loadingDetail = false;
      });
    }
  }

  void _beginEdit() {
    final detail = _detail;
    if (detail == null) return;
    _editor.text = detail.content;
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    final detail = _detail;
    if (detail == null || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateSkill(
        widget.projectId,
        detail.summary.name,
        rootId: detail.rootId,
        content: _editor.text,
      );
      if (!mounted) return;
      setState(() {
        _detail = updated;
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Skill saved')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _catalog?.projectName.isNotEmpty == true
        ? '${_catalog!.projectName} skills'
        : 'Skills Manager';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            key: const ValueKey('skills-refresh'),
            tooltip: 'Refresh skills',
            onPressed: _loadingCatalog ? null : _loadCatalog,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_loadingCatalog) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && _catalog == null) {
            return _ErrorState(error: _error!, onRetry: _loadCatalog);
          }
          final list = _SkillsList(
            skills: _catalog?.skills ?? const [],
            selectedName: _selectedName,
            onSelected: _selectSkill,
          );
          final detail = _buildDetail();
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                SizedBox(height: 220, child: list),
                const Divider(),
                Expanded(child: detail),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 320, child: list),
              const VerticalDivider(),
              Expanded(child: detail),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetail() {
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final selected = _catalog?.skills
          .where((skill) => skill.name == _selectedName)
          .firstOrNull;
      return _ErrorState(
        error: _error!,
        onRetry: selected == null ? _loadCatalog : () => _selectSkill(selected),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const Center(child: Text('Select a managed skill'));
    }
    return _editing ? _buildEditor(detail) : _buildViewer(detail);
  }

  Widget _buildViewer(ManagedSkillDetail detail) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.summary.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail.relativePath,
                    key: const ValueKey('skill-relative-path'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('skill-edit'),
              onPressed: _beginEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ],
        ),
        if (detail.summary.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(detail.summary.description),
        ],
        if (detail.summary.relatedSkills.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final related in detail.summary.relatedSkills)
                Chip(
                  avatar: const Icon(Icons.account_tree_outlined, size: 16),
                  label: Text(related),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Expanded(
          child: MarkdownWidget(
            key: const ValueKey('skill-markdown'),
            data: detail.content,
          ),
        ),
      ],
    ),
  );

  Widget _buildEditor(ManagedSkillDetail detail) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Editing ${detail.summary.name}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            key: const ValueKey('skill-editor'),
            controller: _editor,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'SKILL.md content',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('skill-save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SkillsList extends StatelessWidget {
  const _SkillsList({
    required this.skills,
    required this.selectedName,
    required this.onSelected,
  });

  final List<ManagedSkillSummary> skills;
  final String? selectedName;
  final ValueChanged<ManagedSkillSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) {
      return const Center(child: Text('No managed Fixer skills found'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: skills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final skill = skills[index];
        return ListTile(
          key: ValueKey('skill-${skill.name}'),
          selected: selectedName == skill.name,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: const Icon(Icons.extension_outlined),
          title: Text(skill.name),
          subtitle: Text(
            skill.description.isEmpty
                ? 'Managed Fixer skill'
                : skill.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: skill.locations.length > 1
              ? Tooltip(
                  message: '${skill.locations.length} materializations',
                  child: Badge(label: Text('${skill.locations.length}')),
                )
              : null,
          onTap: () => onSelected(skill),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 36),
          const SizedBox(height: 12),
          Text('Could not load skills: $error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
