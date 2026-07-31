import 'package:fixer_dashboard_app/src/dashboard_runtime_client.dart';
import 'package:fixer_dashboard_app/src/hub/skills/skills_manager.dart';
import 'package:fixer_dashboard_app/src/hub/skills/skills_models.dart';
import 'package:fixer_dashboard_app/src/hub/skills/skills_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bridge repository uses scoped list, detail, and edit routes', () async {
    final client = _FakeRuntimeClient();
    final repository = BridgeSkillsRepository(runtimeClient: client);

    final catalog = await repository.loadSkills(7);
    final detail = await repository.loadSkill(7, 'agents', 'init-fixer');
    final updated = await repository.updateSkill(
      7,
      'init-fixer',
      rootId: 'agents',
      content: '# Updated',
    );

    expect(catalog.projectName, 'Fixer MCP');
    expect(catalog.skills.single.locations.single.rootId, 'agents');
    expect(detail.content, contains('Original'));
    expect(updated.content, '# Updated');
    expect(client.readPaths, [
      '/api/projects/7/skills',
      '/api/projects/7/skills/agents/init-fixer',
    ]);
    expect(client.postPaths, ['/api/actions/projects/7/skills/init-fixer']);
    expect(client.lastPostBody, {'root_id': 'agents', 'content': '# Updated'});
  });

  testWidgets('lists, previews, switches, and edits managed skills', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeSkillsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SkillsManagerScreen(projectId: 2, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fixer MCP skills'), findsOneWidget);
    expect(find.text('init-fixer'), findsWidgets);
    expect(find.text('run-netrunner-wave'), findsWidgets);
    expect(find.byKey(const ValueKey('skill-relative-path')), findsOneWidget);
    expect(find.text('Initialize Fixer'), findsWidgets);
    expect(repository.loaded, [('agents', 'init-fixer')]);

    await tester.tap(find.byKey(const ValueKey('skill-run-netrunner-wave')));
    await tester.pumpAndSettle();
    expect(repository.loaded.last, ('agents', 'run-netrunner-wave'));
    expect(find.text('Run a parallel wave.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('skill-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skill-editor')), findsOneWidget);
    const edited = '''---
name: run-netrunner-wave
description: Updated wave skill.
---
# Updated body
''';
    await tester.enterText(find.byKey(const ValueKey('skill-editor')), edited);
    await tester.tap(find.byKey(const ValueKey('skill-save')));
    await tester.pumpAndSettle();

    expect(repository.savedContent, edited);
    expect(find.text('Skill saved'), findsOneWidget);
    expect(find.byKey(const ValueKey('skill-markdown')), findsOneWidget);

    // markdown_widget uses a short visibility-detector timer. Dispose the
    // renderer and let that timer drain before the binding checks invariants.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('shows an explicit empty state', (tester) async {
    final repository = _FakeSkillsRepository(empty: true);
    await tester.pumpWidget(
      MaterialApp(
        home: SkillsManagerScreen(projectId: 2, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No managed Fixer skills found'), findsOneWidget);
    expect(find.text('Select a managed skill'), findsOneWidget);
  });
}

class _FakeRuntimeClient extends DashboardRuntimeClient {
  final readPaths = <String>[];
  final postPaths = <String>[];
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> readDashboardJson(String path) async {
    readPaths.add(path);
    if (path.endsWith('/skills')) {
      return {
        'project': {'id': 7, 'name': 'Fixer MCP', 'cwd': '/tmp/fixer'},
        'skills': [_summaryJson()],
      };
    }
    return {..._summaryJson(), 'root_id': 'agents', 'content': '# Original'};
  }

  @override
  Future<Map<String, dynamic>> postDashboardJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    postPaths.add(path);
    lastPostBody = payload;
    return {
      ..._summaryJson(),
      'root_id': payload['root_id'],
      'content': payload['content'],
    };
  }

  Map<String, dynamic> _summaryJson() => {
    'name': 'init-fixer',
    'description': 'Initialize Fixer',
    'locations': [
      {
        'root_id': 'agents',
        'root_label': 'Agents',
        'relative_path': '.agents/skills/init-fixer/SKILL.md',
      },
    ],
    'related_skills': ['run-netrunner-wave'],
    'relative_path': '.agents/skills/init-fixer/SKILL.md',
  };
}

class _FakeSkillsRepository implements SkillsRepository {
  _FakeSkillsRepository({this.empty = false});

  final bool empty;
  final loaded = <(String, String)>[];
  String? savedContent;

  List<ManagedSkillSummary> get _skills => [
    _summary(
      'init-fixer',
      'Initialize Fixer',
      related: const ['run-netrunner-wave'],
    ),
    _summary('run-netrunner-wave', 'Run parallel workers'),
  ];

  @override
  Future<ProjectSkillsCatalog> loadSkills(int projectId) async =>
      ProjectSkillsCatalog(
        projectName: 'Fixer MCP',
        skills: empty ? const [] : _skills,
      );

  @override
  Future<ManagedSkillDetail> loadSkill(
    int projectId,
    String rootId,
    String name,
  ) async {
    loaded.add((rootId, name));
    final summary = _skills.firstWhere((skill) => skill.name == name);
    return ManagedSkillDetail(
      summary: summary,
      rootId: rootId,
      relativePath: '.agents/skills/$name/SKILL.md',
      content: name == 'init-fixer'
          ? '# Initialize Fixer\n\nUse the wave skill.'
          : '# Run a parallel wave.\n',
    );
  }

  @override
  Future<ManagedSkillDetail> updateSkill(
    int projectId,
    String name, {
    required String rootId,
    required String content,
  }) async {
    savedContent = content;
    return ManagedSkillDetail(
      summary: _summary(name, 'Updated wave skill.'),
      rootId: rootId,
      relativePath: '.agents/skills/$name/SKILL.md',
      content: content,
    );
  }

  ManagedSkillSummary _summary(
    String name,
    String description, {
    List<String> related = const [],
  }) => ManagedSkillSummary(
    name: name,
    description: description,
    locations: [
      SkillLocation(
        rootId: 'agents',
        rootLabel: 'Agents',
        relativePath: '.agents/skills/$name/SKILL.md',
      ),
    ],
    relatedSkills: related,
  );
}
