import '../../dashboard_runtime_client.dart';
import 'netrunner_models.dart';

abstract interface class NetrunnerExplorerRepository {
  Future<NetrunnerExplorerSnapshot> loadProjectNetrunners(int projectId);
}

class BridgeNetrunnerExplorerRepository implements NetrunnerExplorerRepository {
  BridgeNetrunnerExplorerRepository({
    String? baseUrl,
    DashboardRuntimeClient? runtimeClient,
  }) : _runtimeClient =
           runtimeClient ?? DashboardRuntimeClient(dashboardBaseUrl: baseUrl);

  final DashboardRuntimeClient _runtimeClient;

  @override
  Future<NetrunnerExplorerSnapshot> loadProjectNetrunners(int projectId) async {
    final payload = await _runtimeClient.readDashboardJson(
      '/api/projects/$projectId/netrunners',
    );
    return NetrunnerExplorerSnapshot.fromJson(payload);
  }
}
