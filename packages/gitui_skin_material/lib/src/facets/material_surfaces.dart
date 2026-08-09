import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:photo_view/photo_view.dart';

import '../material_glyphs.dart';
import '../material_ink.dart';
import '../material_theme.dart';

/// Things that hold other things, in Material 3.
///
/// Nineteen members, the largest facet, and every one of them is a body MOVED
/// out of a component in `lib/shared/`: `base_card.dart`, `base_list_item.dart`,
/// `base_panel.dart`, `base_badge.dart`, `base_menu_item.dart`,
/// `base_tree_item.dart`, `base_diff_viewer.dart`, `empty_state.dart`,
/// `commit_graph_painter.dart` and the four viewer dialogs. Nothing here was
/// designed; what changed is WHERE the delegation lives.
///
/// **Two behaviours in this facet are load-bearing and were each a defect
/// once.** Both are stated here because a reader who does not know them will
/// simplify them away, and both have their reasoning carried with them at the
/// member that owns it.
///
///  1. **A row and a card paint their fill so that the state layer lands on
///     TOP of the selection, never under it.** [listRow] does it with an [Ink]
///     tile rather than a `Container`, because `Ink` paints into the ancestor
///     `Material`'s ink layer and the hover and press features are added to
///     that same layer afterwards - so they composite above the fill. A
///     `Container` paints over them instead, and a selected row silently loses
///     its hover feedback. [card] reaches the same ordering the other way, with
///     a transparent `Material` INSIDE its decorated box, and both are asserted
///     by this package's own conformance suite.
///  2. **A row publishes its foreground to every slot, not only to its
///     content.** A badge or a trailing label sits on the same tile as the
///     title, and wrapping only the content left them on the ambient
///     `onSurface`: a label in the trailing slot of a selected row measured
///     4.13 : 1 in the dark theme, under the 4.5 : 1 SC 1.4.3 asks of body
///     text.
///
/// **Where a member reads a length, a colour or a type role it does so through
/// `material_ink.dart`**, which is the one place this package is allowed to
/// learn a value. The exceptions are the geometries that belong to a single
/// surface and to nothing else - a list row's 56 dp floor, a tree row's 18 dp
/// mark, a deletable pill's target arithmetic - and each of those is a named
/// constant on this class with the measurement that produced it.
final class MaterialSurfaces implements SkinSurfaces {
  /// Builds the Material surfaces.
  const MaterialSurfaces();

  /// Smallest height a list row may occupy: the Material 3 one-line list-item
  /// height (`_defaultTileHeight`,
  /// flutter/lib/src/material/list_tile.dart:1509). Taller content grows the
  /// row, exactly as it does in `ListTile`.
  static const double listRowMinHeight = 56;

  /// Smallest height a panel header may occupy. The same M3 one-line height an
  /// `ExpansionTile` header is built from; a taller title or an action button
  /// grows the header, as it does there.
  static const double panelHeaderMinHeight = 56;

  /// The mark a tree row draws at.
  ///
  /// Between the dense rung (16) and the compact one (20), and it is neither:
  /// it is the size a tree row has always drawn its folder and file marks at,
  /// which sits deliberately above the caret beside it so the hierarchy reads
  /// before the individual node does.
  static const double _treeGlyphSize = 18;

  /// The caret a tree row draws at, and the pad around it. Smaller than the
  /// node's own mark for the reason above.
  static const double _treeCaretSize = 16;

  /// The pad around a tree row's caret, which is what gives the caret a hit
  /// area larger than the glyph without moving the row's rhythm.
  static const double _treeCaretPad = 2;

  /// How far one level of a tree indents the next.
  static const double _treeIndent = MaterialMetrics.spaceM;

  /// The fill a code line's own meaning is washed onto its row at.
  ///
  /// 12 % is what a diff row has always used: enough to separate an added line
  /// from an unchanged one at a glance, light enough that the line's own
  /// foreground still clears 4.5 : 1 over it, which
  /// `test/conformance/a11y/git_colors_contrast_test.dart` measures directly.
  static const double _codeLineWash = 0.12;

  /// The fill a hunk header is washed onto its row at. Lighter than
  /// [_codeLineWash] because a header is structure rather than content.
  static const double _headerWash = 0.1;

  /// The fill an object's own identity colour is washed onto a surface at.
  ///
  /// A card carrying `Tone.series(n)` or `Tone.accent` is a TINT of the surface
  /// it sits on and not a container in its own right, which is why the
  /// foreground rule below keeps trying `onSurface` on it rather than the
  /// on-role of a container the card is then not painting.
  static const double _identityWash = 0.1;

  /// The fill an avatar's tone is washed onto its circle at. Heavier than a
  /// card's, because the mark inside it is one or two characters and has to
  /// hold its own against a full-width surface.
  static const double _avatarWash = 0.2;

  /// The line height a code line is set at. Tighter than the ramp's own, so a
  /// two-hundred-line diff fits on a screen without the eye losing the column.
  static const double _codeLineHeight = 1.2;

  /// How faint the rule between two list rows is.
  ///
  /// A separator that reads as a line rather than as a hint turns a hundred-row
  /// list into a grid; 30 % of `outlineVariant` is the weight at which the eye
  /// finds the row boundary without counting it.
  static const double _rowSeparatorAlpha = 0.3;

  // ---------------------------------------------------------------------
  // Containers
  // ---------------------------------------------------------------------

