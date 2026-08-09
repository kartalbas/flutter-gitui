import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;
import '../../generated/app_localizations.dart';
import 'base_dialog.dart' show DialogKeyboardHost;
import '../../shared/theme/app_theme.dart';
import 'base_button.dart';
import 'base_icon.dart';
import 'base_label.dart';
import 'base_layout.dart';

/// Base component for full-screen viewer dialogs.
///
/// Use this for dialogs that need:
/// - Full-screen layout (90% of viewport)
/// - Custom header with icon, title, subtitle, and X close button
/// - Expanded content area (not wrapped in scroll view)
/// - Optional actions at bottom
///
/// Example usage:
/// ```dart
/// BaseViewerDialog(
///   icon: IconRole.gitDiff,
///   title: 'Commit Diff',
///   subtitle: 'abc1234: file.dart',
///   headerActions: [
///     BaseIconButton(
///       icon: IconRole.textIndent,
///       tooltip: 'Toggle compact',
///       onPressed: () {},
///     ),
///   ],
///   content: BaseDiffViewer(...),
///   actions: [
///     BaseButton(
///       label: 'Copy All',
///       variant: ButtonVariant.tertiary,
///       onPressed: () {},
///     ),
///   ],
/// );
/// ```
class BaseViewerDialog extends StatelessWidget {
  const BaseViewerDialog({
    super.key,
    required this.title,
    required this.content,
    this.subtitle,
    this.icon,
    this.headerActions,
    this.headerMetadata,
    this.actions,
    this.footer,
    this.barrierDismissible = true,
    this.onSubmit,
    this.widthFactor = 0.9,
    this.heightFactor = 0.9,
  });

  /// Dialog title
  final String title;

  /// Optional subtitle (e.g., file path, description)
  final String? subtitle;

  /// The meaning of an optional mark in the header; the skin chooses the
  /// glyph.
  final IconRole? icon;

  /// Main content (takes full available space)
  final Widget content;

  /// Optional actions in header (between title and close button)
  final List<Widget>? headerActions;

  /// Optional metadata display in header (e.g., "Page 1 of 5", "100 rows x 5 columns")
  final Widget? headerMetadata;

  /// Optional action buttons (bottom row with buttons)
  final List<Widget>? actions;

  /// Optional footer widget (for custom controls like PDF navigation)
  final Widget? footer;

  /// Allow closing by clicking outside dialog
  final bool barrierDismissible;

  /// The dialog's primary action, triggered by Enter from anywhere inside it
  /// (same contract as [BaseDialog.onSubmit], including the multiline-field
  /// exception). For a pure viewer this is typically "close".
  final VoidCallback? onSubmit;

  /// Width as factor of screen width (default 0.9)
  final double widthFactor;

  /// Height as factor of screen height (default 0.9)
  final double heightFactor;

