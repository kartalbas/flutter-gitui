import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, Tone;
import '../../shared/theme/app_theme.dart';
import 'base_icon.dart';
import 'base_pressable.dart';
import 'base_layout.dart';

/// Base component for all panel patterns in the app.
///
/// A panel is a card with a header section containing a title and
/// optional action buttons, plus a content area and optional footer.
///
/// The container is the Material 3 **elevated card** (`Card`,
/// flutter/lib/src/material/card.dart:301-323): level-1 elevation on
/// `surfaceContainerLow` behind a 12 dp corner. The header is the Material 3
/// **expansion-tile header** (`ExpansionTile`,
/// flutter/lib/src/material/expansion_tile.dart:907-925): a 56 dp minimum
/// height, an `onSurfaceVariant` caret while collapsed and a `primary` one
/// while expanded, and hover/focus/press state layers painted by its
/// [InkWell]. See
/// packages/gitui_skin_material/test/conformance/components/base_panel_conformance_test.dart.
///
/// Example usage:
/// ```dart
/// BasePanel(
///   title: BaseLabel('Branches', role: TextRole.sectionTitle),
///   actions: [
///     IconButton(icon: Icon(PhosphorIconsRegular.plus), onPressed: () {}),
///   ],
///   content: ListView(children: [...]),
///   footer: BaseLabel('5 branches total', role: TextRole.body),
/// )
/// ```
///
/// Collapsible panel example:
/// ```dart
/// BasePanel(
///   title: BaseLabel('Settings', role: TextRole.sectionTitle),
///   isCollapsible: true,
///   initiallyExpanded: false,
///   content: Column(children: [...]),
/// )
/// ```
class BasePanel extends StatefulWidget {
  const BasePanel({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.footer,
    this.isCollapsible = false,
    this.initiallyExpanded = true,
    this.elevation = AppTheme.elevationLevel1,
    this.hasBorder = false,
    this.inset = Inset.roomy,
  });

  /// Panel title (header)
  final Widget title;

  /// Main content area
  final Widget content;

  /// Optional action buttons in header (top-right)
  final List<Widget>? actions;

  /// Optional footer section
  final Widget? footer;

  /// Allow panel to be collapsed/expanded
  final bool isCollapsible;

  /// Initial expansion state (if collapsible)
  final bool initiallyExpanded;

  /// Panel elevation
  final double elevation;

  /// Show border around panel
  final bool hasBorder;

  /// How far the content sits from the panel's own edge.
  ///
  /// A rung rather than an `EdgeInsets`, for the same reason `BaseCard.inset`
  /// is one. [Inset.none] is what a panel says when its content is a list or a
  /// tree that owns its own row geometry: the rows reach the panel's edge and
  /// each row insets itself.
  final Inset inset;

  /// Smallest height the header may occupy, the Material 3 one-line
  /// list-item height an `ExpansionTile` header is built from
  /// (`_defaultTileHeight`, flutter/lib/src/material/list_tile.dart:1509).
  /// A taller title or an action button grows the header, as it does there.
  static const double headerMinHeight = 56.0;

  @override
  State<BasePanel> createState() => _BasePanelState();
}

