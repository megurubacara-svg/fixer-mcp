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
import 'package:fixer_dashboard_server/src/generated/protocol.dart' as _i2;

/// A client-submitted revision of an order.
abstract class Revision
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Revision._({
    this.id,
    required this.orderId,
    required this.revisionNumber,
    required this.revisionText,
    this.attachmentUrls,
    this.resultSummary,
    required this.status,
    required this.description,
    this.branchName,
    this.previewUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Revision({
    int? id,
    required int orderId,
    required int revisionNumber,
    required String revisionText,
    List<String>? attachmentUrls,
    String? resultSummary,
    required String status,
    required String description,
    String? branchName,
    String? previewUrl,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _RevisionImpl;

  factory Revision.fromJson(Map<String, dynamic> jsonSerialization) {
    return Revision(
      id: jsonSerialization['id'] as int?,
      orderId: jsonSerialization['orderId'] as int,
      revisionNumber: jsonSerialization['revisionNumber'] as int,
      revisionText: jsonSerialization['revisionText'] as String,
      attachmentUrls: jsonSerialization['attachmentUrls'] == null
          ? null
          : _i2.Protocol().deserialize<List<String>>(
              jsonSerialization['attachmentUrls'],
            ),
      resultSummary: jsonSerialization['resultSummary'] as String?,
      status: jsonSerialization['status'] as String,
      description: jsonSerialization['description'] as String,
      branchName: jsonSerialization['branchName'] as String?,
      previewUrl: jsonSerialization['previewUrl'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = RevisionTable();

  static const db = RevisionRepository._();

  @override
  int? id;

  int orderId;

  int revisionNumber;

  String revisionText;

  List<String>? attachmentUrls;

  String? resultSummary;

  String status;

  String description;

  String? branchName;

  String? previewUrl;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Revision]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Revision copyWith({
    int? id,
    int? orderId,
    int? revisionNumber,
    String? revisionText,
    List<String>? attachmentUrls,
    String? resultSummary,
    String? status,
    String? description,
    String? branchName,
    String? previewUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Revision',
      if (id != null) 'id': id,
      'orderId': orderId,
      'revisionNumber': revisionNumber,
      'revisionText': revisionText,
      if (attachmentUrls != null) 'attachmentUrls': attachmentUrls?.toJson(),
      if (resultSummary != null) 'resultSummary': resultSummary,
      'status': status,
      'description': description,
      if (branchName != null) 'branchName': branchName,
      if (previewUrl != null) 'previewUrl': previewUrl,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Revision',
      if (id != null) 'id': id,
      'orderId': orderId,
      'revisionNumber': revisionNumber,
      'revisionText': revisionText,
      if (attachmentUrls != null) 'attachmentUrls': attachmentUrls?.toJson(),
      if (resultSummary != null) 'resultSummary': resultSummary,
      'status': status,
      'description': description,
      if (branchName != null) 'branchName': branchName,
      if (previewUrl != null) 'previewUrl': previewUrl,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static RevisionInclude include() {
    return RevisionInclude._();
  }

  static RevisionIncludeList includeList({
    _i1.WhereExpressionBuilder<RevisionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RevisionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RevisionTable>? orderByList,
    RevisionInclude? include,
  }) {
    return RevisionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Revision.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Revision.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RevisionImpl extends Revision {
  _RevisionImpl({
    int? id,
    required int orderId,
    required int revisionNumber,
    required String revisionText,
    List<String>? attachmentUrls,
    String? resultSummary,
    required String status,
    required String description,
    String? branchName,
    String? previewUrl,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         orderId: orderId,
         revisionNumber: revisionNumber,
         revisionText: revisionText,
         attachmentUrls: attachmentUrls,
         resultSummary: resultSummary,
         status: status,
         description: description,
         branchName: branchName,
         previewUrl: previewUrl,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Revision]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Revision copyWith({
    Object? id = _Undefined,
    int? orderId,
    int? revisionNumber,
    String? revisionText,
    Object? attachmentUrls = _Undefined,
    Object? resultSummary = _Undefined,
    String? status,
    String? description,
    Object? branchName = _Undefined,
    Object? previewUrl = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Revision(
      id: id is int? ? id : this.id,
      orderId: orderId ?? this.orderId,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      revisionText: revisionText ?? this.revisionText,
      attachmentUrls: attachmentUrls is List<String>?
          ? attachmentUrls
          : this.attachmentUrls?.map((e0) => e0).toList(),
      resultSummary: resultSummary is String?
          ? resultSummary
          : this.resultSummary,
      status: status ?? this.status,
      description: description ?? this.description,
      branchName: branchName is String? ? branchName : this.branchName,
      previewUrl: previewUrl is String? ? previewUrl : this.previewUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RevisionUpdateTable extends _i1.UpdateTable<RevisionTable> {
  RevisionUpdateTable(super.table);

  _i1.ColumnValue<int, int> orderId(int value) => _i1.ColumnValue(
    table.orderId,
    value,
  );

  _i1.ColumnValue<int, int> revisionNumber(int value) => _i1.ColumnValue(
    table.revisionNumber,
    value,
  );

  _i1.ColumnValue<String, String> revisionText(String value) => _i1.ColumnValue(
    table.revisionText,
    value,
  );

  _i1.ColumnValue<List<String>, List<String>> attachmentUrls(
    List<String>? value,
  ) => _i1.ColumnValue(
    table.attachmentUrls,
    value,
  );

  _i1.ColumnValue<String, String> resultSummary(String? value) =>
      _i1.ColumnValue(
        table.resultSummary,
        value,
      );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> description(String value) => _i1.ColumnValue(
    table.description,
    value,
  );

  _i1.ColumnValue<String, String> branchName(String? value) => _i1.ColumnValue(
    table.branchName,
    value,
  );

  _i1.ColumnValue<String, String> previewUrl(String? value) => _i1.ColumnValue(
    table.previewUrl,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );
}

class RevisionTable extends _i1.Table<int?> {
  RevisionTable({super.tableRelation}) : super(tableName: 'revision') {
    updateTable = RevisionUpdateTable(this);
    orderId = _i1.ColumnInt(
      'orderId',
      this,
    );
    revisionNumber = _i1.ColumnInt(
      'revisionNumber',
      this,
    );
    revisionText = _i1.ColumnString(
      'revisionText',
      this,
    );
    attachmentUrls = _i1.ColumnSerializable<List<String>>(
      'attachmentUrls',
      this,
    );
    resultSummary = _i1.ColumnString(
      'resultSummary',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    description = _i1.ColumnString(
      'description',
      this,
    );
    branchName = _i1.ColumnString(
      'branchName',
      this,
    );
    previewUrl = _i1.ColumnString(
      'previewUrl',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final RevisionUpdateTable updateTable;

  late final _i1.ColumnInt orderId;

  late final _i1.ColumnInt revisionNumber;

  late final _i1.ColumnString revisionText;

  late final _i1.ColumnSerializable<List<String>> attachmentUrls;

  late final _i1.ColumnString resultSummary;

  late final _i1.ColumnString status;

  late final _i1.ColumnString description;

  late final _i1.ColumnString branchName;

  late final _i1.ColumnString previewUrl;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    orderId,
    revisionNumber,
    revisionText,
    attachmentUrls,
    resultSummary,
    status,
    description,
    branchName,
    previewUrl,
    createdAt,
    updatedAt,
  ];
}

class RevisionInclude extends _i1.IncludeObject {
  RevisionInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Revision.t;
}

class RevisionIncludeList extends _i1.IncludeList {
  RevisionIncludeList._({
    _i1.WhereExpressionBuilder<RevisionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Revision.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Revision.t;
}

class RevisionRepository {
  const RevisionRepository._();

  /// Returns a list of [Revision]s matching the given query parameters.
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
  Future<List<Revision>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RevisionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RevisionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RevisionTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Revision>(
      where: where?.call(Revision.t),
      orderBy: orderBy?.call(Revision.t),
      orderByList: orderByList?.call(Revision.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Revision] matching the given query parameters.
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
  Future<Revision?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RevisionTable>? where,
    int? offset,
    _i1.OrderByBuilder<RevisionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RevisionTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Revision>(
      where: where?.call(Revision.t),
      orderBy: orderBy?.call(Revision.t),
      orderByList: orderByList?.call(Revision.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Revision] by its [id] or null if no such row exists.
  Future<Revision?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Revision>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Revision]s in the list and returns the inserted rows.
  ///
  /// The returned [Revision]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<Revision>> insert(
    _i1.DatabaseSession session,
    List<Revision> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<Revision>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [Revision] and returns the inserted row.
  ///
  /// The returned [Revision] will have its `id` field set.
  Future<Revision> insertRow(
    _i1.DatabaseSession session,
    Revision row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Revision>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Revision]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Revision>> update(
    _i1.DatabaseSession session,
    List<Revision> rows, {
    _i1.ColumnSelections<RevisionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Revision>(
      rows,
      columns: columns?.call(Revision.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Revision]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Revision> updateRow(
    _i1.DatabaseSession session,
    Revision row, {
    _i1.ColumnSelections<RevisionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Revision>(
      row,
      columns: columns?.call(Revision.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Revision] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Revision?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<RevisionUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Revision>(
      id,
      columnValues: columnValues(Revision.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Revision]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Revision>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<RevisionUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<RevisionTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RevisionTable>? orderBy,
    _i1.OrderByListBuilder<RevisionTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Revision>(
      columnValues: columnValues(Revision.t.updateTable),
      where: where(Revision.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Revision.t),
      orderByList: orderByList?.call(Revision.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Revision]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Revision>> delete(
    _i1.DatabaseSession session,
    List<Revision> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Revision>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Revision].
  Future<Revision> deleteRow(
    _i1.DatabaseSession session,
    Revision row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Revision>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Revision>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RevisionTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Revision>(
      where: where(Revision.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RevisionTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Revision>(
      where: where?.call(Revision.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Revision] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RevisionTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Revision>(
      where: where(Revision.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
