import 'package:flutter/material.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_menu_item.dart';

/// Dialog for selecting a remote repository
class SelectRemoteDialog extends StatelessWidget {
  final List<String> remotes;

  const SelectRemoteDialog({
    super.key,
    required this.remotes,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return BaseDialog(
      title: loc.selectRemoteDialog,
      variant: DialogVariant.normal,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: remotes.map((remote) {
          return BaseListItem(
            content: MenuItemLabel(remote),
            onTap: () => Navigator.of(context).pop(remote),
          );
        }).toList(),
      ),
    );
  }
}
