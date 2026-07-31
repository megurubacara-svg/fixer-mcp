import '../../dashboard_runtime_client.dart';
import 'netrunner_thread_models.dart';

abstract interface class NetrunnerThreadRepository {
  Future<NetrunnerThreadSnapshot> loadThread(int sessionId);

  Future<NetrunnerContinuationResult> sendFollowUp(
    int sessionId,
    String message,
  );
}

class BridgeNetrunnerThreadRepository implements NetrunnerThreadRepository {
  BridgeNetrunnerThreadRepository({
    String? baseUrl,
    DashboardRuntimeClient? runtimeClient,
  }) : _runtimeClient =
           runtimeClient ?? DashboardRuntimeClient(dashboardBaseUrl: baseUrl);

  final DashboardRuntimeClient _runtimeClient;

  @override
  Future<NetrunnerThreadSnapshot> loadThread(int sessionId) async {
    final payload = await _runtimeClient.readDashboardJson(
      '/api/sessions/$sessionId/thread',
    );
    return NetrunnerThreadSnapshot.fromJson(payload);
  }

  @override
  Future<NetrunnerContinuationResult> sendFollowUp(
    int sessionId,
    String message,
  ) async {
    final payload = await _runtimeClient.postDashboardJson(
      '/api/actions/sessions/$sessionId/thread/messages',
      {'message': message},
    );
    return NetrunnerContinuationResult.fromJson(payload);
  }
}
