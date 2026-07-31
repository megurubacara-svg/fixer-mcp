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
import 'package:serverpod/serverpod.dart' as _i1;

/// Public response returned after a client registration or login.
abstract class ClientAuthResponse
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ClientAuthResponse._({
    required this.clientId,
    required this.email,
    required this.displayName,
    required this.sessionToken,
  });

  factory ClientAuthResponse({
    required _i1.UuidValue clientId,
    required String email,
    required String displayName,
    required String sessionToken,
  }) = _ClientAuthResponseImpl;

  factory ClientAuthResponse.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClientAuthResponse(
      clientId: _i1.UuidValueJsonExtension.fromJson(
        jsonSerialization['clientId'],
      ),
      email: jsonSerialization['email'] as String,
      displayName: jsonSerialization['displayName'] as String,
      sessionToken: jsonSerialization['sessionToken'] as String,
    );
  }

  _i1.UuidValue clientId;

  String email;

  String displayName;

  String sessionToken;

  /// Returns a shallow copy of this [ClientAuthResponse]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClientAuthResponse copyWith({
    _i1.UuidValue? clientId,
    String? email,
    String? displayName,
    String? sessionToken,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClientAuthResponse',
      'clientId': clientId.toJson(),
      'email': email,
      'displayName': displayName,
      'sessionToken': sessionToken,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ClientAuthResponse',
      'clientId': clientId.toJson(),
      'email': email,
      'displayName': displayName,
      'sessionToken': sessionToken,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ClientAuthResponseImpl extends ClientAuthResponse {
  _ClientAuthResponseImpl({
    required _i1.UuidValue clientId,
    required String email,
    required String displayName,
    required String sessionToken,
  }) : super._(
         clientId: clientId,
         email: email,
         displayName: displayName,
         sessionToken: sessionToken,
       );

  /// Returns a shallow copy of this [ClientAuthResponse]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClientAuthResponse copyWith({
    _i1.UuidValue? clientId,
    String? email,
    String? displayName,
    String? sessionToken,
  }) {
    return ClientAuthResponse(
      clientId: clientId ?? this.clientId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }
}
