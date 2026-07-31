/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:fixer_dashboard_client/src/protocol/client_auth_response.dart'
    as _i6;
import 'package:fixer_dashboard_client/src/protocol/client_profile.dart' as _i7;
import 'package:fixer_dashboard_client/src/protocol/order.dart' as _i8;
import 'package:fixer_dashboard_client/src/protocol/revision.dart' as _i9;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i10;
import 'protocol.dart' as _i11;

/// Registration, login, and current-client operations for client tenants.
/// {@category Endpoint}
class EndpointClientAuth extends _i1.EndpointRef {
  EndpointClientAuth(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'clientAuth';

  /// Registers a client with an email and password and returns a session token.
  _i2.Future<_i6.ClientAuthResponse> register({
    required String email,
    required String password,
    required String displayName,
  }) => caller.callServerEndpoint<_i6.ClientAuthResponse>(
    'clientAuth',
    'register',
    {'email': email, 'password': password, 'displayName': displayName},
  );

  /// Logs a client in and returns a new session token.
  _i2.Future<_i6.ClientAuthResponse> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_i6.ClientAuthResponse>(
    'clientAuth',
    'login',
    {'email': email, 'password': password},
  );
}

/// Base endpoint for methods that are only available to client tenants.
/// {@category Endpoint}
abstract class EndpointClientProtected extends _i1.EndpointRef {
  EndpointClientProtected(_i1.EndpointCaller caller) : super(caller);
}

/// Protected client-tenant profile operations.
/// {@category Endpoint}
class EndpointClientProfile extends EndpointClientProtected {
  EndpointClientProfile(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'clientProfile';

  /// Returns the profile represented by the validated client session token.
  _i2.Future<_i7.ClientProfile> current() => caller
      .callServerEndpoint<_i7.ClientProfile>('clientProfile', 'current', {});
}

/// {@category Endpoint}
class EndpointDashboardRuntime extends _i1.EndpointRef {
  EndpointDashboardRuntime(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'dashboardRuntime';

  _i2.Future<String> health() =>
      caller.callServerEndpoint<String>('dashboardRuntime', 'health', {});

  _i2.Future<List<String>> topology() => caller
      .callServerEndpoint<List<String>>('dashboardRuntime', 'topology', {});

  _i2.Future<Map<String, dynamic>> homeSnapshot() =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'dashboardRuntime',
        'homeSnapshot',
        {},
      );

  _i2.Future<Map<String, dynamic>> projectSnapshot(int projectId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'dashboardRuntime',
        'projectSnapshot',
        {'projectId': projectId},
      );

  _i2.Future<Map<String, dynamic>> projectDocs(int projectId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'dashboardRuntime',
        'projectDocs',
        {'projectId': projectId},
      );

  _i2.Future<Map<String, dynamic>> threadBinding(int projectId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'dashboardRuntime',
        'threadBinding',
        {'projectId': projectId},
      );

  _i2.Future<Map<String, dynamic>> sessionDetail(int sessionId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'dashboardRuntime',
        'sessionDetail',
        {'sessionId': sessionId},
      );

  _i2.Future<Map<String, dynamic>> threadMessages(String threadId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'dashboardRuntime',
        'threadMessages',
        {'threadId': threadId},
      );

  _i2.Future<Map<String, dynamic>> sendThreadMessage(
    String threadId,
    String prompt,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'dashboardRuntime',
    'sendThreadMessage',
    {'threadId': threadId, 'prompt': prompt},
  );

