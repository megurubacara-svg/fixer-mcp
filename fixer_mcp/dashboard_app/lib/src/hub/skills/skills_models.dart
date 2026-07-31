class SkillLocation {
  const SkillLocation({
    required this.rootId,
    required this.rootLabel,
    required this.relativePath,
  });

  factory SkillLocation.fromJson(Map<String, dynamic> json) => SkillLocation(
    rootId: json['root_id'] as String? ?? '',
    rootLabel: json['root_label'] as String? ?? '',
    relativePath: json['relative_path'] as String? ?? '',
  );

  final String rootId;
  final String rootLabel;
  final String relativePath;
}

class ManagedSkillSummary {
  const ManagedSkillSummary({
    required this.name,
    required this.description,
    required this.locations,
    required this.relatedSkills,
  });

  factory ManagedSkillSummary.fromJson(Map<String, dynamic> json) =>
      ManagedSkillSummary(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        locations: _mapList(json['locations'], SkillLocation.fromJson),
        relatedSkills: (json['related_skills'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  final String name;
  final String description;
  final List<SkillLocation> locations;
  final List<String> relatedSkills;
}

class ManagedSkillDetail {
  const ManagedSkillDetail({
    required this.summary,
    required this.rootId,
    required this.relativePath,
    required this.content,
  });

  factory ManagedSkillDetail.fromJson(Map<String, dynamic> json) =>
      ManagedSkillDetail(
        summary: ManagedSkillSummary.fromJson(json),
        rootId: json['root_id'] as String? ?? '',
        relativePath: json['relative_path'] as String? ?? '',
        content: json['content'] as String? ?? '',
      );

  final ManagedSkillSummary summary;
  final String rootId;
  final String relativePath;
  final String content;
}

class ProjectSkillsCatalog {
  const ProjectSkillsCatalog({required this.projectName, required this.skills});

  factory ProjectSkillsCatalog.fromJson(Map<String, dynamic> json) {
    final project = json['project'];
    final projectJson = project is Map
        ? Map<String, dynamic>.from(project)
        : const <String, dynamic>{};
    return ProjectSkillsCatalog(
      projectName: projectJson['name'] as String? ?? '',
      skills: _mapList(json['skills'], ManagedSkillSummary.fromJson),
    );
  }

  final String projectName;
  final List<ManagedSkillSummary> skills;
}

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) convert) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => convert(Map<String, dynamic>.from(item)))
        .toList(growable: false);
