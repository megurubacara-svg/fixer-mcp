import 'package:fixer_dashboard_server/src/generated/client_user.dart';
import 'package:serverpod/serverpod.dart';

/// Authentication boundary for client tenants.
///
/// Serverpod resolves and validates the bearer token before endpoint dispatch.
/// Endpoints that extend [ClientProtectedEndpoint] additionally require this
/// scope, which keeps client sessions distinct from Architect sessions.
abstract final class ClientAuthMiddleware {
  /// Scope granted only to client sessions created by [ClientAuthEndpoint].
  static const clientScope = Scope('client');

  /// The endpoint scope required for client-protected operations.
  static final requiredScopes = <Scope>{clientScope};

  /// Returns the authenticated client ID or rejects the request.
  static UuidValue requireClientId(Session session) {
    final authenticationInfo = session.authenticated;
    if (authenticationInfo == null) {
      throw NotAuthorizedException(
        reason: AuthenticationFailureReason.unauthenticated,
      );
    }

    if (!authenticationInfo.scopes.contains(clientScope)) {
      throw NotAuthorizedException(
        reason: AuthenticationFailureReason.insufficientAccess,
      );
    }

    try {
      return UuidValue.withValidation(authenticationInfo.userIdentifier);
    } on FormatException {
      throw NotAuthorizedException(
        reason: AuthenticationFailureReason.insufficientAccess,
      );
    }
  }

  /// Loads the client represented by the current, validated session.
  static Future<ClientUser> requireClient(Session session) async {
    final clientId = requireClientId(session);
    final client = await ClientUser.db.findById(session, clientId);
    if (client == null) {
      throw NotAuthorizedException(
        reason: AuthenticationFailureReason.insufficientAccess,
      );
    }
    return client;
  }
}

/// Base endpoint for methods that are only available to client tenants.
abstract class ClientProtectedEndpoint extends Endpoint {
  @override
  Set<Scope> get requiredScopes => ClientAuthMiddleware.requiredScopes;
}
