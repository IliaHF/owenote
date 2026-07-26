import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:owenote/core/icons.dart';
import '../core/localization.dart';

import '../core/money.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import 'forms.dart';
import 'widgets.dart';

class PersonDetailsScreen extends ConsumerWidget {
  const PersonDetailsScreen({super.key, required this.personId});
  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currencyProvider);
    final personAsync = ref.watch(personProvider(personId));
    final transactionsAsync = ref.watch(personTransactionsProvider(personId));
    return personAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: EmptyState(
          icon: PhosphorIconsRegular.warningCircle,
          title: context.l10n.text('couldNotOpenPerson'),
          message: friendlyError(context, e),
        ),
      ),
      data: (person) {
        if (person == null) {
          return Scaffold(
            body: EmptyState(
              icon: PhosphorIconsRegular.userMinus,
              title: context.l10n.text('personRemoved'),
              message: context.l10n.text('personRemovedMessage'),
            ),
          );
        }
        return transactionsAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: EmptyState(
              icon: PhosphorIconsRegular.warningCircle,
              title: context.l10n.text('couldNotLoadActivity'),
              message: friendlyError(context, e),
            ),
          ),
          data: (transactions) {
            final balance = transactions.fold(
              0,
              (sum, t) =>
                  sum +
                  TransactionDirection.values
                      .byName(t.direction)
                      .apply(t.amountMinor),
            );
            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  tooltip: context.l10n.text('back'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(PhosphorIconsRegular.caretLeft),
                ),
                actions: [
                  PopupMenuButton<String>(
                    tooltip: context.l10n.text('personMenu'),
                    icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
                    onSelected: (value) {
                      if (value == 'edit') {
                        openPersonForm(context, person: person);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(PhosphorIconsRegular.pencilSimple),
                          title: Text(context.l10n.text('editOrDelete')),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          PersonAvatar(
                            name: person.name,
                            size: 72,
                            heroTag: 'avatar-${person.id}',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            person.name,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          if (person.note != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              person.note!,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  context.l10n.text('currentBalance'),
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: Text(
                                    Money.format(balance, absolute: true),
                                    key: ValueKey(balance),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                BalanceText(
                                  balance: balance,
                                  name: person.name,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => openTransactionForm(
                                    context,
                                    person: person,
                                  ),
                                  icon: const Icon(PhosphorIconsRegular.plus),
                                  label: Text(
                                    context.l10n.text('addTransaction'),
                                  ),
                                ),
                              ),
                              if (balance != 0) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => openTransactionForm(
                                      context,
                                      person: person,
                                      settlement: true,
                                    ),
                                    icon: const Icon(
                                      PhosphorIconsRegular.handshake,
                                    ),
                                    label: Text(
                                      context.l10n.text('settleBalance'),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 26),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.l10n.text('activity'),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: PhosphorIconsRegular.receipt,
                        title: context.l10n.text('noTransactionsYet'),
                        message: context.l10n.text('noTransactionsYetMessage'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      sliver: SliverList.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final t = transactions[index];
                          final showDate =
                              index == 0 ||
                              !DateUtils.isSameDay(
                                t.transactionDate,
                                transactions[index - 1].transactionDate,
                              );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDate)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: index == 0 ? 0 : 16,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    DateFormat.yMMMMd(
                                      Localizations.localeOf(
                                        context,
                                      ).toLanguageTag(),
                                    ).format(t.transactionDate),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: TransactionTile(
                                  key: ValueKey(t.id),
                                  transaction: t,
                                  onTap: () => openTransactionForm(
                                    context,
                                    person: person,
                                    transaction: t,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
