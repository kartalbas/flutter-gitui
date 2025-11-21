import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_text_field.dart';
import '../components/base_dialog.dart';
import '../components/base_button.dart';
import '../../core/git/models/remote.dart';

/// Dialog for renaming a remote
class RenameRemoteDialog extends StatefulWidget {
  final GitRemote remote;

  const RenameRemoteDialog({
    super.key,
    required this.remote,
  });

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
      icon: PhosphorIconsRegular.textAa,
      variant: DialogVariant.normal,
      content: Form(
        key: _formKey,
        child: BaseTextField(
          controller: _controller,
          label: l10n.newName,
          prefixIcon: PhosphorIconsRegular.textAa,
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
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: l10n.rename,
          variant: ButtonVariant.primary,
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
