import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:owenote/core/icons.dart';

import '../core/money.dart';
import '../core/preferences.dart';
import '../data/ledger_repository.dart';
import '../providers.dart';
import 'forms.dart';
import 'widgets.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final search = TextEditingController();
  TransactionDirection? direction;
  DateTimeRange? dates;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool matches(TransactionWithPerson item) {
    final query = search.text.trim().toLowerCase();
    final t = item.transaction;
    if (query.isNotEmpty &&
        !'${item.person.name} ${t.reason} ${t.note ?? ''}'
            .toLowerCase()
            .contains(query)) {
      return false;
    }
    if (direction != null && t.direction != direction!.name) return false;
    if (dates != null) {
      final day = DateUtils.dateOnly(t.transactionDate);
      if (day.isBefore(DateUtils.dateOnly(dates!.start)) ||
          day.isAfter(DateUtils.dateOnly(dates!.end))) {
        return false;
      }
    }
    return true;
  }

  Future<void> pickDates() async {
    final weekStart = await ref.read(weekStartProvider.future);
    if (!mounted) return;
    final locale = switch (weekStart) {
      WeekStartOption.monday => const Locale('en', 'GB'),
      WeekStartOption.sunday => const Locale('en', 'US'),
      WeekStartOption.system => null,
    };
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      locale: locale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          dates ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) setState(() => dates = picked);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final history = ref.watch(historyProvider);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('history-scroll'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search people, reasons, notes',
                      prefixIcon: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                      ),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                search.clear();
                                setState(() {});
                              },
                              icon: const Icon(PhosphorIconsRegular.x),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          showCheckmark: false,
                          label: const Text('All directions'),
                          selected: direction == null,
                          onSelected: (_) => setState(() => direction = null),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          showCheckmark: false,
                          label: const Text('I gave'),
                          avatar: const Icon(
                            PhosphorIconsRegular.arrowUpRight,
                            size: 17,
                          ),
                          selected:
                              direction == TransactionDirection.iGaveMoney,
                          onSelected: (_) => setState(
                            () => direction =
                                direction == TransactionDirection.iGaveMoney
                                ? null
                                : TransactionDirection.iGaveMoney,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          showCheckmark: false,
                          label: const Text('I received'),
                          avatar: const Icon(
                            PhosphorIconsRegular.arrowDownLeft,
                            size: 17,
                          ),
                          selected:
                              direction == TransactionDirection.iReceivedMoney,
                          onSelected: (_) => setState(
                            () => direction =
                                direction == TransactionDirection.iReceivedMoney
                                ? null
                                : TransactionDirection.iReceivedMoney,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          showCheckmark: false,
                          label: Text(
                            dates == null
                                ? 'Date range'
                                : '${DateFormat.MMMd().format(dates!.start)} - ${DateFormat.MMMd().format(dates!.end)}',
                          ),
                          avatar: const Icon(
                            PhosphorIconsRegular.calendarBlank,
                            size: 17,
                          ),
                          selected: dates != null,
                          onSelected: (_) => dates == null
                              ? pickDates()
                              : setState(() => dates = null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          history.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: EmptyState(
                icon: PhosphorIconsRegular.warningCircle,
                title: 'Could not load history',
                message: friendlyError(e),
              ),
            ),
            data: (all) {
              final items = all.where(matches).toList();
              if (all.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyState(
                    icon: PhosphorIconsRegular.clockCounterClockwise,
                    title: 'No history yet',
                    message: 'Transactions from everyone will appear here.',
                  ),
                );
              }
              if (items.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyState(
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    title: 'No matching transactions',
                    message:
                        'Try clearing a filter or using a different search.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return TransactionTile(
                      key: ValueKey(item.transaction.id),
                      transaction: item.transaction,
                      personName: item.person.name,
                      onTap: () => openTransactionForm(
                        context,
                        person: item.person,
                        transaction: item.transaction,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
