import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import 'app_database.dart';

class PersonBalance {
  const PersonBalance(this.person, this.balanceMinor, this.lastActivity);
  final Person person;
  final int balanceMinor;
  final DateTime? lastActivity;
}

class TransactionWithPerson {
  const TransactionWithPerson(this.transaction, this.person);
  final MoneyTransaction transaction;
  final Person person;
}

class LedgerRepository {
  LedgerRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final AppDatabase db;
  final Uuid _uuid;

  Stream<List<PersonBalance>> watchPeople() {
    final gaveTotal = db.moneyTransactions.amountMinor.sum(
      filter: db.moneyTransactions.direction.equals(
        TransactionDirection.iGaveMoney.name,
      ),
    );
    final receivedTotal = db.moneyTransactions.amountMinor.sum(
      filter: db.moneyTransactions.direction.equals(
        TransactionDirection.iReceivedMoney.name,
      ),
    );
    final last = db.moneyTransactions.transactionDate.max();
    final query =
        db.select(db.people).join([
            leftOuterJoin(
              db.moneyTransactions,
              db.moneyTransactions.personId.equalsExp(db.people.id),
            ),
          ])
          ..addColumns([gaveTotal, receivedTotal, last])
          ..groupBy([db.people.id])
          ..orderBy([OrderingTerm.asc(db.people.name)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => PersonBalance(
              row.readTable(db.people),
              (row.read(gaveTotal) ?? 0) - (row.read(receivedTotal) ?? 0),
              row.read(last),
            ),
          )
          .toList(),
    );
  }

