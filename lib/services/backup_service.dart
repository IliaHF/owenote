import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../data/app_database.dart';
import '../data/ledger_repository.dart';

class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.peopleCount,
    required this.transactionCount,
    required this.data,
  });
  final DateTime exportedAt;
  final int peopleCount;
  final int transactionCount;
  final Map<String, Object?> data;
}

class BackupService {
  BackupService(this.repository);
  final LedgerRepository repository;

  Future<Map<String, Object?>> exportData() async {
    final people = await repository.getAllPeople();
    final transactions = await repository.getAllTransactions();
    return {
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'people': people
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'note': p.note,
              'createdAt': p.createdAt.toIso8601String(),
              'updatedAt': p.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'transactions': transactions
          .map(
            (t) => {
              'id': t.id,
              'personId': t.personId,
              'direction': t.direction,
              'amountMinor': t.amountMinor,
              'reason': t.reason,
              'note': t.note,
              'transactionDate': t.transactionDate.toIso8601String(),
              'createdAt': t.createdAt.toIso8601String(),
              'updatedAt': t.updatedAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<String> exportJson() async =>
      const JsonEncoder.withIndent('  ').convert(await exportData());

  Future<File> saveBackup() async {
    final directory = await getApplicationDocumentsDirectory();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final file = File(
      '${directory.path}${Platform.pathSeparator}owenote-backup-$date.json',
    );
    return file.writeAsString(await exportJson(), flush: true);
  }

  Future<File> shareBackup() async {
    final file = await saveBackup();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'OweNote backup',
      text: 'OweNote local backup',
    );
    return file;
  }

  BackupPreview validate(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('This file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The backup must contain a JSON object.');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('This backup version is not supported.');
    }
    final exportedAt = _date(decoded['exportedAt'], 'exportedAt');
    final people = decoded['people'];
    final transactions = decoded['transactions'];
    if (people is! List || transactions is! List) {
      throw const FormatException(
        'The backup is missing people or transactions.',
      );
    }

    final ids = <String>{};
    for (final raw in people) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('A person record is invalid.');
      }
      final id = _string(raw['id'], 'person id');
      if (!Uuid.isValidUUID(fromString: id)) {
        throw const FormatException('A person ID is not a valid UUID.');
      }
      if (!ids.add(id)) {
        throw const FormatException(
          'The backup contains duplicate person IDs.',
        );
      }
      if (_string(raw['name'], 'person name').trim().isEmpty) {
        throw const FormatException('A person has an empty name.');
      }
      _date(raw['createdAt'], 'person createdAt');
      _date(raw['updatedAt'], 'person updatedAt');
    }
    final transactionIds = <String>{};
    for (final raw in transactions) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('A transaction record is invalid.');
      }
      final id = _string(raw['id'], 'transaction id');
      if (!Uuid.isValidUUID(fromString: id)) {
        throw const FormatException('A transaction ID is not a valid UUID.');
      }
      if (!transactionIds.add(id)) {
        throw const FormatException(
          'The backup contains duplicate transaction IDs.',
        );
      }
      final personId = _string(raw['personId'], 'personId');
      if (!ids.contains(personId)) {
        throw const FormatException(
          'A transaction refers to a missing person.',
        );
      }
      final direction = _string(raw['direction'], 'direction');
      if (!TransactionDirection.values.any((d) => d.name == direction)) {
        throw const FormatException('A transaction direction is invalid.');
      }
      if (raw['amountMinor'] is! int || (raw['amountMinor'] as int) <= 0) {
        throw const FormatException(
          'Transaction amounts must be positive integers.',
        );
      }
      _string(raw['reason'], 'reason');
      _date(raw['transactionDate'], 'transactionDate');
      _date(raw['createdAt'], 'transaction createdAt');
      _date(raw['updatedAt'], 'transaction updatedAt');
    }
    return BackupPreview(
      exportedAt: exportedAt,
      peopleCount: people.length,
      transactionCount: transactions.length,
      data: decoded,
    );
  }

  Future<void> replaceWith(BackupPreview preview) async {
    final people = preview.data['people']! as List;
    final transactions = preview.data['transactions']! as List;
    await repository.db.transaction(() async {
      await repository.db.delete(repository.db.moneyTransactions).go();
      await repository.db.delete(repository.db.people).go();
      for (final item in people.cast<Map<String, dynamic>>()) {
        await repository.db
            .into(repository.db.people)
            .insert(
              PeopleCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                note: Value(item['note'] as String?),
                createdAt: DateTime.parse(item['createdAt'] as String),
                updatedAt: DateTime.parse(item['updatedAt'] as String),
              ),
            );
      }
      for (final item in transactions.cast<Map<String, dynamic>>()) {
        await repository.db
            .into(repository.db.moneyTransactions)
            .insert(
              MoneyTransactionsCompanion.insert(
                id: item['id'] as String,
                personId: item['personId'] as String,
                direction: item['direction'] as String,
                amountMinor: item['amountMinor'] as int,
                reason: item['reason'] as String,
                note: Value(item['note'] as String?),
                transactionDate: DateTime.parse(
                  item['transactionDate'] as String,
                ),
                createdAt: DateTime.parse(item['createdAt'] as String),
                updatedAt: DateTime.parse(item['updatedAt'] as String),
              ),
            );
      }
    });
  }

  static String _string(Object? value, String field) {
    if (value is! String || value.isEmpty) {
      throw FormatException('The $field field is invalid.');
    }
    return value;
  }

  static DateTime _date(Object? value, String field) {
    if (value is! String) throw FormatException('The $field field is invalid.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('The $field date is invalid.');
    return parsed;
  }
}
