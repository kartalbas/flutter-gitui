import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import '../../generated/app_localizations.dart';
import '../../core/constants/constants.dart';
import '../../shared/theme/app_theme.dart';
import '../utils/keyboard_guards.dart';
import 'base_button.dart';
import 'base_label.dart';

/// Dialog visual variants
enum DialogVariant {
  /// Standard dialog
  normal,

  /// Confirmation dialog (OK/Cancel)
  confirmation,

  /// Destructive action dialog (red accent)
  destructive,
}

/// What an action at the bottom of a dialog *means*, independent of how any
/// one design language chooses to draw it.
///
/// The role, not a button variant, is what a dialog declares, because the
/// three design languages disagree about how emphasis is expressed and even
/// about where the actions go: Material 3 and Apple's HIG put the affirmative
/// action last (on the right), Fluent 2 puts it **first** (on the left) and
/// stretches every action to equal width, and Cupertino expresses "this one is
/// destructive" and "this one is the default" on the action itself
/// (`CupertinoDialogAction.isDestructiveAction` / `isDefaultAction`) rather
/// than on the dialog. A caller that hands over a ready-made button has
/// already made all three of those decisions for every language at once, and
/// none of them can be undone by the code that renders the dialog — which is
/// why [BaseDialog.actions] carries data with a role instead of widgets.
enum DialogActionRole {
  /// Completes the dialog by doing the thing it asked about: Save, Create,
  /// Merge, Continue, and the OK of a dialog whose only job is to be
  /// acknowledged.
  ///
  /// A dialog has **at most one** affirmative action — it is the one a
  /// language may single out as its default, and "the default" is not a set.
  /// A dialog offering several equally weighted ways forward gives them all
  /// [neutral] instead ([BaseDialog] asserts this).
  affirmative,

  /// Completes the dialog by destroying something: Delete, Discard, Force
  /// delete, Reset --hard, Abort.
  ///
  /// Separate from [affirmative] rather than a flag on it, because a dialog
  /// may legitimately offer two of them (delete and force-delete) while it may
  /// only ever have one default, and because two languages draw a destructive
  /// action with their own treatment rather than with a red tint we choose.
  destructive,

  /// Leaves the dialog without doing what it asked: Cancel, Close, Not now.
  /// The lowest-emphasis action, and the one Escape is the keyboard
  /// equivalent of.
  dismissive,

  /// Any other action the dialog offers, weighted between [dismissive] and
  /// [affirmative]: a second way forward that is not *the* way forward (Keep
  /// both, Download only, a soft reset next to a hard one), or an auxiliary
  /// action that does not close the dialog at all (Copy, Refresh, Clear
  /// filters).
  neutral,
}

/// One action at the bottom of a [BaseDialog], as data rather than as a
/// widget.
///
/// Everything here is language-neutral: a string, a callback, a role, two
/// flags and an [IconData] (which Flutter's Material, Cupertino and Fluent
/// libraries all accept). Nothing in it names a Material class, a colour or a
/// size, so each design language can render the same action its own way — put
/// it on the other side of the row, stretch it to equal width, or turn it into
/// a `CupertinoDialogAction` with the alert's dividers.
class DialogAction {
  const DialogAction({
    required this.label,
    required this.onPressed,
    required this.role,
    this.icon,
    this.enabled = true,
    this.isLoading = false,
  });

  /// The action's text. Also its accessible name, and in the languages that
  /// stack their actions full-width the only thing distinguishing them.
  final String label;

  /// What the action does. Null disables it, exactly as on a button, so a
  /// call site that already computes `condition ? callback : null` needs no
  /// rewriting; [enabled] is the readable alternative for the cases that do
  /// have a callback and simply may not run it yet.
  final VoidCallback? onPressed;

  /// What the action means. See [DialogActionRole]: this is the single piece
  /// of information the widget form threw away, and the reason this type
  /// exists.
  final DialogActionRole role;

  /// An optional leading glyph. [IconData] is the one visual value that
  /// survives the language change unharmed — all three libraries take it —
  /// though which *glyph* is right per language remains a skin's decision.
  final IconData? icon;

  /// Whether the action may run right now. Distinct from a null [onPressed]
  /// only in how it reads at the call site: a dialog whose confirm button
  /// waits for a typed token or a validated form says
  /// `enabled: _tokenMatches` and keeps its callback visible, instead of
  /// hiding it inside a ternary.
  final bool enabled;

  /// Whether the action is currently running, so the dialog can show progress
  /// in its place. A loading action is never invokable.
  final bool isLoading;

