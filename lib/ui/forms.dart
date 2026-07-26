import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:owenote/core/icons.dart';
import '../core/localization.dart';

import '../core/money.dart';
import '../core/preferences.dart';
import '../data/app_database.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

Future<void> openPersonForm(BuildContext context, {Person? person}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PersonForm(person: person),
    );

class PersonForm extends ConsumerStatefulWidget {
  const PersonForm({super.key, this.person});
  final Person? person;
  @override
  ConsumerState<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends ConsumerState<PersonForm> {
  late final TextEditingController name = TextEditingController(
    text: widget.person?.name,
  );
  late final TextEditingController note = TextEditingController(
    text: widget.person?.note,
  );
  final formKey = GlobalKey<FormState>();
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await ref
          .read(repositoryProvider)
          .savePerson(id: widget.person?.id, name: name.text, note: note.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> delete() async {
    final transactionCount = await ref
        .read(repositoryProvider)
        .watchPersonTransactions(widget.person!.id)
        .first
        .then((v) => v.length);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('deletePersonQuestion')),
        content: Text(
          transactionCount == 0
              ? context.l10n.text('deletePersonNoTransactions')
              : context.l10n.text('deletePersonWithTransactions', {
                  'name': widget.person!.name,
                  'count': transactionCount,
                }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: Text(context.l10n.text('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(repositoryProvider).deletePerson(widget.person!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.text(
                widget.person == null ? 'addPerson' : 'editPerson',
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              autofocus: widget.person == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.l10n.text('name')),
              validator: (v) => v == null || v.trim().isEmpty
                  ? context.l10n.text('pleaseEnterName')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.text('noteOptional'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.check),
              label: Text(
                context.l10n.text(
                  widget.person == null ? 'addPerson' : 'saveChanges',
                ),
              ),
            ),
            if (widget.person != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: saving ? null : delete,
                icon: const Icon(PhosphorIconsRegular.trash),
                label: Text(context.l10n.text('deletePerson')),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.negative,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<void> openTransactionForm(
  BuildContext context, {
  required Person person,
  MoneyTransaction? transaction,
  bool duplicate = false,
  bool settlement = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => TransactionForm(
    person: person,
    transaction: transaction,
    duplicate: duplicate,
    settlement: settlement,
  ),
);

class TransactionForm extends ConsumerStatefulWidget {
  const TransactionForm({
    super.key,
    required this.person,
    this.transaction,
    this.duplicate = false,
    this.settlement = false,
  });
  final Person person;
  final MoneyTransaction? transaction;
  final bool duplicate;
  final bool settlement;
  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController amount = TextEditingController(
    text: widget.transaction == null
        ? ''
        : (widget.transaction!.amountMinor / 100).toStringAsFixed(2),
  );
  late final TextEditingController reason = TextEditingController(
    text: widget.transaction?.reason,
  );
  late final TextEditingController note = TextEditingController(
    text: widget.transaction?.note,
  );
  late TransactionDirection direction = widget.transaction == null
      ? TransactionDirection.iGaveMoney
      : TransactionDirection.values.byName(widget.transaction!.direction);
  late DateTime date = widget.transaction?.transactionDate ?? DateTime.now();
  int? baseBalance;
  bool saving = false;
  bool adjustmentReasonInitialized = false;

  @override
  void initState() {
    super.initState();
    amount.addListener(_refresh);
    _loadBalance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.settlement && !adjustmentReasonInitialized) {
      reason.text = context.l10n.text('settlement');
      adjustmentReasonInitialized = true;
    }
  }

  @override
  void dispose() {
    amount.removeListener(_refresh);
    amount.dispose();
    reason.dispose();
    note.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _loadBalance() async {
    final repo = ref.read(repositoryProvider);
    final base = await repo.balanceFor(
      widget.person.id,
      excludingTransactionId: widget.transaction != null && !widget.duplicate
          ? widget.transaction!.id
          : null,
    );
    if (!mounted) return;
    setState(() {
      baseBalance = base;
      if (widget.settlement) {
        direction = base > 0
            ? TransactionDirection.iReceivedMoney
            : TransactionDirection.iGaveMoney;
        amount.text = (base.abs() / 100).toStringAsFixed(2);
      }
    });
  }

  int? get amountMinor => Money.parseMinor(amount.text);
  int? get resultingBalance => baseBalance == null || amountMinor == null
      ? null
      : baseBalance! + direction.apply(amountMinor!);

  Future<void> pickDate() async {
    final weekStart = await ref.read(weekStartProvider.future);
    if (!mounted) return;
    final locale = switch (weekStart) {
      WeekStartOption.monday => const Locale('en', 'GB'),
      WeekStartOption.sunday => const Locale('en', 'US'),
      WeekStartOption.system => null,
    };
    final picked = await showDatePicker(
      context: context,
      locale: locale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    if (widget.settlement && amountMinor! > baseBalance!.abs()) {
      showMessage(context, context.l10n.text('settlementTooLarge'));
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(repositoryProvider)
          .saveTransaction(
            id: widget.duplicate ? null : widget.transaction?.id,
            personId: widget.person.id,
            direction: direction,
            amountMinor: amountMinor!,
            reason: reason.text,
            note: note.text,
            date: date,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('deleteTransactionQuestion')),
        content: Text(context.l10n.text('deleteTransactionMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: Text(context.l10n.text('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(repositoryProvider)
          .deleteTransaction(widget.transaction!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final editing = widget.transaction != null && !widget.duplicate;
    final result = resultingBalance;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.settlement
                    ? context.l10n.text('settleBalance')
                    : editing
                    ? context.l10n.text('editTransaction')
                    : widget.duplicate
                    ? context.l10n.text('duplicateTransaction')
                    : context.l10n.text('addTransaction'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                widget.settlement
                    ? context.l10n.text('settlementHistoryMessage')
                    : context.l10n.text('withPerson', {
                        'name': widget.person.name,
                      }),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              if (!widget.settlement)
                SegmentedButton<TransactionDirection>(
                  segments: [
                    ButtonSegment(
                      value: TransactionDirection.iGaveMoney,
                      label: Text(context.l10n.text('iGaveMoney')),
                      icon: Icon(PhosphorIconsRegular.arrowUpRight),
                    ),
                    ButtonSegment(
                      value: TransactionDirection.iReceivedMoney,
                      label: Text(context.l10n.text('iReceivedMoney')),
                      icon: Icon(PhosphorIconsRegular.arrowDownLeft),
                    ),
                  ],
                  selected: {direction},
                  onSelectionChanged: (v) =>
                      setState(() => direction = v.first),
                  showSelectedIcon: false,
                ),
              if (!widget.settlement) const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: context.l10n.text('amount'),
                  prefixText: Money.currencyPrefix.isEmpty
                      ? null
                      : Money.currencyPrefix,
                ),
                validator: (v) => amountMinor == null
                    ? context.l10n.text('invalidAmount')
                    : amountMinor! <= 0
                    ? context.l10n.text('positiveAmount')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reason,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.l10n.text('reasonOptional'),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.l10n.text('date'),
                    prefixIcon: Icon(PhosphorIconsRegular.calendarBlank),
                  ),
                  child: Text(
                    DateFormat.yMMMMd(
                      Localizations.localeOf(context).toLanguageTag(),
                    ).format(date),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: note,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.text('noteOptional'),
                  prefixIcon: Icon(PhosphorIconsRegular.note),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: result == null
                    ? const SizedBox(height: 18)
                    : Container(
                        key: ValueKey(result),
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: result == 0
                              ? AppColors.surfaceSoft
                              : result > 0
                              ? AppColors.positiveSoft
                              : AppColors.negativeSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          result == 0
                              ? localizedTransactionBalanceLabel(
                                  context,
                                  widget.person.name,
                                  0,
                                )
                              : context.l10n.text('afterTransaction', {
                                  'balance': localizedTransactionBalanceLabel(
                                    context,
                                    widget.person.name,
                                    result,
                                  ),
                                }),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: saving || baseBalance == null ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.settlement
                            ? PhosphorIconsRegular.handshake
                            : PhosphorIconsRegular.check,
                      ),
                label: Text(
                  widget.settlement
                      ? context.l10n.text('recordSettlement')
                      : editing
                      ? context.l10n.text('saveChanges')
                      : context.l10n.text('addTransaction'),
                ),
              ),
              if (editing) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          openTransactionForm(
                            context,
                            person: widget.person,
                            transaction: widget.transaction,
                            duplicate: true,
                          );
                        },
                        icon: const Icon(PhosphorIconsRegular.copy),
                        label: Text(context.l10n.text('duplicate')),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: remove,
                        icon: const Icon(PhosphorIconsRegular.trash),
                        label: Text(context.l10n.text('delete')),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.negative,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
