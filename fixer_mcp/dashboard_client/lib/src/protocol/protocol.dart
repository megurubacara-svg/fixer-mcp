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
import 'client_auth_response.dart' as _i7;
import 'client_profile.dart' as _i8;
import 'order.dart' as _i9;
import 'revision.dart' as _i10;
import 'package:fixer_dashboard_client/src/protocol/order.dart' as _i12;
import 'package:fixer_dashboard_client/src/protocol/revision.dart' as _i13;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i14;
export 'client_auth_response.dart';
export 'client_profile.dart';
export 'order.dart';
export 'revision.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i7.ClientAuthResponse) {
      return _i7.ClientAuthResponse.fromJson(data) as T;
    }
    if (t == _i8.ClientProfile) {
      return _i8.ClientProfile.fromJson(data) as T;
    }
    if (t == _i9.Order) {
      return _i9.Order.fromJson(data) as T;
    }
    if (t == _i10.Revision) {
      return _i10.Revision.fromJson(data) as T;
    }
    if (t == _i1.getType<_i7.ClientAuthResponse?>()) {
      return (data != null ? _i7.ClientAuthResponse.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.ClientProfile?>()) {
      return (data != null ? _i8.ClientProfile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.Order?>()) {
      return (data != null ? _i9.Order.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.Revision?>()) {
      return (data != null ? _i10.Revision.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _i1.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == Map<String, dynamic>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)),
          )
          as T;
    }
    if (t == List<_i12.Order>) {
      return (data as List).map((e) => deserialize<_i12.Order>(e)).toList()
          as T;
    }
    if (t == List<_i13.Revision>) {
      return (data as List).map((e) => deserialize<_i13.Revision>(e)).toList()
          as T;
    }
    if (t == List<Map<String, dynamic>>) {
      return (data as List)
              .map((e) => deserialize<Map<String, dynamic>>(e))
              .toList()
          as T;
    }
    try {
      return _i14.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i7.ClientAuthResponse => 'ClientAuthResponse',
      _i8.ClientProfile => 'ClientProfile',
      _i9.Order => 'Order',
      _i10.Revision => 'Revision',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'fixer_dashboard.',
        '',
      );
    }

    switch (data) {
      case _i7.ClientAuthResponse():
        return 'ClientAuthResponse';
      case _i8.ClientProfile():
        return 'ClientProfile';
      case _i9.Order():
        return 'Order';
      case _i10.Revision():
        return 'Revision';
    }
    className = _i14.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'ClientAuthResponse') {
      return deserialize<_i7.ClientAuthResponse>(data['data']);
    }
    if (dataClassName == 'ClientProfile') {
      return deserialize<_i8.ClientProfile>(data['data']);
    }
    if (dataClassName == 'Order') {
      return deserialize<_i9.Order>(data['data']);
    }
    if (dataClassName == 'Revision') {
      return deserialize<_i10.Revision>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i14.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i14.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
