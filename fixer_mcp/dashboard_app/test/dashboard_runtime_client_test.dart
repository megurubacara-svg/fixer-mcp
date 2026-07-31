import 'package:fixer_dashboard_app/src/dashboard_runtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the conflict-free dashboard API port by default', () {
    expect(
      DashboardRuntimeClient.defaultDashboardBaseUrl,
      'http://127.0.0.1:18090',
    );
  });
}