  _i2.Future<Map<String, dynamic>> threadTurnStatus(String streamId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'dashboardRuntime',
        'threadTurnStatus',
        {'streamId': streamId},
      );
}

/// CRUD operations for client-owned orders and their revisions.
/// {@category Endpoint}
class EndpointClientOrder extends EndpointClientProtected {
  EndpointClientOrder(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'clientOrder';

  /// Creates a draft order for the authenticated client.
  _i2.Future<_i8.Order> createOrder({
    required String title,
    required String description,
  }) => caller.callServerEndpoint<_i8.Order>('clientOrder', 'createOrder', {
    'title': title,
    'description': description,
  });

  /// Lists the authenticated client's orders, newest updates first.
  _i2.Future<List<_i8.Order>> listOrders() => caller
      .callServerEndpoint<List<_i8.Order>>('clientOrder', 'listOrders', {});

  /// Fetches one order only when it belongs to the authenticated client.
  _i2.Future<_i8.Order?> getOrder(int orderId) =>
      caller.callServerEndpoint<_i8.Order?>('clientOrder', 'getOrder', {
        'orderId': orderId,
      });

  /// Updates the editable client-facing fields of an order.
  _i2.Future<_i8.Order> updateOrder({
    required int orderId,
    required String title,
    required String description,
  }) => caller.callServerEndpoint<_i8.Order>('clientOrder', 'updateOrder', {
    'orderId': orderId,
    'title': title,
    'description': description,
  });

  /// Deletes an order and all of its revisions.
  _i2.Future<bool> deleteOrder(int orderId) => caller.callServerEndpoint<bool>(
    'clientOrder',
    'deleteOrder',
    {'orderId': orderId},
  );

  /// Creates the next draft revision for an order.
  _i2.Future<_i9.Revision> createRevision({
    required int orderId,
    required String description,
  }) => caller.callServerEndpoint<_i9.Revision>(
    'clientOrder',
    'createRevision',
    {'orderId': orderId, 'description': description},
  );

  /// Lists revisions belonging to an order owned by the authenticated client.
  _i2.Future<List<_i9.Revision>> listRevisions(int orderId) =>
      caller.callServerEndpoint<List<_i9.Revision>>(
        'clientOrder',
        'listRevisions',
        {'orderId': orderId},
      );

  /// Fetches one revision only when its parent order is client-owned.
  _i2.Future<_i9.Revision?> getRevision(int revisionId) =>
      caller.callServerEndpoint<_i9.Revision?>('clientOrder', 'getRevision', {
        'revisionId': revisionId,
      });

  /// Updates the editable description of a revision.
  _i2.Future<_i9.Revision> updateRevision({
    required int revisionId,
    required String description,
  }) => caller.callServerEndpoint<_i9.Revision>(
    'clientOrder',
    'updateRevision',
    {'revisionId': revisionId, 'description': description},
  );

  /// Deletes a revision belonging to the authenticated client's order.
  _i2.Future<bool> deleteRevision(int revisionId) =>
      caller.callServerEndpoint<bool>('clientOrder', 'deleteRevision', {
        'revisionId': revisionId,
      });
}

/// Order intake and delivery-status operations for the client-facing flow.
/// {@category Endpoint}
class EndpointOrder extends EndpointClientProtected {
  EndpointOrder(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'order';

  /// Creates an order in the autonomous delivery pipeline.
  _i2.Future<int> createOrder({
    required String clientId,
    required String projectDescription,
    required int budgetCents,
  }) => caller.callServerEndpoint<int>('order', 'createOrder', {
    'clientId': clientId,
    'projectDescription': projectDescription,
    'budgetCents': budgetCents,
  });

  /// Lists the delivery status of a client's orders.
  _i2.Future<List<Map<String, dynamic>>> listOrders(String clientId) =>
      caller.callServerEndpoint<List<Map<String, dynamic>>>(
        'order',
        'listOrders',
        {'clientId': clientId},
      );

  /// Submits a client revision to the delivery pipeline.
  _i2.Future<int> submitRevision({
    required int orderId,
    required String revisionText,
    List<String>? attachmentUrls,
  }) => caller.callServerEndpoint<int>('order', 'submitRevision', {
    'orderId': orderId,
    'revisionText': revisionText,
    'attachmentUrls': attachmentUrls,
  });

  /// Returns the current status, Architect result summary, and revisions.
  _i2.Future<Map<String, dynamic>> orderStatus(int orderId) =>
      caller.callServerEndpoint<Map<String, dynamic>>('order', 'orderStatus', {
        'orderId': orderId,
      });
}

class Modules {
  Modules(Client client) {
    serverpod_auth_core = _i10.Caller(client);
  }

  late final _i10.Caller serverpod_auth_core;
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(_i1.MethodCallContext, Object, StackTrace)? onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i11.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    clientAuth = EndpointClientAuth(this);
    clientProfile = EndpointClientProfile(this);
    dashboardRuntime = EndpointDashboardRuntime(this);
    clientOrder = EndpointClientOrder(this);
    order = EndpointOrder(this);
    modules = Modules(this);
  }

  late final EndpointClientAuth clientAuth;

  late final EndpointClientProfile clientProfile;

  late final EndpointDashboardRuntime dashboardRuntime;

  late final EndpointClientOrder clientOrder;

  late final EndpointOrder order;

  late final Modules modules;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'clientAuth': clientAuth,
    'clientProfile': clientProfile,
    'dashboardRuntime': dashboardRuntime,
    'clientOrder': clientOrder,
    'order': order,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
