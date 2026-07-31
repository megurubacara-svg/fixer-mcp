import '../../dashboard_runtime_client.dart';
import 'skills_models.dart';

abstract class SkillsRepository {
  Future<ProjectSkillsCatalog> loadSkills(int projectId);

  Future<ManagedSkillDetail> loadSkill(
    int projectId,
    String rootId,
    String name,
  );

  Future<ManagedSkillDetail> updateSkill(
    int projectId,
    String name, {
    required String rootId,
    required String content,
  });
}

class BridgeSkillsRepository implements SkillsRepository {
  BridgeSkillsRepository({DashboardRuntimeClient? runtimeClient})
    : _runtimeClient = runtimeClient ?? DashboardRuntimeClient();

  final DashboardRuntimeClient _runtimeClient;

  @override
  Future<ProjectSkillsCatalog> loadSkills(int projectId) async {
    final json = await _runtimeClient.readDashboardJson(
      '/api/projects/$projectId/skills',
    );
    return ProjectSkillsCatalog.fromJson(json);
  }

  @override
  Future<ManagedSkillDetail> loadSkill(
    int projectId,
    String rootId,
    String name,
  ) async {
    final json = await _runtimeClient.readDashboardJson(
      '/api/projects/$projectId/skills/${_segment(rootId)}/${_segment(name)}',
    );
    return ManagedSkillDetail.fromJson(json);
  }

  @override
  Future<ManagedSkillDetail> updateSkill(
    int projectId,
    String name, {
    required String rootId,
    required String content,
  }) async {
    final json = await _runtimeClient.postDashboardJson(
      '/api/actions/projects/$projectId/skills/${_segment(name)}',
      {'root_id': rootId, 'content': content},
    );
    return ManagedSkillDetail.fromJson(json);
  }

  String _segment(String value) => Uri.encodeComponent(value);
}
