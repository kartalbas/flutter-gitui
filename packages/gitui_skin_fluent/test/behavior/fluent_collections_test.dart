/// The collection surfaces: the list row, the tree, the tabs, the
/// disclosure and the card - every touchable state read from the paint
/// stream, and every assertion one a reimplementation gets wrong: the
/// selected tile wearing the HOVER fill at rest, the accent pill that
/// collapses while pressed and goes neutral when the collection loses the
/// keyboard, the chevron that is its own gesture inside a selectable row,
/// and the tab that merges into the content layer.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_checkbox.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_control_marks.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_surfaces.dart';
import 'package:gitui_skin_fluent/src/fluent_accent.dart';
import 'package:gitui_skin_fluent/src/fluent_motion.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';
import 'package:gitui_skin_fluent/src/surfaces/fluent_list_row.dart';
import 'package:gitui_skin_fluent/src/surfaces/fluent_surface_parts.dart';

import 'support/fluent_behavior_harness.dart';

const FluentResources _light = FluentResources.light();
const FluentAccent _accent = FluentAccent.windowsDefault();

/// A member built exactly as the application reaches it.
Widget _member(Widget Function(BuildContext context) build) =>
    Builder(builder: build);

/// The row's own container - the first AnimatedContainer under the row,
/// which is the tile (the menu anchor would add a second, so these tests
/// keep menus empty except where the anchor itself is the subject).
Finder _tile() => find
    .descendant(
      of: find.byType(FluentListRow),
      matching: find.byType(AnimatedContainer),
    )
    .first;

