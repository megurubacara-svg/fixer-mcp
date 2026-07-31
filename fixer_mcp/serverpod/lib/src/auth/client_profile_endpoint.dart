import 'package:fixer_dashboard_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'client_auth_middleware.dart';

/// Protected client-tenant profile operations.
class ClientProfileEndpoint extends ClientProtectedEndpoint {
  /// Returns the profile represented by the validated client session token.
  Future<ClientProfile> current(Session session) async {
    final client = await ClientAuthMiddleware.requireClient(session);
    return ClientProfile(
      clientId: client.id!,
      email: client.email,
      displayName: client.displayName,
    );
  }
}
