import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:owenote/core/icons.dart';

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
      if (mounted) showMessage(context, friendlyError(e));
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
        title: const Text('Delete this person?'),
        content: Text(
          transactionCount == 0
              ? 'This person will be removed from OweNote.'
              : 'This will permanently delete ${widget.person!.name} and all $transactionCount of their transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Delete'),
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
              widget.person == null ? 'Add person' : 'Edit person',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              autofocus: widget.person == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter a name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
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
                widget.person == null ? 'Add person' : 'Save changes',
              ),
            ),
            if (widget.person != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: saving ? null : delete,
                icon: const Icon(PhosphorIconsRegular.trash),
                label: const Text('Delete person'),
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
    text: widget.settlement ? 'Settlement' : widget.transaction?.reason,
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

  @override
  void initState() {
    super.initState();
    amount.addListener(_refresh);
    _loadBalance();
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
      showMessage(
        context,
        'A settlement cannot exceed the outstanding balance.',
      );
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
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'The balance will be recalculated without this transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Delete'),
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
                    ? 'Settle balance'
                    : editing
                    ? 'Edit transaction'
                    : widget.duplicate
                    ? 'Duplicate transaction'
                    : 'Add transaction',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                widget.settlement
                    ? 'This will be recorded as a normal transaction in your history.'
                    : 'With ${widget.person.name}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              if (!widget.settlement)
                SegmentedButton<TransactionDirection>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionDirection.iGaveMoney,
                      label: Text('I gave money'),
                      icon: Icon(PhosphorIconsRegular.arrowUpRight),
                    ),
                    ButtonSegment(
                      value: TransactionDirection.iReceivedMoney,
                      label: Text('I received'),
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
                  labelText: 'Amount',
                  prefixText: Money.currency.prefix.isEmpty
                      ? null
                      : Money.currency.prefix,
                  suffixText: Money.currency.suffix.isEmpty
                      ? null
                      : Money.currency.suffix,
                ),
                validator: (v) => amountMinor == null
                    ? 'Enter a valid amount with up to two decimals.'
                    : amountMinor! <= 0
                    ? 'Amount must be greater than zero.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reason,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(PhosphorIconsRegular.calendarBlank),
                  ),
                  child: Text(DateFormat.yMMMMd().format(date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: note,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
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
                              ? Money.balanceLabel(widget.person.name, 0)
                              : 'After this transaction, ${Money.balanceLabel(widget.person.name, result).toLowerCase()}.',
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
                      ? 'Record settlement'
                      : editing
                      ? 'Save changes'
                      : 'Add transaction',
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
                        label: const Text('Duplicate'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: remove,
                        icon: const Icon(PhosphorIconsRegular.trash),
                        label: const Text('Delete'),
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