  // `backgroundColor`, `headerBackgroundColor` and `footerBackgroundColor`
  // used to sit here: three `Color`s crossing an application API, which is
  // three design decisions taken in a screen. They are gone, and removing
  // them is what fixes the defect they caused rather than moving it.
  //
  // A fill and the foreground that pairs with it are ONE decision, and this
  // API let a caller take half of it. The one caller ever to pass them
  // (`image_viewer_dialog.dart`) painted the header with
  // `colorScheme.scrim.withValues(alpha: 0.7)` while this component paired
  // the title with `colorScheme.onPrimary` — the on-colour of a fill nobody
  // had painted. Measured across the ten `AppColorScheme` values: 1.61 : 1 in
  // light and 1.06 : 1 in six of the ten dark schemes, i.e. black title on a
  // near-black header. Nothing here could have got that right, because
  // `lib/` has no way to ask what ink pairs with an arbitrary colour — only
  // a skin can answer that (`MaterialInk.foregroundOn`), and the whole point
  // of #249 is that it should be the one asked.
  //
  // So the viewer's chrome is now the ordinary dialog chrome every other
  // viewer already uses, which the theme pairs correctly in both
  // brightnesses. The image itself still sits on a dark backdrop, because
  // that is `PhotoView.backgroundDecoration`'s job and it kept it.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // The same keyboard host BaseDialog uses, rather than a second copy of
    // the Esc/Enter handler: this component used to wrap itself in an eager
    // `Focus(autofocus: true)`, which registers before any descendant and
    // therefore won the autofocus race against a field inside the viewer, so
    // such a viewer opened with focus on the dialog frame and nothing to type
    // into. The shared host defers its claim until the autofocus pipeline has
    // settled, and stays out of the Tab ring.
    return DialogKeyboardHost(
      barrierDismissible: barrierDismissible,
      onSubmit: onSubmit,
      child: Dialog(
        // The same 12 dp corner BaseDialog carries, and for the same reason:
        // see DLG-001/VIEW-001 in
        // packages/gitui_skin_material/docs/deviation_register.yaml. A viewer
        // fills 90% of the window, where Material 3's 28 dp would cut a visible arc
        // out of every corner of what is effectively a second window.
        //
        // **This corner is the one in this file, and it is not waiting for a
        // member to be built.** `chrome.dialogSurface` ships, `DialogExtent
        // .browser` is the rung for "something to look through", and the
        // Material skin already contains this exact frame - the same 12 dp
        // corner, the same 90% box, the same header row and close button - as
        // `_MaterialViewerDialogSurface`. It has ZERO callers in `lib/` and
        // zero tests in its own package, because `DialogSpec` cannot say four
        // things every viewer here says: a SUBTITLE (6 of the 9 call sites -
        // the file name or the commit subject under the name), header
        // METADATA (csv_viewer_dialog's "100 rows x 5 columns"), header
        // ACTIONS beside the close button (unified_diff_dialog), and a FOOTER
        // (image_viewer_dialog's zoom controls, changelog_dialog's release
        // navigation). The two size factors are a fifth difference and the
        // only one the member is right to refuse: 0.85/0.85 and 0.75/0.85 are
        // two screens deciding a length, and adopting the member deletes them
        // rather than carrying them. So the finding is a HEADER the spec
        // cannot state, exactly as `PanelSpec`'s is - one member short of the
        // same shape - and a skin member that shipped ahead of its caller has
        // been drifting untested ever since.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * widthFactor,
          height: MediaQuery.of(context).size.height * heightFactor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header. It paints nothing of its own, so the dialog's surface
              // is what shows through and the theme's own pairing is what the
              // labels inherit — which is the arrangement that cannot be got
              // wrong, and the reason neither label below says anything about
              // colour.
              BaseInset(
                child: Row(
                  children: [
                    if (icon != null) ...[
                      // `prominent` is the 24 dp rung the ambient icon theme
                      // already gave this mark; `accent` is the meaning the
                      // spelled-out colour carried.
                      BaseIcon(
                        icon!,
                        scale: ControlScale.prominent,
                        tone: Tone.accent,
                      ),
                      const BaseGap(Proximity.related),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BaseLabel(title, role: TextRole.pageTitle),
                          if (subtitle != null)
                            BaseLabel(subtitle!, role: TextRole.detail),
                        ],
                      ),
                    ),
                    if (headerMetadata != null) ...[
                      headerMetadata!,
                      const BaseGap(Proximity.grouped),
                    ],
                    if (headerActions != null) ...[
                      ...headerActions!,
                      const BaseGap(Proximity.related),
                    ],
                    BaseIconButton(
                      icon: IconRole.x,
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Content (expanded)
              Expanded(child: content),

              // Footer (custom widget like PDF navigation)
              ?footer,

              // Actions (row of buttons)
              if (actions != null && actions!.isNotEmpty)
                BaseInset(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < actions!.length; i++) ...[
                        if (i > 0) const BaseGap(Proximity.related),
                        actions![i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show viewer dialog helper
  static Future<T?> show<T>({
    required BuildContext context,
    required BaseViewerDialog dialog,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      builder: (context) => dialog,
    );
  }
}
