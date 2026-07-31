import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixer_dashboard_client/fixer_dashboard_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientIdentity {
  const ClientIdentity({
    required this.clientId,
    required this.email,
    required this.displayName,
  });

  factory ClientIdentity.fromJson(Map<String, dynamic> json) {
    return ClientIdentity(
      clientId: _requiredString(json, 'clientId'),
      email: _requiredString(json, 'email'),
      displayName: _requiredString(json, 'displayName'),
    );
  }

  final String clientId;
  final String email;
  final String displayName;

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'email': email,
    'displayName': displayName,
  };
}

/// The complete client session persisted between application launches.
class ClientSession {
  const ClientSession({required this.identity, required this.sessionToken});

  factory ClientSession.fromJson(Map<String, dynamic> json) {
    return ClientSession(
      identity: ClientIdentity.fromJson(json),
      sessionToken: _requiredString(json, 'sessionToken'),
    );
  }

  final ClientIdentity identity;
  final String sessionToken;

  Map<String, dynamic> toJson() => {
    ...identity.toJson(),
    'sessionToken': sessionToken,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or empty $key');
  }
  return value;
}

abstract interface class ClientSessionStore {
  Future<ClientSession?> read();

  Future<void> write(ClientSession session);

  Future<void> clear();
}

/// SharedPreferences-backed storage for the client identity and session token.
///
/// The store is injected into the repository and provider so tests can use a
/// deterministic in-memory implementation without touching platform storage.
class SharedPreferencesClientSessionStore implements ClientSessionStore {
  SharedPreferencesClientSessionStore({SharedPreferences? preferences})
    : _preferences = preferences != null
          ? Future<SharedPreferences>.value(preferences)
          : SharedPreferences.getInstance();

  static const storageKey = 'fixer_dashboard.client_session';

  final Future<SharedPreferences> _preferences;

  @override
  Future<ClientSession?> read() async {
    final raw = (await _preferences).getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Session is not JSON');
      return ClientSession.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      await clear();
      return null;
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(ClientSession session) async {
    await (await _preferences).setString(
      storageKey,
      jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    await (await _preferences).remove(storageKey);
  }
}

class ClientOrderRecord {
  const ClientOrderRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.budgetCents = 0,
    this.latestResultSummary,
  });

  final int? id;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int budgetCents;
  final String? latestResultSummary;

  String get projectDescription => description;

  ClientOrderRecord copyWith({String? status, String? latestResultSummary}) {
    return ClientOrderRecord(
      id: id,
      title: title,
      description: description,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      budgetCents: budgetCents,
      latestResultSummary: latestResultSummary ?? this.latestResultSummary,
    );
  }
}

class ClientRevisionRecord {
  const ClientRevisionRecord({
    required this.id,
    required this.orderId,
    required this.revisionNumber,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resultSummary,
  });

  final int? id;
  final int orderId;
  final int revisionNumber;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resultSummary;
}

class ClientOrderDetail {
  const ClientOrderDetail({
    required this.order,
    required this.revisions,
    this.latestResultSummary,
  });

  final ClientOrderRecord order;
  final List<ClientRevisionRecord> revisions;
  final String? latestResultSummary;
}

abstract interface class ClientOrderRepository {
  Future<ClientIdentity> login({
    required String email,
    required String password,
  });

  Future<List<ClientOrderRecord>> loadOrders();

  Future<ClientOrderRecord> createOrder({
    required String title,
    required String description,
  });

  /// Uses the client-facing intake endpoint when a budget is available.
  ///
  /// The default keeps older repository fakes source-compatible while the
  /// bridge can send the budget to the newer Serverpod endpoint.
  Future<ClientOrderRecord> createOrderWithBudget({
    required String projectDescription,
    required int budgetCents,
  }) {
    return createOrder(
      title: _titleFromDescription(projectDescription),
      description: projectDescription,
    );
  }

  Future<ClientOrderDetail> loadOrderDetail(int orderId) async {
    final orders = await loadOrders();
    for (final order in orders) {
      if (order.id == orderId) {
        return ClientOrderDetail(order: order, revisions: const []);
      }
    }
    throw StateError('Order not found');
  }

