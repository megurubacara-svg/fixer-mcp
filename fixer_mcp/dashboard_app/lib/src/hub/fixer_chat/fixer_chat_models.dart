class FixerProviderOption {
  const FixerProviderOption({
    required this.backend,
    required this.label,
    required this.models,
    required this.reasoningOptions,
  });

  final String backend;
  final String label;
  final List<String> models;
  final List<String> reasoningOptions;

  String get defaultModel => models.first;
  String get defaultReasoning => reasoningOptions.first;
}

const supportedFixerProviders = <FixerProviderOption>[
  FixerProviderOption(
    backend: 'codex',
    label: 'Codex CLI',
    models: ['gpt-5.6-luna', 'gpt-5.6-sol', 'gpt-5.6-terra'],
    reasoningOptions: ['xhigh', 'high', 'medium', 'low'],
  ),
  FixerProviderOption(
    backend: 'antigravity',
    label: 'Google Antigravity',
    models: [
      'default',
      'Gemini 3.5 Flash',
      'Gemini 3.6 Flash',
      'Gemini 3.1 Pro',
      'Claude Sonnet 4.6',
      'Claude Opus 4.6',
      'GPT-OSS 120B',
    ],
    reasoningOptions: ['default', 'low', 'medium', 'high', 'thinking'],
  ),
  FixerProviderOption(
    backend: 'claude',
    label: 'Claude Code',
    models: ['sonnet', 'opus', 'haiku'],
    reasoningOptions: ['medium'],
  ),
  FixerProviderOption(
    backend: 'kimi-code',
    label: 'Kimi Code',
    models: ['kimi-k2.7-code', 'kimi-k3'],
    reasoningOptions: ['default', 'low', 'medium', 'high', 'xhigh'],
  ),
  FixerProviderOption(
    backend: 'droid',
    label: 'Factory Droid',
    models: ['kimi-k2.6', 'kimi-k2.7-code', 'glm-5.1'],
    reasoningOptions: ['high', 'medium', 'low', 'none'],
  ),
  FixerProviderOption(
    backend: 'junie',
    label: 'Junie CLI',
    models: ['kimi-k2.6', 'kimi-k2.7-code', 'glm-5.1'],
    reasoningOptions: ['default'],
  ),
];

class FixerThreadRecord {
  const FixerThreadRecord({
    required this.externalId,
    required this.headline,
    required this.status,
    required this.backend,
    required this.model,
    required this.reasoning,
    required this.cwd,
    required this.lastActivityAt,
    required this.transcriptAvailable,
  });

  final String externalId;
  final String headline;
  final String status;
  final String backend;
  final String model;
  final String reasoning;
  final String cwd;
  final String lastActivityAt;
  final bool transcriptAvailable;

  factory FixerThreadRecord.fromJson(Map<String, dynamic> json) {
    return FixerThreadRecord(
      externalId: _string(json['external_id']),
      headline: _string(json['headline'], fallback: 'Fixer thread'),
      status: _string(json['status'], fallback: 'history'),
      backend: _string(json['backend'], fallback: 'codex'),
      model: _string(json['model']),
      reasoning: _string(json['reasoning']),
      cwd: _string(json['cwd']),
      lastActivityAt: _string(json['last_activity_at']),
      transcriptAvailable: json['transcript_available'] == true,
    );
  }
}

class FixerChatLaunchRequest {
  const FixerChatLaunchRequest({
    required this.backend,
    required this.model,
    required this.reasoning,
    required this.cwd,
  });

  final String backend;
  final String model;
  final String reasoning;
  final String cwd;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'backend': backend,
    'model': model,
    'reasoning': reasoning,
    'cwd': cwd,
  };
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
