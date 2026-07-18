import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_button.dart';

/// Batch operations bar for selected tags
class TagsBatchOperationsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onPush;
  final VoidCallback onDelete;

  const TagsBatchOperationsBar({
    super.key,
    required this.selectedCount,
    required this.onPush,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.paddingM),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.pushTagsCount(selectedCount),
                leadingIcon: PhosphorIconsRegular.upload,
                onPressed: onPush,
                variant: ButtonVariant.secondary,
                size: ButtonSize.medium,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: AppTheme.paddingM),
            Expanded(
              child: BaseButton(
                label: AppLocalizations.of(context)!.deleteTagsCount(selectedCount),
                leadingIcon: PhosphorIconsRegular.trash,
                onPressed: onDelete,
                variant: ButtonVariant.danger,
                size: ButtonSize.medium,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
