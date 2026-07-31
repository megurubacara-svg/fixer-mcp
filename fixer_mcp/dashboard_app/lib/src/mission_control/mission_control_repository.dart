import '../dashboard_runtime_client.dart';
import 'mission_control_models.dart';

abstract class MissionControlRepository {
  Future<MissionControlWavesSnapshot> loadWaves(int projectId);

  Future<void> runWaveAction(int projectId, int waveId, String action);
}

class MissionControlWaveActionResult {
  const MissionControlWaveActionResult({this.initializedWaveId = 0});

  final int initializedWaveId;
}

abstract interface class MissionControlWaveActionResultSource {
  MissionControlWaveActionResult get lastWaveActionResult;
}

class BridgeMissionControlRepository
    implements MissionControlRepository, MissionControlWaveActionResultSource {
  BridgeMissionControlRepository({DashboardRuntimeClient? runtimeClient})
    : _runtimeClient = runtimeClient ?? DashboardRuntimeClient();

  final DashboardRuntimeClient _runtimeClient;
  MissionControlWaveActionResult _lastWaveActionResult =
      const MissionControlWaveActionResult();

  @override
  MissionControlWaveActionResult get lastWaveActionResult =>
      _lastWaveActionResult;

  @override
  Future<MissionControlWavesSnapshot> loadWaves(int projectId) async {
    final payload = await _runtimeClient.readDashboardJson(
      '/api/projects/$projectId/waves',
    );
    return MissionControlWavesSnapshot.fromJson(payload);
  }

  @override
  Future<void> runWaveAction(int projectId, int waveId, String action) async {
    _lastWaveActionResult = const MissionControlWaveActionResult();
    if (action == 'initialize') {
      final payload = await _runtimeClient.postDashboardJson(
        '/api/actions/projects/$projectId/planned-waves/$waveId/initialize',
        const <String, dynamic>{},
      );
      final initializedWaveId = _asPositiveInt(payload['wave_id']);
      if (initializedWaveId == 0) {
        throw StateError(
          'Governed Initialize returned no normal wave identity.',
        );
      }
      _lastWaveActionResult = MissionControlWaveActionResult(
        initializedWaveId: initializedWaveId,
      );
      return;
    }
    if (!MissionControlActionCapabilities.actionOrder.contains(action)) {
      throw ArgumentError.value(action, 'action', 'Unsupported wave action');
    }
    await _runtimeClient.postDashboardJson(
      '/api/actions/projects/$projectId/waves/$waveId/$action',
      const <String, dynamic>{},
    );
  }
}

int _asPositiveInt(dynamic value) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()) ?? 0,
    _ => 0,
  };
  return parsed > 0 ? parsed : 0;
}
