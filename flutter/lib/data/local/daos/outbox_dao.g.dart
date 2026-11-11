// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$OutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $OutboxMutationsTable get outboxMutations => attachedDatabase.outboxMutations;
  OutboxDaoManager get managers => OutboxDaoManager(this);
}

class OutboxDaoManager {
  final _$OutboxDaoMixin _db;
  OutboxDaoManager(this._db);
  $$OutboxMutationsTableTableManager get outboxMutations =>
      $$OutboxMutationsTableTableManager(
        _db.attachedDatabase,
        _db.outboxMutations,
      );
}
