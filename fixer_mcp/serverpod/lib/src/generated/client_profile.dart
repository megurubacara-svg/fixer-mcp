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

/// Public client profile returned by protected client endpoints.
abstract class ClientProfile
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ClientProfile._({
    required this.clientId,
    required this.email,
    required this.displayName,
  });

  factory ClientProfile({
    required _i1.UuidValue clientId,
    required String email,
    required String displayName,
  }) = _ClientProfileImpl;

  factory ClientProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClientProfile(
      clientId: _i1.UuidValueJsonExtension.fromJson(
        jsonSerialization['clientId'],
      ),
      email: jsonSerialization['email'] as String,
      displayName: jsonSerialization['displayName'] as String,
    );
  }

  _i1.UuidValue clientId;

  String email;

  String displayName;

  /// Returns a shallow copy of this [ClientProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClientProfile copyWith({
    _i1.UuidValue? clientId,
    String? email,
    String? displayName,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClientProfile',
      'clientId': clientId.toJson(),
      'email': email,
      'displayName': displayName,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ClientProfile',
      'clientId': clientId.toJson(),
      'email': email,
      'displayName': displayName,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ClientProfileImpl extends ClientProfile {
  _ClientProfileImpl({
    required _i1.UuidValue clientId,
    required String email,
    required String displayName,
  }) : super._(
         clientId: clientId,
         email: email,
         displayName: displayName,
       );

  /// Returns a shallow copy of this [ClientProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClientProfile copyWith({
    _i1.UuidValue? clientId,
    String? email,
    String? displayName,
  }) {
    return ClientProfile(
      clientId: clientId ?? this.clientId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}
