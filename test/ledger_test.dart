import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owenote/core/money.dart';
import 'package:owenote/data/app_database.dart';
import 'package:owenote/data/ledger_repository.dart';
import 'package:owenote/services/backup_service.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repository;
  late BackupService backup;
  late String personId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LedgerRepository(db);
    backup = BackupService(repository);
    Money.currency = CurrencyOption.chf;
    personId = await repository.savePerson(name: 'Father');
  });
  tearDown(() => db.close());

  test(
    'giving money increases and receiving money decreases balance',
    () async {
      await repository.saveTransaction(
        personId: personId,
        direction: TransactionDirection.iGaveMoney,
        amountMinor: 10000,
        date: DateTime(2026),
      );
      expect(await repository.balanceFor(personId), 10000);
      await repository.saveTransaction(
        personId: personId,
        direction: TransactionDirection.iReceivedMoney,
        amountMinor: 3000,
        date: DateTime(2026),
      );
      expect(await repository.balanceFor(personId), 7000);
    },
  );

  test('homepage aggregate handles one-sided balances', () async {
    await repository.saveTransaction(
      personId: personId,
      direction: TransactionDirection.iGaveMoney,
      amountMinor: 18000,
      date: DateTime(2026),
    );

    final people = await repository.watchPeople().first;
    expect(people.single.balanceMinor, 18000);
    expect(await repository.balanceFor(personId), people.single.balanceMinor);
  });

  test('currency changes labels without changing minor-unit values', () {
    Money.currency = CurrencyOption.eur;
    expect(Money.format(125050), '€1’250.50');
    expect(Money.parseMinor('12.50'), 1250);
  });
  test(
    'full settlement creates a normal transaction and produces zero',
    () async {
      await repository.saveTransaction(
        personId: personId,
        direction: TransactionDirection.iGaveMoney,
        amountMinor: 18000,
        date: DateTime(2026),
      );
      await repository.settle(
        personId: personId,
        amountMinor: 18000,
        date: DateTime(2026, 7, 26),
      );
      expect(await repository.balanceFor(personId), 0);
      final transactions = await repository.getAllTransactions();
      final settlement = transactions.singleWhere(
        (t) => t.reason == 'Settlement',
      );
      expect(settlement.direction, TransactionDirection.iReceivedMoney.name);
      expect(settlement.amountMinor, 18000);
    },
  );

  test('partial settlement leaves the correct balance', () async {
    await repository.saveTransaction(
      personId: personId,
      direction: TransactionDirection.iGaveMoney,
      amountMinor: 18000,
      date: DateTime(2026),
    );
    await repository.settle(personId: personId, amountMinor: 10000);
    expect(await repository.balanceFor(personId), 8000);
  });

  test('settlement direction reverses when the user owes money', () async {
    await repository.saveTransaction(
      personId: personId,
      direction: TransactionDirection.iReceivedMoney,
      amountMinor: 4500,
      date: DateTime(2026),
    );
    await repository.settle(personId: personId, amountMinor: 2000);
    final settlement = (await repository.getAllTransactions()).singleWhere(
      (t) => t.reason == 'Settlement',
    );
    expect(settlement.direction, TransactionDirection.iGaveMoney.name);
    expect(await repository.balanceFor(personId), -2500);
  });

  test('editing and deleting a transaction recalculates balance', () async {
    final id = await repository.saveTransaction(
      personId: personId,
      direction: TransactionDirection.iGaveMoney,
      amountMinor: 1000,
      date: DateTime(2026),
    );
    await repository.saveTransaction(
      id: id,
      personId: personId,
      direction: TransactionDirection.iReceivedMoney,
      amountMinor: 2500,
      date: DateTime(2026),
    );
    expect(await repository.balanceFor(personId), -2500);
    await repository.deleteTransaction(id);
    expect(await repository.balanceFor(personId), 0);
  });

  test('CHF minor units use Swiss formatting', () {
    expect(Money.format(125050), 'CHF 1’250.50');
    expect(Money.parseMinor('1’250.50'), isNull);
    expect(Money.parseMinor('12.50'), 1250);
  });

  test('JSON export includes settlement transactions', () async {
    await repository.saveTransaction(
      personId: personId,
      direction: TransactionDirection.iGaveMoney,
      amountMinor: 5000,
      date: DateTime(2026),
    );
    await repository.settle(personId: personId, amountMinor: 5000);
    final data = jsonDecode(await backup.exportJson()) as Map<String, dynamic>;
    expect(
      (data['transactions'] as List).any((t) => t['reason'] == 'Settlement'),
      isTrue,
    );
  });

  test('invalid import data is rejected', () {
    const invalid =
        '{"schemaVersion":1,"exportedAt":"2026-07-26T12:00:00Z","people":[],"transactions":[{"id":"t","personId":"missing","direction":"bad","amountMinor":0}]}';
    expect(() => backup.validate(invalid), throwsFormatException);
  });

  test('valid backup replacement succeeds', () async {
    final exported = await backup.exportJson();
    await repository.savePerson(name: 'Temporary');
    final preview = backup.validate(exported);
    await backup.replaceWith(preview);
    final people = await repository.getAllPeople();
    expect(people.map((p) => p.name), ['Father']);
  });
}
