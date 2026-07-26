import 'package:intl/intl.dart';

enum TransactionDirection { iGaveMoney, iReceivedMoney }

extension TransactionDirectionX on TransactionDirection {
  int apply(int amountMinor) =>
      this == TransactionDirection.iGaveMoney ? amountMinor : -amountMinor;

  String get label => this == TransactionDirection.iGaveMoney
      ? 'You gave money'
      : 'You received money';
}

class Money {
  const Money._();

  static String currency = 'CHF';
  static final _format = NumberFormat.decimalPatternDigits(
    locale: 'de_CH',
    decimalDigits: 2,
  );

  static String format(int minor, {bool absolute = false}) {
    final value = (absolute ? minor.abs() : minor) / 100;
    final number = _format
        .format(value)
        .replaceAll('\u00a0', ' ')
        .replaceAll("'", '\u2019');
    return '$currencyPrefix$number';
  }

  static String get currencyPrefix {
    final value = currency.trim();
    if (value.isEmpty) return '';
    return RegExp(r'^[A-Za-z]{2,}$').hasMatch(value) ? '$value ' : value;
  }

  static int? parseMinor(String input) {
    var value = input
        .trim()
        .replaceAll(RegExp(RegExp.escape(currency), caseSensitive: false), '')
        .replaceAll(' ', '');
    if (value.isEmpty) return null;
    if (value.contains(',') && value.contains('.')) {
      value = value.lastIndexOf(',') > value.lastIndexOf('.')
          ? value.replaceAll('.', '').replaceAll(',', '.')
          : value.replaceAll(',', '');
    } else {
      value = value.replaceAll(',', '.');
    }
    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final francs = int.parse(parts.first);
    final cents = parts.length == 1
        ? 0
        : int.parse(parts.last.padRight(2, '0'));
    return francs * 100 + cents;
  }

  static String balanceLabel(String name, int balance) {
    if (balance > 0) return '$name owes you ${format(balance)}';
    if (balance < 0) return 'You owe $name ${format(balance, absolute: true)}';
    return 'Your balance with $name will be settled.';
  }
}