  Future<ClientRevisionRecord> submitRevision({
    required int orderId,
    required String description,
  }) {
    throw UnimplementedError('This repository does not support revisions.');
  }

  void logout();
}

/// Optional repository capability for restoring a persisted client session.
///
/// Keeping this separate preserves compatibility with lightweight repository
/// fakes that only implement the original order operations.
abstract interface class ClientSessionRestorer {
  Future<ClientIdentity?> restoreSession();
}

/// Supplies the token to Serverpod and restores it from the session store.
class ClientSessionAuthProvider implements ClientAuthKeyProvider {
  ClientSessionAuthProvider({this.sessionStore});

  final ClientSessionStore? sessionStore;
  String? _token;
  Future<void>? _initialization;
  int _stateVersion = 0;

  bool get isAuthenticated => _token != null;

  /// Loads the stored token before the first authenticated request.
  Future<void> initialize() {
    return _initialization ??= _loadStoredToken();
  }

  Future<void> _loadStoredToken() async {
    final store = sessionStore;
    if (store == null) return;
    final version = _stateVersion;
    final session = await store.read();
    if (version == _stateVersion) {
      _token = session?.sessionToken;
    }
  }

  void setToken(String token) {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'must not be empty');
    }
    _stateVersion++;
    _token = token;
  }

  void clear() {
    _stateVersion++;
    _token = null;
  }

  @override
  Future<String?> get authHeaderValue async {
    await initialize();
    final token = _token;
    return token == null ? null : wrapAsBearerAuthHeaderValue(token);
  }
}

