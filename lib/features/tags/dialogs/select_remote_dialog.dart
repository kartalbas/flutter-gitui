import 'package:flutter/material.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/controllers/item_navigation_controller.dart';
import '../../../shared/widgets/keyboard_navigable_view.dart';

/// Dialog for selecting a remote repository.
///
/// The list is navigated with the arrow keys and confirmed with Enter, the
/// same semantics every other collection in the app has. It used to be a
/// plain column of tappable rows with no keyboard path at all, so a user who
/// reached this dialog with the keyboard had to pick up the mouse to answer
/// it.
class SelectRemoteDialog extends StatefulWidget {
  final List<String> remotes;

  const SelectRemoteDialog({super.key, required this.remotes});

  @override
  State<SelectRemoteDialog> createState() => _SelectRemoteDialogState();
}

class _SelectRemoteDialogState extends State<SelectRemoteDialog> {
  late final ItemNavigationController _listController;

  /// Height of one row, for keeping the highlight scrolled into view. A fixed
  /// extent is what lets the list scroll the highlight into view at all, so it
  /// is sized for the remote name plus the list item's own padding.
  static const double _rowExtent = 72;

  /// Cap on the list's height, so a workspace with many remotes scrolls
  /// instead of pushing the dialog past the screen. BaseDialog scrolls its
  /// content, which leaves the list unbounded without a cap like this.
  static const double _maxListHeight = 320;

  @override
  void initState() {
    super.initState();
    _listController = ItemNavigationController(onActivate: _pickIndex);
    // The first remote is highlighted from the start, so Enter without any
    // arrow key takes it - which for the common single-remote case makes the
    // whole dialog one keystroke.
    _listController.scheduleInitialHighlight();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _pickIndex(int index) {
    if (index < 0 || index >= widget.remotes.length) return;
    Navigator.of(context).pop(widget.remotes[index]);
  }

  void _confirm() {
    if (widget.remotes.isEmpty) return;
    final index = _listController.selectedIndex;
    _pickIndex(index < 0 ? 0 : index.clamp(0, widget.remotes.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final height = (widget.remotes.length * _rowExtent).clamp(
      _rowExtent,
      _maxListHeight,
    );

    return BaseDialog(
      title: loc.selectRemoteDialog,
      variant: DialogVariant.normal,
      // Enter takes the highlighted remote from anywhere in the dialog.
      onSubmit: widget.remotes.isEmpty ? null : _confirm,
      content: SizedBox(
        height: height,
        child: KeyboardNavigableListView(
          controller: _listController,
          itemCount: widget.remotes.length,
          itemExtent: _rowExtent,
          itemBuilder: (context, index, isSelected, containerHasFocus) =>
              BaseListItem(
                isSelected: isSelected,
                containerHasFocus: containerHasFocus,
                content: MenuItemLabel(widget.remotes[index]),
                onTap: () => _pickIndex(index),
              ),
        ),
      ),
    );
  }
}
