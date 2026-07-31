import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('declares the client order flow endpoints and payload fields', () {
    final source = File(
      'lib/src/orders/order_endpoint.dart',
    ).readAsStringSync();

    expect(source, contains('Future<int> createOrder'));
    expect(source, contains('extends ClientProtectedEndpoint'));
    expect(source, contains('required String clientId'));
    expect(source, contains('required String projectDescription'));
    expect(source, contains('required int budgetCents'));
    expect(source, contains('Future<List<Map<String, dynamic>>> listOrders'));
    expect(source, contains("'order_id'"));
    expect(source, contains("'project_id'"));
    expect(source, contains("'created_at'"));
    expect(source, contains('Future<int> submitRevision'));
    expect(source, contains('List<String>? attachmentUrls'));
    expect(source, contains('Future<Map<String, dynamic>> orderStatus'));
    expect(source, contains("'latest_result_summary'"));
    expect(source, contains("'revisions'"));
    expect(source, contains("order.status = 'pending'"));
    expect(source, contains('revisions.first.resultSummary'));
  });

  test('declares the order-flow persistence fields', () {
    final order = File('lib/src/models/order.spy.yaml').readAsStringSync();
    final revision = File(
      'lib/src/models/revision.spy.yaml',
    ).readAsStringSync();

    expect(order, contains('projectDescription: String'));
    expect(order, contains('budgetCents: int'));
    expect(order, contains('assignedProjectId: int?'));
    expect(revision, contains('revisionText: String'));
    expect(revision, contains('attachmentUrls: List<String>?'));
    expect(revision, contains('resultSummary: String?'));
  });

  test('ships an in-place migration for existing order data', () {
    final migration = File(
      'migrations/20260721175443919-client-order-flow/migration.sql',
    ).readAsStringSync();

    expect(migration, contains('ALTER TABLE "order"'));
    expect(migration, contains('"projectDescription" text NOT NULL'));
    expect(migration, contains('"budgetCents" bigint NOT NULL'));
    expect(migration, contains('"assignedProjectId" bigint'));
    expect(migration, contains('ALTER TABLE "revision"'));
    expect(migration, contains('"revisionText" text NOT NULL'));
    expect(migration, contains('"attachmentUrls" json'));
    expect(migration, isNot(contains('DROP TABLE "order"')));
    expect(migration, isNot(contains('DROP TABLE "revision"')));
  });
}
