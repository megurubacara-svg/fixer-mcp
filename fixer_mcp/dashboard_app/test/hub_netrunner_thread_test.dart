import 'package:fixer_dashboard_app/src/hub/netrunner_thread/netrunner_thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the linked provider transcript and sends a follow-up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeNetrunnerThreadRepository(_codexThread());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetrunnerThreadPanel(sessionId: 403, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Netrunner #17 thread'), findsOneWidget);
    expect(find.text('codex'), findsOneWidget);
    expect(find.text('Inspect the failing test.'), findsOneWidget);
    expect(find.text('The focused test is now green.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('netrunner-thread-composer')),
      'Please rerun the full package.',
    );
    await tester.tap(find.byKey(const Key('netrunner-thread-send')));
    await tester.pumpAndSettle();

    expect(repository.sentMessages, ['Please rerun the full package.']);
    expect(find.text('Follow-up submitted.'), findsOneWidget);
  });

  testWidgets('keeps a pending manual session visibly unlaunched', (
    tester,
  ) async {
    final repository = _FakeNetrunnerThreadRepository(_pendingManualThread());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetrunnerThreadPanel(sessionId: 404, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No backend'), findsOneWidget);
    expect(
      find.text('Choose a backend to launch this Netrunner'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('netrunner-thread-composer')), findsNothing);
  });

  testWidgets('explains unsupported provider continuation truthfully', (
    tester,
  ) async {
    final repository = _FakeNetrunnerThreadRepository(_kimiThread());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetrunnerThreadPanel(sessionId: 405, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('kimi-code'), findsOneWidget);
    expect(find.text('Transcript metadata only'), findsOneWidget);
    expect(find.text('Follow-up is unavailable'), findsOneWidget);
    expect(find.textContaining('project-scoped MCP config'), findsOneWidget);
    expect(find.byKey(const Key('netrunner-thread-composer')), findsNothing);
  });
}

NetrunnerThreadSnapshot _codexThread() {
  return const NetrunnerThreadSnapshot(
    sessionId: 403,
    localId: 17,
    projectId: 2,
    status: 'in_progress',
    backend: 'codex',
    model: 'gpt-5.6-sol',
    reasoning: 'high',
    externalSessionId: 'codex-thread-403',
    launchState: 'linked',
    transcriptAvailability: 'available',
    transcriptPath: '/tmp/codex-thread-403.jsonl',
    messages: [
      NetrunnerThreadMessageRecord(
        id: '1',
        role: 'user',
        text: 'Inspect the failing test.',
        createdAt: '',
        source: 'provider_transcript',
      ),
      NetrunnerThreadMessageRecord(
        id: '2',
        role: 'assistant',
        text: 'The focused test is now green.',
        createdAt: '',
        source: 'provider_transcript',
      ),
    ],
    continuation: NetrunnerContinuationCapabilityRecord(
      supported: true,
      mode: 'headless_resume',
      reason: '',
    ),
  );
}

NetrunnerThreadSnapshot _pendingManualThread() {
  return const NetrunnerThreadSnapshot(
    sessionId: 404,
    localId: 18,
    projectId: 2,
    status: 'pending',
    backend: '',
    model: '',
    reasoning: '',
    externalSessionId: '',
    launchState: 'awaiting_backend',
    transcriptAvailability: 'unavailable',
    transcriptPath: '',
    messages: [],
    continuation: NetrunnerContinuationCapabilityRecord(
      supported: false,
      mode: 'awaiting_backend',
      reason: 'Choose and launch a backend first.',
    ),
  );
}

NetrunnerThreadSnapshot _kimiThread() {
  return const NetrunnerThreadSnapshot(
    sessionId: 405,
    localId: 19,
    projectId: 2,
    status: 'in_progress',
    backend: 'kimi-code',
    model: 'kimi-k2.5',
    reasoning: 'default',
    externalSessionId: 'kimi-thread-405',
    launchState: 'linked',
    transcriptAvailability: 'metadata_only',
    transcriptPath: '',
    messages: [],
    continuation: NetrunnerContinuationCapabilityRecord(
      supported: false,
      mode: 'unsupported',
      reason:
          'Kimi resume needs its project-scoped MCP config; direct continuation is not wired yet.',
    ),
  );
}

class _FakeNetrunnerThreadRepository implements NetrunnerThreadRepository {
  _FakeNetrunnerThreadRepository(this.thread);

  final NetrunnerThreadSnapshot thread;
  final sentMessages = <String>[];

  @override
  Future<NetrunnerThreadSnapshot> loadThread(int sessionId) async => thread;

  @override
  Future<NetrunnerContinuationResult> sendFollowUp(
    int sessionId,
    String message,
  ) async {
    sentMessages.add(message);
    return NetrunnerContinuationResult(
      status: 'started',
      sessionId: sessionId,
      backend: thread.backend,
      externalSessionId: thread.externalSessionId,
      processId: 123,
      message: 'Follow-up submitted.',
    );
  }
}
