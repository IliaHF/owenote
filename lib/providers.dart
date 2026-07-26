import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/money.dart';
import 'core/preferences.dart';
import 'data/app_database.dart';
import 'data/ledger_repository.dart';
import 'services/backup_service.dart';
import 'services/update_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(databaseProvider)),
);
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(repositoryProvider)),
);
final updateServiceProvider = Provider<UpdateService>(
  (ref) => UpdateService(ref.watch(repositoryProvider)),
);
final peopleProvider = StreamProvider<List<PersonBalance>>(
  (ref) => ref.watch(repositoryProvider).watchPeople(),
);
final personProvider = StreamProvider.family<Person?, String>(
  (ref, id) => ref.watch(repositoryProvider).watchPerson(id),
);
final personTransactionsProvider =
    StreamProvider.family<List<MoneyTransaction>, String>(
      (ref, id) => ref.watch(repositoryProvider).watchPersonTransactions(id),
    );
final historyProvider = StreamProvider<List<TransactionWithPerson>>(
  (ref) => ref.watch(repositoryProvider).watchAllTransactions(),
);
final biometricEnabledProvider = StreamProvider<bool>(
  (ref) => ref.watch(repositoryProvider).watchBiometricEnabled(),
);

final currencyProvider = StreamProvider<CurrencyOption>(
  (ref) => ref
      .watch(repositoryProvider)
      .watchCurrency()
      .map(
        (value) => CurrencyOption.values.firstWhere(
          (option) => option.name == value,
          orElse: () => CurrencyOption.chf,
        ),
      ),
);

final weekStartProvider = StreamProvider<WeekStartOption>(
  (ref) => ref
      .watch(repositoryProvider)
      .watchWeekStart()
      .map(
        (value) => WeekStartOption.values.firstWhere(
          (option) => option.name == value,
          orElse: () => WeekStartOption.system,
        ),
      ),
);
Future<void> seedDebugData(LedgerRepository repository) async {
  if (!kDebugMode || (await repository.getAllPeople()).isNotEmpty) return;
  final now = DateTime.now();
  final father = await repository.savePerson(name: 'Father', note: 'Family');
  await repository.saveTransaction(
    personId: father,
    direction: TransactionDirection.iGaveMoney,
    amountMinor: 25000,
    reason: 'Home repair',
    date: now.subtract(const Duration(days: 9)),
  );
  await repository.saveTransaction(
    personId: father,
    direction: TransactionDirection.iReceivedMoney,
    amountMinor: 7000,
    reason: 'Part payment',
    date: now.subtract(const Duration(days: 2)),
  );
  final brother = await repository.savePerson(name: 'Brother');
  await repository.saveTransaction(
    personId: brother,
    direction: TransactionDirection.iReceivedMoney,
    amountMinor: 4500,
    reason: 'Train tickets',
    date: now.subtract(const Duration(days: 4)),
  );
  final daniel = await repository.savePerson(name: 'Daniel');
  await repository.saveTransaction(
    personId: daniel,
    direction: TransactionDirection.iGaveMoney,
    amountMinor: 6000,
    reason: 'Dinner',
    date: now.subtract(const Duration(days: 1)),
  );
}