  Stream<Person?> watchPerson(String id) =>
      (db.select(db.people)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<Person?> getPerson(String id) =>
      (db.select(db.people)..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<List<MoneyTransaction>> watchPersonTransactions(String personId) =>
      (db.select(db.moneyTransactions)
            ..where((t) => t.personId.equals(personId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.transactionDate),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .watch();

  Stream<List<TransactionWithPerson>> watchAllTransactions() {
    final query =
        db.select(db.moneyTransactions).join([
          innerJoin(
            db.people,
            db.people.id.equalsExp(db.moneyTransactions.personId),
          ),
        ])..orderBy([
          OrderingTerm.desc(db.moneyTransactions.transactionDate),
          OrderingTerm.desc(db.moneyTransactions.createdAt),
        ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TransactionWithPerson(
              row.readTable(db.moneyTransactions),
              row.readTable(db.people),
            ),
          )
          .toList(),
    );
  }

  Future<int> balanceFor(
    String personId, {
    String? excludingTransactionId,
  }) async {
    final rows =
        await (db.select(db.moneyTransactions)..where(
              (t) =>
                  t.personId.equals(personId) &
                  (excludingTransactionId == null
                      ? const Constant(true)
                      : t.id.equals(excludingTransactionId).not()),
            ))
            .get();
    return rows.fold<int>(
      0,
      (sum, t) =>
          sum +
          TransactionDirection.values.byName(t.direction).apply(t.amountMinor),
    );
  }

  Future<String> savePerson({
    String? id,
    required String name,
    String? note,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw const FormatException('Please enter a name.');
    final now = DateTime.now();
    final personId = id ?? _uuid.v4();
    final existing = id == null ? null : await getPerson(id);
    await db
        .into(db.people)
        .insertOnConflictUpdate(
          PeopleCompanion.insert(
            id: personId,
            name: clean,
            note: Value(_nullable(note)),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
    return personId;
  }

  Future<void> deletePerson(String id) =>
      (db.delete(db.people)..where((p) => p.id.equals(id))).go();

  Future<String> saveTransaction({
    String? id,
    required String personId,
    required TransactionDirection direction,
    required int amountMinor,
    String? reason,
    String? note,
    required DateTime date,
  }) async {
    if (amountMinor <= 0) {
      throw const FormatException('Amount must be greater than zero.');
    }
    if (await getPerson(personId) == null) {
      throw const FormatException('This person no longer exists.');
    }
    final now = DateTime.now();
    final transactionId = id ?? _uuid.v4();
    final existing = id == null
        ? null
        : await (db.select(
            db.moneyTransactions,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
    await db
        .into(db.moneyTransactions)
        .insertOnConflictUpdate(
          MoneyTransactionsCompanion.insert(
            id: transactionId,
            personId: personId,
            direction: direction.name,
            amountMinor: amountMinor,
            reason: (reason?.trim().isNotEmpty ?? false)
                ? reason!.trim()
                : 'Transaction',
            note: Value(_nullable(note)),
            transactionDate: date,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
    return transactionId;
  }

  Future<String> settle({
    required String personId,
    required int amountMinor,
    DateTime? date,
  }) async {
    final balance = await balanceFor(personId);
    if (balance == 0) {
      throw const FormatException('This balance is already settled.');
    }
    if (amountMinor <= 0 || amountMinor > balance.abs()) {
      throw const FormatException(
        'Settlement must be within the outstanding balance.',
      );
    }
    return saveTransaction(
      personId: personId,
      direction: balance > 0
          ? TransactionDirection.iReceivedMoney
          : TransactionDirection.iGaveMoney,
      amountMinor: amountMinor,
      reason: 'Balance adjustment',
      date: date ?? DateTime.now(),
    );
  }

  Future<void> deleteTransaction(String id) =>
      (db.delete(db.moneyTransactions)..where((t) => t.id.equals(id))).go();

  Future<MoneyTransaction?> getTransaction(String id) => (db.select(
    db.moneyTransactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Person>> getAllPeople() => db.select(db.people).get();
  Future<List<MoneyTransaction>> getAllTransactions() =>
      db.select(db.moneyTransactions).get();

  Future<bool> biometricEnabled() async =>
      (await (db.select(
            db.appPreferences,
          )..where((p) => p.key.equals('biometricLock'))).getSingleOrNull())
          ?.value ==
      'true';

  Stream<bool> watchBiometricEnabled() =>
      (db.select(db.appPreferences)
            ..where((p) => p.key.equals('biometricLock')))
          .watchSingleOrNull()
          .map((p) => p?.value == 'true');

  Future<void> setBiometricEnabled(bool value) => db
      .into(db.appPreferences)
      .insertOnConflictUpdate(
        AppPreferencesCompanion.insert(
          key: 'biometricLock',
          value: value.toString(),
        ),
      );

  Stream<String> watchCurrency() => _watchPreference('currency', 'CHF');

  Future<void> setCurrency(String value) =>
      _setPreference('currency', value.trim());

  Stream<String> watchLanguage() => _watchPreference('language', 'system');

  Future<void> setLanguage(String value) => _setPreference('language', value);

  Stream<String> watchWeekStart() => _watchPreference('weekStart', 'system');

  Future<void> setWeekStart(String value) => _setPreference('weekStart', value);

  Future<DateTime?> lastUpdateCheck() async {
    final value = await _getPreference('lastUpdateCheck');
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> setLastUpdateCheck(DateTime value) =>
      _setPreference('lastUpdateCheck', value.toUtc().toIso8601String());

  Future<String?> _getPreference(String key) async => (await (db.select(
    db.appPreferences,
  )..where((p) => p.key.equals(key))).getSingleOrNull())?.value;

  Stream<String> _watchPreference(String key, String fallback) =>
      (db.select(db.appPreferences)..where((p) => p.key.equals(key)))
          .watchSingleOrNull()
          .map((preference) => preference?.value ?? fallback);

  Future<void> _setPreference(String key, String value) => db
      .into(db.appPreferences)
      .insertOnConflictUpdate(
        AppPreferencesCompanion.insert(key: key, value: value),
      );
  String? _nullable(String? value) =>
      (value?.trim().isEmpty ?? true) ? null : value!.trim();
}
