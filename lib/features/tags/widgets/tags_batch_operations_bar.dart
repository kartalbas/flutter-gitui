import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_layout.dart';

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
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: BaseInset(
        all: Inset.normal,
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: BaseButton(
                  label: AppLocalizations.of(
                    context,
                  )!.pushTagsCount(selectedCount),
                  leadingIcon: IconRole.upload,
                  onPressed: onPush,
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.medium,
                  fullWidth: true,
                ),
              ),
              const BaseGap(Proximity.grouped),
              Expanded(
                child: BaseButton(
                  label: AppLocalizations.of(
                    context,
                  )!.deleteTagsCount(selectedCount),
                  leadingIcon: IconRole.trash,
                  onPressed: onDelete,
                  variant: ButtonVariant.danger,
                  size: ButtonSize.medium,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