  /// **Here is one self-contained object the user can pick** - a repository, a
  /// workspace, a project.
  ///
  /// This is Material 3's **outlined card**: flat behind a 1 px `outlineVariant`
  /// border, exactly like `Card.outlined`
  /// (flutter/lib/src/material/card.dart:371-396), with the tonal containers
  /// reserved for selection rather than for elevation. `surfaceContainerHigh`
  /// rather than `surface` is registered as CARD-001, the absent margin as
  /// CARD-002 and the absent per-card focus layer as CARD-003.
  ///
  /// **Hover and press are not container-colour swaps but state layers** the
  /// card's own [InkWell] paints, so they read the same on a resting card and
  /// on a selected one. The ordering is what makes that true: the fill is on
  /// the decorated box, and the ink surface is a TRANSPARENT `Material` inside
  /// the clip, so every layer the well paints lands above the fill. Without a
  /// `Material` in there the card's own children would paint their layers onto
  /// a `Material` behind the card's background and stay invisible - which
  /// keyboard traversal exposes the moment a tile inside a card takes focus.
  ///
  /// [CardSpec.elevation] is honoured only above `resting`, and that is not a
  /// dropped parameter but the shape of the answer: an outlined card is flat by
  /// construction, so `flush` and `resting` are the same picture here and the
  /// two upper rungs add the shadow a Material surface uses to leave the page.
  @override
  Widget card(BuildContext context, CardSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = spec.selection == RowSelection.primary;
    final bool isMultiSelected = spec.selection == RowSelection.multi;

    // An object's OWN colour, where it has one. `Tone.neutral` is the card that
    // carries no identity and keeps the scheme's tonal containers; every other
    // tone is a tint of the surface, which is what the repositories grid and
    // the workspaces grid paint today.
    //
    // `Tone.accent` resolves to the scheme's SECONDARY accent while the card is
    // one of several gathered for a batch action, because `Tone` names one
    // accent and a Material scheme carries two - and painting both selections
    // in `primary` would make a multi-selection indistinguishable from the row
    // the user is actually acting on.
    final Color? identity = spec.tone == Tone.neutral
        ? null
        : (spec.tone == Tone.accent && isMultiSelected
              ? colors.secondary
              : MaterialInk.foreground(context, spec.tone));

    final Color backgroundColor;
    if (isSelected || isMultiSelected) {
      backgroundColor =
          identity?.withValues(alpha: _identityWash) ??
          (isSelected ? colors.secondaryContainer : colors.tertiaryContainer);
    } else {
      backgroundColor = colors.surfaceContainerHigh;
    }

    // The content's foreground follows the container the card actually paints.
    // Selection swaps that container for a tonal one, and a label left on
    // `onSurface` would keep the role chosen against the *unselected*
    // background: 4.13 : 1 on `secondaryContainer` in the dark theme, under the
    // 4.5 : 1 SC 1.4.3 asks of body text. [_readableForeground] takes the M3
    // pairing for the state and departs from it only where the scheme's own
    // on-role misses the threshold - which it does here, at 4.45 : 1.
    //
    // An identity tint is *not* one of those pairings, so it keeps `onSurface`
    // as the role to try: the colour comes from outside the scheme, and the
    // on-role of a container this card is then not painting would be wrong.
    // Trying `onSurface` and falling back only when it fails is what keeps a
    // tinted card reading like the surface it is a tint of.
    //
    // Both go through the rule against the colour the card *composites* to,
    // not against the colour it was handed: a 10 % tint is transparent, and
    // judging it by its own channels reads a pale lilac `primary` as a light
    // container in the dark theme and answers black. What a card is composited
    // over is `surface` - M3's role for what the application paints behind
    // everything, and the darkest of the surface tones the card can land on -
    // so the flattened colour is never assumed lighter than it really is.
    final Color foregroundColor = _readableForeground(
      preferred: identity != null
          ? colors.onSurface
          : isSelected
          ? colors.onSecondaryContainer
          : isMultiSelected
          ? colors.onTertiaryContainer
          : colors.onSurface,
      background: backgroundColor,
      backgroundBase: colors.surface,
    );

    // The emphasized border is the focus ring: it shows its on-container colour
    // only while the card's collection holds keyboard focus. An unfocused
    // selection keeps the tinted background behind the resting outline colour,
    // at the same width so the content does not shift when focus moves - still
    // clearly the selection, no longer claiming the keyboard.
    final BoxBorder border;
    if (isSelected) {
      border = Border.all(
        color: spec.containerFocused
            ? (identity ?? colors.onSecondaryContainer)
            : colors.outlineVariant,
        width: 2,
      );
    } else if (isMultiSelected) {
      border = Border.all(
        color: spec.containerFocused
            ? (identity ?? colors.onTertiaryContainer)
            : colors.outlineVariant,
        width: 2,
      );
    } else {
      border = Border.all(color: identity ?? colors.outlineVariant, width: 1);
    }

    final Widget surface = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        borderRadius: BorderRadius.circular(MaterialMetrics.radiusL),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MaterialMetrics.radiusL),
        // Ink children - list tiles, ink wells - paint their hover, focus and
        // pressed state layers on the nearest Material. Without one inside the
        // decorated box those layers land on a Material behind the card's
        // background and stay invisible.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: spec.onTap,
            // A card collection is a single Tab stop with a roving highlight,
            // so an individual card must never become a Tab stop of its own;
            // the focus indication is the emphasized border driven by
            // `containerFocused`. Registered as CARD-003.
            canRequestFocus: false,
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: foregroundColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (spec.header != null) ...<Widget>[
                    spec.header!.mount(),
                    _rule(colors),
                  ],
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.all(
                        MaterialSpacing.inset(spec.inset),
                      ),
                      child: spec.content.mount(),
                    ),
                  ),
                  if (spec.footer != null) ...<Widget>[
                    _rule(colors),
                    spec.footer!.mount(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return _withContextMenu(
      spec.onContextMenu,
      _lifted(spec.elevation, MaterialMetrics.radiusL, surface),
    );
  }

  /// **Here is a named standing region of the interface** - the commit log, the
  /// file tree, the details pane.
  ///
  /// The container is Material 3's **elevated card** (`Card`,
  /// flutter/lib/src/material/card.dart:301-323): level-1 elevation on
  /// `surfaceContainerLow` behind a 12 dp corner, with the absent margin
  /// registered as PANEL-002. The header is the Material 3 **expansion-tile
  /// header** (`ExpansionTile`, expansion_tile.dart:907-925) minus its caret,
  /// which belongs to [disclosure]: the 56 dp minimum height, the `bodyLarge`
  /// title on `onSurface` that a header inherits from `ListTile`
  /// (list_tile.dart:1844), and its state layers painted by its own [InkWell].
  ///
  /// The header's 24 dp leading inset is registered as PANEL-001, and the
  /// reason travels with it: a panel header sits directly above the panel's own
  /// content, separated only by a rule, and the eye reads the two as one
  /// column - so the header has to start on the same optical left edge as that
  /// content. The M3 list-item inset of 16 would offset every panel title from
  /// everything underneath it by 8 px. The trailing inset, where no such
  /// alignment exists, keeps the M3 24 dp.
  @override
  Widget panel(BuildContext context, PanelSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Material(
      elevation: MaterialSpacing.elevation(spec.elevation),
      borderRadius: BorderRadius.circular(MaterialMetrics.radiusL),
      color: colors.surfaceContainerLow,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MaterialMetrics.radiusL),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium!.copyWith(color: colors.onSurface),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: panelHeaderMinHeight,
                ),
                child: Padding(
                  // Horizontal 24 keeps the title on the same optical left edge
                  // as the content below the rule (PANEL-001); vertical 8 is
                  // the M3 `minVerticalPadding`, with the height carried by the
                  // 56 dp minimum above.
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: MaterialMetrics.spaceL,
                    vertical: MaterialMetrics.spaceS,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        // ignore: avoid_text_with_style
                        child: Text(
                          spec.title,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (spec.actions.isNotEmpty)
                        const SizedBox(width: MaterialMetrics.spaceM),
                      for (final ToolbarActionEntry action in spec.actions)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: MaterialMetrics.spaceS,
                          ),
                          child: _headerAction(context, action),
                        ),
                    ],
                  ),
                ),
              ),
              _rule(colors),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.all(MaterialSpacing.inset(spec.inset)),
                  child: spec.content.mount(),
                ),
              ),
              if (spec.footer != null) ...<Widget>[
                _rule(colors),
                Padding(
                  padding: EdgeInsets.all(MaterialSpacing.inset(spec.inset)),
                  child: spec.footer!.mount(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// **The user can choose to see more of this** - a settings section, a
  /// command-log entry, a stash row, a collapsible panel.
  ///
  /// The reveal is the one place this facet keeps a motion, and it is the
  /// motion the application already had: a 200 ms `easeInOut` half-turn on the
  /// caret and a 200 ms cross-fade on the body. `AnimatedRotation` replaces the
  /// `AnimationController` plus `RotationTransition` pair the settings section
  /// drives by hand, which is the same curve over the same duration with the
  /// controller's lifetime deleted - and deleting it is the point, because the
  /// controller only existed to hold state the spec now carries.
  ///
  /// Expansion is APPLICATION state (`expanded` plus `onExpandedChanged`)
  /// rather than the `ExpansionTile` controller Material would own, so a
  /// rebuild cannot lose it and the settings section's stored preference stays
  /// the single source of truth.
  @override
  Widget disclosure(BuildContext context, DisclosureSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: spec.enabled
              ? () => spec.onExpandedChanged(!spec.expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(MaterialMetrics.spaceM),
            child: Row(
              children: <Widget>[
                if (spec.leading != null) ...<Widget>[
                  Icon(
                    MaterialGlyphs.of(spec.leading!),
                    size: MaterialMetrics.iconL,
                    color: colors.primary,
                  ),
                  const SizedBox(width: MaterialMetrics.spaceM),
                ],
                Expanded(child: spec.header.mount()),
                if (spec.trailing != null) ...<Widget>[
                  const SizedBox(width: MaterialMetrics.spaceS),
                  spec.trailing!.mount(),
                ],
                const SizedBox(width: MaterialMetrics.spaceS),
                AnimatedRotation(
                  turns: spec.expanded ? 0.5 : 0,
                  duration: _revealDuration,
                  curve: Curves.easeInOut,
                  child: Icon(
                    MaterialGlyphs.of(IconRole.caretDown),
                    size: MaterialMetrics.iconM,
                    // M3 tints the caret with `primary` while the tile is
                    // expanded and leaves it `onSurfaceVariant` while
                    // collapsed, so the caret carries the state on its own
                    // (expansion_tile.dart:918 and :924).
                    color: spec.expanded
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: spec.body.mount(),
          secondChild: const SizedBox.shrink(),
          crossFadeState: spec.expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: _revealDuration,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------

  /// **Here is one entry in a list of like things.**
  ///
  /// The row reproduces Material 3 list-item geometry as the SDK's own
  /// `ListTile` renders it (list_tile.dart:1818-1860): a 56 dp minimum tile
  /// height, a 16 dp leading edge, a 24 dp trailing edge, a 16 dp gap after the
  /// leading slot, a `bodyLarge` title, an `onSurfaceVariant` icon theme, and
  /// hover and press painted as state layers over an [Ink] tile rather than as
  /// container-colour swaps. The 16 dp vertical padding is registered as
  /// LIST-001 and the absent per-row focus layer as LIST-002.
  ///
  /// It is a [StatefulWidget] for one reason, and it is behaviour rather than
  /// appearance: a row has to react on the press, so the double click is
  /// recognised from the interval between taps instead of through the
  /// detector's `onDoubleTap`, which would hold every single tap for the 300 ms
  /// double-tap window.
  @override
  Widget listRow(BuildContext context, ListRowSpec spec) =>
      _MaterialListRow(spec: spec);

  /// **Here is a hierarchy the user walks, opens and picks from.**
  ///
  /// The member is at the TREE rather than at the row, so this owns the walk:
  /// it flattens `roots` against `expanded` and builds only the rows a
  /// bounded viewport asks for. That is the extraction of what both floor sites
  /// already do - `file_tree_view.dart` and `git_status_tree_view.dart` each
  /// flatten their own model and hand it to a `ListView.builder` - and it is
  /// why the member builds through a builder rather than a `Column`: a
  /// ten-thousand-file working tree must not build ten thousand rows to show
  /// twenty.
  ///
  /// The consequence is that the member needs a bounded height, which is not a
  /// restriction this skin invents: both floor sites already put their tree
  /// inside an `Expanded`.
  ///
  /// `BaseFocusRegion` and the roving-highlight keyboard contract stay in
  /// application code and wrap AROUND whatever this returns.
  @override
  Widget tree(BuildContext context, TreeSpec spec) {
    final List<_FlatNode> rows = <_FlatNode>[];
    void walk(List<TreeNodeSpec> nodes, int depth) {
      for (final TreeNodeSpec node in nodes) {
        final bool open = spec.expanded.contains(node.id);
        rows.add(_FlatNode(node, depth, open));
        if (open) walk(node.children, depth + 1);
      }
    }

    walk(spec.roots, 0);
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (BuildContext row, int index) =>
          _MaterialTreeRow(spec: spec, node: rows[index]),
    );
  }

  /// **Here are several views of the same subject; the user picks one.**
  ///
  /// The bodies come with the strip, because two of the three languages' tab
  /// views own their children - so the member is `TabBar` over
  /// `Expanded(TabBarView)`, which is exactly the arrangement
  /// `branches_screen.dart` and `select_hosted_repository_dialog.dart` build by
  /// hand today.
  ///
  /// The `TabController` is created and driven from the application's
  /// `selectedIndex` rather than owned by the application, which is the same
  /// move a skin whose canonical tab view demands a controller has to make -
  /// and it is only possible because a renderer may return a `StatefulWidget`.
  ///
  /// Every `TabEntry.body` builder is invoked, not only the selected one, and
  /// that is Material's answer rather than an oversight: `TabBarView` is a page
  /// view, so it holds its neighbours in order to slide between them. A skin
  /// whose canonical tab view builds lazily would call fewer, which is exactly
  /// the kind of difference the builder shape exists to let each language make.
  @override
  Widget tabs(BuildContext context, TabSetSpec spec) =>
      _MaterialTabs(spec: spec);

  /// **Here is a table of values the user reads across and down.**
  ///
  /// Material's own `DataTable`, which is the clearest one-language member in
  /// the whole contract: neither `fluent_ui` nor `macos_ui` ships a grid, and
  /// both compose one from their own rows and rules. The values are the CSV
  /// viewer's: a `surfaceContainerHigh` heading row, an `outlineVariant` rule
  /// on every cell, and the column spacing and horizontal margin off the
  /// spacing scale.
  ///
  /// [GridDensity] moves the column spacing and the row height together,
  /// because "how much of this does the user want to see at once" is one
  /// question and answering it on one axis only would leave a compact grid as
  /// tall as a roomy one. `normal` keeps the CSV viewer's column spacing and
  /// margin but NOT its row height: the hand-painted table sat on
  /// `DataTable`'s stock 48 fixed, and this member's `normal` rung is the
  /// touch minimum plus a breath (56) with no ceiling, so a long cell wraps
  /// and grows its row instead of clipping at a height chosen for buttons.
  /// A deliberate, reported change of the conversion, not a drifting copy.
  ///
  /// There is no sorting, and that is settled rather than missing: the floor
  /// does not sort, and a member is derived from a need rather than from a
  /// package's full parameter list.
  @override
  Widget dataGrid(BuildContext context, DataGridSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double spacing = switch (spec.density) {
      GridDensity.compact => MaterialMetrics.spaceM,
      GridDensity.normal => MaterialMetrics.spaceL,
      GridDensity.roomy => MaterialMetrics.spaceXL,
    };
    final double rowHeight = switch (spec.density) {
      GridDensity.compact => kMinInteractiveDimension,
      GridDensity.normal => kMinInteractiveDimension + MaterialMetrics.spaceS,
      GridDensity.roomy => kMinInteractiveDimension + MaterialMetrics.spaceL,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(colors.surfaceContainerHigh),
          columnSpacing: spacing,
          horizontalMargin: MaterialMetrics.spaceM,
          dataRowMinHeight: rowHeight,
          dataRowMaxHeight: double.infinity,
          border: TableBorder.all(color: colors.outlineVariant),
          columns: <DataColumn>[
            for (final String column in spec.columns)
              DataColumn(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MaterialMetrics.spaceS,
                    vertical: MaterialMetrics.spaceXS,
                  ),
                  // ignore: avoid_text_with_style
                  child: Text(
                    column,
                    style: MaterialTypeResolution.styleOf(
                      context,
                      TextRole.itemTitle,
                    ),
                  ),
                ),
              ),
          ],
          rows: <DataRow>[
            for (final List<ContentPort> row in spec.rows)
              DataRow(
                cells: <DataCell>[
                  for (int column = 0; column < spec.columns.length; column++)
                    DataCell(
                      column < row.length
                          ? row[column].mount()
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Marks and small standing things
  // ---------------------------------------------------------------------

  /// **This region can be acted on, and must say so under the pointer and
  /// under the keyboard.**
  ///
  /// Material's `InkWell`, which is what the twenty hand-built tappable regions
  /// in the application already use and what gives them their hover, focus and
  /// press layers. The member exists because the structural alternatives the
  /// attribution walk admits - a `GestureDetector`, a `MouseRegion` - give a
  /// tap target with no state layer at all, and a touch target without one is
  /// an unfinished control by this repository's rules.
  ///
  /// The secondary button has no `InkWell` equivalent, so the context-menu
  /// gesture keeps its own detector around the well, exactly as a list row
  /// does.
  @override
  Widget pressable(BuildContext context, PressableSpec spec) {
    final Widget well = InkWell(
      onTap: spec.enabled ? spec.onTap : null,
      onDoubleTap: spec.enabled ? spec.onDoubleTap : null,
      child: spec.child.mount(),
    );
    final Widget named = Semantics(
      label: spec.semanticsLabel,
      selected: spec.selected,
      enabled: spec.enabled,
      child: spec.tooltip == null
          ? well
          : Tooltip(message: spec.tooltip!, child: well),
    );
    return _withContextMenu(spec.enabled ? spec.onContextMenu : null, named);
  }

  /// **How many, riding on something else?**
  ///
  /// The pill `BaseBadge` has always drawn: a rounded fill at the tone's own
  /// colour washed to 15 %, the tone's colour as the foreground, and a
  /// `labelSmall` label at 600 weight. The scale moves the padding, the type
  /// size, the mark size and the corner together, because a badge is small
  /// enough that changing only one of them reads as a rendering fault.
  ///
  /// `Tone.neutral` is the exception and it is the application's own: a neutral
  /// badge is a `surfaceContainerHighest` chip on `onSurface`, not a wash of a
  /// colour, because "no particular meaning" has no colour to wash.
  @override
  Widget badge(BuildContext context, BadgeSpec spec) => _pill(
    context,
    label: spec.label,
    icon: spec.icon,
    tone: spec.tone,
    scale: spec.scale,
  );

  /// **Here is a named thing the user can take away again** - an active filter,
  /// a chosen tag.
  ///
  /// The same pill as [badge] plus its removal, and the removal is the whole
  /// difference: it is a second, separately named control inside the pill, and
  /// this repository requires every mark-only control to say what it does.
  ///
  /// **A deletable pill is wider and taller than the same pill without a
  /// removal**, and that is deliberate arithmetic rather than a side effect.
  /// The removal is a real button with the full 48 dp interactive minimum
  /// around it, laid out in a stack over the pill so that only the *target*
  /// grows and the painted pill keeps its own height - the move
  /// `BaseIconButton` already makes. Growing the pill instead would turn a
  /// 25 dp status pill into a 56 dp one wherever it happens to be removable.
  ///
  /// The gap before the removal is not a spacing choice either: it is what
  /// keeps the 48 dp box off the label. The box is centred on the glyph, so it
  /// reaches 24 dp back towards the label, and anything the label occupies
  /// inside that reach is a place where clicking the pill's own text deletes
  /// it. Material draws the same line for its chip - the delete affordance's
  /// hit region is capped at the label padding plus the icon so that it claims
  /// the gap and never the label (chip.dart:2425-2431,
  /// `accessibleDeleteButtonWidth`) - and this is that rule with this
  /// application's larger target.
  @override
  Widget tag(BuildContext context, TagSpec spec) {
    final _PillMetrics metrics = _PillMetrics.of(ControlScale.normal);
    final Color foreground = _pillForeground(context, spec.tone);
    final double glyphSize = metrics.glyph + 2;

    final Widget pill = _pill(
      context,
      label: spec.label,
      icon: spec.icon,
      tone: spec.tone,
      scale: ControlScale.normal,
      onTap: spec.onTap,
      reservedTrailing: spec.onRemoved == null ? null : glyphSize,
    );
    if (spec.onRemoved == null) return pill;

    // The two children are aligned on their trailing edge, so the arithmetic is
    // one number: how far the centre of the reserved glyph slot sits from the
    // pill's trailing edge. Whichever of the two boxes reaches less far takes
    // the difference as padding, which puts the 48 dp box exactly over the slot
    // and makes the tag as wide as it needs to be for the target to be
    // hit-testable in full.
    final double slotCentre = metrics.horizontal + glyphSize / 2;
    final double targetRadius = kMinInteractiveDimension / 2;
    final double pillOverhang = math.max(0, targetRadius - slotCentre);
    final double targetInset = math.max(0, slotCentre - targetRadius);

    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(end: pillOverhang),
          child: pill,
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(end: targetInset),
          child: _TagRemoveButton(
            glyphSize: glyphSize,
            color: foreground,
            tooltip:
                spec.removeTooltip ??
                MaterialLocalizations.of(context).deleteButtonTooltip,
            onRemoved: spec.onRemoved!,
          ),
        ),
      ],
    );
  }

  /// **Which person or thing is this?** - as a single compact mark.
  ///
  /// Material's `CircleAvatar`, which is what the blame panel's author monogram
  /// and the stash list's index mark already are. It is a member rather than a
  /// glyph inside a leading port because a port may only be POSITIONED and
  /// CONSTRAINED by a skin and never styled: put the monogram in a port and the
  /// circle around it, its diameter and its foreground pairing all become the
  /// application's to draw, which is the leak rather than the fix.
  ///
  /// The scale moves the diameter and the type role together, which is the
  /// difference the two floor sites already carry: a 12 dp radius with a
  /// `micro` monogram in a dense blame gutter, the stock 20 dp radius with an
  /// `itemTitle` one on a stash row.
  @override
  Widget avatar(BuildContext context, AvatarSpec spec) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double radius = switch (spec.scale) {
      ControlScale.compact => MaterialMetrics.iconXS,
      ControlScale.normal => MaterialMetrics.iconM,
      ControlScale.prominent => MaterialMetrics.iconXL - MaterialMetrics.iconXS,
    };
    final TextRole role = switch (spec.scale) {
      ControlScale.compact => TextRole.micro,
      ControlScale.normal => TextRole.itemTitle,
      ControlScale.prominent => TextRole.sectionTitle,
    };

    // `Tone.neutral` and `Tone.accent` have containers in the scheme and use
    // them; every other tone is washed onto the surface, because Material has
    // no container role for "this file is staged" and inventing one would be
    // this skin answering a question the scheme does not ask.
    final Color background;
    final Color foreground;
    if (spec.tone == Tone.neutral) {
      background = colors.surfaceContainerHighest;
      foreground = colors.onSurface;
    } else if (spec.tone == Tone.accent) {
      background = colors.primaryContainer;
      foreground = colors.onPrimaryContainer;
    } else {
      foreground = MaterialInk.foreground(context, spec.tone);
      background = foreground.withValues(alpha: _avatarWash);
    }

    return Semantics(
      label: spec.semanticsLabel,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: background,
        child: spec.monogram != null
            // ignore: avoid_text_with_style
            ? Text(
                spec.monogram!,
                style: MaterialTypeResolution.styleOf(
                  context,
                  role,
                )?.copyWith(color: foreground),
              )
            : Icon(
                MaterialGlyphs.of(spec.glyph!),
                size: radius,
                color: foreground,
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Things that say something
  // ---------------------------------------------------------------------

  /// **Something about this whole surface needs saying**, and it stays said
  /// until the condition changes.
  ///
  /// The shell's missing-settings warning, generalised: a tonal container
  /// filling the width, the tone's mark, a `titleMedium` statement over a
  /// `bodySmall` explanation, and the actions that do something about it.
  ///
  /// The actions are not decoration. Material's own `MaterialBanner` declares
  /// `required this.actions` and asserts the list is non-empty
  /// (banner.dart:105-108), so a banner spec carrying only a tone and a message
  /// would make the canonical widget unreachable - hand-painting imposed by the
  /// contract at exactly the point the contract exists to prevent it.
  ///
  /// They are built through this skin's own `controls.button` rather than
  /// assembled here, so that a banner's action and a dialog's action are one
  /// implementation. That is also why going back in through the contract is the
  /// right route and not a detour: the button a banner offers is the same
  /// button, and a second copy of it here would be the first place the two
  /// drift apart.
  @override
  Widget banner(BuildContext context, BannerSpec spec) {
    final ThemeData theme = Theme.of(context);
    final (Color container, Color onContainer) = _bannerColors(
      context,
      spec.tone,
    );
    return Container(
      padding: const EdgeInsets.all(MaterialMetrics.spaceM),
      color: container,
      child: Row(
        children: <Widget>[
          if (spec.icon != null) ...<Widget>[
            Icon(MaterialGlyphs.of(spec.icon!), color: onContainer),
            const SizedBox(width: MaterialMetrics.spaceM),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ignore: avoid_text_with_style
                Text(
                  spec.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onContainer,
                  ),
                ),
                if (spec.body != null) ...<Widget>[
                  const SizedBox(height: MaterialMetrics.spaceXS),
                  // ignore: avoid_text_with_style
                  Text(
                    spec.body!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final NoticeAction action in spec.actions) ...<Widget>[
            const SizedBox(width: MaterialMetrics.spaceS),
            _noticeAction(context, action, spec.tone),
          ],
          if (spec.onDismiss != null) ...<Widget>[
            const SizedBox(width: MaterialMetrics.spaceS),
            // `avoid_icon_button` tells the code it finds to use `BaseButton`,
            // which lives in the application and which the workspace-isolation
            // gate makes unreachable from a skin package. There is nothing to
            // switch to, and the rule's spirit - application code must not
            // instantiate a Material control directly - is satisfied by this
            // being a skin. Silenced per site rather than per package, so a
            // reader sees the reason where the control is.
            // ignore: avoid_icon_button
            IconButton(
              onPressed: spec.onDismiss,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              color: onContainer,
              icon: Icon(MaterialGlyphs.of(IconRole.x)),
            ),
          ],
        ],
      ),
    );
  }

  /// **There is nothing here yet, and here is what to do about it.**
  ///
  /// `empty_state.dart`, moved: a centred column inside a 32 dp inset, a 64 dp
  /// mark wearing the spec's tone, a `titleLarge` statement, a `bodyMedium`
  /// explanation on `onSurfaceVariant`, and the ways out.
  ///
  /// The 64 dp mark is the one length here that is not on the icon ramp, and it
  /// is derived rather than chosen: it is twice the largest rung, which is how
  /// the application has always written it (`AppTheme.iconXL * 2`). An empty
  /// state's mark is not an icon in a row, it is the picture the screen is
  /// currently showing.
  ///
  /// The tone reaches the MARK and nothing else. For the muted default it
  /// resolves to exactly the `onSurfaceVariant` this member always painted;
  /// for a failure it is the scheme's error role - the whole difference
  /// between "there is nothing here" and "this went wrong", said where it is
  /// loudest. The headline and the sentence keep their own roles either way,
  /// because the words already say what happened and a page of red prose
  /// would be shouting rather than stating.
  ///
  /// A single way out is drawn on its own; several are stacked, each in its own
  /// half-step of vertical rhythm. That is the shape `empty_state.dart` already
  /// has, and it matters: one action centred under a message reads as the
  /// answer, whereas the same action inside a one-item column reads as the
  /// first of a list.
  @override
  Widget emptyState(BuildContext context, EmptyStateSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MaterialMetrics.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              MaterialGlyphs.of(spec.icon),
              size: MaterialMetrics.iconXL * 2,
              color: MaterialInk.foreground(context, spec.tone),
            ),
            const SizedBox(height: MaterialMetrics.spaceL),
            // ignore: avoid_text_with_style
            Text(
              spec.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: MaterialMetrics.spaceS),
            // ignore: avoid_text_with_style
            Text(
              spec.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (spec.actions.length == 1) ...<Widget>[
              const SizedBox(height: MaterialMetrics.spaceL),
              _emptyStateAction(context, spec.actions.single),
            ] else if (spec.actions.length > 1) ...<Widget>[
              const SizedBox(height: MaterialMetrics.spaceL),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final EmptyStateAction action in spec.actions)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MaterialMetrics.spaceS,
                      ),
                      child: _emptyStateAction(context, action),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// **Things can be dragged onto this region.**
  ///
  /// The repositories screen's drop overlay, moved: a `primary` wash over the
  /// whole region and, centred in it, a `primaryContainer` callout behind a
  /// 2 px `primary` border with a 64 dp mark and a `titleLarge` label. Five
  /// paint decisions that sat in a feature file, which is what lit this member
  /// up under three separate leak detectors at once.
  ///
  /// The callout exists only while something is over the region, which is what
  /// makes `active` visible without a colour of its own, and the region
  /// underneath stays visible through the wash rather than being replaced -
  /// the user is dropping onto something and has to keep seeing what.
  @override
  Widget dropTarget(BuildContext context, DropTargetSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Stack(
      children: <Widget>[
        spec.child.mount(),
        if (spec.active)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: colors.primary.withValues(alpha: _identityWash),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(MaterialMetrics.spaceXL),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        MaterialMetrics.radiusL,
                      ),
                      border: Border.all(
                        color: colors.primary,
                        width: 2,
                        // Inside, so the callout does not grow by the border
                        // width and shift the label it contains.
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          MaterialGlyphs.of(spec.icon),
                          size: MaterialMetrics.iconXL * 2,
                          color: colors.primary,
                        ),
                        const SizedBox(height: MaterialMetrics.spaceM),
                        // ignore: avoid_text_with_style
                        Text(
                          spec.label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Text that is not prose
  // ---------------------------------------------------------------------

  /// **Here is one line of a diff or of a code view.**
  ///
  /// `base_diff_viewer.dart`'s own diff row, moved: the two fixed-width number
  /// gutters, git's gutter character, and the line itself as selectable
  /// monospaced text over a wash of the line's own meaning.
  ///
  /// **What each tone means on a line**, so that the façade has one table to
  /// read rather than a judgement to make per line type:
  ///
  /// | Tone | Fill | Foreground |
  /// |---|---|---|
  /// | `neutral` | none | `onSurface` - an unchanged context line |
  /// | `muted` | none | `onSurfaceVariant` - git's own informational text |
  /// | `accent` | `primary` at 10 % | `primary` - a hunk header |
  /// | `info` | `surfaceContainerHighest` | `onSurface` - a file header |
  /// | anything else | the tone at 12 % | the tone - added, deleted, conflicted |
  ///
  /// **A run at `Tone.neutral` inherits the LINE's tone rather than resolving
  /// to `onSurface`.** That is what "neutral" means one level down: the run has
  /// no meaning of its own that differs from its neighbours', so it takes the
  /// line's. Without it, every ordinary run of an added line would be painted
  /// in the surface's foreground and the line would lose its colour the moment
  /// the contract landed.
  ///
  /// The gutter is drawn when the line has a number on either side and omitted
  /// when it has neither, which is the same rule the diff viewer applies by
  /// line type: a context, added or deleted line carries at least one number
  /// and a header carries none.
  @override
  Widget codeLine(BuildContext context, CodeLineSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color foreground = _codeLineForeground(context, spec.tone);
    final TextStyle? mono = MaterialTypeResolution.styleOf(
      context,
      TextRole.code,
    )?.copyWith(height: _codeLineHeight);
    final bool numbered = spec.oldNumber != null || spec.newNumber != null;

    return InkWell(
      onTap: spec.onTap,
      child: Container(
        // Selection wins over the line's own meaning, because a selected line
        // is a line the user is about to act on and that has to be legible
        // against every diff colour at once. It is the same role a selected
        // list row paints, so a selection reads the same everywhere here.
        color: spec.selected
            ? colors.secondaryContainer
            : _codeLineFill(context, spec.tone),
        padding: const EdgeInsets.symmetric(
          horizontal: MaterialMetrics.spaceS,
          vertical: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (numbered) ...<Widget>[
              _lineNumber(context, spec.oldNumber),
              const SizedBox(width: MaterialMetrics.spaceS),
              _lineNumber(context, spec.newNumber),
              const SizedBox(width: MaterialMetrics.spaceS),
            ],
            if (spec.marker != null)
              // ignore: avoid_text_with_style
              Text(
                spec.marker!,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            const SizedBox(width: MaterialMetrics.spaceXS),
            Expanded(
              child: SelectableText.rich(
                TextSpan(
                  children: <InlineSpan>[
                    for (final TextRun run in spec.runs)
                      TextSpan(
                        text: run.text,
                        style: mono?.copyWith(
                          color: _codeLineForeground(
                            context,
                            run.tone == Tone.neutral ? spec.tone : run.tone,
                          ),
                          fontWeight: run.emphasised ? FontWeight.w600 : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **Here is a whole block of machine output the user reads and copies** -
  /// git stdout, a command-log entry, a blame line, a commit message body.
  ///
  /// The fourteen hand-built `SelectableText` blocks, moved onto one member.
  /// Selectability is BEHAVIOUR - what the user can do - so the application
  /// states it and this supplies Material's own selection affordances with it;
  /// a block that is not selectable is a plain `Text` rather than a
  /// `SelectableText` that refuses, because a selection handle the user cannot
  /// use is worse than none.
  ///
  /// Wrapping is a fact about the content rather than a look: command output is
  /// read unwrapped and a commit message wrapped. An unwrapped block therefore
  /// gets a real horizontal scroll rather than a clip, because output the user
  /// cannot reach the end of is output they cannot read.
  @override
  Widget codeBlock(BuildContext context, CodeBlockSpec spec) {
    final TextStyle? mono = MaterialTypeResolution.styleOf(
      context,
      TextRole.code,
    )?.copyWith(color: MaterialInk.foreground(context, spec.tone));
    final Widget body = spec.selectable
        ? SelectableText(spec.text, style: mono, maxLines: spec.maxLines)
        // ignore: avoid_text_with_style
        : Text(
            spec.text,
            style: mono,
            maxLines: spec.maxLines,
            softWrap: spec.wrap,
            overflow: spec.maxLines == null
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
          );
    return spec.wrap
        ? body
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: body);
  }

  /// **Here is how this commit connects to the ones above and below it.**
  ///
  /// `commit_graph_painter.dart`, moved whole - and it is the application's
  /// only `CustomPainter`, so after this member lands there is no `paint()`
  /// call left in `lib/` for a leak to hide in, which closes the attribution
  /// walk's one blind spot by construction rather than by allowlist.
  ///
  /// The three numbers that used to sit beside the painter came with it: a
  /// 12 dp lane, a 4 dp dot and a 2 dp stroke, plus the eight-lane render cap
  /// that keeps a pathological window from crowding out the subject text and
  /// the divider strip the dot has to be centred above rather than through.
  ///
  /// **It fills the box it is given rather than sizing itself**, and that is
  /// load-bearing rather than lazy: the graph has to span the whole row, rule
  /// strip included, so each row's lane segments meet the neighbouring rows'
  /// edge to edge. A painter confined to a gutter inside the row's own padding
  /// would leave a gap at every rule. The row places it as a fill layer, which
  /// is a `Stack` and therefore structure the application keeps.
  ///
  /// `isCurrent` gets a halo - a second ring one stroke outside the dot -
  /// because the commit HEAD is on is the one the eye has to find in a
  /// thousand-row window, and the application had no way to say so before this
  /// member existed.
  @override
  Widget commitGraphRow(BuildContext context, GraphRowSpec spec) =>
      IgnorePointer(
        child: CustomPaint(
          painter: _CommitGraphPainter(
            spec: spec,
            lanes: MaterialGitPalette.of(context).lanes,
          ),
        ),
      );

  // ---------------------------------------------------------------------
  // The two pictorial members
  // ---------------------------------------------------------------------

  /// **Here is a document written in Markdown.**
  ///
  /// The style sheet the markdown viewer builds by hand today, moved - which is
  /// the whole reason this member needs no escape hatch: the application never
  /// constructs a `MarkdownStyleSheet`, so there is no `TextStyle` left for it
  /// to choose. Every role is Material's own ramp on `onSurface`, a quote is
  /// `onSurfaceVariant` in italic, and code is monospaced on
  /// `surfaceContainerHighest` behind the control corner.
  @override
  Widget markdown(BuildContext context, MarkdownSpec spec) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    return Markdown(
      data: spec.source,
      selectable: spec.selectable,
      imageDirectory: spec.baseDirectory,
      onTapLink: spec.onLinkTapped == null
          ? null
          : (String label, String? href, String title) {
              if (href != null) spec.onLinkTapped!(href);
            },
      styleSheet: MarkdownStyleSheet(
        p: text.bodyMedium?.copyWith(color: colors.onSurface),
        h1: text.displaySmall?.copyWith(color: colors.onSurface),
        h2: text.headlineMedium?.copyWith(color: colors.onSurface),
        h3: text.titleLarge?.copyWith(color: colors.onSurface),
        h4: text.titleMedium?.copyWith(color: colors.onSurface),
        h5: text.titleSmall?.copyWith(color: colors.onSurface),
        h6: text.labelLarge?.copyWith(color: colors.onSurface),
        listBullet: text.bodyMedium?.copyWith(color: colors.onSurface),
        blockquote: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        code: text.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: colors.onSurface,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(MaterialMetrics.radiusM),
        ),
      ),
    );
  }

  /// **Here is a picture the user wants to look at closely.**
  ///
  /// The image viewer's `PhotoView`, moved with its three scale decisions
  /// intact: the picture opens contained, may not be shrunk below that, and
  /// zooms to three times its covering scale.
  ///
  /// `heroAttributes` did not come with it, and that is a deliberate loss
  /// rather than an oversight: a hero tag is an identity the application would
  /// have to supply and `ImageViewerSpec` carries only an `ImageProvider`, so
  /// carrying the flight would have meant growing the spec a field for a
  /// transition that only one language has.
  @override
  Widget imageViewer(BuildContext context, ImageViewerSpec spec) => Semantics(
    image: true,
    label: spec.semanticsLabel,
    child: PhotoView(
      imageProvider: spec.image,
      backgroundDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.scrim,
      ),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
    ),
  );

  // ---------------------------------------------------------------------
  // Composition, shared by the members above
  // ---------------------------------------------------------------------

  /// How long a reveal takes.
  ///
  /// The settings section's own 200 ms, which is the only duration this facet
  /// owns: everything else it draws is a state, not a change.
  static const Duration _revealDuration = Duration(milliseconds: 200);

  /// The hairline a card or a panel draws between its sections.
  static Widget _rule(ColorScheme colors) =>
      Divider(height: 1, thickness: 1, color: colors.outlineVariant);

  /// [child] under a shadow, where the rung asks for one.
  ///
  /// Returns [child] untouched at the two lower rungs, which is what keeps an
  /// outlined card flat: wrapping it in a zero-elevation `Material` would draw
  /// no shadow but would insert an ink surface between the card's own fill and
  /// its children, and where a surface's ink lands is exactly the ordering this
  /// facet is careful about.
  static Widget _lifted(Elevation elevation, double radius, Widget child) {
    final double level = MaterialSpacing.elevation(elevation);
    if (level <= MaterialMetrics.elevationResting) return child;
    return Material(
      elevation: level,
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }

  /// [child] with its own context-menu gesture, where it has one.
  ///
  /// The secondary (right) button has no `InkWell` equivalent, so it keeps its
  /// own detector around whatever the member built. Returns [child] untouched
  /// when there is no menu, so a surface that never offers one is not wrapped
  /// in a detector that swallows nothing.
  static Widget _withContextMenu(
    ValueChanged<Offset>? onContextMenu,
    Widget child,
  ) {
    if (onContextMenu == null) return child;
    return GestureDetector(
      onSecondaryTapDown: (TapDownDetails details) =>
          onContextMenu(details.globalPosition),
      child: child,
    );
  }

  /// One action belonging to a panel's own header.
  ///
  /// A panel header does not overflow - a region small enough to need overflow
  /// is a region whose actions belong in a menu - so the entries are drawn as
  /// they arrive, each as a compact icon button carrying its own name.
  static Widget _headerAction(
    BuildContext context,
    ToolbarActionEntry action,
    // ignore: avoid_icon_button
  ) => IconButton(
    onPressed: action.onPressed,
    tooltip: action.tooltip,
    iconSize: MaterialMetrics.iconS,
    icon: Icon(MaterialGlyphs.of(action.icon)),
  );

  /// One action offered by a banner, built through this skin's own button.
  static Widget _noticeAction(
    BuildContext context,
    NoticeAction action,
    Tone tone,
  ) => Tooltip(
    message: action.tooltip,
    child: SkinScope.of(context).skin.controls.button(
      context,
      ButtonSpec(
        label: action.label,
        onPressed: action.onPressed,
        leading: action.icon,
        tone: tone,
        scale: ControlScale.compact,
      ),
    ),
  );

  /// One way out of an empty state, built through this skin's own button.
  static Widget _emptyStateAction(
    BuildContext context,
    EmptyStateAction action,
  ) => SkinScope.of(context).skin.controls.button(
    context,
    ButtonSpec(
      label: action.label,
      onPressed: action.onPressed,
      emphasis: action.emphasis,
      leading: action.icon,
    ),
  );

  /// The container and foreground a banner's tone paints on.
  ///
  /// Three of the tones have a container role in the scheme and take it; the
  /// rest are washed onto the surface and get the foreground the contrast rule
  /// answers, because Material has no container for "this succeeded" and
  /// inventing one would be this skin answering a question the scheme does not
  /// ask.
  static (Color, Color) _bannerColors(BuildContext context, Tone tone) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (tone == Tone.danger) {
      return (colors.errorContainer, colors.onErrorContainer);
    }
    if (tone == Tone.accent || tone == Tone.info) {
      return (colors.primaryContainer, colors.onPrimaryContainer);
    }
    if (tone == Tone.neutral) {
      return (colors.surfaceContainerHigh, colors.onSurface);
    }
    final Color container = MaterialInk.foreground(
      context,
      tone,
    ).withValues(alpha: _codeLineWash);
    return (
      container,
      _readableForeground(
        preferred: colors.onSurface,
        background: container,
        backgroundBase: colors.surface,
      ),
    );
  }

  /// One side of a diff's number gutter.
  ///
  /// Both sides are the same fixed width and right-aligned, which is what keeps
  /// the code column starting at the same x on every line however many digits a
  /// line number has. A side with no number on it is blank rather than absent,
  /// for the same reason.
  static Widget _lineNumber(BuildContext context, int? number) => SizedBox(
    width:
        MaterialMetrics.iconXL +
        MaterialMetrics.spaceM +
        MaterialMetrics.spaceXS,
    // ignore: avoid_text_with_style
    child: Text(
      number?.toString() ?? '',
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  /// The wash a code line's own meaning puts behind it. See [codeLine] for the
  /// table this implements.
  static Color? _codeLineFill(BuildContext context, Tone tone) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (tone == Tone.neutral || tone == Tone.muted) return null;
    if (tone == Tone.info) return colors.surfaceContainerHighest;
    if (tone == Tone.accent) {
      return colors.primary.withValues(alpha: _headerWash);
    }
    return MaterialInk.foreground(
      context,
      tone,
    ).withValues(alpha: _codeLineWash);
  }

  /// The foreground a code line's own meaning paints in. See [codeLine].
  static Color _codeLineForeground(BuildContext context, Tone tone) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // A file header is a filled band whose words are ordinary rather than
    // quiet: the fill already says the line is structure, and muting the words
    // as well would make the file name the hardest thing on the screen to read.
    if (tone == Tone.info) return colors.onSurface;
    return MaterialInk.foreground(context, tone);
  }

  /// The pill both [badge] and [tag] are drawn as.
  ///
  /// [reservedTrailing] is the width a removal's glyph will occupy, reserved
  /// inside the pill by the pill rather than contained by it: the removal is
  /// painted by a control stacked OVER this slot, which is what lets the pill
  /// keep its own height while the target grows to the interactive minimum.
  static Widget _pill(
    BuildContext context, {
    required String label,
    required IconRole? icon,
    required Tone tone,
    required ControlScale scale,
    VoidCallback? onTap,
    double? reservedTrailing,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final _PillMetrics metrics = _PillMetrics.of(scale);
    final Color foreground = _pillForeground(context, tone);
    final Color background = tone == Tone.neutral
        ? colors.surfaceContainerHighest
        : foreground.withValues(alpha: _pillWash);

    final Widget pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.horizontal,
        vertical: metrics.vertical,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(metrics.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              MaterialGlyphs.of(icon),
              size: metrics.glyph,
              color: foreground,
            ),
            const SizedBox(width: MaterialMetrics.spaceXS),
          ],
          // ignore: avoid_text_with_style
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: metrics.fontSize,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (reservedTrailing != null) ...<Widget>[
            SizedBox(
              width: math.max(
                MaterialMetrics.spaceXS,
                kMinInteractiveDimension / 2 - reservedTrailing / 2,
              ),
            ),
            SizedBox.square(dimension: reservedTrailing),
          ],
        ],
      ),
    );

    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(metrics.radius),
      child: pill,
    );
  }

  /// How faint a pill's fill is behind its own foreground.
  ///
  /// 15 % is the wash the badge has always used, and it is measured rather than
  /// picked: `git_colors_contrast_test.dart` asserts that every git tone still
  /// clears 4.5 : 1 over its own colour at this alpha on every surface the
  /// application paints a badge on.
  static const double _pillWash = 0.15;

  /// The colour a pill's tone means.
  static Color _pillForeground(BuildContext context, Tone tone) =>
      tone == Tone.neutral
      ? Theme.of(context).colorScheme.onSurface
      : MaterialInk.foreground(context, tone);

  /// The rule that keeps a foreground readable on a container it did not
  /// choose.
  ///
  /// [preferred] is the Material 3 role for the pairing - `onSecondaryContainer`
  /// on `secondaryContainer`, and so on - and the fallback is not a second
  /// design decision: it is the same black-or-white rule this skin already uses
  /// to put a readable label on a solid tone, and it only ever takes over where
  /// the scheme's own on-role misses the threshold. In this application's dark
  /// themes that happens on the selection containers, where
  /// `onSecondaryContainer` reaches 4.45 : 1 - close enough to look designed
  /// and still a failure.
  ///
  /// [backgroundBase] is the opaque colour painted BEHIND [background], and it
  /// is required rather than optional because a caller that does not think
  /// about it gets the wrong answer silently: a container may be translucent,
  /// and judging such a tint by its own channels inverts the result - `primary`
  /// is a pale lilac in the dark theme, so the unflattened rule reads "light
  /// container" and answers black, which is then painted on the near-black the
  /// tint actually composites to.
  ///
  /// Its honest home is `material_ink.dart`, beside the palette it measures
  /// against, and it is here because that library was being written
  /// concurrently with this facet. Moving it is a rename at three call sites.
  static Color _readableForeground({
    required Color preferred,
    required Color background,
    required Color backgroundBase,
    double minRatio = _wcagTextContrast,
  }) {
    // sRGB source-over, exactly what the compositor does. Flattening first is a
    // precondition rather than a detail: `computeLuminance()` reads the three
    // channels and ignores alpha completely, so a 10 % tint would otherwise
    // measure as the fully saturated colour it was derived from - a colour that
    // is nowhere on screen.
    final Color painted = Color.alphaBlend(background, backgroundBase);
    return _wcagContrast(preferred, painted) >= minRatio
        ? preferred
        : MaterialInk.foregroundOn(painted);
  }

  /// SC 1.4.3, body text: 4.5 : 1 against its own background.
  static const double _wcagTextContrast = 4.5;

  /// SC 1.4.11, non-text UI: 3 : 1 for glyphs, outlines and other graphics that
  /// carry meaning.
  static const double _wcagNonTextContrast = 3;

  /// The WCAG 2.x contrast ratio between two opaque colours.
  static double _wcagContrast(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double hi = la > lb ? la : lb;
    final double lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

// -----------------------------------------------------------------------
// The pill's per-scale geometry
// -----------------------------------------------------------------------

/// Everything a pill's scale decides at once.
///
/// A badge is small enough that moving the padding without the type size, or
/// the corner without either, reads as a rendering fault rather than as a
/// smaller badge - so the four move together and the three steps are named
/// here rather than resolved one at a time at the call site.
@immutable
final class _PillMetrics {
  const _PillMetrics({
    required this.horizontal,
    required this.vertical,
    required this.fontSize,
    required this.glyph,
    required this.radius,
  });

  /// How far the label sits from the pill's leading and trailing edges.
  final double horizontal;

  /// How far it sits from the top and bottom.
  final double vertical;

  /// The label's size. Below the smallest rung of the ramp on purpose: a badge
  /// is nearly a symbol, and the ramp's smallest role is still prose.
  final double fontSize;

  /// The mark's size, which tracks the label's.
  final double glyph;

  /// The corner. Half the pill's own height at every step, so the shape stays
  /// fully rounded however wide the label grows - geometry derived from the
  /// size rather than a corner token.
  final double radius;

  /// The geometry [scale] asks for.
  static _PillMetrics of(ControlScale scale) => switch (scale) {
    ControlScale.compact => const _PillMetrics(
      horizontal: MaterialMetrics.spaceS,
      vertical: 2,
      fontSize: 10,
      glyph: 10,
      radius: 12,
    ),
    ControlScale.normal => const _PillMetrics(
      horizontal: MaterialMetrics.spaceM,
      vertical: 4,
      fontSize: 12,
      glyph: 12,
      radius: 16,
    ),
    ControlScale.prominent => const _PillMetrics(
      horizontal: MaterialMetrics.spaceL,
      vertical: MaterialMetrics.spaceS,
      fontSize: 14,
      glyph: 14,
      radius: 20,
    ),
  };
}

/// The removal of a removable pill: a 48 dp interactive box around a glyph that
/// keeps the size the pill draws it at.
///
/// It exists because the glyph used to be a bare `GestureDetector` - a 14 dp
/// tap target with no state layer, no focus and no keyboard activation. This is
/// the same shape Material gives its own chip's delete affordance
/// (chip.dart:1305-1321): a circular `InkResponse` whose highlight is sized to
/// the glyph rather than to the box, so the state layer stays inside the pill
/// while the target does not have to.
class _TagRemoveButton extends StatelessWidget {
  const _TagRemoveButton({
    required this.glyphSize,
    required this.color,
    required this.tooltip,
    required this.onRemoved,
  });

  /// The painted glyph's size; the interactive box is always
  /// [kMinInteractiveDimension].
  final double glyphSize;

  /// The pill's foreground, so the glyph keeps carrying the tone the label
  /// does.
  final Color color;

  /// What removing it does. The glyph is the whole control, so without this it
  /// reaches assistive technology as a tappable node with no name at all.
  final String tooltip;

  /// What removing it actually does.
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    // An InkResponse paints its state layers into the nearest Material, and a
    // pill is placed in toolbars and rows that may not offer one. A transparent
    // Material guarantees the ink surface without painting anything itself.
    child: Material(
      type: MaterialType.transparency,
      child: SizedBox.square(
        dimension: kMinInteractiveDimension,
        child: InkResponse(
          onTap: onRemoved,
          customBorder: const CircleBorder(),
          // The hover, focus and pressed circle is sized to the glyph plus one
          // spacing step, not to the 48 dp box, so it stays within the pill it
          // is drawn on.
          radius: glyphSize / 2 + MaterialMetrics.spaceXS,
          child: Icon(
            MaterialGlyphs.of(IconRole.x),
            size: glyphSize,
            color: color,
          ),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------
// The list row
// -----------------------------------------------------------------------

/// One row of a list, with the tile ordering that makes a selected row still
/// show its hover.
class _MaterialListRow extends StatefulWidget {
  const _MaterialListRow({required this.spec});

  final ListRowSpec spec;

  @override
  State<_MaterialListRow> createState() => _MaterialListRowState();
}

class _MaterialListRowState extends State<_MaterialListRow> {
  // Rows must react on the press, so the double click is recognised from the
  // interval between taps rather than through the detector's onDoubleTap, which
  // would hold every single tap for 300 ms. Each row has its own state and
  // therefore its own tracker, so `this` identifies the row.
  final _DoubleTapTracker _tapTracker = _DoubleTapTracker();

  void _handleTap() {
    final bool isDoubleTap = _tapTracker.registerTap(this, DateTime.now());
    if (isDoubleTap && widget.spec.onActivate != null) {
      widget.spec.onActivate!();
      return;
    }
    widget.spec.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ListRowSpec spec = widget.spec;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = spec.selection == RowSelection.primary;
    final bool isMultiSelected = spec.selection == RowSelection.multi;

    // Hover is deliberately absent here: it is a state layer the InkWell paints
    // on top of the Ink tile, so it stays visible on a selected row instead of
    // being hidden under an opaque selection colour.
    final Color? backgroundColor = isSelected
        ? colors.secondaryContainer
        : isMultiSelected
        ? colors.tertiaryContainer
        : null;

    // The row's foreground follows the tile the row actually paints. Selection
    // swaps the tile for a tonal container while the title stays on
    // `onSurface`, which is the role chosen against the *unselected* tile -
    // 4.13 : 1 on `secondaryContainer` in the dark theme, under the 4.5 : 1
    // SC 1.4.3 asks of body text.
    //
    // A row that paints no tile publishes nothing of its own and inherits
    // instead, because "transparent" means the text sits on whatever is behind
    // the row - which is `onSurface` on a plain surface, and the enclosing
    // container's own foreground inside a selected card.
    final Color foregroundColor = backgroundColor == null
        ? DefaultTextStyle.of(context).style.color ?? colors.onSurface
        : MaterialSurfaces._readableForeground(
            preferred: isSelected
                ? colors.onSecondaryContainer
                : colors.onTertiaryContainer,
            background: backgroundColor,
            backgroundBase: colors.surface,
          );

    // Icons are held to SC 1.4.11's 3 : 1 rather than to 4.5 : 1: a row's
    // glyphs are non-text UI. M3's list-item icon role is `onSurfaceVariant`
    // (list_tile.dart:1818-1860) and it stays exactly that wherever it clears
    // the threshold; on the dark theme's selected tile it measures 2.86 : 1, so
    // there the same fallback the label uses takes over. Without this the
    // leading glyph of a selected row was the one part of it still coloured for
    // the unselected tile.
    final Color iconColor = backgroundColor == null
        ? colors.onSurfaceVariant
        : MaterialSurfaces._readableForeground(
            preferred: colors.onSurfaceVariant,
            background: backgroundColor,
            backgroundBase: colors.surface,
            minRatio: MaterialSurfaces._wcagNonTextContrast,
          );

    // The border is the focus ring: it shows its on-container colour only while
    // the row's collection holds keyboard focus. An unfocused selection paints
    // the same border in the background colour - invisible, so the muted
    // highlight is the tinted background alone, and the row does not shift by
    // the border width when focus moves (a decoration border insets the
    // content).
    final BoxBorder? border = isSelected
        ? Border.all(
            color: spec.containerFocused
                ? colors.onSecondaryContainer
                : colors.secondaryContainer,
            width: 2,
          )
        : isMultiSelected
        ? Border.all(
            color: spec.containerFocused
                ? colors.onTertiaryContainer
                : colors.tertiaryContainer,
            width: 2,
          )
        : null;

    final bool isInteractive = spec.onTap != null || spec.onActivate != null;
    final Widget? trailing = _trailing(context, spec, iconColor);

    return MaterialSurfaces._withContextMenu(
      spec.onContextMenu,
      Stack(
        children: <Widget>[
          InkWell(
            // Deliberately no onDoubleTap: registering one makes Flutter
            // withhold every single tap until the 300 ms double-tap window
            // closes.
            onTap: isInteractive ? _handleTap : null,
            // A list is a single Tab stop with a roving highlight, so an
            // individual row must never become a Tab stop of its own; the focus
            // indication is the ring driven by `containerFocused`. Registered
            // as LIST-002.
            canRequestFocus: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: MaterialSurfaces.listRowMinHeight,
              ),
              // Ink, not Container: the tile colour has to be painted INTO the
              // ancestor Material's ink layer so the hover and press state
              // layers land on top of it. A Container would paint over them and
              // a selected row would lose its hover feedback. This is how
              // ListTile paints its own tileColor (list_tile.dart:999-1003).
              child: Ink(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: border,
                ),
                padding: const EdgeInsetsDirectional.only(
                  start: MaterialMetrics.spaceM,
                  end: MaterialMetrics.spaceL,
                  top: MaterialMetrics.spaceM,
                  bottom: MaterialMetrics.spaceM,
                ),
                // The tile's foreground is published to the whole row, not just
                // to the title slot. A badge or a trailing label sits on the
                // same tile as the title, and wrapping only the content left
                // them on the ambient `onSurface`: a label in the trailing slot
                // of a selected row measured 4.13 : 1 in the dark theme, the
                // exact failure this row's own content slot had. Only the
                // COLOUR is merged here so each slot keeps its own type role -
                // the title's `bodyLarge`, a badge's `labelSmall` - and only
                // the colour moves with the tile.
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foregroundColor),
                  child: IconTheme.merge(
                    data: IconThemeData(color: iconColor),
                    child: Row(
                      children: <Widget>[
                        if (spec.leading != null) ...<Widget>[
                          spec.leading!.mount(),
                          const SizedBox(width: MaterialMetrics.spaceM),
                        ],
                        Expanded(
                          child: DefaultTextStyle(
                            style: theme.textTheme.bodyLarge!.copyWith(
                              color: foregroundColor,
                            ),
                            // A row with no subtitle mounts its title alone
                            // rather than inside a one-child column, because
                            // the column would impose its own cross-axis
                            // alignment on content that arrived already laid
                            // out.
                            child: spec.subtitle == null
                                ? spec.title.mount()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      spec.title.mount(),
                                      spec.subtitle!.mount(),
                                    ],
                                  ),
                          ),
                        ),
                        if (spec.badgeCount != null) ...<Widget>[
                          const SizedBox(width: MaterialMetrics.spaceS),
                          _CountBadge(count: spec.badgeCount!),
                        ],
                        if (trailing != null) ...<Widget>[
                          const SizedBox(width: MaterialMetrics.spaceM),
                          trailing,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The rule between two rows, inset to the row's leading edge. It is
          // drawn INSIDE the tile's own height rather than stacked below it, so
          // a row's pitch equals its tile height: a list that allocates a fixed
          // extent per row would otherwise be one pixel short of every row.
          PositionedDirectional(
            start: MaterialMetrics.spaceM,
            end: 0,
            bottom: 0,
            child: Divider(
              height: 1,
              thickness: 1,
              color: colors.outlineVariant.withValues(
                alpha: MaterialSurfaces._rowSeparatorAlpha,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The row's trailing slot, with its own menu folded in where it has one.
  static Widget? _trailing(
    BuildContext context,
    ListRowSpec spec,
    Color iconColor,
  ) {
    if (spec.menu.isEmpty) return spec.trailing?.mount();
    final Widget anchor = _MenuAnchor(entries: spec.menu, color: iconColor);
    if (spec.trailing == null) return anchor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        spec.trailing!.mount(),
        const SizedBox(width: MaterialMetrics.spaceS),
        anchor,
      ],
    );
  }
}

// -----------------------------------------------------------------------
// The tree
// -----------------------------------------------------------------------

/// One node of a tree, with the depth and the openness the walk resolved.
@immutable
final class _FlatNode {
  const _FlatNode(this.node, this.depth, this.open);

  final TreeNodeSpec node;
  final int depth;
  final bool open;
}

/// One row of a tree.
///
/// Stateful for the same reason a list row is: a tree row acts on the press, so
/// the double click is recognised from the interval between taps.
class _MaterialTreeRow extends StatefulWidget {
  const _MaterialTreeRow({required this.spec, required this.node});

  final TreeSpec spec;
  final _FlatNode node;

  @override
  State<_MaterialTreeRow> createState() => _MaterialTreeRowState();
}

class _MaterialTreeRowState extends State<_MaterialTreeRow> {
  final _DoubleTapTracker _tapTracker = _DoubleTapTracker();

  void _handleTap() {
    final Object id = widget.node.node.id;
    final bool isDoubleTap = _tapTracker.registerTap(id, DateTime.now());
    if (isDoubleTap && widget.spec.onActivate != null) {
      widget.spec.onActivate!(id);
      return;
    }
    widget.spec.onSelect(id);
  }

  @override
  Widget build(BuildContext context) {
    final TreeSpec spec = widget.spec;
    final TreeNodeSpec node = widget.node.node;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool selected = spec.selected.contains(node.id);
    final bool parent = node.children.isNotEmpty;
    final Color? selectedForeground = selected
        ? colors.onPrimaryContainer
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Deliberately no onDoubleTap: registering one makes Flutter withhold
        // every single tap until the 300 ms double-tap window closes.
        onTap: _handleTap,
        onSecondaryTapDown: spec.onContextMenu == null
            ? null
            : (TapDownDetails details) =>
                  spec.onContextMenu!(node.id, details.globalPosition),
        child: Container(
          padding: EdgeInsets.only(
            left:
                widget.node.depth * MaterialSurfaces._treeIndent +
                MaterialMetrics.spaceS,
            right: MaterialMetrics.spaceS,
            top: MaterialMetrics.spaceXS,
            bottom: MaterialMetrics.spaceXS,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : null,
          ),
          // The focus ring, painted in the foreground so it costs no layout: a
          // decoration border would inset the dense row content by its width
          // every time focus moves. It appears only while the tree itself holds
          // keyboard focus; an unfocused selection keeps the muted tinted
          // background alone.
          foregroundDecoration: selected && spec.containerFocused
              ? BoxDecoration(
                  border: Border.all(
                    color: colors.onPrimaryContainer,
                    width: 2,
                  ),
                )
              : null,
          child: Row(
            children: <Widget>[
              if (node.checked != null) ...<Widget>[
                _TreeCheck(
                  checked: node.checked,
                  onChanged: spec.onCheck == null
                      ? null
                      : (bool? value) => spec.onCheck!(node.id, value),
                ),
                const SizedBox(width: MaterialMetrics.spaceXS),
              ],
              if (parent)
                _TreeCaret(
                  open: widget.node.open,
                  color: selectedForeground,
                  onPressed: () => spec.onToggleExpanded(node.id),
                )
              else
                const SizedBox(width: MaterialMetrics.spaceM),
              const SizedBox(width: MaterialMetrics.spaceXS),
              if (node.leading != null) ...<Widget>[
                Icon(
                  // A KNOWN weight loss, recorded here rather than hidden: the
                  // file and status trees have always drawn their folder and
                  // file marks at Phosphor BOLD - the glyph census counts 21
                  // such references in `file_icon_utils.dart` alone and three
                  // more in `base_tree_item.dart` - and this draws them at the
                  // ordinary weight. The table it was waiting for now exists:
                  // the swap is `MaterialGlyphs.boldOf`, one line. It is held
                  // back only because the tree is covered by goldens that
                  // cannot be regenerated on Windows, and it is a weight
                  // rather than a glyph, so nothing the row SAYS changes while
                  // it waits.
                  MaterialGlyphs.of(node.leading!),
                  size: MaterialSurfaces._treeGlyphSize,
                  // A branch of the tree is the accent, because the hierarchy
                  // is what the eye has to find first; a leaf takes whatever
                  // the row publishes.
                  color: parent ? colors.primary : selectedForeground,
                ),
                const SizedBox(width: MaterialMetrics.spaceS),
              ],
              Expanded(
                child: DefaultTextStyle(
                  style: (theme.textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(color: selectedForeground),
                  overflow: TextOverflow.ellipsis,
                  child: node.content.mount(),
                ),
              ),
              if (node.badgeCount != null) ...<Widget>[
                const SizedBox(width: MaterialMetrics.spaceS),
                _CountBadge(count: node.badgeCount!),
              ],
              if (node.trailing != null) ...<Widget>[
                const SizedBox(width: MaterialMetrics.spaceS),
                node.trailing!.mount(),
              ],
              if (node.menu.isNotEmpty) ...<Widget>[
                const SizedBox(width: MaterialMetrics.spaceS),
                _MenuAnchor(entries: node.menu, color: selectedForeground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The affordance that opens and closes a branch.
///
/// Its own control rather than part of the row, and that is what the spec says
/// and what every real tree does: clicking the caret opens the node, clicking
/// the row selects it, and the two are not the same gesture.
class _TreeCaret extends StatelessWidget {
  const _TreeCaret({
    required this.open,
    required this.color,
    required this.onPressed,
  });

  final bool open;
  final Color? color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkResponse(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      radius:
          MaterialSurfaces._treeCaretSize / 2 + MaterialSurfaces._treeCaretPad,
      child: Padding(
        padding: const EdgeInsets.all(MaterialSurfaces._treeCaretPad),
        child: Icon(
          MaterialGlyphs.of(open ? IconRole.caretDown : IconRole.caretRight),
          size: MaterialSurfaces._treeCaretSize,
          color: color,
        ),
      ),
    ),
  );
}

/// The tri-state mark a tree row carries when its node can be checked.
///
/// Drawn as the three glyphs the status tree already draws - a filled square, a
/// half square for a folder whose children are only partly checked, an empty
/// one - rather than as a `Checkbox`, because the mark sits inside a 20 dp
/// dense row and Material's own checkbox brings a 48 dp target that would set
/// the whole tree's rhythm. It keeps a real state layer, which a bare glyph did
/// not have.
///
/// Two of the three marks were bold in the status tree and are drawn at the
/// ordinary weight here, for the reason recorded on the tree row's own mark.
class _TreeCheck extends StatelessWidget {
  const _TreeCheck({required this.checked, required this.onChanged});

  final bool? checked;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget glyph = Icon(
      MaterialGlyphs.of(
        checked == null
            ? IconRole.minusSquare
            : checked!
            ? IconRole.checkSquare
            : IconRole.square,
      ),
      size: MaterialMetrics.iconS,
      color: checked == false ? colors.onSurfaceVariant : colors.primary,
    );
    if (onChanged == null) return glyph;
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        onTap: () => onChanged!(checked != true),
        customBorder: const CircleBorder(),
        radius: MaterialMetrics.iconS / 2 + MaterialMetrics.spaceXS,
        child: glyph,
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Tabs
// -----------------------------------------------------------------------

/// A set of tabs and their bodies.
///
/// The controller is this skin's, created here and driven from the
/// application's `selectedIndex`. That is legal precisely because a renderer
/// may return a `StatefulWidget`, and it is what lets a language whose
/// canonical tab view demands a controller reach it without the application
/// ever holding one.
class _MaterialTabs extends StatefulWidget {
  const _MaterialTabs({required this.spec});

  final TabSetSpec spec;

  @override
  State<_MaterialTabs> createState() => _MaterialTabsState();
}

class _MaterialTabsState extends State<_MaterialTabs>
    with TickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _build();
  }

  @override
  void didUpdateWidget(_MaterialTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spec.tabs.length != oldWidget.spec.tabs.length) {
      _controller.removeListener(_report);
      _controller.dispose();
      _controller = _build();
    } else if (_controller.index != _clampedIndex) {
      _controller.index = _clampedIndex;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_report);
    _controller.dispose();
    super.dispose();
  }

  int get _clampedIndex => widget.spec.tabs.isEmpty
      ? 0
      : widget.spec.selectedIndex.clamp(0, widget.spec.tabs.length - 1);

  TabController _build() => TabController(
    length: widget.spec.tabs.length,
    initialIndex: _clampedIndex,
    vsync: this,
  )..addListener(_report);

  /// Reports a move the user made, and only one the user made: the controller
  /// is also driven from `selectedIndex`, and echoing that back would be the
  /// skin telling the application what the application just said.
  void _report() {
    if (_controller.indexIsChanging) return;
    if (_controller.index != widget.spec.selectedIndex) {
      widget.spec.onSelect(_controller.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spec.tabs.isEmpty) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        TabBar(
          controller: _controller,
          tabs: <Widget>[
            for (final TabEntry entry in widget.spec.tabs)
              Tab(
                icon: entry.icon == null
                    ? null
                    : Icon(
                        MaterialGlyphs.of(entry.icon!),
                        size: MaterialMetrics.iconS,
                      ),
                text: entry.badgeCount == null ? entry.label : null,
                child: entry.badgeCount == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(entry.label),
                          const SizedBox(width: MaterialMetrics.spaceS),
                          _CountBadge(count: entry.badgeCount!),
                        ],
                      ),
              ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: <Widget>[
              for (final TabEntry entry in widget.spec.tabs)
                entry.body().mount(),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Shared small parts
// -----------------------------------------------------------------------

/// The count a row, a node or a tab carries.
///
/// `BaseNumericBadge`, moved: a `primary` pill on `onPrimary` whose corner is
/// half its own minimum size, so the shape stays fully rounded however wide the
/// count grows.
///
/// The centre shrink-wraps deliberately. A `Center` with no factors expands to
/// whatever maximum it is offered, so the badge filled its parent whenever that
/// parent handed down a bounded width - inside a `Row` the main axis is
/// unbounded and it happened to hug its label, but in any bounded box a 20 dp
/// count became as large as the box.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  /// How many.
  final int count;

  /// The largest count drawn in full; above it the badge says "99+" rather than
  /// growing wide enough to push the row's content off the end. A constant
  /// rather than a parameter, because `badgeCount` is an `int?` everywhere it
  /// appears on the contract and no spec carries a cap for the skin to honour.
  static const int _maxCount = 99;

  /// The badge's own minimum size, and twice its corner.
  static const double _minSize = 20;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(
        minWidth: _minSize,
        minHeight: _minSize,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(_minSize / 2),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        // ignore: avoid_text_with_style
        child: Text(
          count > _maxCount ? '$_maxCount+' : '$count',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// The anchor a row or a node hangs its own menu off.
///
/// The entries arrive as DATA precisely so that each skin can build its own
/// anchor, and this is Material's: the overflow glyph, opening the menu through
/// [Overlays], the application's only overlay entry point. Going back in
/// through the front door rather than calling this skin's overlay facet
/// directly is what re-captures the envelope, so a menu opened from a row is
/// drawn by the same skin in the same brightness as the row.
///
/// The tooltip is Material's own "show menu" string rather than the
/// application's "More actions", and that is a real loss recorded rather than
/// hidden: a skin package may not reach into the application's translations,
/// `ListRowSpec` carries no name for the anchor, and `MaterialLocalizations` is
/// already translated into every locale this application ships.
class _MenuAnchor extends StatelessWidget {
  const _MenuAnchor({required this.entries, required this.color});

  /// What the menu offers.
  final List<MenuEntry> entries;

  /// The foreground the row published, so the anchor is coloured for the tile
  /// it sits on rather than for the surface behind it.
  final Color? color;

  @override
  // ignore: avoid_icon_button
  Widget build(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
    color: color,
    icon: Icon(MaterialGlyphs.of(IconRole.dotsThreeVertical)),
    onPressed: () =>
        Overlays.menu(context, at: _centreOf(context), entries: entries),
  );

  /// Where this anchor is, in the coordinates an overlay is placed in.
  static Offset _centreOf(BuildContext context) {
    final RenderObject? object = context.findRenderObject();
    if (object == null) return Offset.zero;
    return MatrixUtils.transformPoint(
      object.getTransformTo(null),
      object.paintBounds.center,
    );
  }
}

/// Recognises a double click from the interval between taps.
///
/// Flutter's own `onDoubleTap` cannot be used on rows that must feel instant: a
/// gesture detector carrying both `onTap` and `onDoubleTap` holds the gesture
/// arena until the double-tap window closes, so the single tap only fires
/// `kDoubleTapTimeout` (300 ms) after the button is released. Rows fed through
/// this tracker keep `onDoubleTap` off the detector, act on the single tap
/// immediately, and still recognise the double click.
///
/// This is only safe where the single-tap action is cheap and repeatable -
/// selecting or highlighting a row - because it always runs before the second
/// click can arrive.
class _DoubleTapTracker {
  /// How close two taps must be to count as a double click.
  final Duration timeout = kDoubleTapTimeout;

  Object? _lastTarget;
  DateTime? _lastTapAt;

  /// Records a tap on [target] at [at] and reports whether it completes a
  /// double click.
  ///
  /// [target] identifies the row, so two quick clicks on *different* rows stay
  /// two single clicks instead of being read as a double click.
  bool registerTap(Object target, DateTime at) {
    final Object? lastTarget = _lastTarget;
    final DateTime? lastTapAt = _lastTapAt;

    final bool isDouble =
        lastTapAt != null &&
        identical(lastTarget, target) &&
        at.difference(lastTapAt) <= timeout;

    if (isDouble) {
      // Consumed: a third quick click starts a new pair rather than reporting a
      // second double click.
      _lastTarget = null;
      _lastTapAt = null;
      return true;
    }

    _lastTarget = target;
    _lastTapAt = at;
    return false;
  }
}

// -----------------------------------------------------------------------
// The commit graph
// -----------------------------------------------------------------------

/// Paints one commit row's slice of the graph: the dot, the edges into and out
/// of it, and the lanes passing by.
///
/// The painter spans the whole row, divider strip included, so each row's lane
/// segments meet the neighbouring rows' edge to edge; a painter confined to the
/// leading slot would leave a gap at every rule.
class _CommitGraphPainter extends CustomPainter {
  const _CommitGraphPainter({required this.spec, required this.lanes});

  /// The row, as data. No colour crosses the contract - only an index into the
  /// series this skin owns.
  final GraphRowSpec spec;

  /// The lane cycle for the brightness this row is painted at.
  final List<Color> lanes;

  /// How wide one lane is.
  static const double _laneWidth = 12;

  /// A pathological window can need dozens of lanes; capping the rendered
  /// columns keeps the graph from crowding out the subject text. Columns beyond
  /// the cap pin to the last one, which merely overlaps their lines.
  static const int _maxRenderedLanes = 8;

  /// The dot's radius, and the stroke every lane is drawn with.
  static const double _dotRadius = 4;

  /// How thick a lane is.
  static const double _strokeWidth = 2;

  /// The strip a list row appends below its content for its rule. The dot must
  /// centre on the content, not on content plus rule.
  static const double _dividerStrip = MaterialMetrics.spaceS + 1;

  /// How wide the gutter is: one lane per column in play, capped.
  ///
  /// [GraphRowSpec.laneCount] is a COUNT rather than a width precisely so that
  /// this line, and not the application, decides how wide the gutter is.
  double get _gutterWidth =>
      _laneWidth * spec.laneCount.clamp(1, _maxRenderedLanes);

  /// Where a lane sits, measured from the row's own leading edge.
  ///
  /// The offset is the row's leading inset, because the painter covers the
  /// whole row and the graph has to start where the row's content does. A lane
  /// beyond the render cap pins to the last column, which merely overlaps its
  /// line rather than pushing the subject text off the end.
  double _laneX(int lane) =>
      MaterialMetrics.spaceL +
      _laneWidth *
          (lane.clamp(0, math.max(0, _gutterWidth ~/ _laneWidth - 1)) + 0.5);

  Color _laneColor(int index) => lanes[index % lanes.length];

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = (size.height - _dividerStrip) / 2;
    final double dotX = _laneX(spec.lane);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    for (final GraphEdgeSpec edge in spec.passing) {
      final double x = _laneX(edge.lane);
      stroke.color = _laneColor(edge.toneIndex);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
    }

    for (final GraphEdgeSpec edge in spec.incoming) {
      final double x = _laneX(edge.lane);
      stroke.color = _laneColor(edge.toneIndex);
      final Path path = Path()..moveTo(x, 0);
      if (x == dotX) {
        path.lineTo(dotX, centerY);
      } else {
        path.quadraticBezierTo(x, centerY, dotX, centerY);
      }
      canvas.drawPath(path, stroke);
    }

    for (final GraphEdgeSpec edge in spec.outgoing) {
      final double x = _laneX(edge.lane);
      stroke.color = _laneColor(edge.toneIndex);
      final Path path = Path()..moveTo(dotX, centerY);
      if (x == dotX) {
        path.lineTo(dotX, size.height);
      } else {
        path.quadraticBezierTo(x, centerY, x, size.height);
      }
      canvas.drawPath(path, stroke);
    }

    // A ring instead of a filled dot is what keeps a merge readable at a glance
    // even where the joining edge is only a few pixels long.
    final Paint dot = Paint()..color = _laneColor(spec.toneIndex);
    if (spec.isMerge) {
      dot
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
    }
    canvas.drawCircle(Offset(dotX, centerY), _dotRadius, dot);

    // The commit HEAD is on wears a halo one stroke outside its own dot. It has
    // to be legible against every lane colour at once and beside a dot that may
    // already be a ring, so it is a second circle rather than a change to the
    // first.
    if (spec.isCurrent) {
      canvas.drawCircle(
        Offset(dotX, centerY),
        _dotRadius + _strokeWidth,
        Paint()
          ..color = _laneColor(spec.toneIndex)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth / 2,
      );
    }
  }

  @override
  bool shouldRepaint(_CommitGraphPainter oldDelegate) =>
      !identical(oldDelegate.spec, spec) ||
      !identical(oldDelegate.lanes, lanes);
}