  /// The resolved answer to "can the user invoke this now", folding together
  /// the three ways an action can be unavailable.
  bool get isEnabled => enabled && !isLoading && onPressed != null;
}

/// How Material 3 — this app's current and default design language — expresses
/// each [DialogActionRole].
///
/// This mapping is deliberately the *only* place a role becomes a button
/// variant. Another language expresses the same four roles differently (Fluent
/// gives the affirmative its accent fill and leaves the rest as standard
/// buttons; Cupertino has no fills at all and marks the default action with
/// weight), so a call site that picked a variant itself would have been
/// picking Material's answer for every language.
ButtonVariant _variantForRole(DialogActionRole role) => switch (role) {
  DialogActionRole.affirmative => ButtonVariant.primary,
  DialogActionRole.destructive => ButtonVariant.danger,
  DialogActionRole.dismissive => ButtonVariant.tertiary,
  DialogActionRole.neutral => ButtonVariant.secondary,
};

/// Whether the widget holding primary focus is a multiline editable text.
///
/// Enter inside such a field inserts a newline; a dialog-level Enter-to-submit
/// handler must let it through or the field becomes impossible to fill.
/// Single-line fields lose nothing: their Enter has no editing meaning.
///
/// The rule itself lives in [focusedEditableOwnsKey]; this asks it about a
/// plain Enter press for callers that hold no key event of their own.
bool focusedEditableKeepsEnter() => focusedEditableOwnsKey(
  const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.enter,
    logicalKey: LogicalKeyboardKey.enter,
    timeStamp: Duration.zero,
  ),
);

