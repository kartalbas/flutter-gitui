import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_toggle_row.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

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
      icon: IconRole.warningCircle,
      variant: DialogVariant.destructive,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BaseLabel(confirmMessage, role: TextRole.body),
            if (widget.hasRemotes) ...[
              const BaseGap(Proximity.separate),
              const BaseSeparator(),
              const BaseGap(Proximity.grouped),
              BaseToggleRow(
                value: _deleteFromRemote,
                onChanged: (value) {
                  setState(() {
                    _deleteFromRemote = value ?? false;
                  });
                },
                label: loc.alsoDeleteFromRemote,
                description: loc.deleteFromRemoteSubtitle,
              ),
            ],
          ],
        ),
      ),
      actions: [
        DialogAction(
          label: loc.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        DialogAction(
          label: loc.delete,
          role: DialogActionRole.destructive,
          onPressed: () => Navigator.of(
            context,
          ).pop({'confirmed': true, 'deleteFromRemote': _deleteFromRemote}),
        ),
      ],
    );
  }
}
