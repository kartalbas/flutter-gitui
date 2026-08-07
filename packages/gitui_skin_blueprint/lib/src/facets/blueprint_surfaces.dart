import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../blueprint_ink.dart';

/// Things that hold other things, naked.
///
/// Nineteen members, the largest facet, and the one where a parameter is most
/// easily dropped without anybody noticing: a row has a leading slot, a
/// trailing slot, a badge and a menu; a tree has expansion, selection, checking
/// and a context menu per node; a banner has actions and a dismissal. A skin
/// that quietly renders none of those still looks finished. Under this skin it
/// does not, because every one of them is drawn.
///
/// **How the vocabularies are rendered here**, over and above what
/// [BlueprintMarks] and [BlueprintGeometry] already fix:
///
/// | Fact | Rendering |
/// |---|---|
/// | [Elevation] | concentric outlines, `BlueprintGeometry.rings` |
/// | [RowSelection] | the selection wash, plus `[primary]` / `[multi]` |
/// | `containerFocused` | one more outline, plus `[containerUnfocused]` when it is false |
/// | [Inset], [Proximity] | resolved through [BlueprintDistance]; zero unless the instrument was built with a distance |
/// | expansion | `v` open, `>` closed, `·` leaf, preceded by one `.` per level of depth |
/// | [GridDensity] | the cell inset, plus `[compact]` / `[roomy]` |
/// | [Emphasis] on an action | outline weight and, for a link, a broken outline |
///
/// Two of those are additions to `docs/SKIN-CONTRACT-MEMBERS.md` §9.1 rather
/// than departures from it, and both exist for the same reason. §9.1 fixes
/// "selection = filled outline; container focus = a second outline", which is
/// honoured literally - but ring count already carries [Elevation], so a
/// resting focused card and a raised unfocused card would draw the same two
/// rectangles. The mark is what keeps the two vocabularies separable, and the
/// rule the whole package obeys is that information survives even when
/// appearance does not. Depth is the same case one level down: indentation is a
/// distance and must collapse to zero under `BlueprintSkin(distance: 0)`, which
/// is the Zero Test executed - so the hierarchy is also stated as a run of
/// leading dots, which is a mark and survives the collapse.
///
/// The one thing this facet must never do is let a `Row` overflow. Flutter's
/// overflow indicator paints yellow and black stripes, and those pixels satisfy
/// neither half of the chromatic census's invariant (`r == g && b == 0xFF`), so
/// an overflowing naked row would report as a leak the application did not
/// cause. Every run of marks and actions whose length the skin cannot bound is
/// therefore a [Wrap], and every text body that could be long is a single
/// `Text` that wraps or clips on its own terms.
final class BlueprintSurfaces implements SkinSurfaces {
  /// Takes the distance every rung resolves against.
  const BlueprintSurfaces(this.distance);

  /// How far apart things are under this instrument. Zero unless the skin was
  /// built with a distance.
  final BlueprintDistance distance;

  // ---------------------------------------------------------------------
  // Containers
  // ---------------------------------------------------------------------

  /// **Here is one self-contained object the user can pick** - a repository, a
  /// workspace, a project.
  ///
  /// The application is asking for a unit it can select, not for a rounded
  /// rectangle with a shadow: what it varies is which object this is
  /// ([CardSpec.tone], where the object carries its own identity colour),
  /// whether the user has picked it, whether the collection holding it has the
  /// keyboard, and how far off the page it stands. All four are drawn, and none
  /// of them is drawn in a colour.
  @override
  Widget card(BuildContext context, CardSpec spec) {
    final bool selected = spec.selection != RowSelection.none;
    return _ContentPressable(
      onPressed: spec.onTap,
      onContextMenu: spec.onContextMenu,
      selected: selected,
      child: BlueprintBox(
        rings:
            BlueprintGeometry.rings(spec.elevation) +
            _focusRing(spec.containerFocused),
        filled: selected,
        fillWidth: true,
        child: _inset(
          spec.inset,
          _column(<Widget>[
            _marks(<String>[
              BlueprintMarks.tone(spec.tone),
              _selectionMark(spec.selection),
              _containerMark(spec.containerFocused),
            ]),
            if (spec.header != null) spec.header!.mount(),
            spec.content.mount(),
            if (spec.footer != null) spec.footer!.mount(),
          ]),
        ),
      ),
    );
  }

  /// **Here is a named standing region of the interface** - the commit log, the
  /// file tree, the details pane.
  ///
  /// Not a card: a card is one object the user picks and a panel is a region
  /// that is always there, which is why it has a name and, sometimes, its own
  /// actions and why it has no selection. Its header is a [Wrap] rather than a
  /// row, because the number of actions is the application's to decide and a
  /// naked row that overflowed would paint pixels the chromatic census reads as
  /// an application leak.
  @override
  Widget panel(BuildContext context, PanelSpec spec) => BlueprintBox(
    rings: BlueprintGeometry.rings(spec.elevation),
    fillWidth: true,
    child: _inset(
      spec.inset,
      _column(<Widget>[
        _wrap(<Widget>[
          BlueprintMark(BlueprintMarks.textRole(TextRole.sectionTitle)),
          BlueprintText(spec.title),
          for (final ToolbarActionEntry action in spec.actions)
            _action(context, action),
        ]),
        spec.content.mount(),
        if (spec.footer != null) spec.footer!.mount(),
      ]),
    ),
  );