/// Base component for all dialog patterns in the app.
///
/// Provides 3 variants:
/// - Normal: Standard dialog
/// - Confirmation: OK/Cancel dialog
/// - Destructive: Red accent for destructive actions
///
/// Example usage:
/// ```dart
/// BaseDialog.show(
///   context: context,
///   dialog: BaseDialog(
///     title: 'Delete branch?',
///     content: Text('This action cannot be undone.'),
///     variant: DialogVariant.destructive,
///     icon: PhosphorIconsRegular.warning,
///     actions: [
///       DialogAction(
///         label: 'Cancel',
///         role: DialogActionRole.dismissive,
///         onPressed: () => Navigator.pop(context, false),
///       ),
///       DialogAction(
///         label: 'Delete',
///         role: DialogActionRole.destructive,
///         onPressed: () {
///           deleteBranch();
///           Navigator.pop(context, true);
///         },
///       ),
///     ],
///   ),
/// );
/// ```
class BaseDialog extends StatelessWidget {
  const BaseDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.variant = DialogVariant.normal,
    this.icon,
    this.maxWidth = AppConstants.defaultDialogWidth,
    this.barrierDismissible = true,
    this.onSubmit,
  });

  /// Dialog title
  final String title;

  /// Dialog content (scrollable if long).
  ///
  /// The content is wrapped in a [SingleChildScrollView], which hands it
  /// unbounded height. A [Column] passed here must therefore not contain an
  /// [Expanded], [Spacer] or tight [Flexible] child - a scroll view leaves no
  /// "remaining space" to distribute, so such a child is a RenderFlex error,
  /// not a layout. Give an inner list a bounded height instead (for example a
  /// [ConstrainedBox] with `maxHeight` around a shrink-wrapped list), so the
  /// dialog grows with its content up to the cap and scrolls beyond it.
  /// [build] asserts the direct-child case in debug builds.
  final Widget content;

  /// The actions along the bottom of the dialog, in reading order — typically
  /// a dismissive Cancel followed by the affirmative confirm.
  ///
  /// Data, not widgets, so that the code rendering the dialog can still tell
  /// which action is which: see [DialogActionRole] for why that matters and
  /// what a widget list made impossible. The order given here is the order
  /// Material renders and the order Tab walks; a design language that arranges
  /// them differently derives its own order from the roles rather than from
  /// the position in this list.
  final List<DialogAction>? actions;

  /// Dialog variant (visual style)
  final DialogVariant variant;

  /// Optional icon in title area
  final IconData? icon;

  /// Maximum dialog width
  final double maxWidth;

  /// Allow closing by clicking outside dialog
  final bool barrierDismissible;

  /// The dialog's primary action, triggered by Enter from anywhere inside it.
  ///
  /// A dialog that can only be completed with the mouse is unfinished: Esc
  /// already cancels from anywhere, and Enter has to confirm the same way.
  /// A multiline field keeps its Enter (it inserts a newline there); every
  /// other focus position submits. Left null for a dialog with no single
  /// primary action — or deliberately for one whose affirmative action
  /// destroys something, where Enter must never wave the loss through
  /// (see [showDestructiveDialog]).
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    // Turn the runtime RenderFlex error into an immediate, named one: the
    // content sits in a scroll view, so a flex child of a content Column can
    // never get the remaining space it asks for. This mirrors RenderFlex's
    // own condition (a tight flex child always throws under unbounded
    // height; a loose Flexible only when the Column wants MainAxisSize.max),
    // so a legal loose Flexible in a min Column stays allowed. Only direct
    // children are checkable here; the doc on [content] covers the rest.
    assert(() {
      final inner = content;
      if (inner is Flex && inner.direction == Axis.vertical) {
        for (final child in inner.children) {
          final alwaysThrows =
              child is Spacer ||
              (child is Flexible && child.fit == FlexFit.tight);
          final throwsInMaxColumn =
              child is Flexible &&
              child.fit == FlexFit.loose &&
              inner.mainAxisSize == MainAxisSize.max;
          if (alwaysThrows || throwsInMaxColumn) {
            throw FlutterError(
              'BaseDialog content must not contain an unbounded flex child.\n'
              'BaseDialog scrolls its content, so the content Column has '
              'unbounded height and a ${child.runtimeType} inside it is a '
              'RenderFlex error, not a layout. Give the child a bounded '
              'height instead, e.g. a ConstrainedBox(maxHeight: ...) around '
              'a shrink-wrapped list.',
            );
          }
        }
      }
      return true;
    }());

    // At most one action may be the affirmative one. Several languages single
    // the affirmative action out - Cupertino makes it the default action,
    // Fluent moves it to the head of the row - and none of them can do that
    // with a set of two, so a second affirmative would silently make the
    // dialog unrenderable in a language other than this one. Peers that are
    // all equally a way forward take DialogActionRole.neutral instead.
    assert(() {
      final affirmative =
          actions
              ?.where((a) => a.role == DialogActionRole.affirmative)
              .length ??
          0;
      if (affirmative > 1) {
        throw FlutterError(
          'BaseDialog "$title" declares $affirmative affirmative actions.\n'
          'A dialog has at most one: the affirmative action is the one a '
          'design language may single out as its default, and a default is '
          'not a set. Give the equally weighted alternatives '
          'DialogActionRole.neutral, and keep DialogActionRole.affirmative '
          'for the single action that completes the dialog.',
        );
      }
      return true;
    }());

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Determine icon and color based on variant
    IconData? variantIcon = icon;
    Color? iconColor;
    Color titleColor;

    if (icon == null) {
      switch (variant) {
        case DialogVariant.normal:
          variantIcon = null;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.confirmation:
          variantIcon = PhosphorIconsRegular.question;
          iconColor = colorScheme.primary;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.destructive:
          variantIcon = PhosphorIconsRegular.warning;
          iconColor = colorScheme.error;
          titleColor = colorScheme.error;
          break;
      }
    } else {
      // Custom icon provided
      switch (variant) {
        case DialogVariant.normal:
          iconColor = colorScheme.primary;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.confirmation:
          iconColor = colorScheme.primary;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.destructive:
          iconColor = colorScheme.error;
          titleColor = colorScheme.error;
          break;
      }
    }

    return DialogKeyboardHost(
      barrierDismissible: barrierDismissible,
      onSubmit: onSubmit,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = MediaQuery.of(context).size.width;
          final availableHeight = MediaQuery.of(context).size.height;
          // Honour the caller's maxWidth, which was accepted and then ignored:
          // every dialog rendered at 90% of the window regardless. The 90% only
          // survives as a ceiling so a wide dialog cannot outgrow a small
          // screen; the height still shrinks to its content below.
          final widthCeiling = availableWidth * 0.9;
          final dialogWidth = maxWidth < widthCeiling ? maxWidth : widthCeiling;
          final dialogHeight = availableHeight * 0.9;

          // ignore: avoid_dialog
          return Dialog(
            // 12 dp, not Material 3's 28 (DLG-001 in
            // packages/gitui_skin_material/docs/deviation_register.yaml). This
            // is a Windows/Linux desktop
            // app, and 28 dp is a phone-scale corner: it is the one radius in
            // the whole app that would read as a mobile sheet. 12 dp is the
            // surface corner this app already uses for the cards and panels
            // the dialog hosts, and it sits between the 8 dp of Windows 11's
            // own ContentDialog and the 12 dp of libadwaita's.
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth.clamp(
                  AppConstants.minDialogWidth,
                  double.infinity,
                ),
                maxHeight: dialogHeight,
              ),
              child: Padding(
                // Material 3's dialog insets, which happen to be exactly this
                // app's own spacing steps: 24 dp around the whole dialog, 16
                // between the title and the content, 24 between the content
                // and the action row. These are AlertDialog's defaults
                // (flutter/lib/src/material/dialog.dart:825 for the title
                // padding, :857 for the content padding, :1994 for the
                // actions padding). The uniform 32 dp this used to spend was
                // never measured against them.
                padding: EdgeInsets.all(AppTheme.paddingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title section with optional icon and X close button
                    Row(
                      children: [
                        if (variantIcon != null) ...{
                          // The M3 dialog icon is the ambient 24 dp glyph:
                          // AlertDialog wraps it in an IconTheme that sets a
                          // colour and nothing else
                          // (flutter/lib/src/material/dialog.dart:818), so the
                          // size comes from the theme. The 28 that stood here
                          // was on no icon scale at all.
                          Icon(
                            variantIcon,
                            size: AppTheme.iconL,
                            color: iconColor,
                          ),
                          SizedBox(width: AppTheme.paddingM),
                        },
                        Expanded(
                          child: HeadlineSmallLabel(title, color: titleColor),
                        ),
                        if (barrierDismissible) ...{
                          SizedBox(width: AppTheme.paddingM),
                          BaseIconButton(
                            icon: PhosphorIconsRegular.x,
                            tooltip: l10n.close,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        },
                      ],
                    ),

                    SizedBox(height: AppTheme.paddingM),

                    // Content section (scrollable if long).
                    //
                    // The content is its own traversal group, and that is a
                    // correctness fix rather than a tidiness one. Tab's
                    // default policy sorts the ring by where the controls
                    // currently *are*, and it scrolls the control it moves to
                    // into view - so as soon as a dialog's content scrolls,
                    // the rows that scrolled off the top acquire smaller
                    // global y coordinates than the title row's close button
                    // and get sorted in front of it. The ring then wraps from
                    // the last action into the middle of the list instead of
                    // back to the close button, and the rows near the top are
                    // visited twice per cycle. Measured on the bulk branch
                    // delete at 10 branches: Close, b0..b9, force, Cancel,
                    // Delete, b0, b1, b2, Close - 17 stops for 14 controls.
                    // A group is sorted among its siblings by the group's own
                    // rect, which is this Flexible's box and does not move
                    // when the content inside scrolls, so the title row and
                    // the action row keep their places and the content keeps
                    // its internal reading order.
                    Flexible(
                      child: FocusTraversalGroup(
                        child: SingleChildScrollView(child: content),
                      ),
                    ),

                    // Actions section. A Wrap, not a Row: a Row overflows
                    // when the buttons outgrow the dialog width (the update
                    // dialog's three actions did); wrapping onto a second
                    // end-aligned run is the M3 fallback for that case and
                    // renders identically while one line fits.
                    if (actions != null && actions!.isNotEmpty) ...{
                      SizedBox(height: AppTheme.paddingL),
                      Wrap(
                        alignment: WrapAlignment.end,
                        // 8 dp between actions, the spacing M3's OverflowBar
                        // gets from AlertDialog's default buttonPadding
                        // (dialog.dart:882). The run spacing is ours: an
                        // OverflowBar stacks its overflow with no gap at all,
                        // which would leave two wrapped buttons touching.
                        spacing: AppTheme.paddingS,
                        runSpacing: AppTheme.paddingS,
                        children: [
                          for (final action in actions!)
                            BaseButton(
                              label: action.label,
                              variant: _variantForRole(action.role),
                              leadingIcon: action.icon,
                              isLoading: action.isLoading,
                              onPressed: action.isEnabled
                                  ? action.onPressed
                                  : null,
                            ),
                        ],
                      ),
                    },
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Show dialog helper
  static Future<T?> show<T>({
    required BuildContext context,
    required BaseDialog dialog,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      builder: (context) => dialog,
    );
  }
}

/// The keyboard host every dialog is wrapped in, so the dialog keyboard
/// contract is inherited from one place instead of being re-typed per dialog
/// component. [BaseDialog] and `BaseViewerDialog` both build on it.
///
/// It carries two responsibilities that are each easy to get wrong on their
/// own:
///
/// **The keys.** Escape closes a dismissible dialog and Enter fires
/// [onSubmit], both from anywhere inside it — a dialog that can only be
/// completed with the mouse is unfinished. The single exception is a focused
/// multiline editable, which keeps its Enter because Enter inserts a newline
/// there (see [focusedEditableKeepsEnter]); hijacking it would make the field
/// impossible to fill.
///
/// **The focus.** The host must hold focus for those keys to arrive, but it
/// must not steal it: an eager `Focus(autofocus: true)` wrapper registers
/// before any descendant and wins the autofocus race, which silently defeated
/// `autofocus: true` on the first field of every dialog (the focus manager
/// discards later autofocus requests once the scope has a focused child). So
/// the host claims focus only after the autofocus pipeline settled and nothing
/// inside the dialog took it; key events from a focused field still bubble up
/// to this node either way.
///
/// It is deliberately not a Tab stop ([FocusNode.skipTraversal]). The node
/// covers the whole dialog and draws nothing, so leaving it in the traversal
/// ring gave every dialog one stop where the user sees no focus ring and has
/// nothing to operate — Tab is supposed to walk the dialog's *controls*.
/// Skipping traversal keeps it focusable for the fallback above and for the
/// keys, and Tab from it still moves on to the first real control.
class DialogKeyboardHost extends StatefulWidget {
  const DialogKeyboardHost({
    super.key,
    required this.barrierDismissible,
    required this.onSubmit,
    required this.child,
  });

  /// Whether Escape may close the dialog, mirroring the host route's own
  /// barrier behaviour so both dismissal paths agree.
  final bool barrierDismissible;

  /// The dialog's primary action, fired by Enter. Null leaves Enter inert,
  /// which is what a destructive prompt wants.
  final VoidCallback? onSubmit;

  final Widget child;

  @override
  State<DialogKeyboardHost> createState() => _DialogKeyboardHostState();
}

class _DialogKeyboardHostState extends State<DialogKeyboardHost> {
  final FocusNode _node = FocusNode(debugLabel: 'DialogKeyboardHost');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pending autofocus requests (a field's, queued in its own post-frame
      // callback) are applied in a microtask after this frame's callbacks;
      // decide on the next frame, after they ran, and make sure that frame
      // actually comes.
      WidgetsBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (FocusScope.of(context).focusedChild == null) {
          _node.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.barrierDismissible) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
    }

    // Enter confirms from anywhere in the dialog, not only while a single
    // text field happens to hold focus. The exception is a multiline
    // editable: Enter inserts a newline there, and hijacking it would make
    // the field impossible to fill.
    final onSubmit = widget.onSubmit;
    if (onSubmit != null &&
        !focusedEditableKeepsEnter() &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      onSubmit();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}

/// Helper function for confirmation dialogs
///
/// Returns true if confirmed, false if cancelled or dismissed.
/// Enter confirms, Esc cancels.
///
/// Example usage:
/// ```dart
/// final confirmed = await showConfirmationDialog(
///   context: context,
///   title: 'Confirm Action',
///   message: 'Are you sure you want to proceed?',
/// );
///
/// if (confirmed) {
///   // User confirmed
/// }
/// ```
Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await BaseDialog.show<bool>(
    context: context,
    dialog: BaseDialog(
      title: title,
      content: Text(message),
      variant: DialogVariant.confirmation,
      // Enter confirms: a confirmation prompt's whole job is a quick yes.
      onSubmit: () => Navigator.of(context).pop(true),
      actions: [
        DialogAction(
          label: cancelText ?? l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: confirmText ?? l10n.confirm,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Helper function for destructive action dialogs
///
/// Returns true if confirmed, false if cancelled or dismissed.
///
/// Example usage:
/// ```dart
/// final confirmed = await showDestructiveDialog(
///   context: context,
///   title: 'Delete Branch',
///   message: 'Are you sure you want to delete this branch? This action cannot be undone.',
///   confirmText: 'Delete',
/// );
///
/// if (confirmed) {
///   // User confirmed deletion
///   deleteBranch();
/// }
/// ```
Future<bool> showDestructiveDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await BaseDialog.show<bool>(
    context: context,
    dialog: BaseDialog(
      title: title,
      content: Text(message),
      variant: DialogVariant.destructive,
      // Deliberately no onSubmit: Enter must never trigger a destructive
      // action, or the key repeat of the keystroke that opened this prompt
      // destroys data. Esc cancels from anywhere; the red button stays
      // reachable with Tab + Enter/Space, which is the deliberate two-step.
      actions: [
        DialogAction(
          label: cancelText ?? l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: confirmText ?? l10n.delete,
          role: DialogActionRole.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  return result ?? false;
}
