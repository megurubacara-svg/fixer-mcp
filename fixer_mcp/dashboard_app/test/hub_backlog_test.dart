import 'package:fixer_dashboard_app/src/dashboard_runtime_client.dart';
import 'package:fixer_dashboard_app/src/hub/backlog/backlog_models.dart';
import 'package:fixer_dashboard_app/src/hub/backlog/backlog_panel.dart';
import 'package:fixer_dashboard_app/src/hub/backlog/backlog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders structured items and canonical backlog documents', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 900,
          child: BacklogPanel(
            repository: FakeBacklogRepository(_snapshot),
            projectId: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Structured backlog items'), findsOneWidget);
    expect(find.text('Promote the backlog panel'), findsOneWidget);
    expect(find.text('Status: open'), findsOneWidget);
    expect(find.text('Canonical backlog documents'), findsOneWidget);
    expect(find.text('Backlog Canon'), findsOneWidget);

    await tester.tap(find.text('Backlog Canon'));
    await tester.pumpAndSettle();
    expect(find.text('# Current backlog\nCanonical notes.'), findsOneWidget);
  });

  testWidgets('shows a useful empty state when both sources are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BacklogPanel(
          repository: FakeBacklogRepository(
            const ProjectBacklogSnapshot(
              project: BacklogProjectRecord(id: 1, name: 'Empty', cwd: '/tmp'),
              items: <BacklogItemRecord>[],
              documents: <BacklogDocumentRecord>[],
            ),
          ),
          projectId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No backlog yet'), findsOneWidget);
    expect(
      find.text(
        'This project has no structured backlog items or canonical backlog documents.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows an error state with retry affordance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BacklogPanel(
          repository: FakeBacklogRepository.failure(),
          projectId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load backlog'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  test('bridge repository requests the project backlog endpoint', () async {
    final runtimeClient = _RecordingRuntimeClient();
    final repository = BridgeBacklogRepository(runtimeClient: runtimeClient);
    final snapshot = await repository.loadProjectBacklog(7);

    expect(runtimeClient.requestedPath, '/api/projects/7/backlog');
    expect(snapshot.project.name, 'Fixer MCP');
    expect(snapshot.items.single.title, 'Promote the backlog panel');
    expect(snapshot.documents.single.docType, 'backlog');
  });
}

class FakeBacklogRepository implements BacklogRepository {
  FakeBacklogRepository(this.snapshot) : error = null;

  FakeBacklogRepository.failure()
    : snapshot = null,
      error = StateError('bridge unavailable');

  final ProjectBacklogSnapshot? snapshot;
  final Object? error;

  @override
  Future<ProjectBacklogSnapshot> loadProjectBacklog(int projectId) {
    final error = this.error;
    if (error != null) return Future<ProjectBacklogSnapshot>.error(error);
    return Future<ProjectBacklogSnapshot>.value(snapshot!);
  }
}

class _RecordingRuntimeClient extends DashboardRuntimeClient {
  _RecordingRuntimeClient() : super(dashboardBaseUrl: 'http://unused');

  String? requestedPath;

  @override
  Future<Map<String, dynamic>> readDashboardJson(String path) async {
    requestedPath = path;
    return _snapshotJson;
  }
}

const _snapshot = ProjectBacklogSnapshot(
  project: BacklogProjectRecord(id: 1, name: 'Fixer MCP', cwd: '/tmp/fixer'),
  items: <BacklogItemRecord>[
    BacklogItemRecord(
      id: 7,
      projectId: 1,
      title: 'Promote the backlog panel',
      description: 'Expose structured work in the dashboard.',
      status: 'open',
      priority: 'high',
      createdAt: '2026-07-01',
      updatedAt: '2026-07-02',
    ),
  ],
  documents: <BacklogDocumentRecord>[
    BacklogDocumentRecord(
      id: 3,
      title: 'Backlog Canon',
      docType: 'backlog',
      contentPreview: '# Current backlog\nCanonical notes.',
      parentDocId: 0,
      level: 0,
      slug: 'backlog',
      path: 'fixer-mcp/backlog',
      status: 'current',
    ),
  ],
);

final _snapshotJson = <String, dynamic>{
  'project': {'id': 1, 'name': 'Fixer MCP', 'cwd': '/tmp/fixer'},
  'items': [
    {
      'id': 7,
      'project_id': 1,
      'title': 'Promote the backlog panel',
      'description': 'Expose structured work in the dashboard.',
      'status': 'open',
      'priority': 'high',
      'created_at': '2026-07-01',
      'updated_at': '2026-07-02',
    },
  ],
  'documents': [
    {
      'id': 3,
      'title': 'Backlog Canon',
      'doc_type': 'backlog',
      'content_preview': '# Current backlog\nCanonical notes.',
      'level': 0,
      'slug': 'backlog',
      'path': 'fixer-mcp/backlog',
      'status': 'current',
    },
  ],
};