  /// **The user can choose to see more of this** - a settings section, a
  /// command-log entry, a stash row.
  ///
  /// What the application states is the fact (`expanded`) and how to be told it
  /// changed; what it never states is how the reveal is animated, which is why
  /// the body simply is or is not in the tree here. That is the honest zero:
  /// every duration under this skin is `Duration.zero`, and a disclosure that
  /// cross-faded would hide a motion dependence the zero-and-extremes sweep
  /// exists to find.
  ///
  /// The whole header is the control, as it is at the floor, and it carries no
  /// accessible name of its own. Naming it would mean reading the words out of
  /// [DisclosureSpec.header], and a skin may position and constrain a
  /// [ContentPort] but never look inside one - so the state is announced by the
  /// visible mark and the name is the header sitting beside it.
  @override
  Widget disclosure(BuildContext context, DisclosureSpec spec) => BlueprintBox(
    fillWidth: true,
    child: _column(<Widget>[
      _ContentPressable(
        onPressed: spec.enabled
            ? () => spec.onExpandedChanged(!spec.expanded)
            : null,
        enabled: spec.enabled,
        child: Row(
          spacing: distance.gap(Proximity.related),
          children: <Widget>[
            BlueprintMark(_branch(0, true, spec.expanded)),
            _marks(<String>[
              _iconMark(spec.leading),
              _enabledMark(spec.enabled),
            ]),
            Expanded(child: spec.header.mount()),
            if (spec.trailing != null) spec.trailing!.mount(),
          ],
        ),
      ),
      if (spec.expanded) spec.body.mount(),
    ]),
  );

  // ---------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------

