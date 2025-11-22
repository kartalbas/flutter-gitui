import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_text_field.dart';
import '../components/base_dialog.dart';
import '../components/base_button.dart';
import '../../core/git/models/remote.dart';

/// Dialog for editing a remote's URL
class EditRemoteUrlDialog extends StatefulWidget {
  final GitRemote remote;

  const EditRemoteUrlDialog({
    super.key,
    required this.remote,
  });

  @override
  State<EditRemoteUrlDialog> createState() => _EditRemoteUrlDialogState();
}

class _EditRemoteUrlDialogState extends State<EditRemoteUrlDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.remote.fetchUrl);
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
      title: l10n.editRemoteUrl(widget.remote.name),
      icon: PhosphorIconsRegular.link,
      variant: DialogVariant.normal,
      content: Form(
        key: _formKey,
        child: BaseTextField(
          controller: _controller,
          label: l10n.remoteUrlLabel,
          prefixIcon: PhosphorIconsRegular.link,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.enterUrl;
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
          label: l10n.save,
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