void main() {
  group('the list row', () {
    testWidgets('rests transparent and wears the HOVER fill while '
        'selected - the selected tile treatment a reimplementation '
        'flattens into a special colour', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(
        paintedFillColors(tester, _tile()).first.a,
        0,
        reason: 'rest is nothing',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                selection: RowSelection.primary,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectPaintedColor(
        // The tile's own fill paints first; the selection pill inside it
        // paints after.
        paintedFillColors(tester, _tile()).first,
        _light.subtleFillColorSecondary,
        reason:
            'a selected tile resolves with the hovered state unioned in '
            '(list_tile.dart:280-286)',
      );
    });

    testWidgets('the primary selection wears the 3 epx accent pill, '
        'ANIMATED in - and it collapses while the row is pressed', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                selection: RowSelection.primary,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      // Mid-flight: the pill is growing at the medium (250 ms) step.
      await tester.pump(const Duration(milliseconds: 80));
      final double midway = tester
          .getSize(
            find.descendant(
              of: find.byType(FluentSelectionPill),
              matching: find.byType(Container),
            ),
          )
          .height;
      await tester.pumpAndSettle();
      final Size pill = tester.getSize(
        find.descendant(
          of: find.byType(FluentSelectionPill),
          matching: find.byType(Container),
        ),
      );
      expect(pill.width, FluentSurfaceMetrics.pillWidth);
      expectPaintedColor(
        paintedFillColors(tester, find.byType(FluentSelectionPill)).single,
        _accent.defaultBrushFor(Brightness.light),
        reason: 'the pill is the accent while the collection has the keyboard',
      );
      final double settled = pill.height;
      expect(
        settled,
        // A literal, never derived from the constant under test - a pin
        // computed from the factor would drift along with it.
        moreOrLessEquals(28.0, epsilon: 0.01),
        reason:
            'at rest the pill stands at 70% of the 40 epx tile minimum '
            '(list_tile.dart:374,383) - pinned, so the factor cannot drift',
      );
      expect(
        midway,
        allOf(greaterThan(0), lessThan(settled)),
        reason: 'the pill was mid-grow 80 ms into the medium step',
      );
      expect(
        tester.getSize(find.byType(FluentListRow)).height,
        FluentSurfaceMetrics.tileMinHeight + 4,
        reason:
            'the tile keeps its own 40 epx minimum plus its 2/2 vertical '
            'margins - the pill must never stretch it to the viewport',
      );

      // Pressing collapses it to 30% of the tile minimum
      // (list_tile.dart:373, `tileHeight * 0.3`).
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_tile()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final double pressed = tester
          .getSize(
            find.descendant(
              of: find.byType(FluentSelectionPill),
              matching: find.byType(Container),
            ),
          )
          .height;
      expect(
        pressed,
        lessThan(settled),
        reason: 'the pill shrinks under the press',
      );
      expect(
        pressed,
        // A literal: 40 * 0.3 * 0.7. Deriving the pin from the constants
        // under test would let the collapse drift unnoticed.
        moreOrLessEquals(8.4, epsilon: 0.01),
        reason:
            'the published collapse is 30% of the 40 epx tile minimum, '
            'then the pill\'s own 70% (list_tile.dart:373,383) - pinned, '
            'so the depth cannot drift',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a selected row lays out inside a real ListView - the '
        'unbounded-height viewport every application list provides', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          height: 300,
          child: ListView(
            children: <Widget>[
              _member(
                (BuildContext context) => const FluentSurfaces().listRow(
                  context,
                  ListRowSpec(
                    title: const ContentPort(Text('alpha')),
                    selection: RowSelection.primary,
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(FluentListRow)).height,
        FluentSurfaceMetrics.tileMinHeight + 4,
        reason:
            'under a viewport\'s unbounded height the tile is its 40 epx '
            'minimum plus margins - a fractional pill turns 0 * infinity '
            'into NaN here and crashes the list',
      );
    });

    testWidgets('when the collection loses the keyboard the pill goes '
        'neutral - still the selection, no longer claiming the focus', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                selection: RowSelection.primary,
                containerFocused: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectPaintedColor(
        paintedFillColors(tester, find.byType(FluentSelectionPill)).single,
        _light.controlStrongFillColorDefault,
      );
    });

    testWidgets('a gathered row (multi) carries the checked mark, inert on '
        'purpose: the ROW answers the press', (WidgetTester tester) async {
      int taps = 0;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                selection: RowSelection.multi,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(FluentCheckboxBox), findsOneWidget);
      await tester.tap(find.byType(FluentCheckboxBox));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        taps,
        1,
        reason:
            'the mark reflects the selection and the row takes the tap '
            '(list_tile.dart:352-361)',
      );
    });

    testWidgets('the double click opens; the first tap still answers '
        'immediately', (WidgetTester tester) async {
      int taps = 0;
      int opens = 0;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                onTap: () => taps++,
                onActivate: () => opens++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(_tile());
      await tester.pump();
      expect(taps, 1);
      await tester.tap(_tile());
      await tester.pump();
      expect(opens, 1);
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('the secondary button asks for the row\'s menu with its '
        'position', (WidgetTester tester) async {
      Offset? at;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                onContextMenu: (Offset offset) => at = offset,
              ),
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_tile()),
        buttons: kSecondaryButton,
      );
      await gesture.up();
      await tester.pump();
      expect(at, isNotNull);
    });

    testWidgets('a count rides the row as the InfoBadge, and a menu as the '
        'drawn more-anchor', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().listRow(
              context,
              ListRowSpec(
                title: const ContentPort(Text('alpha')),
                badgeCount: 7,
                menu: <MenuEntry>[MenuAction(label: 'Open', onPressed: () {})],
              ),
            ),
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.byType(FluentMoreMark), findsOneWidget);
    });
  });

  group('the tree', () {
    TreeSpec spec({
      Set<Object> expanded = const <Object>{},
      Set<Object> selected = const <Object>{},
      bool containerFocused = true,
      ValueChanged<Object>? onToggle,
      ValueChanged<Object>? onSelect,
      ValueChanged<Object>? onActivate,
      void Function(Object, bool?)? onCheck,
      bool checkable = false,
    }) => TreeSpec(
      roots: <TreeNodeSpec>[
        TreeNodeSpec(
          id: 'a',
          content: const ContentPort(Text('alpha')),
          checked: checkable ? true : null,
          children: <TreeNodeSpec>[
            TreeNodeSpec(id: 'b', content: const ContentPort(Text('beta'))),
          ],
        ),
      ],
      expanded: expanded,
      selected: selected,
      containerFocused: containerFocused,
      onToggleExpanded: onToggle ?? (Object _) {},
      onSelect: onSelect ?? (Object _) {},
      onActivate: onActivate,
      onCheck: onCheck,
    );

    Widget tree(TreeSpec spec) => SizedBox(
      width: 400,
      height: 300,
      child: _member(
        (BuildContext context) => const FluentSurfaces().tree(context, spec),
      ),
    );

    testWidgets('a closed node hides its children; an open one shows them '
        'INDENTED by the level', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, tree(spec()));
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(tester, tree(spec(expanded: <Object>{'a'})));
      expect(find.text('beta'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('beta')).dx,
        tester.getTopLeft(find.text('alpha')).dx +
            FluentSurfaceMetrics.treeIndent,
        reason: '16 epx per level (tree_view.dart:41,:1451-1453)',
      );
    });

    testWidgets('the chevron is its OWN gesture: it opens the node and '
        'does not select it', (WidgetTester tester) async {
      final List<Object> toggled = <Object>[];
      final List<Object> selectedIds = <Object>[];
      await pumpFluentBehavior(
        tester,
        tree(spec(onToggle: toggled.add, onSelect: selectedIds.add)),
      );
      await tester.tap(find.byType(FluentChevron));
      await tester.pump(const Duration(milliseconds: 200));
      expect(toggled, <Object>['a']);
      expect(
        selectedIds,
        isEmpty,
        reason:
            'clicking the chevron opens, clicking the row selects - two '
            'gestures, not one',
      );
      await tester.tap(find.text('alpha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(selectedIds, <Object>['a']);
    });

    testWidgets('the double click opens the node; the first tap still '
        'selects immediately - the same interval recognition the list row '
        'answers with', (WidgetTester tester) async {
      final List<Object> selectedIds = <Object>[];
      final List<Object> opened = <Object>[];
      await pumpFluentBehavior(
        tester,
        tree(spec(onSelect: selectedIds.add, onActivate: opened.add)),
      );
      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect(
        selectedIds,
        <Object>['a'],
        reason:
            'the first tap answers immediately - a row that holds its '
            'tap for the double-tap window feels broken',
      );
      expect(opened, isEmpty);
      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect(opened, <Object>[
        'a',
      ], reason: 'the second tap inside the 300 ms window opens the node');
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('a selected node wears the pill and the selected fill', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, tree(spec(selected: <Object>{'a'})));
      await tester.pumpAndSettle();
      final List<Color> fills = paintedFillColors(
        tester,
        find.byType(AnimatedContainer),
      );
      expect(
        fills.any(
          (Color fill) =>
              fill.toARGB32() == _light.subtleFillColorSecondary.toARGB32(),
        ),
        isTrue,
        reason: 'the selected row wears the hover fill at rest',
      );
      // The pill: the accent-filled rounded rectangle at the row's start
      // (tree_view.dart:1559-1571).
      final Color accent = _accent.defaultBrushFor(Brightness.light);
      final List<Color> rowPaints = paintedFillColors(
        tester,
        find.byType(Stack),
      );
      expect(
        rowPaints.any((Color fill) => fill.toARGB32() == accent.toARGB32()),
        isTrue,
        reason: 'the 3 epx accent pill marks the selection',
      );
    });

    testWidgets('a checked node draws the checkbox and reports the NEXT '
        'state through onCheck', (WidgetTester tester) async {
      final List<(Object, bool?)> checks = <(Object, bool?)>[];
      await pumpFluentBehavior(
        tester,
        tree(
          spec(
            checkable: true,
            onCheck: (Object id, bool? value) => checks.add((id, value)),
          ),
        ),
      );
      expect(find.byType(FluentCheckboxBox), findsOneWidget);
      await tester.tap(find.byType(FluentCheckboxBox));
      await tester.pump(const Duration(milliseconds: 200));
      expect(checks, <(Object, bool?)>[('a', false)]);
    });

    testWidgets('revealed scrolls the named node into the viewport when '
        'the value ARRIVES - and only then', (WidgetTester tester) async {
      final TreeSpec bigSpec = TreeSpec(
        roots: <TreeNodeSpec>[
          for (int i = 0; i < 60; i++)
            TreeNodeSpec(id: i, content: ContentPort(Text('node $i'))),
        ],
        expanded: const <Object>{},
        selected: const <Object>{},
        onToggleExpanded: (Object _) {},
        onSelect: (Object _) {},
        revealed: 50,
      );
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          height: 300,
          child: _member(
            (BuildContext context) =>
                const FluentSurfaces().tree(context, bigSpec),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );
      expect(
        scrollable.position.pixels,
        greaterThan(0),
        reason: 'node 50 cannot be inside a 300 px viewport from the top',
      );
      expect(find.text('node 50'), findsOneWidget);
    });
  });

  group('the tabs', () {
    TabSetSpec tabs({
      required int selectedIndex,
      ValueChanged<int>? onSelect,
      List<String>? built,
    }) => TabSetSpec(
      tabs: <TabEntry>[
        TabEntry(
          label: 'One',
          body: () {
            built?.add('One');
            return const ContentPort(Text('body one'));
          },
        ),
        TabEntry(
          label: 'Two',
          body: () {
            built?.add('Two');
            return const ContentPort(Text('body two'));
          },
        ),
      ],
      selectedIndex: selectedIndex,
      onSelect: onSelect ?? (int _) {},
    );

    Widget view(TabSetSpec spec) => SizedBox(
      width: 400,
      height: 300,
      child: _member(
        (BuildContext context) => const FluentSurfaces().tabs(context, spec),
      ),
    );

    testWidgets('the selected tab fills with the content layer and MERGES '
        'into the body painted in the same layer', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, view(tabs(selectedIndex: 0)));
      final Finder selectedTab = find.ancestor(
        of: find.text('One'),
        matching: find.byType(AnimatedContainer),
      );
      expectPaintedColor(
        singleFillOf(tester, selectedTab.first),
        _light.solidBackgroundFillColorTertiary,
        reason: 'the selected tab paints the content layer (tab.dart:372)',
      );
      final Finder restingTab = find.ancestor(
        of: find.text('Two'),
        matching: find.byType(AnimatedContainer),
      );
      expect(
        singleFillOf(tester, restingTab.first).a,
        0,
        reason: 'an unselected tab rests transparent (tab.dart:380)',
      );
    });

    testWidgets('only the selected body is BUILT - the reference shows one '
        'body at a time, where Material\'s page view holds neighbours', (
      WidgetTester tester,
    ) async {
      final List<String> built = <String>[];
      await pumpFluentBehavior(
        tester,
        view(tabs(selectedIndex: 0, built: built)),
      );
      expect(built, <String>['One']);
      expect(find.text('body one'), findsOneWidget);
      expect(find.text('body two'), findsNothing);
    });

    testWidgets('choosing a tab reports its index', (
      WidgetTester tester,
    ) async {
      final List<int> chosen = <int>[];
      await pumpFluentBehavior(
        tester,
        view(tabs(selectedIndex: 0, onSelect: chosen.add)),
      );
      await tester.tap(find.text('Two'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(chosen, <int>[1]);
    });
  });

  group('the disclosure', () {
    DisclosureSpec spec({
      required bool expanded,
      ValueChanged<bool>? onChanged,
      bool enabled = true,
    }) => DisclosureSpec(
      header: const ContentPort(Text('header')),
      body: const ContentPort(Text('the body')),
      expanded: expanded,
      onExpandedChanged: onChanged ?? (bool _) {},
      enabled: enabled,
    );

    Widget disclosure(DisclosureSpec spec) => SizedBox(
      width: 400,
      child: _member(
        (BuildContext context) =>
            const FluentSurfaces().disclosure(context, spec),
      ),
    );

    testWidgets('the body exists only while open, the chevron makes the '
        'half-turn, and the reveal is ANIMATED at the medium step', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, disclosure(spec(expanded: false)));
      expect(find.text('the body'), findsNothing);
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(tester, disclosure(spec(expanded: true)));
      await tester.pumpAndSettle();
      expect(find.text('the body'), findsOneWidget);
      final AnimatedRotation chevron = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(chevron.turns, 0.5, reason: 'expander.dart:383-395');
      expect(
        chevron.duration,
        FluentMotion.medium,
        reason: 'the half-turn runs at the medium step',
      );
      expect(
        tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
        FluentMotion.medium,
        reason: 'and so does the reveal (expander.dart:284-296)',
      );
    });

    testWidgets('the whole header is the control and reports the flip; '
        'disabled reports nothing', (WidgetTester tester) async {
      final List<bool> flips = <bool>[];
      await pumpFluentBehavior(
        tester,
        disclosure(spec(expanded: false, onChanged: flips.add)),
      );
      await tester.tap(find.text('header'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(flips, <bool>[true]);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(
        tester,
        disclosure(spec(expanded: false, onChanged: flips.add, enabled: false)),
      );
      await tester.tap(find.text('header'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(flips, hasLength(1), reason: 'a disabled disclosure stays shut');
    });

    testWidgets('the header is a card band: card fill behind the card '
        'stroke', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, disclosure(spec(expanded: false)));
      final List<Color> fills = paintedFillColors(
        tester,
        find.byType(Container).first,
      );
      expect(
        fills.any(
          (Color fill) =>
              fill.toARGB32() ==
              _light.cardBackgroundFillColorDefault.toARGB32(),
        ),
        isTrue,
        reason: 'expander.dart:327-341',
      );
    });
  });

  group('the card', () {
    CardSpec spec({
      RowSelection selection = RowSelection.none,
      bool containerFocused = true,
      Tone tone = Tone.neutral,
      VoidCallback? onTap,
    }) => CardSpec(
      content: const ContentPort(Text('content')),
      selection: selection,
      containerFocused: containerFocused,
      tone: tone,
      onTap: onTap,
    );

    Widget card(CardSpec spec) => SizedBox(
      width: 300,
      child: _member(
        (BuildContext context) => const FluentSurfaces().card(context, spec),
      ),
    );

    Finder box() => find.byType(DecoratedBox).first;

    testWidgets('a resting card is a FILL plus a ONE-EPX STROKE - never a '
        'shadow, never a tint: Fluent\'s whole depth grammar', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(tester, card(spec()));
      final List<Color> fills = paintedFillColors(tester, box());
      expect(
        fills.any(
          (Color fill) =>
              fill.toARGB32() ==
              _light.cardBackgroundFillColorDefault.toARGB32(),
        ),
        isTrue,
        reason: 'CardBackgroundFillColorDefault (card.dart:107-112)',
      );
      // A uniform box border reaches the canvas as a drawDRRect ring, so
      // the stroke reader recovers its width from the two rectangles.
      final List<PaintedStroke> strokes = paintedStrokes(tester, box());
      expect(strokes, isNotEmpty);
      expect(strokes.first.width, 1);
      expectPaintedColor(strokes.first.color, _light.cardStrokeColorDefault);
    });

    testWidgets('a selected card wears the 2 epx accent stroke while its '
        'collection has the keyboard, and the strong neutral when it does '
        'not', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        card(spec(selection: RowSelection.primary, onTap: () {})),
      );
      final List<PaintedStroke> focused = paintedStrokes(tester, box());
      expect(focused.first.width, 2);
      expectPaintedColor(
        focused.first.color,
        _accent.defaultBrushFor(Brightness.light),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(
        tester,
        card(
          spec(
            selection: RowSelection.primary,
            containerFocused: false,
            onTap: () {},
          ),
        ),
      );
      final List<PaintedStroke> unfocused = paintedStrokes(tester, box());
      expect(unfocused.first.width, 2);
      expectPaintedColor(
        unfocused.first.color,
        _light.controlStrongStrokeColorDefault,
      );
    });

    testWidgets('an object\'s identity is worn on the STROKE - in a '
        'language whose card is fill plus stroke, the edge is where a '
        'colour means something', (WidgetTester tester) async {
      await pumpFluentBehavior(tester, card(spec(tone: const Tone.series(4))));
      final List<PaintedStroke> strokes = paintedStrokes(tester, box());
      // series(4) on light surfaces is blue.dark (FluentInk.seriesLight).
      expectPaintedColor(strokes.first.color, const Color(0xFF0066B4));
    });

    testWidgets('a gathered card carries the checked mark in its corner - '
        'WinUI\'s multiple-selection treatment', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        card(spec(selection: RowSelection.multi)),
      );
      expect(find.byType(FluentCheckboxBox), findsOneWidget);
    });

    testWidgets('a card with onTap answers the tap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpFluentBehavior(tester, card(spec(onTap: () => taps++)));
      await tester.tap(find.text('content'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });
  });
}
