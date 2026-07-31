class NetrunnerThreadMessageRecord {
  const NetrunnerThreadMessageRecord({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    required this.source,
  });

  final String id;
  final String role;
  final String text;
  final String createdAt;
  final String source;

  factory NetrunnerThreadMessageRecord.fromJson(Map<String, dynamic> json) {
    return NetrunnerThreadMessageRecord(
      id: _string(json['id']),
      role: _string(json['role']),
      text: _string(json['text']),
      createdAt: _string(json['created_at']),
      source: _string(json['source']),
    );
  }
}

class NetrunnerContinuationCapabilityRecord {
  const NetrunnerContinuationCapabilityRecord({
    required this.supported,
    required this.mode,
    required this.reason,
  });

  final bool supported;
  final String mode;
  final String reason;

  factory NetrunnerContinuationCapabilityRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return NetrunnerContinuationCapabilityRecord(
      supported: json['supported'] == true,
      mode: _string(json['mode']),
      reason: _string(json['reason']),
    );
  }
}

class NetrunnerThreadSnapshot {
  const NetrunnerThreadSnapshot({
    required this.sessionId,
    required this.localId,
    required this.projectId,
    required this.status,
    required this.backend,
    required this.model,
    required this.reasoning,
    required this.externalSessionId,
    required this.launchState,
    required this.transcriptAvailability,
    required this.transcriptPath,
    required this.messages,
    required this.continuation,
  });

  final int sessionId;
  final int localId;
  final int projectId;
  final String status;
  final String backend;
  final String model;
  final String reasoning;
  final String externalSessionId;
  final String launchState;
  final String transcriptAvailability;
  final String transcriptPath;
  final List<NetrunnerThreadMessageRecord> messages;
  final NetrunnerContinuationCapabilityRecord continuation;

  bool get isAwaitingBackend => launchState == 'awaiting_backend';
  bool get hasTranscript => transcriptAvailability == 'available';

  factory NetrunnerThreadSnapshot.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = <NetrunnerThreadMessageRecord>[];
    if (rawMessages is List) {
      for (final raw in rawMessages) {
        if (raw is Map) {
          messages.add(
            NetrunnerThreadMessageRecord.fromJson(
              Map<String, dynamic>.from(raw),
            ),
          );
        }
      }
    }
    return NetrunnerThreadSnapshot(
      sessionId: _integer(json['session_id']),
      localId: _integer(json['local_id']),
      projectId: _integer(json['project_id']),
      status: _string(json['status']),
      backend: _string(json['backend']),
      model: _string(json['model']),
      reasoning: _string(json['reasoning']),
      externalSessionId: _string(json['external_session_id']),
      launchState: _string(json['launch_state']),
      transcriptAvailability: _string(json['transcript_availability']),
      transcriptPath: _string(json['transcript_path']),
      messages: messages,
      continuation: NetrunnerContinuationCapabilityRecord.fromJson(
        _map(json['continuation']),
      ),
    );
  }
}

class NetrunnerContinuationResult {
  const NetrunnerContinuationResult({
    required this.status,
    required this.sessionId,
    required this.backend,
    required this.externalSessionId,
    required this.processId,
    required this.message,
  });

  final String status;
  final int sessionId;
  final String backend;
  final String externalSessionId;
  final int processId;
  final String message;

  factory NetrunnerContinuationResult.fromJson(Map<String, dynamic> json) {
    return NetrunnerContinuationResult(
      status: _string(json['status']),
      sessionId: _integer(json['session_id']),
      backend: _string(json['backend']),
      externalSessionId: _string(json['external_session_id']),
      processId: _integer(json['process_id']),
      message: _string(json['message']),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _string(Object? value) => value is String ? value : '';

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