class BridgeClientOrderRepository
    implements ClientOrderRepository, ClientSessionRestorer {
  BridgeClientOrderRepository({
    String? serverpodBaseUrl,
    Client? client,
    ClientSessionStore? sessionStore,
    ClientSessionAuthProvider? authProvider,
  }) : _sessionStore =
           sessionStore ??
           authProvider?.sessionStore ??
           SharedPreferencesClientSessionStore(),
       authProvider =
           authProvider ??
           ClientSessionAuthProvider(
             sessionStore:
                 sessionStore ?? SharedPreferencesClientSessionStore(),
           ),
       _client = client ?? Client(_serverpodHost(serverpodBaseUrl)) {
    _client.authKeyProvider = this.authProvider;
  }

  final Client _client;
  final ClientSessionStore _sessionStore;
  final ClientSessionAuthProvider authProvider;
  ClientIdentity? _identity;

  @override
  Future<ClientIdentity?> restoreSession() async {
    final stored = await _sessionStore.read();
    if (stored == null) {
      authProvider.clear();
      return null;
    }

    try {
      await authProvider.initialize();
      authProvider.setToken(stored.sessionToken);
      final profile = await _client.clientProfile.current();
      final identity = ClientIdentity(
        clientId: profile.clientId.toString(),
        email: profile.email,
        displayName: profile.displayName,
      );
      _identity = identity;
      await _sessionStore.write(
        ClientSession(identity: identity, sessionToken: stored.sessionToken),
      );
      return identity;
    } on Object {
      authProvider.clear();
      await _clearPersistedSession();
      return null;
    }
  }

  @override
  Future<ClientIdentity> login({
    required String email,
    required String password,
  }) async {
    await authProvider.initialize();
    final response = await _client.clientAuth.login(
      email: email,
      password: password,
    );
    authProvider.setToken(response.sessionToken);
    final identity = ClientIdentity(
      clientId: response.clientId.toString(),
      email: response.email,
      displayName: response.displayName,
    );
    _identity = identity;
    try {
      await _sessionStore.write(
        ClientSession(identity: identity, sessionToken: response.sessionToken),
      );
    } on Object {
      authProvider.clear();
      _identity = null;
      rethrow;
    }
    return identity;
  }

  @override
  Future<List<ClientOrderRecord>> loadOrders() async {
    final orders = await _client.clientOrder.listOrders();
    return orders.map(_mapOrder).toList(growable: false);
  }

  @override
  Future<ClientOrderRecord> createOrder({
    required String title,
    required String description,
  }) async {
    final order = await _client.clientOrder.createOrder(
      title: title,
      description: description,
    );
    return _mapOrder(order);
  }

  @override
  Future<ClientOrderRecord> createOrderWithBudget({
    required String projectDescription,
    required int budgetCents,
  }) async {
    final identity = _identity;
    if (identity == null) {
      throw StateError('Sign in before creating an order.');
    }
    final orderId = await _client.order.createOrder(
      clientId: identity.clientId,
      projectDescription: projectDescription,
      budgetCents: budgetCents,
    );
    final order = await _client.clientOrder.getOrder(orderId);
    if (order == null) {
      throw StateError('The created order could not be loaded.');
    }
    return _mapOrder(order);
  }

  @override
  Future<ClientOrderDetail> loadOrderDetail(int orderId) async {
    final orderFuture = _client.clientOrder.getOrder(orderId);
    final revisionsFuture = _client.clientOrder.listRevisions(orderId);
    final statusFuture = _client.order.orderStatus(orderId);
    final order = await orderFuture;
    if (order == null) {
      throw StateError('Order not found.');
    }
    final revisions = await revisionsFuture;
    Map<String, dynamic>? status;
    try {
      status = await statusFuture;
    } catch (_) {
      // The legacy clientOrder endpoint still provides enough data to render
      // the detail screen while older servers roll out orderStatus.
    }
    final latestResultSummary =
        _nonEmptyString(status?['latest_result_summary']) ??
        _latestRevisionSummary(revisions);
    final record = _mapOrder(order).copyWith(
      status: _nonEmptyString(status?['status']) ?? order.status,
      latestResultSummary: latestResultSummary,
    );
    return ClientOrderDetail(
      order: record,
      revisions: revisions.map(_mapRevision).toList(growable: false),
      latestResultSummary: latestResultSummary,
    );
  }

  @override
  Future<ClientRevisionRecord> submitRevision({
    required int orderId,
    required String description,
  }) async {
    final revisionId = await _client.order.submitRevision(
      orderId: orderId,
      revisionText: description,
    );
    final revisions = await _client.clientOrder.listRevisions(orderId);
    for (final revision in revisions) {
      if (revision.id == revisionId) return _mapRevision(revision);
    }
    throw StateError('The submitted revision could not be loaded.');
  }

  @override
  void logout() {
    authProvider.clear();
    _identity = null;
    unawaited(_clearPersistedSession());
  }

  Future<void> _clearPersistedSession() async {
    try {
      await _sessionStore.clear();
    } on Object {
      // Logout must still clear the in-memory provider if platform storage is
      // temporarily unavailable.
    }
  }

  ClientOrderRecord _mapOrder(Order order) {
    return ClientOrderRecord(
      id: order.id,
      title: order.title,
      description: order.projectDescription,
      status: order.status,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
      budgetCents: order.budgetCents,
    );
  }

  ClientRevisionRecord _mapRevision(Revision revision) {
    return ClientRevisionRecord(
      id: revision.id,
      orderId: revision.orderId,
      revisionNumber: revision.revisionNumber,
      description: revision.revisionText,
      status: revision.status,
      createdAt: revision.createdAt,
      updatedAt: revision.updatedAt,
      resultSummary: revision.resultSummary,
    );
  }

  String? _latestRevisionSummary(List<Revision> revisions) {
    for (final revision in revisions) {
      final summary = _nonEmptyString(revision.resultSummary);
      if (summary != null) return summary;
    }
    return null;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String _serverpodHost(String? explicit) {
    final configured = explicit?.trim();
    final environment = Platform.environment['SERVERPOD_API_URL']?.trim();
    final host = configured?.isNotEmpty == true
        ? configured!
        : environment?.isNotEmpty == true
        ? environment!
        : 'http://127.0.0.1:28080';
    return host.endsWith('/') ? host : '$host/';
  }
}

String _titleFromDescription(String description) {
  final firstLine = description.trim().split('\n').first.trim();
  if (firstLine.length <= 80) return firstLine;
  return '${firstLine.substring(0, 77)}...';
}
