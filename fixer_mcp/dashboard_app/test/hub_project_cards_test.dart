import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixer_dashboard_app/src/hub/project_cards/project_cards.dart';

void main() {
  test('parses explicit wave count and activity timestamp', () {
    final card = HubProjectCard.fromJson({
      'project': {'id': 7, 'name': 'Fixer MCP', 'cwd': '/workspace/fixer-mcp'},
      'active_wave_count': 3,
      'last_activity_at': '2026-07-23T12:30:00Z',
    });

    expect(card.projectId, 7);
    expect(card.name, 'Fixer MCP');
    expect(card.activeWaveCount, 3);
    expect(card.lastActivityAt, '2026-07-23T12:30:00Z');
  });

  test('sorts newest activity first and falls back to project id', () {
    final cards = HubProjectCard.sortByActivity([
      const HubProjectCard(
        projectId: 4,
        name: 'No activity',
        cwd: '/tmp/4',
        activeWaveCount: 0,
        lastActivityAt: '',
      ),
      const HubProjectCard(
        projectId: 9,
        name: 'Older',
        cwd: '/tmp/9',
        activeWaveCount: 1,
        lastActivityAt: '2026-07-23T08:00:00Z',
      ),
      const HubProjectCard(
        projectId: 2,
        name: 'Newer',
        cwd: '/tmp/2',
        activeWaveCount: 2,
        lastActivityAt: '2026-07-23T09:00:00Z',
      ),
    ]);

    expect(cards.map((card) => card.projectId), [2, 9, 4]);
  });

  testWidgets('renders active waves and timestamp instead of P/I/R', (
    tester,
  ) async {
    var tappedProjectId = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectCards(
          projects: const [
            HubProjectCard(
              projectId: 7,
              name: 'Fixer MCP',
              cwd: '/workspace/fixer-mcp',
              activeWaveCount: 2,
              lastActivityAt: '2026-07-23T12:30:00Z',
            ),
          ],
          onProjectTap: (projectId) => tappedProjectId = projectId,
        ),
      ),
    );

    expect(find.text('2 active waves'), findsOneWidget);
    expect(find.text('2026-07-23T12:30:00Z'), findsOneWidget);
    expect(find.textContaining('P '), findsNothing);
    expect(find.textContaining('I '), findsNothing);
    expect(find.textContaining('R '), findsNothing);

    await tester.tap(find.text('Fixer MCP'));
    expect(tappedProjectId, 7);
  });
}