class _BasePanelState extends State<BasePanel> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(BasePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset expansion state if collapsible property changes
    if (widget.isCollapsible != oldWidget.isCollapsible &&
        !widget.isCollapsible) {
      _isExpanded = true;
    }
  }

  void _toggleExpanded() {
    if (widget.isCollapsible) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The three corners below are this panel's surface, and the surface is
    // `surfaces.panel` - which ships, and which `update_available_dialog.dart`
    // already calls. They stay because the member cannot say what these five
    // panel headers say, and that is a CONTRACT FINDING rather than a wait on
    // an unbuilt member:
    //
    //  * `PanelSpec.title` is a bare `String`, drawn by the Material member as
    //    `bodyLarge` with no mark. Every one of the five panels in `lib/`
    //    (commit details, commit diff, file tree, and both panes of the
    //    changes screen) states its title as a `Row` of an accent [BaseIcon]
    //    and a `sectionTitle` [BaseLabel]. Calling the member today would
    //    delete five region marks and drop the name a type weight - a change
    //    of content, not of treatment.
    //  * Two of the five QUALIFY the name: commit_diff_panel.dart carries the
    //    displayed file path beside it as a muted `detail`, and the changes
    //    screen's diff pane carries the path plus a per-file staging mark. A
    //    header content port would hold them, and would put this application's
    //    panel-header typography back into application code - the leak the
    //    member exists to close - so the shape that is missing is a named
    //    `leading` mark plus a qualifier, not an opaque slot.
    //  * `PanelSpec` also has no outlined variant, which is what the border
    //    below is. No screen passes `hasBorder`; it is alive only in the
    //    Material conformance suite and one golden scene, so deleting the
    //    variant would take one of these three corners with it and move a
    //    golden - a decision for whoever owns that manifest, not a side
    //    effect of this pass.
    return Material(
      elevation: widget.elevation,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      color: colorScheme.surfaceContainerLow,
      child: Container(
        decoration: BoxDecoration(
          border: widget.hasBorder
              ? Border.all(color: colorScheme.outlineVariant, width: 1)
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: colorScheme.onSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section
                BasePressable(
                  onTap: widget.isCollapsible ? _toggleExpanded : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: BasePanel.headerMinHeight,
                    ),
                    child: BaseInset(
                      // Across, the header is `roomy`: the title stands on the
                      // same optical left edge as the panel content below the
                      // divider (registered as PANEL-001). Down the page it is
                      // `tight` - the M3 minVerticalPadding - with the height
                      // carried by the 56 dp minimum above rather than by this
                      // rung.
                      x: Inset.roomy,
                      y: Inset.tight,
                      child: Row(
                        children: [
                          // Title. The header's own text role is bodyLarge on
                          // onSurface, the style an ExpansionTile header
                          // inherits from ListTile (list_tile.dart:1844,
                          // expansion_tile.dart:915); a call site that passes
                          // a styled label overrides it.
                          Expanded(
                            child: DefaultTextStyle(
                              style: theme.textTheme.bodyLarge!.copyWith(
                                color: colorScheme.onSurface,
                              ),
                              child: widget.title,
                            ),
                          ),

                          // Action buttons. The distance in front of each one
                          // is stated as a gap between neighbours rather than
                          // as a one-sided padding around it: `BaseInset` has
                          // deliberately no per-side form, because a leading
                          // `EdgeInsets.only` is a gap wearing a padding
                          // idiom - the space belongs BETWEEN the title and
                          // the actions, and between one action and the next,
                          // not inside any of them. Restating it as
                          // composition is what `base_layout.dart` prescribes,
                          // and it lays out identically.
                          if (widget.actions != null &&
                              widget.actions!.isNotEmpty) ...[
                            const BaseGap(Proximity.grouped),
                            for (final Widget action in widget.actions!) ...[
                              const BaseGap(Proximity.related),
                              action,
                            ],
                          ],

                          // Collapse/expand icon. M3 tints the caret with
                          // `primary` while the tile is expanded and leaves it
                          // `onSurfaceVariant` while collapsed, so the caret
                          // carries the state on its own
                          // (expansion_tile.dart:918 and :924) - and both of
                          // those are meanings the vocabulary has words for:
                          // the open state is the panel's own accent, the shut
                          // one is secondary to the title it sits beside.
                          //
                          // It converts now rather than waiting for
                          // `surfaces.panel`, and that is a decision rather
                          // than impatience: `PanelSpec` is {title, content,
                          // actions, footer, elevation, inset} and has no word
                          // for a panel that OPENS AND SHUTS at all, so there
                          // is no slot this caret is queuing for. Reported as a
                          // contract finding; until the spec can say it, the
                          // mark stands on its own and `BaseIcon` is exactly
                          // the facade for a mark that does.
                          //
                          // Nothing moves: `ControlScale.normal` is the same
                          // 20 dp the token here stood for, `Tone.accent`
                          // resolves to `colorScheme.primary`, and
                          // `Tone.muted` resolves against the `onSurface` this
                          // panel publishes at its own root - which is the
                          // case `MaterialInk._muted` answers with
                          // `onSurfaceVariant`, the colour written here.
                          if (widget.isCollapsible) ...[
                            const BaseGap(Proximity.grouped),
                            BaseIcon(
                              _isExpanded
                                  ? IconRole.caretUp
                                  : IconRole.caretDown,
                              tone: _isExpanded ? Tone.accent : Tone.muted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Divider (only if content is visible)
                if (_isExpanded)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),

                // Content section (collapsible)
                if (_isExpanded)
                  Flexible(
                    child: BaseInset(all: widget.inset, child: widget.content),
                  ),

                // Footer section
                if (_isExpanded && widget.footer != null) ...{
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  BaseInset(all: Inset.roomy, child: widget.footer!),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
