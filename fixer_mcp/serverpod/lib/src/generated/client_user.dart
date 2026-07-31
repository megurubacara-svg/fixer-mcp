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

/// A client-facing tenant user.
///
/// The UUID is shared with the corresponding Serverpod Auth Core user so the
/// built-in server-side session token manager can authenticate this record
/// without a second identity mapping table.
abstract class ClientUser
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  ClientUser._({
    this.id,
    required this.email,
    required this.hashedPassword,
    required this.displayName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ClientUser({
    _i1.UuidValue? id,
    required String email,
    required String hashedPassword,
    required String displayName,
    DateTime? createdAt,
  }) = _ClientUserImpl;

  factory ClientUser.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClientUser(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      email: jsonSerialization['email'] as String,
      hashedPassword: jsonSerialization['hashedPassword'] as String,
      displayName: jsonSerialization['displayName'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ClientUserTable();

  static const db = ClientUserRepository._();

  @override
  _i1.UuidValue? id;

  String email;

  String hashedPassword;

  String displayName;

  DateTime createdAt;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [ClientUser]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClientUser copyWith({
    _i1.UuidValue? id,
    String? email,
    String? hashedPassword,
    String? displayName,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClientUser',
      if (id != null) 'id': id?.toJson(),
      'email': email,
      'hashedPassword': hashedPassword,
      'displayName': displayName,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ClientUserInclude include() {
    return ClientUserInclude._();
  }

  static ClientUserIncludeList includeList({
    _i1.WhereExpressionBuilder<ClientUserTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClientUserTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClientUserTable>? orderByList,
    ClientUserInclude? include,
  }) {
    return ClientUserIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClientUser.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ClientUser.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClientUserImpl extends ClientUser {
  _ClientUserImpl({
    _i1.UuidValue? id,
    required String email,
    required String hashedPassword,
    required String displayName,
    DateTime? createdAt,
  }) : super._(
         id: id,
         email: email,
         hashedPassword: hashedPassword,
         displayName: displayName,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ClientUser]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClientUser copyWith({
    Object? id = _Undefined,
    String? email,
    String? hashedPassword,
    String? displayName,
    DateTime? createdAt,
  }) {
    return ClientUser(
      id: id is _i1.UuidValue? ? id : this.id,
      email: email ?? this.email,
      hashedPassword: hashedPassword ?? this.hashedPassword,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ClientUserUpdateTable extends _i1.UpdateTable<ClientUserTable> {
  ClientUserUpdateTable(super.table);

  _i1.ColumnValue<String, String> email(String value) => _i1.ColumnValue(
    table.email,
    value,
  );

  _i1.ColumnValue<String, String> hashedPassword(String value) =>
      _i1.ColumnValue(
        table.hashedPassword,
        value,
      );

  _i1.ColumnValue<String, String> displayName(String value) => _i1.ColumnValue(
    table.displayName,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class ClientUserTable extends _i1.Table<_i1.UuidValue?> {
  ClientUserTable({super.tableRelation}) : super(tableName: 'client') {
    updateTable = ClientUserUpdateTable(this);
    email = _i1.ColumnString(
      'email',
      this,
    );
    hashedPassword = _i1.ColumnString(
      'hashed_password',
      this,
      fieldName: 'hashedPassword',
    );
    displayName = _i1.ColumnString(
      'display_name',
      this,
      fieldName: 'displayName',
    );
    createdAt = _i1.ColumnDateTime(
      'created_at',
      this,
      fieldName: 'createdAt',
    );
  }

  late final ClientUserUpdateTable updateTable;

  late final _i1.ColumnString email;

  late final _i1.ColumnString hashedPassword;

  late final _i1.ColumnString displayName;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    email,
    hashedPassword,
    displayName,
    createdAt,
  ];
}

class ClientUserInclude extends _i1.IncludeObject {
  ClientUserInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<_i1.UuidValue?> get table => ClientUser.t;
}

class ClientUserIncludeList extends _i1.IncludeList {
  ClientUserIncludeList._({
    _i1.WhereExpressionBuilder<ClientUserTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ClientUser.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => ClientUser.t;
}

class ClientUserRepository {
  const ClientUserRepository._();

  /// Returns a list of [ClientUser]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<ClientUser>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClientUserTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClientUserTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClientUserTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ClientUser>(
      where: where?.call(ClientUser.t),
      orderBy: orderBy?.call(ClientUser.t),
      orderByList: orderByList?.call(ClientUser.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ClientUser] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<ClientUser?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClientUserTable>? where,
    int? offset,
    _i1.OrderByBuilder<ClientUserTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClientUserTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ClientUser>(
      where: where?.call(ClientUser.t),
      orderBy: orderBy?.call(ClientUser.t),
      orderByList: orderByList?.call(ClientUser.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ClientUser] by its [id] or null if no such row exists.
  Future<ClientUser?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ClientUser>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ClientUser]s in the list and returns the inserted rows.
  ///
  /// The returned [ClientUser]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ClientUser>> insert(
    _i1.DatabaseSession session,
    List<ClientUser> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ClientUser>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ClientUser] and returns the inserted row.
  ///
  /// The returned [ClientUser] will have its `id` field set.
  Future<ClientUser> insertRow(
    _i1.DatabaseSession session,
    ClientUser row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ClientUser>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ClientUser]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ClientUser>> update(
    _i1.DatabaseSession session,
    List<ClientUser> rows, {
    _i1.ColumnSelections<ClientUserTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ClientUser>(
      rows,
      columns: columns?.call(ClientUser.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClientUser]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ClientUser> updateRow(
    _i1.DatabaseSession session,
    ClientUser row, {
    _i1.ColumnSelections<ClientUserTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ClientUser>(
      row,
      columns: columns?.call(ClientUser.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClientUser] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ClientUser?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<ClientUserUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ClientUser>(
      id,
      columnValues: columnValues(ClientUser.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ClientUser]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ClientUser>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ClientUserUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ClientUserTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClientUserTable>? orderBy,
    _i1.OrderByListBuilder<ClientUserTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ClientUser>(
      columnValues: columnValues(ClientUser.t.updateTable),
      where: where(ClientUser.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClientUser.t),
      orderByList: orderByList?.call(ClientUser.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ClientUser]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ClientUser>> delete(
    _i1.DatabaseSession session,
    List<ClientUser> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ClientUser>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ClientUser].
  Future<ClientUser> deleteRow(
    _i1.DatabaseSession session,
    ClientUser row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ClientUser>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ClientUser>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClientUserTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ClientUser>(
      where: where(ClientUser.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClientUserTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ClientUser>(
      where: where?.call(ClientUser.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ClientUser] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClientUserTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ClientUser>(
      where: where(ClientUser.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
