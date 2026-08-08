import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../generated/app_localizations.dart';
import '../components/base_text_field.dart';
import '../components/base_dialog.dart';
import '../../core/git/models/remote.dart';

/// Dialog for renaming a remote
class RenameRemoteDialog extends StatefulWidget {
  final GitRemote remote;

  const RenameRemoteDialog({super.key, required this.remote});

  @override
  State<RenameRemoteDialog> createState() => _RenameRemoteDialogState();
}

class _RenameRemoteDialogState extends State<RenameRemoteDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.remote.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BaseDialog(
      title: l10n.renameRemote(widget.remote.name),
      icon: IconRole.textAa,
      variant: DialogVariant.normal,
      onSubmit: () {
        if (_formKey.currentState!.validate()) {
          Navigator.of(context).pop(_controller.text);
        }
      },
      content: Form(
        key: _formKey,
        child: BaseTextField(
          controller: _controller,
          label: l10n.newName,
          prefixIcon: IconRole.textAa,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.enterName;
            }
            if (value.contains(' ')) {
              return l10n.nameCannotContainSpaces;
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.rename,
          role: DialogActionRole.affirmative,
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text);
            }
          },
        ),
      ],
    );
  }
}
