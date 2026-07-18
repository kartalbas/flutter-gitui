import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';

/// Dialog for confirming deletion of multiple tags
class DeleteTagsDialog extends StatefulWidget {
  final Set<String> tagNames;
  final bool hasRemotes;

  const DeleteTagsDialog({
    super.key,
    required this.tagNames,
    this.hasRemotes = false,
  });

  @override
  State<DeleteTagsDialog> createState() => _DeleteTagsDialogState();
}

class _DeleteTagsDialogState extends State<DeleteTagsDialog> {
  bool _deleteFromRemote = true; // Default to checked

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final tagList = widget.tagNames.take(10).join(', ');
    final ellipsis = widget.tagNames.length > 10 ? '...' : '';
    final confirmMessage = loc.deleteTagsConfirm(
      widget.tagNames.length,
      tagList,
      ellipsis,
    );

    return BaseDialog(
      title: loc.deleteTagsDialog,
      icon: PhosphorIconsRegular.warningCircle,
      variant: DialogVariant.destructive,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyMediumLabel(confirmMessage),
            if (widget.hasRemotes) ...[
              const SizedBox(height: AppTheme.paddingL),
              const Divider(),
              const SizedBox(height: AppTheme.paddingM),
              CheckboxListTile(
                value: _deleteFromRemote,
                onChanged: (value) {
                  setState(() {
                    _deleteFromRemote = value ?? false;
                  });
                },
                title: BodyMediumLabel(loc.alsoDeleteFromRemote),
                subtitle: BodySmallLabel(loc.deleteFromRemoteSubtitle),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        BaseButton(
          label: loc.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        BaseButton(
          label: loc.delete,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop({
            'confirmed': true,
            'deleteFromRemote': _deleteFromRemote,
          }),
        ),
      ],
    );
  }
}
