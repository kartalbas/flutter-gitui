import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ContentPort,
        DialogAction,
        DialogActionRole,
        DialogExtent,
        DialogSpec,
        IconRole,
        Overlays,
        SkinDialog,
        Tone;
import '../../generated/app_localizations.dart';
import '../utils/keyboard_guards.dart';

/// The dialog's action data, which is the CONTRACT's type rather than a copy
/// of it.
///
/// `DialogAction` and `DialogActionRole` used to be declared here, word for
/// word identical to the pair in `packages/gitui_skin_api` — same six fields,
/// same four roles, same reasoning in the doc comments. Two identical
/// declarations of one idea is one too many: the skin renders the contract's
/// type, so an application copy could only ever be converted to it at the
/// seam, and the first field that was added to one and not the other would be
/// a silent loss. Re-exporting means the ~50 files that write
/// `DialogAction(...)` against this component keep their single import and now
/// name the type the skin actually receives.
export 'package:gitui_skin_api/gitui_skin_api.dart'
    show DialogAction, DialogActionRole;

/// Dialog visual variants
enum DialogVariant {
  /// Standard dialog
  normal,

  /// Confirmation dialog (OK/Cancel)
  confirmation,

  /// Destructive action dialog (red accent)
  destructive,
}

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
/// **This is a façade** (#249, §2.11), on the same terms as `BaseButton`: the
/// constructor is the one ~82 call sites already write, and the body is one
/// delegation to `chrome.dialogSurface`. Everything the dialog used to draw
/// itself — the `Dialog` and its DLG-001 corner, the 24/16/24 insets, the
/// title row with its mark and its close button, the scrolling content and its
/// traversal group, and the wrapping action row with the role→variant table —
/// moved into the skin verbatim (`material_chrome.dart`,
/// `_MaterialDialogSurface`).
///
/// Two things stayed on this side of the seam, and both are deliberate. The
/// **keyboard contract** ([DialogKeyboardHost]) is what the user can do, not
/// what the dialog looks like, so no skin may weaken it — the same host the
/// application installs on `SkinScope` for the route path is applied here for
/// the widget path. And the **content assertions** below are statements about
/// the application's own widget tree, which the skin never sees.
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
///     icon: IconRole.warning,
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
    this.extent = DialogExtent.form,
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

  /// The meaning of an optional mark in the title area.
  final IconRole? icon;

  /// What KIND of thing this dialog contains — a sentence and its answers, a
  /// set of fields, or something to look through.
  ///
  /// This replaces a raw `maxWidth` in logical pixels, and the replacement is
  /// the point rather than a side effect: how wide a dialog holding a form
  /// should be is a design language's answer, and eleven call sites were each
  /// making it themselves with a number (400, 500, 600, 800). The extent is
  /// the question the application can actually answer; the skin turns it into
  /// a width.
  final DialogExtent extent;

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

  /// What this dialog asks, in the contract's words.
  ///
  /// The one place the façade's own vocabulary becomes the contract's, and it
  /// is exact rather than approximate:
  ///
  /// * [DialogVariant.destructive] is `Tone.danger` — "this dialog destroys
  ///   something" is a meaning, and the red glyph and red title were Material's
  ///   answer to it spelled out in application code. The skin re-derives both,
  ///   and supplies the warning mark when the caller named none, exactly as the
  ///   variant switch here used to.
  /// * [DialogVariant.confirmation] is not a tone at all: its whole content
  ///   was "show a question mark", so it resolves to [IconRole.question] and
  ///   leaves the tone neutral, which is what the old switch's `Tone.accent`
  ///   mark plus `Tone.neutral` title already meant.
  /// * [DialogVariant.normal] states nothing beyond the caller's own mark.
  DialogSpec _spec() {
    // Turn the runtime RenderFlex error into an immediate, named one: the
    // content sits in a scroll view, so a flex child of a content Column can
    // never get the remaining space it asks for. This mirrors RenderFlex's
    // own condition (a tight flex child always throws under unbounded
    // height; a loose Flexible only when the Column wants MainAxisSize.max),
    // so a legal loose Flexible in a min Column stays allowed. Only direct
    // children are checkable here; the doc on [content] covers the rest.
    //
    // It lives on the spec rather than in [build] because both ways of
    // presenting a dialog pass through here: `BaseDialog.show` hands the spec
    // straight to `Overlays.dialog` and never builds this widget at all.
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

    return DialogSpec(
      title: title,
      // The port carries its own ambient environment (see
      // [_MigrationMaterialHost]): the content is still built from Material
      // widgets, and satisfying their needs is the application's job, not the
      // surface's.
      content: ContentPort(_MigrationMaterialHost(child: content)),
      actions: actions ?? const <DialogAction>[],
      icon: switch (variant) {
        // A confirmation's mark WAS the variant: the old switch produced the
        // question glyph and an otherwise ordinary dialog. Stating the mark
        // says the same thing without a second word for it.
        DialogVariant.confirmation => icon ?? IconRole.question,
        // A destructive dialog's warning fallback is the skin's, so it is not
        // repeated here: `Tone.danger` with no mark already means "warn".
        DialogVariant.normal || DialogVariant.destructive => icon,
      },
      tone: variant == DialogVariant.destructive ? Tone.danger : Tone.neutral,
      extent: extent,
      barrierDismissible: barrierDismissible,
      onSubmit: onSubmit,
    );
  }

  /// Hands this dialog's statement to the API package, which composes it.
  ///
  /// The composition used to be written out here as well - the keyboard host
  /// over `chrome.dialogSurface` - which made it the SECOND place a dialog
  /// surface was built, and the copy that could drift. It also lost the paint
  /// attribution fence, because that fence is private to the API package and
  /// cannot be planted from application code. `SkinDialog` is the one place
  /// now, and this widget's whole job is to say what the dialog asks.
  @override
  Widget build(BuildContext context) => SkinDialog(spec: _spec());

  /// Takes the application away until the user answers this dialog.
  ///
  /// The route is the skin's now: this used to call `showDialog` — Material's
  /// own route helper — from application code, which decided for every design
  /// language how a dialog arrives. `Overlays.dialog` states the dialog and
  /// lets the skin push its own route, and it composes the application's
  /// keyboard host and the skin's surface itself, so this widget is never
  /// built on that path.
  static Future<T?> show<T>({
    required BuildContext context,
    required BaseDialog dialog,
  }) => Overlays.dialog<T>(context, dialog._spec());
}

