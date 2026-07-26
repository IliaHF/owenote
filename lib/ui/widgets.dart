import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:owenote/core/icons.dart';

import '../core/money.dart';
import '../data/app_database.dart';
import '../theme/app_theme.dart';

String initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.size = 52,
    this.heroTag,
  });
  final String name;
  final double size;
  final Object? heroTag;
  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          fontSize: size * .32,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
    return heroTag == null
        ? avatar
        : Hero(
            tag: heroTag!,
            child: Material(color: Colors.transparent, child: avatar),
          );
  }
}

class BalanceText extends StatelessWidget {
  const BalanceText({
    super.key,
    required this.balance,
    this.name,
    this.align = TextAlign.start,
  });
  final int balance;
  final String? name;
  final TextAlign align;
  @override
  Widget build(BuildContext context) {
    final text = balance > 0
        ? 'Owes you ${Money.format(balance)}'
        : balance < 0
        ? 'You owe ${Money.format(balance, absolute: true)}'
        : 'Settled';
    final color = balance > 0
        ? AppColors.positive
        : balance < 0
        ? AppColors.negative
        : AppColors.muted;
    return Semantics(
      label: name == null ? text : '$name: $text',
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.personName,
    this.onTap,
  });
  final MoneyTransaction transaction;
  final String? personName;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final direction = TransactionDirection.values.byName(transaction.direction);
    final gave = direction == TransactionDirection.iGaveMoney;
    final color = gave ? AppColors.positive : AppColors.negative;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: gave ? AppColors.positiveSoft : AppColors.negativeSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  gave
                      ? PhosphorIconsRegular.arrowUpRight
                      : PhosphorIconsRegular.arrowDownLeft,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (personName != null)
                      Text(
                        personName!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      transaction.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${direction.label} · ${DateFormat.yMMMd().format(transaction.transactionDate)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                Money.format(transaction.amountMinor),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(begin: .85, end: 1),
            curve: Curves.easeOutBack,
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

String friendlyError(Object error) => error is FormatException
    ? error.message
    : 'Something went wrong. Please try again.';
