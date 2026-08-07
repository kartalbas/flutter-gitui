import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_providers.dart';
import '../../core/git/destructive_action.dart';
import '../../generated/app_localizations.dart';
import '../components/base_dialog.dart';
import '../components/base_label.dart';
import '../components/base_text_field.dart';
import '../theme/app_theme.dart';

/// The single gate every destructive Git action passes through, so a
/// destructive action can never reach git without a confirmation the user can
/// recognise. Returns true when the user confirmed (or has silenced the
/// recoverable tiers), false when they cancelled or dismissed.
///
/// The prompt's strength scales with [DestructiveAction.tier]:
/// - the two recoverable local tiers are silenced when the user turns the
///   "confirm destructive actions" setting off, and otherwise use the softer
///   confirmation styling;
/// - the permanent and remote-affecting tiers always ask and use the red
///   destructive styling, because there is no reflog or local copy to recover
///   from and — for the remote tier — the loss is not even the user's own;
/// - the remote tier additionally demands that the user retype
///   [confirmationToken] (the branch, tag or remote about to be destroyed)
///   before the confirm button enables.
///
/// [title], [message] and [confirmLabel] stay with the caller so each action
/// keeps its own localized, context-specific wording (the commit hash, the
/// branch name, the file path); the tier alone lives in [DestructiveAction].
/// [confirmationToken] is required for remote-permanent actions and ignored
/// for every other tier, so a call site that picks its action at runtime can
/// always pass the token unconditionally.
Future<bool> confirmDestructive({
  required BuildContext context,
  required WidgetRef ref,
  required DestructiveAction action,
  required String title,
  required String message,
  String? confirmLabel,
  IconData? icon,
  String? confirmationToken,
}) async {
  final tier = action.tier;

  // The remote tier cannot run without a token: silently downgrading the
  // strongest gate to a plain dialog would be exactly the kind of quiet
  // weakening this file exists to prevent. Throwing (not asserting) keeps
  // release builds honest too; the lint rule of #309 adds the compile-time
  // net on top.
  if (tier == DangerTier.remotePermanent &&
      (confirmationToken == null || confirmationToken.isEmpty)) {
    throw ArgumentError.value(
      confirmationToken,
      'confirmationToken',
      'A remote-permanent action must name the token the user retypes '
          '(the branch, tag or remote about to be destroyed)',
    );
  }

  if (tier.isSilenceable && !ref.read(confirmDestructiveActionsProvider)) {
    return true;
  }

  final l10n = AppLocalizations.of(context)!;

  if (tier == DangerTier.remotePermanent) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _TypeToConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel ?? l10n.confirm,
        icon: icon,
        token: confirmationToken!,
      ),
    );
    return confirmed ?? false;
  }

  final destructive = tier.usesDestructiveStyle;
  final confirmed = await BaseDialog.show<bool>(
    context: context,
    dialog: BaseDialog(
      title: title,
      icon: icon,
      variant: destructive
          ? DialogVariant.destructive
          : DialogVariant.confirmation,
      // Enter confirms the recoverable tiers only. The permanent tier keeps
      // Enter dead so the key repeat of the keystroke that triggered the
      // action cannot also wave its confirmation through. (The remote tier
      // above arms Enter safely: it does nothing until the typed token
      // matches, and no key repeat can type a ref name.) Esc cancels either
      // way.
      onSubmit: destructive ? null : () => Navigator.of(context).pop(true),
      content: BodyMediumLabel(message),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        // The tier decides the role, exactly as it decides the styling and
        // whether Enter is armed above: the two recoverable tiers are asking
        // the user to go ahead, the permanent ones are asking them to accept
        // a loss. The role is what carries that to a design language which
        // expresses destruction on the action rather than on the dialog
        // (Cupertino's isDestructiveAction), where our red fill has no
        // counterpart at all.
        DialogAction(
          label: confirmLabel ?? l10n.confirm,
          role: destructive
              ? DialogActionRole.destructive
              : DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The remote tier's gate: the confirm button stays disabled and Enter stays
/// inert until the user has retyped [token] exactly.
///
/// The match is exact and case-sensitive with no normalization: git ref names
/// are case-sensitive identifiers — on the remote, "Release" and "release"
/// are different branches — so anything looser would confirm a token the user
/// did not actually reproduce.
class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.token,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String token;
  final IconData? icon;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'TypeToConfirmField');

  // Two Enter paths funnel into _submit: the dialog-level key handler (which
  // sees Enter even while the single-line field has focus, because
  // focusedEditableKeepsEnter() only spares multiline editables) and the
  // field's own onSubmitted. Whichever fires, only the first may pop, or the
  // screen below the dialog would be popped too.
  bool _popped = false;

  bool get _matches => _controller.text == widget.token;

  @override
  void initState() {
    super.initState();
    // Every keystroke re-evaluates the match: the confirm button enables the
    // moment the token is reproduced and disables again if it is edited away.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_matches || _popped) return;
    _popped = true;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Inline error the moment the input stops being a prefix of the token:
    // the user learns about a typo at the keystroke that made it, not after
    // finishing the whole word and wondering why the button stays dead.
    final mismatch =
        _controller.text.isNotEmpty &&
        !widget.token.startsWith(_controller.text);

    return BaseDialog(
      title: widget.title,
      icon: widget.icon,
      variant: DialogVariant.destructive,
      // Unlike the other destructive dialogs, Enter is armed here — but it
      // runs through _submit, which does nothing until the typed token
      // matches. The key repeat of the keystroke that opened this dialog
      // cannot type a ref name, so the reason Enter stays dead on the
      // permanent tier does not apply once a token stands in the way.
      onSubmit: _submit,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyMediumLabel(widget.message),
          const SizedBox(height: AppTheme.paddingL),
          BodyMediumLabel(l10n.typeToConfirmInstruction(widget.token)),
          const SizedBox(height: AppTheme.paddingM),
          BaseTextField(
            controller: _controller,
            focusNode: _fieldFocus,
            // First field of the dialog takes focus so the user can start
            // typing immediately; BaseDialog's focus wrapper defers to it.
            autofocus: true,
            // The floating label is the token itself, so the expected text
            // stays in view while the user types.
            label: widget.token,
            // Escape must always flee this dialog, never spend its press on
            // clearing a half-typed token: a user bailing out of a
            // destructive prompt must not need a second Escape.
            escapeClears: false,
            errorText: mismatch ? l10n.typeToConfirmMismatch : null,
            onSubmitted: (_) {
              if (_matches) {
                _submit();
              } else {
                // The field's default submit behaviour gives focus away; a
                // failed Enter must leave the user exactly where they were,
                // still typing.
                _fieldFocus.requestFocus();
              }
            },
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: widget.confirmLabel,
          role: DialogActionRole.destructive,
          // Disabled until the token matches: a stray click on the red
          // button cannot confirm what the keyboard has not yet proven.
          // Enter is gated by the same predicate inside _submit, so the two
          // paths cannot disagree.
          enabled: _matches,
          onPressed: _submit,
        ),
      ],
    );
  }
}
