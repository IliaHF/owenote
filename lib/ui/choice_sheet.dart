import 'package:flutter/material.dart';

import '../core/icons.dart';
import '../theme/app_theme.dart';

class ChoiceSheet<T> extends StatelessWidget {
  const ChoiceSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.selected,
    required this.label,
  });

  final String title;
  final String subtitle;
  final List<T> values;
  final T selected;
  final String Function(T value) label;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: values
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          tileColor: value == selected
                              ? AppColors.surfaceSoft
                              : Colors.white,
                          title: Text(
                            label(value),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: value == selected
                              ? const Icon(
                                  PhosphorIconsRegular.check,
                                  color: AppColors.positive,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