  /// **Here is one entry in a list of like things.**
  ///
  /// The row is the member most at risk of being quietly reduced to a title:
  /// the application varies a leading slot, a subtitle, a trailing slot, a
  /// count, a menu and two independent facts about selection, and a skin that
  /// rendered only `title` would still look like a list. All eleven fields are
  /// drawn. Title and subtitle stay two separate mounted ports, because they
  /// arrived as two ports precisely so that no application code has to choose
  /// the type roles that tell them apart.
  @override
  Widget listRow(BuildContext context, ListRowSpec spec) {
    final bool selected = spec.selection != RowSelection.none;
    return _ContentPressable(
      onPressed: spec.onTap,
      onDoubleTap: spec.onActivate,
      onContextMenu: spec.onContextMenu,
      selected: selected,
      child: BlueprintBox(
        rings: 1 + _focusRing(spec.containerFocused),
        filled: selected,
        fillWidth: true,
        child: Row(
          spacing: distance.gap(Proximity.related),
          children: <Widget>[
            if (spec.leading != null) spec.leading!.mount(),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: distance.gap(Proximity.hairline),
                children: <Widget>[
                  spec.title.mount(),
                  if (spec.subtitle != null) spec.subtitle!.mount(),
                ],
              ),
            ),
            _marks(<String>[
              _countMark(spec.badgeCount),
              _selectionMark(spec.selection),
              _containerMark(spec.containerFocused),
            ]),
            if (spec.trailing != null) spec.trailing!.mount(),
            _menuAnchor(spec.menu),
          ],
        ),
      ),
    );
  }

  /// **Here is a hierarchy the user walks, opens and picks from.**
  ///
  /// The member is at the tree rather than at the row, so the blueprint owns
  /// the walk: it flattens `roots` against `expanded`, and a node's children
  /// exist in the tree only while the node is open. That is the same shape a
  /// skin with a real tree component has to produce from the same data, which
  /// is the point of asking at arity N.
  ///
  /// Depth is drawn twice on purpose. The indent is a distance and collapses to
  /// nothing at `BlueprintSkin(distance: 0)` - that collapse is the Zero Test
  /// being executed, not a defect - so the level is also stated as a run of
  /// leading dots, which is a mark and survives it. Without that, a tree under
  /// the instrument would be a flat list and the hierarchy, which is
  /// information rather than appearance, would have been destroyed.
  @override
  Widget tree(BuildContext context, TreeSpec spec) {
    final List<Widget> rows = <Widget>[];

    void walk(List<TreeNodeSpec> nodes, int depth) {
      for (final TreeNodeSpec node in nodes) {
        final bool open = spec.expanded.contains(node.id);
        rows.add(_treeNode(spec, node, depth, open));
        if (open) walk(node.children, depth + 1);
      }
    }

    walk(spec.roots, 0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: distance.gap(Proximity.hairline),
      children: rows,
    );
  }

  /// **Here are several views of the same subject; the user picks one.**
  ///
  /// The bodies come with the strip, and the blueprint honours that by building
  /// exactly one of them: `tabs[selectedIndex].body()` is called and mounted,
  /// and the others are not. A skin that kept every body alive would hide the
  /// fact that `TabEntry.body` is a builder, and a skin that built none would
  /// hide a screen that depends on its tab being mounted.
  ///
  /// The selected tab is outlined twice, which is `docs/SKIN-CONTRACT-MEMBERS`
  /// §9.1 taken literally. The strip is a [Wrap] because the application
  /// decides how many tabs there are.
  ///
  /// The body fills the height the member is given, so this member needs a
  /// bounded one. That is not a blueprint restriction but the shape of the
  /// question: `TabBarView` asserts the same thing, and both floor sites
  /// already put their tab view inside an `Expanded`. A member that
  /// shrink-wrapped instead would let a tab body size itself to its content,
  /// which is a different surface from the one the application asked for.
  @override
  Widget tabs(BuildContext context, TabSetSpec spec) {
    final int selected = spec.tabs.isEmpty
        ? -1
        : spec.selectedIndex.clamp(0, spec.tabs.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: distance.gap(Proximity.grouped),
      children: <Widget>[
        _wrap(<Widget>[
          for (int index = 0; index < spec.tabs.length; index++)
            BlueprintPressable(
              onPressed: () => spec.onSelect(index),
              selected: index == selected,
              child: BlueprintBox(
                rings: index == selected ? 2 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: distance.gap(Proximity.related),
                  children: <Widget>[
                    _marks(<String>[
                      _iconMark(spec.tabs[index].icon),
                      _countMark(spec.tabs[index].badgeCount),
                    ]),
                    BlueprintText(spec.tabs[index].label),
                  ],
                ),
              ),
            ),
        ]),
        if (selected >= 0) Expanded(child: spec.tabs[selected].body().mount()),
      ],
    );
  }

  /// **Here is a table of values the user reads across and down.**
  ///
  /// The application is asking for alignment: a CSV's third column has to line
  /// up with every other third column, and that is a property of the whole
  /// grid, not of any cell. So the blueprint uses a real `Table` with intrinsic
  /// column widths - structure, not decoration - and draws its rules in ink at
  /// the one hairline. The header is marked with the section-title marker
  /// rather than set in a heavier face, because a type ramp is exactly what
  /// this skin does not have.
  ///
  /// A short row is padded with `[missing]` rather than silently dropped. A
  /// `Table` requires every row to be the same width, and a spec whose rows do
  /// not match its columns is a fact about the application that the instrument
  /// should show rather than repair.
  @override
  Widget dataGrid(BuildContext context, DataGridSpec spec) {
    final String density = spec.density == GridDensity.normal
        ? BlueprintMarks.none
        : '[${spec.density.name}]';
    final double pad = distance.inset(_densityInset(spec.density));
    if (spec.columns.isEmpty) {
      return BlueprintBox(
        child: _marks(<String>['[dataGrid]', density, _countMark(0)]),
      );
    }

    TableRow line(List<Widget> cells) => TableRow(
      children: <Widget>[
        for (int column = 0; column < spec.columns.length; column++)
          Padding(
            padding: EdgeInsets.all(pad),
            child: column < cells.length
                ? cells[column]
                : const BlueprintMark('[missing]'),
          ),
      ],
    );

    return BlueprintBox(
      fillWidth: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: distance.gap(Proximity.related),
        children: <Widget>[
          _marks(<String>['[dataGrid]', density]),
          Table(
            border: TableBorder.all(
              color: BlueprintInk.ink(context),
              width: BlueprintInk.hairline(context),
            ),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: <TableRow>[
              line(<Widget>[
                for (final String column in spec.columns)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: distance.gap(Proximity.hairline),
                    children: <Widget>[
                      BlueprintMark(
                        BlueprintMarks.textRole(TextRole.sectionTitle),
                      ),
                      BlueprintText(column),
                    ],
                  ),
              ]),
              for (final List<ContentPort> row in spec.rows)
                line(<Widget>[
                  for (final ContentPort cell in row) cell.mount(),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Marks and small standing things
  // ---------------------------------------------------------------------

  /// **This region can be acted on, and must say so under the pointer and
  /// under the keyboard.**
  ///
  /// The member exists because the structural alternatives - a `GestureDetector`
  /// or a `MouseRegion` - give a tap target with no state layer at all. The
  /// blueprint has no state layer either, because a hover tint is a colour; what
  /// it does have is the whole of the behaviour, so the region is focusable,
  /// answers Enter and Space, reports a secondary tap with its position and
  /// carries its own name into the semantics tree.
  ///
  /// Its child's semantics are kept rather than replaced. `semanticsLabel` is
  /// specified as the name to use "where the content inside does not already
  /// say so", which is only true of a region whose content still speaks.
  @override
  Widget pressable(BuildContext context, PressableSpec spec) =>
      _ContentPressable(
        onPressed: spec.onTap,
        onDoubleTap: spec.onDoubleTap,
        onContextMenu: spec.onContextMenu,
        enabled: spec.enabled,
        selected: spec.selected,
        semanticsLabel: spec.semanticsLabel,
        tooltip: spec.tooltip,
        child: BlueprintBox(
          filled: spec.selected,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: distance.gap(Proximity.hairline),
            children: <Widget>[
              _marks(<String>[
                _enabledMark(spec.enabled),
                if (spec.selected) BlueprintMarks.selected(spec.selected),
              ]),
              Flexible(child: spec.child.mount()),
            ],
          ),
        ),
      );

  /// **How many, riding on something else?**
  ///
  /// A count or a one-word status attached to whatever it sits beside. The
  /// scale changes the smallest box the badge may be drawn in and nothing else,
  /// because the blueprint has no padding to vary: at zero inset a wider square
  /// is the only way three coarse steps can be told apart.
  @override
  Widget badge(BuildContext context, BadgeSpec spec) => BlueprintBox(
    minExtent: BlueprintGeometry.extent(context, spec.scale),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: distance.gap(Proximity.hairline),
      children: <Widget>[
        _marks(<String>[_iconMark(spec.icon), BlueprintMarks.tone(spec.tone)]),
        BlueprintText(spec.label),
      ],
    ),
  );

  /// **Here is a named thing the user can take away again** - an active filter,
  /// a chosen tag.
  ///
  /// Split from the badge because a badge has no removal, and the removal is
  /// the whole difference: it is a second, separately named control inside the
  /// pill, and this repository requires every mark-only control to say what it
  /// does. So `removeTooltip` is carried into the removal's own semantics
  /// rather than into the tag's, and a tag with `onRemoved` but no
  /// `removeTooltip` shows up under the instrument as an unnamed `[remove]` -
  /// which is exactly the defect it is.
  @override
  Widget tag(BuildContext context, TagSpec spec) => BlueprintBox(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: distance.gap(Proximity.hairline),
      children: <Widget>[
        BlueprintPressable(
          onPressed: spec.onTap,
          isButton: spec.onTap != null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: distance.gap(Proximity.hairline),
            children: <Widget>[
              _marks(<String>[
                _iconMark(spec.icon),
                BlueprintMarks.tone(spec.tone),
              ]),
              BlueprintText(spec.label),
            ],
          ),
        ),
        if (spec.onRemoved != null)
          BlueprintPressable(
            onPressed: spec.onRemoved,
            tooltip: spec.removeTooltip,
            child: const BlueprintMark('[remove]'),
          ),
      ],
    ),
  );

  /// **Which person or thing is this?** - as a single compact mark.
  ///
  /// A member rather than a glyph inside a leading port, because a port may
  /// only be positioned and constrained by a skin and never styled: put the
  /// monogram in a port and the circle around it becomes the application's to
  /// draw. The blueprint draws a square, not a circle - a circle is a shape
  /// decision - and the identity that a real skin would carry as a hue is
  /// carried here by the tone's own mark.
  @override
  Widget avatar(BuildContext context, AvatarSpec spec) => Semantics(
    label: spec.semanticsLabel,
    child: BlueprintBox(
      minExtent: BlueprintGeometry.extent(context, spec.scale),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: distance.gap(Proximity.hairline),
          children: <Widget>[
            if (spec.monogram != null) BlueprintText(spec.monogram!),
            _marks(<String>[
              _iconMark(spec.glyph),
              BlueprintMarks.tone(spec.tone),
            ]),
          ],
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------------
  // Things that say something
  // ---------------------------------------------------------------------

  /// **Something about this whole surface needs saying**, and it stays said
  /// until the condition changes.
  ///
  /// This is the in-page persistent notice #418 depends on, and its actions are
  /// not speculation: the shell's missing-settings warning is exactly the
  /// banner that wants an "Open settings" button, and Material's own banner
  /// requires a non-empty action list. Every action is drawn as an outlined
  /// label carrying its own name, mark and description, and the dismissal is a
  /// separate control because dismissing is not one of the actions.
  @override
  Widget banner(BuildContext context, BannerSpec spec) => BlueprintBox(
    fillWidth: true,
    child: _column(<Widget>[
      Row(
        spacing: distance.gap(Proximity.related),
        children: <Widget>[
          _marks(<String>[
            BlueprintMarks.tone(spec.tone),
            _iconMark(spec.icon),
          ]),
          Expanded(child: BlueprintText(spec.title)),
          if (spec.onDismiss != null)
            BlueprintPressable(
              onPressed: spec.onDismiss,
              child: const BlueprintMark('[dismiss]'),
            ),
        ],
      ),
      if (spec.body != null) BlueprintText(spec.body!),
      if (spec.actions.isNotEmpty)
        _wrap(<Widget>[
          for (final NoticeAction action in spec.actions) _notice(action),
        ]),
    ]),
  );

  /// **There is nothing here yet, and here is what to do about it.**
  ///
  /// The application states the absence, its explanation and the ways out of
  /// it. The ways out carry an [Emphasis], and that is the one place a naked
  /// square can show which action the empty state is really offering: the
  /// primary way out wears a 3px outline, the rest wear less, and a link wears
  /// a broken one.
  @override
  Widget emptyState(BuildContext context, EmptyStateSpec spec) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: distance.gap(Proximity.grouped),
      children: <Widget>[
        BlueprintMark(BlueprintMarks.icon(spec.icon)),
        BlueprintText(spec.title),
        BlueprintText(spec.message),
        if (spec.actions.isNotEmpty)
          _wrap(<Widget>[
            for (final EmptyStateAction action in spec.actions)
              BlueprintPressable(
                onPressed: action.onPressed,
                child: BlueprintBox(
                  stroke: BlueprintGeometry.stroke(context, action.emphasis),
                  dashed: BlueprintGeometry.dashed(action.emphasis),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: distance.gap(Proximity.hairline),
                    children: <Widget>[
                      BlueprintMark(BlueprintMarks.icon(action.icon)),
                      BlueprintText(action.label),
                    ],
                  ),
                ),
              ),
          ]),
      ],
    ),
  );

  /// **Things can be dragged onto this region.**
  ///
  /// The application knows two facts and no more: what the region accepts, and
  /// whether something is over it right now. Everything the screen decides by
  /// hand today - a tinted wash, a callout, a 2px border, a 64px glyph - is
  /// five paint decisions sitting in a feature file, and all five are the
  /// skin's here. The callout exists only while `active`, which is what makes
  /// the flag visible without a colour: the region either has a callout in it
  /// or it does not.
  ///
  /// The callout is an ordinary stack child rather than a `Positioned.fill`,
  /// and the reason is worth stating because it is the same hazard twice.
  /// Filling would force the callout into the size of whatever is underneath,
  /// and a callout that does not fit reports a `RenderFlex` overflow - which
  /// paints the framework's yellow-and-black stripes, pixels the chromatic
  /// census reads as an application leak the application did not cause.
  /// Centring instead means the region can only grow where the content beneath
  /// it is smaller than the callout, which does not happen on the screen this
  /// member exists for, and where it does it is a visible fact drawn in ink.
  @override
  Widget dropTarget(BuildContext context, DropTargetSpec spec) => Stack(
    alignment: Alignment.center,
    children: <Widget>[
      spec.child.mount(),
      if (spec.active)
        BlueprintBox(
          rings: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: distance.gap(Proximity.related),
            children: <Widget>[
              _marks(<String>['[active]', BlueprintMarks.icon(spec.icon)]),
              BlueprintText(spec.label),
            ],
          ),
        ),
    ],
  );

  // ---------------------------------------------------------------------
  // Text that is not prose
  // ---------------------------------------------------------------------

  /// **Here is one line of a diff or of a code view.**
  ///
  /// What the application knows is which stretches of the line mean what, which
  /// side each number belongs to, and what git's own gutter character was. The
  /// gutter character is content and not decoration - it is what makes a copied
  /// diff still a diff - so it is rendered as the application gave it, while
  /// every meaning that a real skin would carry as a fill or a weight is
  /// rendered as a mark beside the run.
  ///
  /// The line is one `Text.rich` rather than a row of widgets, and that is a
  /// deliberate defence: a row of runs would overflow on a long line and paint
  /// the framework's yellow-and-black overflow stripes, which are pixels the
  /// chromatic census would attribute to the application. Each run keeps its
  /// own span with its own text unchanged, so nothing is concatenated into the
  /// content.
  @override
  Widget codeLine(BuildContext context, CodeLineSpec spec) => _ContentPressable(
    onPressed: spec.onTap,
    selected: spec.selected,
    child: BlueprintBox(
      filled: spec.selected,
      fillWidth: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: distance.gap(Proximity.related),
        children: <Widget>[
          BlueprintMark(_gutter(spec.oldNumber, spec.newNumber)),
          if (spec.marker != null) BlueprintText(spec.marker!),
          _marks(<String>[
            BlueprintMarks.tone(spec.tone),
            if (spec.selected) BlueprintMarks.selected(spec.selected),
          ]),
          Expanded(
            child: _Ink(child: Text.rich(TextSpan(children: _runs(spec.runs)))),
          ),
        ],
      ),
    ),
  );

  /// **Here is a whole block of machine output the user reads and copies** -
  /// git stdout, a command-log entry, a blame line, a commit message body.
  ///
  /// Selectability is behaviour, so it is honoured: a selectable block is a
  /// real `SelectableRegion` and the user can drag a selection across it. What
  /// it does not get is a selection toolbar, and that is the blueprint's one
  /// registered deviation - `AdaptiveTextSelectionToolbar` is Material and
  /// Cupertino, and importing it would break the compile-time proof this whole
  /// package exists to carry.
  ///
  /// Monospace is a family and the blueprint has one family, so the fact that
  /// this is code is stated with the code marker instead. Wrapping is a fact
  /// about the content rather than a look - command output is read unwrapped, a
  /// commit message wrapped - so it is passed straight through.
  @override
  Widget codeBlock(BuildContext context, CodeBlockSpec spec) {
    final bool hosted = _canSelect(context);
    final Widget body = _Ink(
      child: Text(
        spec.text,
        softWrap: spec.wrap,
        maxLines: spec.maxLines,
        overflow: spec.maxLines == null
            ? TextOverflow.clip
            : TextOverflow.ellipsis,
      ),
    );
    return BlueprintBox(
      fillWidth: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: distance.gap(Proximity.related),
        children: <Widget>[
          _marks(<String>[
            BlueprintMarks.textRole(TextRole.code),
            BlueprintMarks.tone(spec.tone),
            if (spec.wrap) '[wrap]',
            ..._selectionMarks(spec.selectable, hosted),
          ]),
          _selectable(body, spec.selectable && hosted),
        ],
      ),
    );
  }

  /// **Here is how this commit connects to the ones above and below it.**
  ///
  /// The application's only `CustomPainter` becomes this member, and the
  /// blueprint deliberately does not paint a graph: lane width, dot radius and
  /// stroke width are the three numbers that moved across the line, and drawing
  /// them back would be inventing the look the member exists to take away. What
  /// it draws instead is every fact the spec carries, in words - which lane the
  /// dot is in and out of how many, which member of the skin's series colours
  /// it, whether it is a merge, whether HEAD is on it, and every edge arriving,
  /// leaving and passing through with its own lane and series index.
  ///
  /// That is more falsifiable than a picture: a skin that drew the dot but
  /// dropped the passing lanes looks fine and reads wrong, and here the
  /// difference is a missing word.
  @override
  Widget commitGraphRow(
    BuildContext context,
    GraphRowSpec spec,
  ) => BlueprintBox(
    child: _wrap(<Widget>[
      BlueprintMark('[lane ${spec.lane} of ${spec.laneCount}]'),
      BlueprintMark(
        '[tone ${BlueprintMarks.tone(Tone.series(spec.toneIndex))}]',
      ),
      if (spec.isMerge) const BlueprintMark('[merge]'),
      if (spec.isCurrent) const BlueprintMark('[current]'),
      if (spec.incoming.isNotEmpty) BlueprintMark(_edges('in', spec.incoming)),
      if (spec.outgoing.isNotEmpty) BlueprintMark(_edges('out', spec.outgoing)),
      if (spec.passing.isNotEmpty)
        BlueprintMark(_edges('through', spec.passing)),
    ]),
  );

  // ---------------------------------------------------------------------
  // The two pictorial members
  // ---------------------------------------------------------------------

  /// **Here is a document written in Markdown.**
  ///
  /// The blueprint renders the source verbatim, and that is the honest answer
  /// rather than a shortcut: Markdown is text, so showing the text destroys no
  /// information, and every real skin owns the style sheet that turns it into a
  /// document. A skin that dropped `source` shows up here immediately.
  ///
  /// Two parameters cannot be rendered without the blueprint becoming a
  /// Markdown parser, which is a third-party job and not this instrument's, so
  /// each is stated as a mark instead: `[linkable]` when the document's links
  /// are live, and the base directory verbatim when relative links resolve
  /// against one. Both are recorded here rather than dropped, which is the
  /// obligation `docs/SKIN-CONTRACT-MEMBERS.md` §9.2 sets for a parameter a
  /// naked square cannot draw.
  @override
  Widget markdown(BuildContext context, MarkdownSpec spec) {
    final bool hosted = _canSelect(context);
    final Widget source = _Ink(child: Text(spec.source));
    return BlueprintBox(
      fillWidth: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: distance.gap(Proximity.related),
        children: <Widget>[
          _marks(<String>[
            '[markdown]',
            if (spec.onLinkTapped != null) '[linkable]',
            if (spec.baseDirectory != null) '[base ${spec.baseDirectory}]',
            ..._selectionMarks(spec.selectable, hosted),
          ]),
          _selectable(source, spec.selectable && hosted),
        ],
      ),
    );
  }

  /// **Here is a picture the user wants to look at closely.**
  ///
  /// The behaviour is what the member is for, so the behaviour is real: the
  /// picture pans and zooms. The picture itself is the one thing in this whole
  /// package that paints colours the blueprint did not choose, which is why it
  /// is fenced in a [BlueprintOpaque] - the chromatic census skips those rects,
  /// counts them and may only ever count fewer.
  ///
  /// It fills the height it is given rather than sizing to the picture, because
  /// deciding how large a picture should be is a design decision and this skin
  /// does not make any.
  @override
  Widget imageViewer(BuildContext context, ImageViewerSpec spec) =>
      BlueprintBox(
        fillWidth: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: distance.gap(Proximity.related),
          children: <Widget>[
            _marks(<String>[
              '[image]',
              if (spec.semanticsLabel != null) '[named]',
            ]),
            Expanded(
              child: BlueprintOpaque(
                site: 'surfaces.imageViewer',
                child: Semantics(
                  image: true,
                  label: spec.semanticsLabel,
                  child: InteractiveViewer(child: Image(image: spec.image)),
                ),
              ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------
  // Composition, shared by the members above
  // ---------------------------------------------------------------------

  /// One node of a tree, and the affordances hanging off it.
  ///
  /// The disclosure mark, the checkbox and the node's own menu are three
  /// separate controls inside one selectable row, which is what the spec says
  /// and what every real tree does: clicking the chevron opens the node,
  /// clicking the row selects it, and the two are not the same gesture.
  Widget _treeNode(TreeSpec spec, TreeNodeSpec node, int depth, bool open) {
    final bool selected = spec.selected.contains(node.id);
    final bool parent = node.children.isNotEmpty;
    return _ContentPressable(
      onPressed: () => spec.onSelect(node.id),
      onDoubleTap: spec.onActivate == null
          ? null
          : () => spec.onActivate!(node.id),
      onContextMenu: spec.onContextMenu == null
          ? null
          : (Offset at) => spec.onContextMenu!(node.id, at),
      selected: selected,
      child: BlueprintBox(
        rings: 1 + _focusRing(spec.containerFocused),
        filled: selected,
        fillWidth: true,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: distance.gap(Proximity.grouped) * depth,
          ),
          child: Row(
            spacing: distance.gap(Proximity.related),
            children: <Widget>[
              BlueprintPressable(
                onPressed: parent ? () => spec.onToggleExpanded(node.id) : null,
                child: BlueprintMark(_branch(depth, parent, open)),
              ),
              if (node.checked != null)
                BlueprintPressable(
                  onPressed: spec.onCheck == null
                      ? null
                      : () => spec.onCheck!(node.id, node.checked != true),
                  isButton: false,
                  checked: node.checked,
                  child: BlueprintMark(BlueprintMarks.check(node.checked)),
                ),
              _marks(<String>[_iconMark(node.leading)]),
              Expanded(child: node.content.mount()),
              _marks(<String>[
                _countMark(node.badgeCount),
                if (selected) BlueprintMarks.selected(selected),
                _containerMark(spec.containerFocused),
              ]),
              if (node.trailing != null) node.trailing!.mount(),
              _menuAnchor(node.menu),
            ],
          ),
        ),
      ),
    );
  }

  /// One action belonging to a panel's own header.
  ///
  /// It reads every field the entry carries, including the two a bar would
  /// normally hide: the label, which a glyph-only rendering would swallow, and
  /// the tooltip, which carries the REASON an action is unavailable and is
  /// therefore rendered even when [ToolbarActionEntry.onPressed] is null.
  Widget _action(BuildContext context, ToolbarActionEntry action) =>
      BlueprintPressable(
        onPressed: action.onPressed,
        tooltip: action.tooltip,
        child: BlueprintBox(
          stroke: BlueprintGeometry.stroke(context, action.emphasis),
          dashed: BlueprintGeometry.dashed(action.emphasis),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: distance.gap(Proximity.hairline),
            children: <Widget>[
              _marks(<String>[
                BlueprintMarks.icon(action.icon),
                _countMark(action.badgeCount),
                _enabledMark(action.onPressed != null),
              ]),
              BlueprintText(action.label),
            ],
          ),
        ),
      );

  /// One action offered by a banner, drawn as the outlined label §9.1 asks for.
  Widget _notice(NoticeAction action) => BlueprintPressable(
    onPressed: action.onPressed,
    tooltip: action.tooltip,
    child: BlueprintBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: distance.gap(Proximity.hairline),
        children: <Widget>[
          _marks(<String>[_iconMark(action.icon)]),
          BlueprintText(action.label),
        ],
      ),
    ),
  );

  /// The anchor a row or a node hangs its own menu off.
  ///
  /// The entries arrive as DATA precisely so that each skin can build its own
  /// anchor, and this is the blueprint's: a mark that opens the menu through
  /// [Overlays], the application's only overlay entry point. Going back in
  /// through the front door rather than calling the overlay facet directly is
  /// what re-captures the envelope, so a menu opened from a row is drawn by the
  /// same skin in the same brightness as the row.
  ///
  /// An empty menu draws nothing at all, because a menu anchor with nothing
  /// behind it is a control the user cannot use.
  Widget _menuAnchor(List<MenuEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Builder(
      builder: (BuildContext anchor) => BlueprintPressable(
        onPressed: () =>
            Overlays.menu(anchor, at: _centreOf(anchor), entries: entries),
        child: BlueprintMark('[menu ${entries.length}]'),
      ),
    );
  }

  /// A column whose rungs come from the instrument's distance.
  Widget _column(List<Widget> children) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: distance.gap(Proximity.grouped),
    children: children,
  );

  /// A run whose length the application decides, and which therefore may never
  /// be a `Row`: an overflowing row paints the framework's yellow-and-black
  /// stripes, and those pixels fail the chromatic census as an application leak
  /// the application did not cause.
  Widget _wrap(List<Widget> children) => Wrap(
    spacing: distance.gap(Proximity.related),
    runSpacing: distance.gap(Proximity.related),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );

  /// The marks that survived being at their default value.
  ///
  /// Empty strings are dropped rather than drawn, because [BlueprintMarks]
  /// answers nothing for a parameter that is where it always is - and a mark on
  /// every default would make every surface in the application carry one, which
  /// is how a marker vocabulary stops meaning anything.
  Widget _marks(List<String> marks) {
    final List<String> shown = marks
        .where((String mark) => mark.isNotEmpty)
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: distance.gap(Proximity.related),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[for (final String mark in shown) BlueprintMark(mark)],
    );
  }

  /// How much of a container's own inset the instrument is resolving today.
  Widget _inset(Inset inset, Widget child) {
    final double pad = distance.inset(inset);
    return pad == 0
        ? child
        : Padding(padding: EdgeInsets.all(pad), child: child);
  }

  /// The extra outline a surface wears while the collection holding it has the
  /// keyboard.
  ///
  /// This is `docs/SKIN-CONTRACT-MEMBERS.md` §9.1's "container focus = a second
  /// outline" taken literally. It is deliberately additive to the ring count
  /// [Elevation] already carries, which is why [_containerMark] exists beside
  /// it: the ring says which state this is, and the mark is what stops two
  /// vocabularies sharing one rendering from becoming ambiguous.
  static int _focusRing(bool containerFocused) => containerFocused ? 1 : 0;

  /// Which of the three selection states a surface is in.
  ///
  /// It follows [BlueprintMarks]' bracketed-name convention rather than living
  /// in that library, for one reason worth stating: [RowSelection] is the only
  /// vocabulary whose §9.1 rendering (the wash) collides with another's (the
  /// ring count, which carries [Elevation]), so the mark is a repair local to
  /// this facet rather than a thirteenth entry in the shared marker set.
  static String _selectionMark(RowSelection selection) =>
      selection == RowSelection.none
      ? BlueprintMarks.none
      : '[${selection.name}]';

  /// Whether the collection holding this surface has the keyboard.
  ///
  /// Marked only when it does NOT, because `containerFocused` defaults to true:
  /// the interesting fact is focus having left, which is the fact
  /// `base_tree_item.dart`'s roving-highlight rule turns on.
  static String _containerMark(bool focused) =>
      focused ? BlueprintMarks.none : '[containerUnfocused]';

  /// A thing that exists but cannot be used right now.
  static String _enabledMark(bool enabled) =>
      enabled ? BlueprintMarks.none : BlueprintMarks.disabled;

  /// A mark, or nothing where there is no mark to make.
  static String _iconMark(IconRole? role) =>
      role == null ? BlueprintMarks.none : BlueprintMarks.icon(role);

  /// A count, or nothing where there is nothing to count.
  static String _countMark(int? value) =>
      value == null ? BlueprintMarks.none : BlueprintMarks.count(value);

  /// Where a node sits, and whether it is open.
  ///
  /// One `.` per level of depth, then `v` for an open parent, `>` for a closed
  /// one and `·` for a leaf. The dots are what keep the hierarchy legible when
  /// the indent collapses to zero, which it does at every distance the
  /// instrument is swept at except the largest.
  static String _branch(int depth, bool parent, bool open) =>
      '${'.' * depth}${parent ? (open ? 'v' : '>') : '·'}';

  /// Whether a real selection can be offered where this member is being built.
  ///
  /// `SelectableRegion` is the only way `package:flutter/widgets.dart` offers to
  /// make non-editable text selectable, and it requires an `Overlay` ancestor -
  /// it throws at build time without one, before any selection is attempted.
  /// The application root has one, because the root sits under a navigator; a
  /// surface pumped on its own in a test does not.
  ///
  /// So the blueprint asks first, and where the answer is no it renders the
  /// text unselectable AND says so. Silently dropping the selection would be a
  /// skin quietly losing behaviour, which is the exact failure this instrument
  /// exists to expose; throwing would make a harness's missing overlay look
  /// like the application's defect. Saying it out loud is the only answer that
  /// is neither.
  static bool _canSelect(BuildContext context) =>
      Overlay.maybeOf(context) != null;

  /// What a block of text says about its own selectability.
  static List<String> _selectionMarks(bool asked, bool hosted) => <String>[
    if (!asked) '[unselectable]',
    if (asked && !hosted) '[noSelectionHost]',
  ];

  /// The block, selectable where that was asked for and possible.
  ///
  /// No `contextMenuBuilder` is supplied, and that is the blueprint's one
  /// registered deviation: `AdaptiveTextSelectionToolbar` is Material and
  /// Cupertino, and importing it would break the compile-time proof this
  /// package's build is supposed to be. The selection works; the toolbar over
  /// it does not exist.
  static Widget _selectable(Widget body, bool selectable) => selectable
      ? SelectableRegion(
          selectionControls: emptyTextSelectionControls,
          child: body,
        )
      : body;

  /// Which line this is on each side of a diff.
  static String _gutter(int? oldNumber, int? newNumber) =>
      '${oldNumber ?? '-'}/${newNumber ?? '-'}';

  /// Every lane crossing a commit row, with the series member colouring it.
  static String _edges(String direction, List<GraphEdgeSpec> edges) =>
      '[$direction ${edges.map((GraphEdgeSpec edge) => '${edge.lane}:${edge.toneIndex}').join(' ')}]';

  /// How tightly a grid's cells are packed, as an inset rather than a height.
  static Inset _densityInset(GridDensity density) => switch (density) {
    GridDensity.compact => Inset.tight,
    GridDensity.normal => Inset.normal,
    GridDensity.roomy => Inset.roomy,
  };

  /// The runs of a code line, each beside its own marks and never merged into
  /// them: the run's span carries exactly the characters the application gave.
  static List<InlineSpan> _runs(List<TextRun> runs) {
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final TextRun run in runs) {
      final String tone = BlueprintMarks.tone(run.tone);
      if (tone.isNotEmpty) spans.add(TextSpan(text: tone));
      if (run.emphasised) {
        spans.add(TextSpan(text: BlueprintMarks.textRole(TextRole.emphasis)));
      }
      spans.add(TextSpan(text: run.text));
    }
    return spans;
  }

  /// Where a widget is, in the coordinates an overlay is placed in.
  static Offset _centreOf(BuildContext context) {
    final RenderObject? object = context.findRenderObject();
    if (object == null) return Offset.zero;
    return MatrixUtils.transformPoint(
      object.getTransformTo(null),
      object.paintBounds.center,
    );
  }
}

