import '../../dashboard_runtime_client.dart';
import 'backlog_models.dart';

abstract class BacklogRepository {
  Future<ProjectBacklogSnapshot> loadProjectBacklog(int projectId);
}

class BridgeBacklogRepository implements BacklogRepository {
  BridgeBacklogRepository({DashboardRuntimeClient? runtimeClient})
    : _runtimeClient = runtimeClient ?? DashboardRuntimeClient();

  final DashboardRuntimeClient _runtimeClient;

  @override
  Future<ProjectBacklogSnapshot> loadProjectBacklog(int projectId) async {
    if (projectId <= 0) {
      throw ArgumentError.value(projectId, 'projectId', 'must be positive');
    }
    final payload = await _runtimeClient.readDashboardJson(
      '/api/projects/$projectId/backlog',
    );
    return ProjectBacklogSnapshot.fromJson(payload);
  }
}
