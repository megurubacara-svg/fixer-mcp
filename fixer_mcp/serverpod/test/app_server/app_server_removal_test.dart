import 'dart:io';

import 'package:test/test.dart';

void _expectNoFiles(String path) {
  final directory = Directory(path);
  final files = directory.existsSync()
      ? directory.listSync(recursive: true).whereType<File>().toList()
      : const <File>[];
  expect(files, isEmpty, reason: path);
}

void main() {
  test('legacy App Server cockpit is absent from runtime registration', () {
    final endpoints = File(
      'lib/src/generated/endpoints.dart',
    ).readAsStringSync();
    final protocol = File('lib/src/generated/protocol.dart').readAsStringSync();
    final protocolMap = File(
      'lib/src/generated/protocol.yaml',
    ).readAsStringSync();

    _expectNoFiles('lib/src/app_server');
    _expectNoFiles('lib/src/generated/app_server');
    expect(endpoints, isNot(contains("'appServer'")));
    expect(endpoints, isNot(contains('AppServerEndpoint')));
    expect(protocol, isNot(contains("export 'app_server/")));
    expect(protocol, isNot(contains("name: 'app_thread'")));
    expect(protocol, isNot(contains("name: 'app_event'")));
    expect(protocolMap, isNot(contains('appServer:')));
  });

  test('legacy Flutter cockpit implementation is removed', () {
    const legacyFiles = <String>[
      '../dashboard_app/lib/src/app_server_cockpit.dart',
      '../dashboard_app/lib/src/app_server_models.dart',
      '../dashboard_app/lib/src/app_server_repository.dart',
      '../dashboard_app/test/app_server_cockpit_test.dart',
    ];

    for (final path in legacyFiles) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });

  test('active dashboard sources contain no App Server cockpit references', () {
    final clientProtocolDirectory = Directory(
      '../dashboard_client/lib/src/protocol/app_server',
    );
    final activeFiles = <String>[
      '../dashboard_app/lib/src/client_order_app.dart',
      '../dashboard_client/lib/src/protocol/client.dart',
      '../dashboard_client/lib/src/protocol/protocol.dart',
    ];
    final retiredReferences = <String>[
      'AppServerRepository',
      'BridgeAppServerRepository',
      'EndpointAppServer',
      "'appServer'",
      'protocol/app_server/',
      "export 'app_server/",
    ];

    _expectNoFiles(clientProtocolDirectory.path);
    for (final path in activeFiles) {
      final contents = File(path).readAsStringSync();
      for (final reference in retiredReferences) {
        expect(
          contents,
          isNot(contains(reference)),
          reason: '$path: $reference',
        );
      }
    }
  });
}