/// The one style, installed around a text this facet has to build itself.
///
/// [BlueprintText] is where every string in this package is drawn, and three
/// of this facet's members cannot go through it: a code line is a `Text.rich`
/// whose runs are separate spans, and a code block and a Markdown source carry
/// [CodeBlockSpec.wrap] and [CodeBlockSpec.maxLines], which are facts about the
/// content the application states and a skin may not decide. Rather than give
/// those three a style each, this installs the same resolved style with a
/// `DefaultTextStyle` and lets the text inherit it - so
/// [BlueprintInk.textStyle]'s guarantee still holds (a style that arrived
/// without a colour is forced to ink, and nothing is ever drawn in the engine's
/// default white where it would pass the chromatic census invisibly).
///
/// It wraps only text this package built. A [ContentPort] is never put inside
/// one: a skin positions and constrains a port and must never style it, and a
/// `DefaultTextStyle` around a port is styling it.
class _Ink extends StatelessWidget {
  const _Ink({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      DefaultTextStyle(style: BlueprintInk.textStyle(context), child: child);
}

/// A region the user can operate that leaves the semantics BELOW it standing.
///
/// It differs from [BlueprintPressable] in two ways, and each of them is a
/// property a surface needs and a control does not.
///
/// The shared primitive merges its whole subtree into one semantics node, which
/// is right for a control whose meaning is its own visible label - a tab, a
/// panel action, a menu anchor, a tag's removal, all of which use it below.
/// It is wrong for a surface that holds OTHER controls: a list row and a tree
/// node each mount a [ContentPort] and then hang their own affordances beside
/// it - a chevron, a tri-state checkbox, a menu anchor - and merging collapses
/// all of them into one node, so a screen reader can no longer reach any of
/// them separately. That is an accessibility regression the instrument would
/// then report as the application's.
///
/// The shared primitive also takes "operable" to mean `onPressed != null`,
/// which would leave a surface that is only right-clickable out of the focus
/// order. A row whose sole affordance is its context menu still has to be
/// reachable from the keyboard.
///
/// It is written here rather than in `blueprint_ink.dart` because that library
/// is shared and was being written concurrently. Its honest home is a flag on
/// [BlueprintPressable]; moving it there is a one-line change at each call site
/// below and deletes this class.
class _ContentPressable extends StatelessWidget {
  const _ContentPressable({
    required this.child,
    this.onPressed,
    this.onDoubleTap,
    this.onContextMenu,
    this.selected,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  });

  /// What is inside, semantics and all.
  final Widget child;

  /// What operating it does.
  final VoidCallback? onPressed;

  /// What operating it twice does, where that means something else.
  final VoidCallback? onDoubleTap;

  /// What asking it for a menu does, and where the user asked.
  final ValueChanged<Offset>? onContextMenu;

  /// Whether it is currently chosen.
  final bool? selected;

  /// What it is, for a screen reader, where the content does not say.
  final String? semanticsLabel;

  /// The longer explanation, announced rather than hovered: `Tooltip` is a
  /// Material widget and drawing one would be both a design decision and an
  /// import this package may not make.
  final String? tooltip;

  /// Whether it may be operated at all.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool operable =
        enabled &&
        (onPressed != null || onDoubleTap != null || onContextMenu != null);
    return Semantics(
      button: onPressed != null,
      enabled: operable,
      label: semanticsLabel,
      tooltip: tooltip,
      selected: selected,
      child: FocusableActionDetector(
        enabled: operable,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              onPressed?.call();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) {
              onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: operable ? onPressed : null,
          onDoubleTap: operable ? onDoubleTap : null,
          onSecondaryTapUp: operable && onContextMenu != null
              ? (TapUpDetails details) =>
                    onContextMenu!.call(details.globalPosition)
              : null,
          child: child,
        ),
      ),
    );
  }
}
