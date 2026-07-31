import 'dart:io';

import 'package:fixer_dashboard_server/src/auth/client_auth_middleware.dart';
import 'package:fixer_dashboard_server/src/orders/client_order_endpoint.dart';
import 'package:test/test.dart';

void main() {
  test('client order endpoint requires the client scope', () {
    expect(
      ClientOrderEndpoint().requiredScopes,
      ClientAuthMiddleware.requiredScopes,
    );
  });

  test('order and revision models declare the client surface schema', () {
    final order = File('lib/src/models/order.spy.yaml').readAsStringSync();
    final revision = File(
      'lib/src/models/revision.spy.yaml',
    ).readAsStringSync();
    final migration = File(
      'migrations/20260721124115992-client-orders/migration.sql',
    ).readAsStringSync();

    expect(order, contains('class: Order'));
    expect(order, contains('table: order'));
    expect(order, contains('clientId: UuidValue'));
    expect(revision, contains('class: Revision'));
    expect(revision, contains('table: revision'));
    expect(revision, contains('revisionNumber: int'));
    expect(migration, contains('CREATE TABLE "order"'));
    expect(migration, contains('CREATE TABLE "revision"'));
    expect(migration, contains('revision_order_number_idx'));
  });

  test('generated server and client protocols expose order CRUD', () {
    final serverEndpoints = File(
      'lib/src/generated/endpoints.dart',
    ).readAsStringSync();
    final client = File(
      '../dashboard_client/lib/src/protocol/client.dart',
    ).readAsStringSync();

    for (final method in [
      'createOrder',
      'listOrders',
      'getOrder',
      'updateOrder',
      'deleteOrder',
      'createRevision',
      'listRevisions',
      'getRevision',
      'updateRevision',
      'deleteRevision',
    ]) {
      expect(serverEndpoints, contains("'$method'"), reason: method);
      expect(client, contains('$method('), reason: method);
    }
    expect(client, contains('class EndpointClientOrder'));
  });

  test('endpoint enforces non-empty order and revision text', () {
    final source = File(
      'lib/src/orders/client_order_endpoint.dart',
    ).readAsStringSync();

    expect(source, contains("throw ArgumentError('\$field is required')"));
    expect(source, contains("status: 'draft'"));
    expect(source, contains('t.clientId.equals(clientId)'));
    expect(source, contains('await Revision.db.deleteWhere'));
  });
}
