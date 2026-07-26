import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owenote/theme/app_theme.dart';
import 'package:owenote/ui/widgets.dart';

void main() {
  testWidgets('balance wording is explicit and accessible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              BalanceText(balance: 18000, name: 'Father'),
              BalanceText(balance: -4500, name: 'Brother'),
              BalanceText(balance: 0, name: 'Daniel'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Owes you CHF 180.00'), findsOneWidget);
    expect(find.text('You owe CHF 45.00'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
  });
}
