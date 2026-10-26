// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LibraryEntitiesTable extends LibraryEntities
    with TableInfo<$LibraryEntitiesTable, LibraryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _remoteRevisionMeta = const VerificationMeta(
    'remoteRevision',
  );
  @override
  late final GeneratedColumn<int> remoteRevision = GeneratedColumn<int>(
    'remote_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    owner,
    id,
    kind,
    payload,
    deleted,
    remoteRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('remote_revision')) {
      context.handle(
        _remoteRevisionMeta,
        remoteRevision.isAcceptableOrUnknown(
          data['remote_revision']!,
          _remoteRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner, id};
  @override
  LibraryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryEntity(
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      remoteRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_revision'],
      )!,
    );
  }

  @override
  $LibraryEntitiesTable createAlias(String alias) {
    return $LibraryEntitiesTable(attachedDatabase, alias);
  }
}

class LibraryEntity extends DataClass implements Insertable<LibraryEntity> {
  final String owner;
  final String id;
  final String kind;
  final String payload;
  final bool deleted;
  final int remoteRevision;
  const LibraryEntity({
    required this.owner,
    required this.id,
    required this.kind,
    required this.payload,
    required this.deleted,
    required this.remoteRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['deleted'] = Variable<bool>(deleted);
    map['remote_revision'] = Variable<int>(remoteRevision);
    return map;
  }

  LibraryEntitiesCompanion toCompanion(bool nullToAbsent) {
    return LibraryEntitiesCompanion(
      owner: Value(owner),
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      deleted: Value(deleted),
      remoteRevision: Value(remoteRevision),
    );
  }

  factory LibraryEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryEntity(
      owner: serializer.fromJson<String>(json['owner']),
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      remoteRevision: serializer.fromJson<int>(json['remoteRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'deleted': serializer.toJson<bool>(deleted),
      'remoteRevision': serializer.toJson<int>(remoteRevision),
    };
  }

  LibraryEntity copyWith({
    String? owner,
    String? id,
    String? kind,
    String? payload,
    bool? deleted,
    int? remoteRevision,
  }) => LibraryEntity(
    owner: owner ?? this.owner,
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    deleted: deleted ?? this.deleted,
    remoteRevision: remoteRevision ?? this.remoteRevision,
  );
  LibraryEntity copyWithCompanion(LibraryEntitiesCompanion data) {
    return LibraryEntity(
      owner: data.owner.present ? data.owner.value : this.owner,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      remoteRevision: data.remoteRevision.present
          ? data.remoteRevision.value
          : this.remoteRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntity(')
          ..write('owner: $owner, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('deleted: $deleted, ')
          ..write('remoteRevision: $remoteRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(owner, id, kind, payload, deleted, remoteRevision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryEntity &&
          other.owner == this.owner &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.deleted == this.deleted &&
          other.remoteRevision == this.remoteRevision);
}

class LibraryEntitiesCompanion extends UpdateCompanion<LibraryEntity> {
  final Value<String> owner;
  final Value<String> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<bool> deleted;
  final Value<int> remoteRevision;
  final Value<int> rowid;
  const LibraryEntitiesCompanion({
    this.owner = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.deleted = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryEntitiesCompanion.insert({
    required String owner,
    required String id,
    required String kind,
    required String payload,
    this.deleted = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : owner = Value(owner),
       id = Value(id),
       kind = Value(kind),
       payload = Value(payload);
  static Insertable<LibraryEntity> custom({
    Expression<String>? owner,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<bool>? deleted,
    Expression<int>? remoteRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (deleted != null) 'deleted': deleted,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryEntitiesCompanion copyWith({
    Value<String>? owner,
    Value<String>? id,
    Value<String>? kind,
    Value<String>? payload,
    Value<bool>? deleted,
    Value<int>? remoteRevision,
    Value<int>? rowid,
  }) {
    return LibraryEntitiesCompanion(
      owner: owner ?? this.owner,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      deleted: deleted ?? this.deleted,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (remoteRevision.present) {
      map['remote_revision'] = Variable<int>(remoteRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntitiesCompanion(')
          ..write('owner: $owner, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('deleted: $deleted, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingMutationsTable extends PendingMutations
    with TableInfo<$PendingMutationsTable, PendingMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [owner, entityId, mutationId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMutation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner, entityId};
  @override
  PendingMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutation(
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
    );
  }

  @override
  $PendingMutationsTable createAlias(String alias) {
    return $PendingMutationsTable(attachedDatabase, alias);
  }
}

class PendingMutation extends DataClass implements Insertable<PendingMutation> {
  final String owner;
  final String entityId;
  final String mutationId;
  const PendingMutation({
    required this.owner,
    required this.entityId,
    required this.mutationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    map['entity_id'] = Variable<String>(entityId);
    map['mutation_id'] = Variable<String>(mutationId);
    return map;
  }

  PendingMutationsCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsCompanion(
      owner: Value(owner),
      entityId: Value(entityId),
      mutationId: Value(mutationId),
    );
  }

  factory PendingMutation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutation(
      owner: serializer.fromJson<String>(json['owner']),
      entityId: serializer.fromJson<String>(json['entityId']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'entityId': serializer.toJson<String>(entityId),
      'mutationId': serializer.toJson<String>(mutationId),
    };
  }

  PendingMutation copyWith({
    String? owner,
    String? entityId,
    String? mutationId,
  }) => PendingMutation(
    owner: owner ?? this.owner,
    entityId: entityId ?? this.entityId,
    mutationId: mutationId ?? this.mutationId,
  );
  PendingMutation copyWithCompanion(PendingMutationsCompanion data) {
    return PendingMutation(
      owner: data.owner.present ? data.owner.value : this.owner,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutation(')
          ..write('owner: $owner, ')
          ..write('entityId: $entityId, ')
          ..write('mutationId: $mutationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(owner, entityId, mutationId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutation &&
          other.owner == this.owner &&
          other.entityId == this.entityId &&
          other.mutationId == this.mutationId);
}

class PendingMutationsCompanion extends UpdateCompanion<PendingMutation> {
  final Value<String> owner;
  final Value<String> entityId;
  final Value<String> mutationId;
  final Value<int> rowid;
  const PendingMutationsCompanion({
    this.owner = const Value.absent(),
    this.entityId = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMutationsCompanion.insert({
    required String owner,
    required String entityId,
    required String mutationId,
    this.rowid = const Value.absent(),
  }) : owner = Value(owner),
       entityId = Value(entityId),
       mutationId = Value(mutationId);
  static Insertable<PendingMutation> custom({
    Expression<String>? owner,
    Expression<String>? entityId,
    Expression<String>? mutationId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (entityId != null) 'entity_id': entityId,
      if (mutationId != null) 'mutation_id': mutationId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMutationsCompanion copyWith({
    Value<String>? owner,
    Value<String>? entityId,
    Value<String>? mutationId,
    Value<int>? rowid,
  }) {
    return PendingMutationsCompanion(
      owner: owner ?? this.owner,
      entityId: entityId ?? this.entityId,
      mutationId: mutationId ?? this.mutationId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsCompanion(')
          ..write('owner: $owner, ')
          ..write('entityId: $entityId, ')
          ..write('mutationId: $mutationId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDocumentsTable extends LocalDocuments
    with TableInfo<$LocalDocumentsTable, LocalDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issueIdMeta = const VerificationMeta(
    'issueId',
  );
  @override
  late final GeneratedColumn<String> issueId = GeneratedColumn<String>(
    'issue_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pagesJsonMeta = const VerificationMeta(
    'pagesJson',
  );
  @override
  late final GeneratedColumn<String> pagesJson = GeneratedColumn<String>(
    'pages_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPendingUploadMeta =
      const VerificationMeta('coverPendingUpload');
  @override
  late final GeneratedColumn<bool> coverPendingUpload = GeneratedColumn<bool>(
    'cover_pending_upload',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cover_pending_upload" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    owner,
    issueId,
    sourcePath,
    pagesJson,
    coverPath,
    coverPendingUpload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('issue_id')) {
      context.handle(
        _issueIdMeta,
        issueId.isAcceptableOrUnknown(data['issue_id']!, _issueIdMeta),
      );
    } else if (isInserting) {
      context.missing(_issueIdMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('pages_json')) {
      context.handle(
        _pagesJsonMeta,
        pagesJson.isAcceptableOrUnknown(data['pages_json']!, _pagesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_pagesJsonMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('cover_pending_upload')) {
      context.handle(
        _coverPendingUploadMeta,
        coverPendingUpload.isAcceptableOrUnknown(
          data['cover_pending_upload']!,
          _coverPendingUploadMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner, issueId};
  @override
  LocalDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDocument(
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      issueId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issue_id'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      pagesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pages_json'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      coverPendingUpload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cover_pending_upload'],
      )!,
    );
  }

  @override
  $LocalDocumentsTable createAlias(String alias) {
    return $LocalDocumentsTable(attachedDatabase, alias);
  }
}

class LocalDocument extends DataClass implements Insertable<LocalDocument> {
  final String owner;
  final String issueId;
  final String sourcePath;
  final String pagesJson;
  final String? coverPath;
  final bool coverPendingUpload;
  const LocalDocument({
    required this.owner,
    required this.issueId,
    required this.sourcePath,
    required this.pagesJson,
    this.coverPath,
    required this.coverPendingUpload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    map['issue_id'] = Variable<String>(issueId);
    map['source_path'] = Variable<String>(sourcePath);
    map['pages_json'] = Variable<String>(pagesJson);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['cover_pending_upload'] = Variable<bool>(coverPendingUpload);
    return map;
  }

  LocalDocumentsCompanion toCompanion(bool nullToAbsent) {
    return LocalDocumentsCompanion(
      owner: Value(owner),
      issueId: Value(issueId),
      sourcePath: Value(sourcePath),
      pagesJson: Value(pagesJson),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      coverPendingUpload: Value(coverPendingUpload),
    );
  }

  factory LocalDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDocument(
      owner: serializer.fromJson<String>(json['owner']),
      issueId: serializer.fromJson<String>(json['issueId']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      pagesJson: serializer.fromJson<String>(json['pagesJson']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      coverPendingUpload: serializer.fromJson<bool>(json['coverPendingUpload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'issueId': serializer.toJson<String>(issueId),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'pagesJson': serializer.toJson<String>(pagesJson),
      'coverPath': serializer.toJson<String?>(coverPath),
      'coverPendingUpload': serializer.toJson<bool>(coverPendingUpload),
    };
  }

  LocalDocument copyWith({
    String? owner,
    String? issueId,
    String? sourcePath,
    String? pagesJson,
    Value<String?> coverPath = const Value.absent(),
    bool? coverPendingUpload,
  }) => LocalDocument(
    owner: owner ?? this.owner,
    issueId: issueId ?? this.issueId,
    sourcePath: sourcePath ?? this.sourcePath,
    pagesJson: pagesJson ?? this.pagesJson,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    coverPendingUpload: coverPendingUpload ?? this.coverPendingUpload,
  );
  LocalDocument copyWithCompanion(LocalDocumentsCompanion data) {
    return LocalDocument(
      owner: data.owner.present ? data.owner.value : this.owner,
      issueId: data.issueId.present ? data.issueId.value : this.issueId,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      pagesJson: data.pagesJson.present ? data.pagesJson.value : this.pagesJson,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      coverPendingUpload: data.coverPendingUpload.present
          ? data.coverPendingUpload.value
          : this.coverPendingUpload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDocument(')
          ..write('owner: $owner, ')
          ..write('issueId: $issueId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('pagesJson: $pagesJson, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverPendingUpload: $coverPendingUpload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    owner,
    issueId,
    sourcePath,
    pagesJson,
    coverPath,
    coverPendingUpload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDocument &&
          other.owner == this.owner &&
          other.issueId == this.issueId &&
          other.sourcePath == this.sourcePath &&
          other.pagesJson == this.pagesJson &&
          other.coverPath == this.coverPath &&
          other.coverPendingUpload == this.coverPendingUpload);
}

class LocalDocumentsCompanion extends UpdateCompanion<LocalDocument> {
  final Value<String> owner;
  final Value<String> issueId;
  final Value<String> sourcePath;
  final Value<String> pagesJson;
  final Value<String?> coverPath;
  final Value<bool> coverPendingUpload;
  final Value<int> rowid;
  const LocalDocumentsCompanion({
    this.owner = const Value.absent(),
    this.issueId = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.pagesJson = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverPendingUpload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDocumentsCompanion.insert({
    required String owner,
    required String issueId,
    required String sourcePath,
    required String pagesJson,
    this.coverPath = const Value.absent(),
    this.coverPendingUpload = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : owner = Value(owner),
       issueId = Value(issueId),
       sourcePath = Value(sourcePath),
       pagesJson = Value(pagesJson);
  static Insertable<LocalDocument> custom({
    Expression<String>? owner,
    Expression<String>? issueId,
    Expression<String>? sourcePath,
    Expression<String>? pagesJson,
    Expression<String>? coverPath,
    Expression<bool>? coverPendingUpload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (issueId != null) 'issue_id': issueId,
      if (sourcePath != null) 'source_path': sourcePath,
      if (pagesJson != null) 'pages_json': pagesJson,
      if (coverPath != null) 'cover_path': coverPath,
      if (coverPendingUpload != null)
        'cover_pending_upload': coverPendingUpload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDocumentsCompanion copyWith({
    Value<String>? owner,
    Value<String>? issueId,
    Value<String>? sourcePath,
    Value<String>? pagesJson,
    Value<String?>? coverPath,
    Value<bool>? coverPendingUpload,
    Value<int>? rowid,
  }) {
    return LocalDocumentsCompanion(
      owner: owner ?? this.owner,
      issueId: issueId ?? this.issueId,
      sourcePath: sourcePath ?? this.sourcePath,
      pagesJson: pagesJson ?? this.pagesJson,
      coverPath: coverPath ?? this.coverPath,
      coverPendingUpload: coverPendingUpload ?? this.coverPendingUpload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (issueId.present) {
      map['issue_id'] = Variable<String>(issueId.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (pagesJson.present) {
      map['pages_json'] = Variable<String>(pagesJson.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (coverPendingUpload.present) {
      map['cover_pending_upload'] = Variable<bool>(coverPendingUpload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDocumentsCompanion(')
          ..write('owner: $owner, ')
          ..write('issueId: $issueId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('pagesJson: $pagesJson, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverPendingUpload: $coverPendingUpload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LibraryEntitiesTable libraryEntities = $LibraryEntitiesTable(
    this,
  );
  late final $PendingMutationsTable pendingMutations = $PendingMutationsTable(
    this,
  );
  late final $LocalDocumentsTable localDocuments = $LocalDocumentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryEntities,
    pendingMutations,
    localDocuments,
  ];
}

typedef $$LibraryEntitiesTableCreateCompanionBuilder =
    LibraryEntitiesCompanion Function({
      required String owner,
      required String id,
      required String kind,
      required String payload,
      Value<bool> deleted,
      Value<int> remoteRevision,
      Value<int> rowid,
    });
typedef $$LibraryEntitiesTableUpdateCompanionBuilder =
    LibraryEntitiesCompanion Function({
      Value<String> owner,
      Value<String> id,
      Value<String> kind,
      Value<String> payload,
      Value<bool> deleted,
      Value<int> remoteRevision,
      Value<int> rowid,
    });

class $$LibraryEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryEntitiesTable> {
  $$LibraryEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryEntitiesTable> {
  $$LibraryEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryEntitiesTable> {
  $$LibraryEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => column,
  );
}

class $$LibraryEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryEntitiesTable,
          LibraryEntity,
          $$LibraryEntitiesTableFilterComposer,
          $$LibraryEntitiesTableOrderingComposer,
          $$LibraryEntitiesTableAnnotationComposer,
          $$LibraryEntitiesTableCreateCompanionBuilder,
          $$LibraryEntitiesTableUpdateCompanionBuilder,
          (
            LibraryEntity,
            BaseReferences<_$AppDatabase, $LibraryEntitiesTable, LibraryEntity>,
          ),
          LibraryEntity,
          PrefetchHooks Function()
        > {
  $$LibraryEntitiesTableTableManager(
    _$AppDatabase db,
    $LibraryEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> owner = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> remoteRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryEntitiesCompanion(
                owner: owner,
                id: id,
                kind: kind,
                payload: payload,
                deleted: deleted,
                remoteRevision: remoteRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String owner,
                required String id,
                required String kind,
                required String payload,
                Value<bool> deleted = const Value.absent(),
                Value<int> remoteRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryEntitiesCompanion.insert(
                owner: owner,
                id: id,
                kind: kind,
                payload: payload,
                deleted: deleted,
                remoteRevision: remoteRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryEntitiesTable, LibraryEntity>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LibraryEntitiesTable,
                    LibraryEntity
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryEntitiesTable,
      LibraryEntity,
      $$LibraryEntitiesTableFilterComposer,
      $$LibraryEntitiesTableOrderingComposer,
      $$LibraryEntitiesTableAnnotationComposer,
      $$LibraryEntitiesTableCreateCompanionBuilder,
      $$LibraryEntitiesTableUpdateCompanionBuilder,
      (
        LibraryEntity,
        BaseReferences<_$AppDatabase, $LibraryEntitiesTable, LibraryEntity>,
      ),
      LibraryEntity,
      PrefetchHooks Function()
    >;
typedef $$PendingMutationsTableCreateCompanionBuilder =
    PendingMutationsCompanion Function({
      required String owner,
      required String entityId,
      required String mutationId,
      Value<int> rowid,
    });
typedef $$PendingMutationsTableUpdateCompanionBuilder =
    PendingMutationsCompanion Function({
      Value<String> owner,
      Value<String> entityId,
      Value<String> mutationId,
      Value<int> rowid,
    });

class $$PendingMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );
}

class $$PendingMutationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingMutationsTable,
          PendingMutation,
          $$PendingMutationsTableFilterComposer,
          $$PendingMutationsTableOrderingComposer,
          $$PendingMutationsTableAnnotationComposer,
          $$PendingMutationsTableCreateCompanionBuilder,
          $$PendingMutationsTableUpdateCompanionBuilder,
          (
            PendingMutation,
            BaseReferences<
              _$AppDatabase,
              $PendingMutationsTable,
              PendingMutation
            >,
          ),
          PendingMutation,
          PrefetchHooks Function()
        > {
  $$PendingMutationsTableTableManager(
    _$AppDatabase db,
    $PendingMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> owner = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion(
                owner: owner,
                entityId: entityId,
                mutationId: mutationId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String owner,
                required String entityId,
                required String mutationId,
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion.insert(
                owner: owner,
                entityId: entityId,
                mutationId: mutationId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingMutationsTable, PendingMutation>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingMutationsTable,
                    PendingMutation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingMutationsTable,
      PendingMutation,
      $$PendingMutationsTableFilterComposer,
      $$PendingMutationsTableOrderingComposer,
      $$PendingMutationsTableAnnotationComposer,
      $$PendingMutationsTableCreateCompanionBuilder,
      $$PendingMutationsTableUpdateCompanionBuilder,
      (
        PendingMutation,
        BaseReferences<_$AppDatabase, $PendingMutationsTable, PendingMutation>,
      ),
      PendingMutation,
      PrefetchHooks Function()
    >;
typedef $$LocalDocumentsTableCreateCompanionBuilder =
    LocalDocumentsCompanion Function({
      required String owner,
      required String issueId,
      required String sourcePath,
      required String pagesJson,
      Value<String?> coverPath,
      Value<bool> coverPendingUpload,
      Value<int> rowid,
    });
typedef $$LocalDocumentsTableUpdateCompanionBuilder =
    LocalDocumentsCompanion Function({
      Value<String> owner,
      Value<String> issueId,
      Value<String> sourcePath,
      Value<String> pagesJson,
      Value<String?> coverPath,
      Value<bool> coverPendingUpload,
      Value<int> rowid,
    });

class $$LocalDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDocumentsTable> {
  $$LocalDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issueId => $composableBuilder(
    column: $table.issueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pagesJson => $composableBuilder(
    column: $table.pagesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get coverPendingUpload => $composableBuilder(
    column: $table.coverPendingUpload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDocumentsTable> {
  $$LocalDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issueId => $composableBuilder(
    column: $table.issueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pagesJson => $composableBuilder(
    column: $table.pagesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get coverPendingUpload => $composableBuilder(
    column: $table.coverPendingUpload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDocumentsTable> {
  $$LocalDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get issueId =>
      $composableBuilder(column: $table.issueId, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pagesJson =>
      $composableBuilder(column: $table.pagesJson, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<bool> get coverPendingUpload => $composableBuilder(
    column: $table.coverPendingUpload,
    builder: (column) => column,
  );
}

class $$LocalDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDocumentsTable,
          LocalDocument,
          $$LocalDocumentsTableFilterComposer,
          $$LocalDocumentsTableOrderingComposer,
          $$LocalDocumentsTableAnnotationComposer,
          $$LocalDocumentsTableCreateCompanionBuilder,
          $$LocalDocumentsTableUpdateCompanionBuilder,
          (
            LocalDocument,
            BaseReferences<_$AppDatabase, $LocalDocumentsTable, LocalDocument>,
          ),
          LocalDocument,
          PrefetchHooks Function()
        > {
  $$LocalDocumentsTableTableManager(
    _$AppDatabase db,
    $LocalDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> owner = const Value.absent(),
                Value<String> issueId = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String> pagesJson = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<bool> coverPendingUpload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDocumentsCompanion(
                owner: owner,
                issueId: issueId,
                sourcePath: sourcePath,
                pagesJson: pagesJson,
                coverPath: coverPath,
                coverPendingUpload: coverPendingUpload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String owner,
                required String issueId,
                required String sourcePath,
                required String pagesJson,
                Value<String?> coverPath = const Value.absent(),
                Value<bool> coverPendingUpload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDocumentsCompanion.insert(
                owner: owner,
                issueId: issueId,
                sourcePath: sourcePath,
                pagesJson: pagesJson,
                coverPath: coverPath,
                coverPendingUpload: coverPendingUpload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalDocumentsTable, LocalDocument>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalDocumentsTable,
                    LocalDocument
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDocumentsTable,
      LocalDocument,
      $$LocalDocumentsTableFilterComposer,
      $$LocalDocumentsTableOrderingComposer,
      $$LocalDocumentsTableAnnotationComposer,
      $$LocalDocumentsTableCreateCompanionBuilder,
      $$LocalDocumentsTableUpdateCompanionBuilder,
      (
        LocalDocument,
        BaseReferences<_$AppDatabase, $LocalDocumentsTable, LocalDocument>,
      ),
      LocalDocument,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LibraryEntitiesTableTableManager get libraryEntities =>
      $$LibraryEntitiesTableTableManager(_db, _db.libraryEntities);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(_db, _db.pendingMutations);
  $$LocalDocumentsTableTableManager get localDocuments =>
      $$LocalDocumentsTableTableManager(_db, _db.localDocuments);
}
