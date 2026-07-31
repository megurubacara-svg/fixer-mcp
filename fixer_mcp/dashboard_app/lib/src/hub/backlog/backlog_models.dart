class BacklogItemRecord {
  const BacklogItemRecord({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String createdAt;
  final String updatedAt;

  factory BacklogItemRecord.fromJson(Map<String, dynamic> json) {
    return BacklogItemRecord(
      id: _asInt(json['id']),
      projectId: _asInt(json['project_id']),
      title: _asString(json['title']),
      description: _asString(json['description']),
      status: _asString(json['status'], fallback: 'open'),
      priority: _asString(json['priority']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }
}

class BacklogDocumentRecord {
  const BacklogDocumentRecord({
    required this.id,
    required this.title,
    required this.docType,
    required this.contentPreview,
    required this.parentDocId,
    required this.level,
    required this.slug,
    required this.path,
    required this.status,
  });

  final int id;
  final String title;
  final String docType;
  final String contentPreview;
  final int parentDocId;
  final int level;
  final String slug;
  final String path;
  final String status;

  factory BacklogDocumentRecord.fromJson(Map<String, dynamic> json) {
    return BacklogDocumentRecord(
      id: _asInt(json['id']),
      title: _asString(json['title']),
      docType: _asString(json['doc_type'], fallback: 'backlog'),
      contentPreview: _asString(json['content_preview']),
      parentDocId: _asInt(json['parent_doc_id']),
      level: _asInt(json['level']),
      slug: _asString(json['slug']),
      path: _asString(json['path']),
      status: _asString(json['status'], fallback: 'current'),
    );
  }
}

class BacklogProjectRecord {
  const BacklogProjectRecord({
    required this.id,
    required this.name,
    required this.cwd,
  });

  final int id;
  final String name;
  final String cwd;

  factory BacklogProjectRecord.fromJson(Map<String, dynamic> json) {
    return BacklogProjectRecord(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      cwd: _asString(json['cwd']),
    );
  }
}

class ProjectBacklogSnapshot {
  const ProjectBacklogSnapshot({
    required this.project,
    required this.items,
    required this.documents,
  });

  final BacklogProjectRecord project;
  final List<BacklogItemRecord> items;
  final List<BacklogDocumentRecord> documents;

  factory ProjectBacklogSnapshot.fromJson(Map<String, dynamic> json) {
    return ProjectBacklogSnapshot(
      project: BacklogProjectRecord.fromJson(_asMap(json['project'])),
      items: _asList(json['items'], BacklogItemRecord.fromJson),
      documents: _asList(json['documents'], BacklogDocumentRecord.fromJson),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

String _asString(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<T> _asList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
