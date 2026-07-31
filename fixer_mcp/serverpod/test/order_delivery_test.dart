import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('registers architect order delivery actions', () {
    final endpoints = File(
      'lib/src/generated/endpoints.dart',
    ).readAsStringSync();

    expect(endpoints, contains("'orderDelivery'"));
    expect(endpoints, contains("'mergeOrder'"));
    expect(endpoints, contains("'approveOrder'"));
    expect(endpoints, contains("'rejectOrder'"));
    expect(endpoints, contains("'resultSummary'"));
    expect(endpoints, contains("resultSummary: params['resultSummary']"));
  });

  test('delivery endpoint updates both order and latest revision', () {
    final source = File(
      'lib/src/orders/order_delivery_endpoint.dart',
    ).readAsStringSync();

    expect(source, contains("order.status = 'completed'"));
    expect(source, contains("revision.status = 'completed'"));
    expect(source, contains('required String resultSummary'));
    expect(
      source,
      contains('revision.resultSummary = normalizedResultSummary'),
    );
    expect(source, contains("order.status = 'rejected'"));
    expect(source, contains("revision.status = 'rejected'"));
    expect(source, contains("'order-updates-\$orderId'"));
    expect(source, contains('Future<Order> approveOrder'));
  });

  test('requires a non-empty result summary before delivery', () {
    final source = File(
      'lib/src/orders/order_delivery_endpoint.dart',
    ).readAsStringSync();

    expect(source, contains('normalizedResultSummary = _requiredText('));
    expect(source, contains("      'resultSummary',"));
    expect(source, contains("throw ArgumentError('\$field is required')"));
  });
}
