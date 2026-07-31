import 'package:fixer_dashboard_app/src/hub/docs/documents_explorer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  const launch = HubDocument(
    id: 2,
    parentDocId: 1,
    level: 1,
    slug: 'launch',
    path: 'runtime/launch',
    status: 'draft',
    title: 'Launch',
    docType: 'contract',
    content: '# Launch\n\nDetails',
  );
  const snapshot = ProjectDocumentsSnapshot(
    projectName: 'Fixer MCP',
    totalDocs: 2,
    roots: [
      HubDocument(
        id: 1,
        level: 0,
        slug: 'runtime',
        path: 'runtime',
        status: 'current',
        title: 'Runtime',
        docType: 'architecture',
        content: '# Runtime',
        children: [launch],
      ),
    ],
  );

  testWidgets('renders hierarchy and opens selected Markdown document', (
    tester,
  ) async {
    HubDocument? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentsExplorer(
            snapshot: snapshot,
            onDocumentSelected: (document) => selected = document,
          ),
        ),
      ),
    );

    expect(find.text('Project documents'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Runtime'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Launch'), findsOneWidget);

    await tester.tap(find.text('Launch'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(selected?.path, 'runtime/launch');
    expect(find.byType(DocumentMarkdownDialog), findsOneWidget);
    expect(find.byType(MarkdownWidget), findsWidgets);
    expect(find.text('draft'), findsWidgets);

    Navigator.of(tester.element(find.byType(DocumentMarkdownDialog))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  test('parses the API tree payload and preserves nested content', () {
    final parsed = ProjectDocumentsSnapshot.fromJson({
      'project': {'name': 'Fixer MCP'},
      'total_docs': 2,
      'roots': [
        {
          'id': 1,
          'level': 0,
          'slug': 'runtime',
          'path': 'runtime',
          'status': 'current',
          'title': 'Runtime',
          'doc_type': 'architecture',
          'content': '# Runtime',
          'children': [
            {
              'id': 2,
              'parent_doc_id': 1,
              'level': 1,
              'slug': 'launch',
              'path': 'runtime/launch',
              'status': 'draft',
              'title': 'Launch',
              'doc_type': 'contract',
              'content': '# Launch\n\nDetails',
              'children': [],
            },
          ],
        },
      ],
    });

    expect(parsed.projectName, 'Fixer MCP');
    expect(parsed.roots.single.children.single.content, '# Launch\n\nDetails');
    expect(parsed.roots.single.children.single.parentDocId, 1);
  });
}
