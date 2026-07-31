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

/// A client-owned order in the client cockpit.
abstract class Order implements _i1.SerializableModel {
  Order._({
    this.id,
    required this.clientId,
    required this.projectDescription,
    required this.budgetCents,
    this.assignedProjectId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order({
    int? id,
    required _i1.UuidValue clientId,
    required String projectDescription,
    required int budgetCents,
    int? assignedProjectId,
    required String title,
    required String description,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _OrderImpl;

  factory Order.fromJson(Map<String, dynamic> jsonSerialization) {
    return Order(
      id: jsonSerialization['id'] as int?,
      clientId: _i1.UuidValueJsonExtension.fromJson(
        jsonSerialization['clientId'],
      ),
      projectDescription: jsonSerialization['projectDescription'] as String,
      budgetCents: jsonSerialization['budgetCents'] as int,
      assignedProjectId: jsonSerialization['assignedProjectId'] as int?,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String,
      status: jsonSerialization['status'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  _i1.UuidValue clientId;

  String projectDescription;

  int budgetCents;

  int? assignedProjectId;

  String title;

  String description;

  String status;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [Order]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Order copyWith({
    int? id,
    _i1.UuidValue? clientId,
    String? projectDescription,
    int? budgetCents,
    Object? assignedProjectId = _Undefined,
    String? title,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Order',
      if (id != null) 'id': id,
      'clientId': clientId.toJson(),
      'projectDescription': projectDescription,
      'budgetCents': budgetCents,
      if (assignedProjectId != null) 'assignedProjectId': assignedProjectId,
      'title': title,
      'description': description,
      'status': status,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OrderImpl extends Order {
  _OrderImpl({
    int? id,
    required _i1.UuidValue clientId,
    required String projectDescription,
    required int budgetCents,
    int? assignedProjectId,
    required String title,
    required String description,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         clientId: clientId,
         projectDescription: projectDescription,
         budgetCents: budgetCents,
         assignedProjectId: assignedProjectId,
         title: title,
         description: description,
         status: status,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Order]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Order copyWith({
    Object? id = _Undefined,
    _i1.UuidValue? clientId,
    String? projectDescription,
    int? budgetCents,
    Object? assignedProjectId = _Undefined,
    String? title,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id is int? ? id : this.id,
      clientId: clientId ?? this.clientId,
      projectDescription: projectDescription ?? this.projectDescription,
      budgetCents: budgetCents ?? this.budgetCents,
      assignedProjectId: assignedProjectId is int?
          ? assignedProjectId
          : this.assignedProjectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
