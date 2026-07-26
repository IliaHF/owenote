import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owenote/theme/app_theme.dart';
import 'package:owenote/ui/choice_sheet.dart';
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

  testWidgets('choice sheet scrolls to every option', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          bottomSheet: ChoiceSheet<int>(
            title: 'Language',
            subtitle: 'Choose a language',
            values: List.generate(9, (index) => index),
            selected: 0,
            label: (value) => 'Language $value',
          ),
        ),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Language 8').hitTestable(), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Language 8').hitTestable(), findsOneWidget);
  });
}
