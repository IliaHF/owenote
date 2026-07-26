import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:owenote/core/icons.dart';

import '../core/money.dart';
import '../data/ledger_repository.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import 'forms.dart';
import 'person_details_screen.dart';
import 'widgets.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currencyProvider);
    final people = ref.watch(peopleProvider);
    return SafeArea(
      bottom: false,
      child: people.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: PhosphorIconsRegular.warningCircle,
          title: 'Could not load people',
          message: friendlyError(e),
        ),
        data: (items) => CustomScrollView(
          key: const PageStorageKey('people-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'OweNote',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 22),
                    SummaryCard(people: items),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'People',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${items.length} ${items.length == 1 ? 'person' : 'people'}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: PhosphorIconsRegular.users,
                  title: 'Start with a person',
                  message:
                      'Add someone to keep a clear, private record of money given and received.',
                  action: FilledButton.icon(
                    onPressed: () => openPersonForm(context),
                    icon: const Icon(PhosphorIconsRegular.plus),
                    label: const Text('Add person'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => PersonCard(
                    key: ValueKey(items[index].person.id),
                    data: items[index],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.people});
  final List<PersonBalance> people;

  @override
  Widget build(BuildContext context) {
    final owedToYou = people.fold(
      0,
      (sum, person) =>
          sum + (person.balanceMinor > 0 ? person.balanceMinor : 0),
    );
    final youOwe = people.fold(
      0,
      (sum, person) =>
          sum + (person.balanceMinor < 0 ? -person.balanceMinor : 0),
    );
    final net = owedToYou - youOwe;
    return Semantics(
      container: true,
      label: 'Balance summary',
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF171714), Color(0xFF292923)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -46,
              top: -62,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                    width: 24,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Net balance',
                    style: TextStyle(color: Color(0xFFA4A49D), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      Money.format(net),
                      key: ValueKey((Money.currency, net)),
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall!.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF3B3B35), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryStat(
                          label: 'Owed to you',
                          value: Money.format(owedToYou),
                        ),
                      ),
                      Expanded(
                        child: _SummaryStat(
                          label: 'You owe',
                          value: Money.format(youOwe),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF92928C), fontSize: 12),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ],
  );
}

class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.data});
  final PersonBalance data;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PersonDetailsScreen(personId: data.person.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            PersonAvatar(
              name: data.person.name,
              heroTag: 'avatar-${data.person.id}',
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.person.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.lastActivity == null
                        ? 'No activity yet'
                        : 'Last activity ${DateFormat.MMMd().format(data.lastActivity!)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            BalanceText(
              balance: data.balanceMinor,
              name: data.person.name,
              align: TextAlign.end,
            ),
          ],
        ),
      ),
    ),
  );
}