/// The ambient environment the application's un-migrated dialog content still
/// requires, supplied by the application because the need is the
/// application's.
///
/// Dialog content is still built from Material widgets - a [TextField]
/// asserts a [Material] ancestor - and under the shipped Material skin that
/// ancestor used to arrive by coincidence: the skin's own dialog surface is a
/// `Dialog`, which builds one. The blueprint builds no Material anywhere,
/// deliberately, so the moment the surface moved behind the contract every
/// dialog holding a Material control crashed under it with "No Material
/// widget found" - a measured regression of the blueprint dialog keyboard
/// sweep from 24 failures to 160. The contract's answer (see `ContentPort` in
/// `gitui_skin_api`) is that content crosses the port with its library's
/// ambient needs already satisfied; this widget is that answer for the
/// migration window.
///
/// [MaterialType.transparency] paints nothing, casts nothing and takes no
/// gesture, and the text style re-states the one already in force at the
/// port, so under the Material skin this wrapper is pixel-neutral. It dies
/// with the migration window: when dialog content no longer contains Material
/// widgets, delete it.
class _MigrationMaterialHost extends StatelessWidget {
  const _MigrationMaterialHost({required this.child});

  /// The application's dialog content, exactly as the caller wrote it.
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    textStyle: DefaultTextStyle.of(context).style,
    child: child,
  );
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
