import '../../dashboard_runtime_client.dart';
import 'overseer_models.dart';

abstract interface class OverseerManagerRepository {
  Future<List<OverseerThreadRecord>> loadThreads();

  Future<OverseerLaunchPlanRecord> createOverseer(
    OverseerLaunchRequest request,
  );

  Future<OverseerLaunchPlanRecord> resumeOverseer(OverseerThreadRecord thread);
}

class DashboardOverseerManagerRepository implements OverseerManagerRepository {
  DashboardOverseerManagerRepository({
    String? baseUrl,
    DashboardRuntimeClient? runtimeClient,
  }) : _runtimeClient =
           runtimeClient ?? DashboardRuntimeClient(dashboardBaseUrl: baseUrl);

  final DashboardRuntimeClient _runtimeClient;

  @override
  Future<List<OverseerThreadRecord>> loadThreads() async {
    final payload = await _runtimeClient.readDashboardJson(
      '/api/overseer/threads',
    );
    final rawThreads = payload['threads'];
    if (rawThreads is! List) {
      return const [];
    }
    return rawThreads
        .whereType<Map>()
        .map(
          (raw) =>
              OverseerThreadRecord.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList(growable: false);
  }

  @override
  Future<OverseerLaunchPlanRecord> createOverseer(
    OverseerLaunchRequest request,
  ) => _launch(request);

  @override
  Future<OverseerLaunchPlanRecord> resumeOverseer(OverseerThreadRecord thread) {
    return _launch(
      OverseerLaunchRequest(
        cwd: thread.spawnCwd,
        backend: thread.backend,
        model: thread.model,
        reasoning: thread.reasoning,
        externalSessionId: thread.externalSessionId,
      ),
    );
  }

  Future<OverseerLaunchPlanRecord> _launch(
    OverseerLaunchRequest request,
  ) async {
    final payload = await _runtimeClient.postDashboardJson(
      '/api/actions/overseer/launch',
      request.toJson(),
    );
    return OverseerLaunchPlanRecord.fromJson(payload);
  }
}
