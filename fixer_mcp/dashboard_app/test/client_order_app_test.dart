import 'package:fixer_dashboard_app/src/client_order_app.dart';
import 'package:fixer_dashboard_app/src/client_order_repository.dart';
import 'package:fixer_dashboard_app/src/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryClientSessionStore implements ClientSessionStore {
  ClientSession? session;

  @override
  Future<ClientSession?> read() async => session;

  @override
  Future<void> write(ClientSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

class _FakeClientOrderRepository implements ClientOrderRepository {
  _FakeClientOrderRepository()
    : _orders = [
        ClientOrderRecord(
          id: 7,
          title: 'Website refresh',
          description: 'Refresh the public marketing site.',
          status: 'draft',
          createdAt: DateTime(2026, 7, 20),
          updatedAt: DateTime(2026, 7, 20),
        ),
      ];

  final List<ClientOrderRecord> _orders;
  bool loggedOut = false;
  int? lastBudgetCents;
  String? lastRevision;

  @override
  Future<ClientIdentity> login({
    required String email,
    required String password,
  }) async {
    return const ClientIdentity(
      clientId: 'client-1',
      email: 'manager@example.com',
      displayName: 'Maya Manager',
    );
  }

  @override
  Future<List<ClientOrderRecord>> loadOrders() async => List.of(_orders);

  @override
  Future<ClientOrderRecord> createOrder({
    required String title,
    required String description,
  }) async {
    final order = ClientOrderRecord(
      id: 8,
      title: title,
      description: description,
      status: 'draft',
      createdAt: DateTime(2026, 7, 21),
      updatedAt: DateTime(2026, 7, 21),
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<ClientOrderRecord> createOrderWithBudget({
    required String projectDescription,
    required int budgetCents,
  }) async {
    lastBudgetCents = budgetCents;
    final order = ClientOrderRecord(
      id: 8,
      title: projectDescription.split('\n').first,
      description: projectDescription,
      status: 'pending',
      createdAt: DateTime(2026, 7, 21),
      updatedAt: DateTime(2026, 7, 21),
      budgetCents: budgetCents,
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<ClientOrderDetail> loadOrderDetail(int orderId) async {
    final order = _orders.firstWhere((candidate) => candidate.id == orderId);
    return ClientOrderDetail(
      order: order,
      latestResultSummary: 'The Architect completed the first pass.',
      revisions: const [],
    );
  }

  @override
  Future<ClientRevisionRecord> submitRevision({
    required int orderId,
    required String description,
  }) async {
    lastRevision = description;
    return ClientRevisionRecord(
      id: 3,
      orderId: orderId,
      revisionNumber: 1,
      description: description,
      status: 'submitted',
      createdAt: DateTime(2026, 7, 21),
      updatedAt: DateTime(2026, 7, 21),
    );
  }

  @override
  void logout() => loggedOut = true;
}

class _RestoringFakeClientOrderRepository extends _FakeClientOrderRepository
    implements ClientSessionRestorer {
  @override
  Future<ClientIdentity?> restoreSession() async => const ClientIdentity(
    clientId: 'client-1',
    email: 'manager@example.com',
    displayName: 'Maya Manager',
  );
}

class _RestoringArchitectOrderRepository extends _FakeClientOrderRepository
    implements ClientSessionRestorer {
  @override
  Future<ClientIdentity?> restoreSession() async => const ClientIdentity(
    clientId: 'architect-1',
    email: 'architect@example.com',
    displayName: 'Architect',
  );
}

void main() {
  test('client session storage round-trips identity and token', () async {
    final store = _MemoryClientSessionStore();
    const session = ClientSession(
      identity: ClientIdentity(
        clientId: 'client-1',
        email: 'manager@example.com',
        displayName: 'Maya Manager',
      ),
      sessionToken: 'session-token',
    );

    await store.write(session);

    expect(await store.read(), same(session));
    expect((await store.read())?.identity.displayName, 'Maya Manager');
    expect((await store.read())?.sessionToken, 'session-token');

    await store.clear();
    expect(await store.read(), isNull);
  });

  test(
    'shared preferences store writes and clears the full client session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesClientSessionStore(
        preferences: preferences,
      );
      const session = ClientSession(
        identity: ClientIdentity(
          clientId: 'client-1',
          email: 'manager@example.com',
          displayName: 'Maya Manager',
        ),
        sessionToken: 'session-token',
      );

      await store.write(session);

      expect((await store.read())?.identity.email, 'manager@example.com');
      expect((await store.read())?.sessionToken, 'session-token');
      expect(
        preferences.getString(SharedPreferencesClientSessionStore.storageKey),
        contains('session-token'),
      );

      await store.clear();
      expect(
        preferences.getString(SharedPreferencesClientSessionStore.storageKey),
        isNull,
      );
    },
  );

  test(
    'client session auth provider exposes and clears a bearer token',
    () async {
      final provider = ClientSessionAuthProvider();

      expect(await provider.authHeaderValue, isNull);
      provider.setToken('session-token');
      expect(await provider.authHeaderValue, 'Bearer session-token');
      expect(provider.isAuthenticated, isTrue);

      provider.clear();
      expect(await provider.authHeaderValue, isNull);
      expect(provider.isAuthenticated, isFalse);
    },
  );

  test(
    'client session auth provider restores the persisted bearer token',
    () async {
      final store = _MemoryClientSessionStore();
      await store.write(
        const ClientSession(
          identity: ClientIdentity(
            clientId: 'client-1',
            email: 'manager@example.com',
            displayName: 'Maya Manager',
          ),
          sessionToken: 'restored-token',
        ),
      );
      final provider = ClientSessionAuthProvider(sessionStore: store);

      expect(await provider.authHeaderValue, 'Bearer restored-token');
      expect(provider.isAuthenticated, isTrue);
    },
  );

  testWidgets('client can sign in, browse orders, and create a brief', (
    tester,
  ) async {
    final repository = _FakeClientOrderRepository();
    await tester.pumpWidget(ClientOrderApp(repository: repository));

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'manager@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Maya Manager'), findsOneWidget);
    await tester.tap(find.text('Orders').first);
    await tester.pumpAndSettle();
    expect(find.text('Website refresh'), findsOneWidget);

    await tester.tap(find.text('Website refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Latest result from your Architect'), findsOneWidget);
    expect(
      find.text('The Architect completed the first pass.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Please tighten the mobile spacing.',
    );
    await tester.ensureVisible(find.text('Submit revision'));
    await tester.tap(find.text('Submit revision'));
    await tester.pumpAndSettle();
    expect(repository.lastRevision, 'Please tighten the mobile spacing.');
    await tester.pump(const Duration(seconds: 5));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('New order'));
    await tester.pumpAndSettle();
    expect(find.text('Create a product brief'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Make checkout faster for returning customers.',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '2500');
    await tester.ensureVisible(find.text('Create order'));
    await tester.tap(find.text('Create order'));
    await tester.pumpAndSettle();

    expect(repository.lastBudgetCents, 250000);
    expect(
      find.text('Make checkout faster for returning customers.'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('client can switch the login language', (tester) async {
    await tester.pumpWidget(
      ClientOrderApp(repository: _FakeClientOrderRepository()),
    );
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Введите корректный email'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('language-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('client restores the persisted login language', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppLocaleController.preferenceKey: 'ru',
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = AppLocaleController(preferences: preferences);

    await tester.pumpWidget(
      ClientOrderApp(
        repository: _FakeClientOrderRepository(),
        localeController: controller,
      ),
    );
    await controller.ready;
    await tester.pumpAndSettle();

    expect(find.text('С возвращением'), findsOneWidget);
    await controller.useSystemLocale();
    controller.dispose();
  });

  testWidgets('client restores a valid persisted session on startup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ClientOrderApp(repository: _RestoringFakeClientOrderRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('client-dashboard')), findsOneWidget);
    expect(find.text('Good morning, Maya Manager'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('architect restores the Architect Workspace on startup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ClientOrderApp(repository: _RestoringArchitectOrderRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('client-dashboard')), findsOneWidget);
    expect(find.text('Architect Workspace'), findsOneWidget);
    expect(find.text('Client Factory'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });
}
