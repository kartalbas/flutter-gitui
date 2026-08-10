/// The layout facet, measured: the Fluent 2 spacing ramp under the
/// contract's vocabulary, the language's own divider, the property list
/// WITHOUT the colon Material draws, the Windows split pane, and the grid
/// that reports its columns.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_layout.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';

import 'support/fluent_behavior_harness.dart';

const FluentLayout facet = FluentLayout();
const FluentResources _light = FluentResources.light();

/// Builds one facet member under the harness.
Widget _member(Widget Function(BuildContext context) build) =>
    Builder(builder: (BuildContext context) => build(context));

/// A port around a fixed box, findable by key.
ContentPort _box(String key, {double width = 40, double height = 20}) =>
    ContentPort(
      SizedBox(key: ValueKey<String>(key), width: width, height: height),
    );

void main() {
  group('column, row and gap resolve the Fluent ramp', () {
    testWidgets(
      'a column at sectioned opens Fluent\'s 24, not Material\'s 32',
      (WidgetTester tester) async {
        await pumpFluentBehavior(
          tester,
          _member(
            (BuildContext context) => facet.column(context, <ContentPort>[
              _box('a'),
              _box('b'),
            ], gap: Proximity.sectioned),
          ),
        );
        final double delta =
            tester.getTopLeft(find.byKey(const ValueKey<String>('b'))).dy -
            tester.getBottomLeft(find.byKey(const ValueKey<String>('a'))).dy;
        // Fluent 2 spacingHorizontalXXL = 24: the ramp's largest ordinary
        // rung, where Material's fifth rung is 32.
        expect(delta, 24);
      },
    );

    testWidgets('a row at related sits 8 apart, and hairline touches at 4', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => facet.column(context, <ContentPort>[
            ContentPort(
              _member(
                (BuildContext context) => facet.row(context, <ContentPort>[
                  _box('a'),
                  _box('b'),
                ], size: MainAxisSize.min),
              ),
            ),
            ContentPort(
              _member(
                (BuildContext context) => facet.row(
                  context,
                  <ContentPort>[_box('c'), _box('d')],
                  gap: Proximity.hairline,
                  size: MainAxisSize.min,
                ),
              ),
            ),
          ]),
        ),
      );
      double gapBetween(String left, String right) =>
          tester.getTopLeft(find.byKey(ValueKey<String>(right))).dx -
          tester.getTopRight(find.byKey(ValueKey<String>(left))).dx;
      expect(gapBetween('a', 'b'), 8); // spacingHorizontalS.
      expect(gapBetween('c', 'd'), 4); // spacingHorizontalXS.
    });

    testWidgets('a free-standing gap reads its axis from the enclosing flex', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: 10, height: 10),
            _member(
              (BuildContext context) => facet.gap(context, Proximity.grouped),
            ),
            const SizedBox(width: 10, height: 10),
          ],
        ),
      );
      // Inside a Row the gap is horizontal: 12 wide (spacingHorizontalM),
      // no height of its own.
      final Size gap = tester.getSize(find.byType(SizedBox).at(1));
      expect(gap.width, 12);
      expect(gap.height, 0);
    });

    testWidgets('inset resolves per axis, tight vertical inside normal', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) =>
              facet.inset(context, _box('c'), y: Inset.tight),
        ),
      );
      final Offset outer = tester.getTopLeft(find.byType(Padding));
      final Offset inner = tester.getTopLeft(
        find.byKey(const ValueKey<String>('c')),
      );
      // Horizontal keeps Inset.normal = 12 (spacingHorizontalM); vertical
      // takes Inset.tight = 6 (spacingHorizontalSNudge).
      expect(inner.dx - outer.dx, 12);
      expect(inner.dy - outer.dy, 6);
    });
  });

  group('separator', () {
    testWidgets('one physical stroke of the language\'s divider ink, with '
        'the indent on the leading edge only', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 200,
          child: _member(
            (BuildContext context) =>
                facet.separator(context, indent: Inset.normal),
          ),
        ),
      );
      // The Container's own box includes the indent margin; the painted
      // rule is the ColoredBox inside it.
      final Finder rule = find.descendant(
        of: find.byType(Container),
        matching: find.byType(ColoredBox),
      );
      expect(tester.getSize(rule).height, 1); // divider.dart:188.
      // DividerStrokeColorDefault light (color_resources.dart:325).
      expectPaintedColor(
        singleFillOf(tester, rule),
        _light.dividerStrokeColorDefault,
      );
      // The indent leads: 12 off the start, flush at the end. The outer
      // Container spans the member's full width; the rule sits inside it.
      final Finder host = find.byType(Container);
      expect(tester.getTopLeft(rule).dx - tester.getTopLeft(host).dx, 12);
      expect(tester.getTopRight(rule).dx, tester.getTopRight(host).dx);
    });
  });

  group('propertyList', () {
    testWidgets('labels are bare body text - no colon, no emboldening - and '
        'the values line up on the longest label', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => facet.propertyList(
              context,
              PropertyListSpec(
                rows: <PropertyRow>[
                  PropertyRow(label: 'Total Lines', value: _box('v1')),
                  PropertyRow(label: 'Author', value: _box('v2')),
                ],
              ),
            ),
          ),
        ),
      );
      // The Fluent divergence Material cannot show: WinUI labels carry no
      // terminal punctuation (InfoLabel renders the bare label,
      // info_label.dart:49-52), where the Material skin draws
      // "Total Lines:".
      expect(find.text('Total Lines'), findsOneWidget);
      expect(find.text('Total Lines:'), findsNothing);
      // Regular body, not a heavier step: hierarchy comes from the aligned
      // column, not from weight.
      final RenderParagraph label = tester.renderObject<RenderParagraph>(
        find.text('Total Lines'),
      );
      expect(label.text.style?.fontSize, 14);
      expect(label.text.style?.fontWeight, isNot(FontWeight.w600));
      // Both values start at the same x: the label column sized to the
      // longest label.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('v1'))).dx,
        tester.getTopLeft(find.byKey(const ValueKey<String>('v2'))).dx,
      );
    });
  });

  group('splitPane', () {
    SplitPaneSpec spec({
      required double fraction,
      PaneSide side = PaneSide.leading,
      ValueChanged<double>? onFractionChanged,
    }) => SplitPaneSpec(
      primary: _box('primary', width: 10, height: 10),
      secondary: _box('secondary', width: 10, height: 10),
      axis: Axis.horizontal,
      fraction: fraction,
      resizableSide: side,
      onFractionChanged: onFractionChanged,
    );

    testWidgets('the handle is an 8 epx strip around the divider hairline, '
        'with the column-resize cursor', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 600,
          height: 200,
          child: _member(
            (BuildContext context) => facet.splitPane(
              context,
              spec(fraction: 0.5, onFractionChanged: (double _) {}),
            ),
          ),
        ),
      );
      final Finder region = find.byType(MouseRegion).last;
      expect(tester.getSize(region).width, 8); // FluentMetrics.spaceS.
      expect(
        tester.widget<MouseRegion>(region).cursor,
        SystemMouseCursors.resizeColumn,
      );
      final Finder hairline = find.descendant(
        of: region,
        matching: find.byType(Container),
      );
      expect(tester.getSize(hairline).width, 1);
      expectPaintedColor(
        singleFillOf(tester, hairline),
        _light.dividerStrokeColorDefault,
      );
    });

    testWidgets('hovering the handle paints the subtle hover layer - a '
        'boundary that can move says so', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 600,
          height: 200,
          child: _member(
            (BuildContext context) => facet.splitPane(
              context,
              spec(fraction: 0.5, onFractionChanged: (double _) {}),
            ),
          ),
        ),
      );
      final Finder handle = find.byType(MouseRegion).last;
      await hoverOver(tester, handle);
      // The handle subtree paints the strip's hover layer and the hairline;
      // the hover step of the subtle ladder must be among the fills.
      final List<Color> fills = paintedFillColors(tester, handle);
      expect(
        fills.map((Color fill) => fill.toARGB32()),
        contains(_light.subtleFillColorSecondary.toARGB32()),
        reason: 'the strip composites SubtleFillColorSecondary while hovered',
      );
    });

    testWidgets('dragging the boundary towards the trailing edge grows the '
        'primary share, whichever side owns the handle', (
      WidgetTester tester,
    ) async {
      for (final PaneSide side in PaneSide.values) {
        double? reported;
        await pumpFluentBehavior(
          tester,
          SizedBox(
            width: 600,
            height: 200,
            child: _member(
              (BuildContext context) => facet.splitPane(
                context,
                spec(
                  fraction: 0.5,
                  side: side,
                  onFractionChanged: (double next) => reported = next,
                ),
              ),
            ),
          ),
        );
        await tester.drag(find.byType(MouseRegion).last, const Offset(60, 0));
        expect(
          reported,
          greaterThan(0.5),
          reason:
              'a rightward drag enlarges the leading half ($side owns the '
              'handle)',
        );
      }
    });

    testWidgets('a fixed division draws the hairline without advertising a '
        'drag', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 600,
          height: 200,
          child: _member(
            (BuildContext context) =>
                facet.splitPane(context, spec(fraction: 0.5)),
          ),
        ),
      );
      // The ports hold plain boxes, so the only MouseRegion a resizable
      // split adds is the handle's - and a fixed one adds none. The finder
      // is scoped under the split itself; the harness's own plumbing above
      // it is not counted.
      expect(
        find.descendant(
          of: find.byType(SizedBox).first,
          matching: find.byType(MouseRegion),
        ),
        findsNothing,
      );
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('neither half can be dragged below the skin\'s floor', (
      WidgetTester tester,
    ) async {
      double? reported;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 600,
          height: 200,
          child: _member(
            (BuildContext context) => facet.splitPane(
              context,
              spec(
                fraction: 0.5,
                onFractionChanged: (double next) => reported = next,
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(MouseRegion).last, const Offset(-400, 0));
      // The floor is 120 of 600: the pane stops there, however far the
      // pointer went.
      expect(reported, 120 / 600);
    });
  });

  group('grid', () {
    testWidgets('reports the resolved column count so keyboard navigation '
        'can move by rows', (WidgetTester tester) async {
      int? columns;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 700,
          height: 400,
          child: _member(
            (BuildContext context) => facet.grid(
              context,
              GridSpec(
                children: <ContentPort>[
                  for (int i = 0; i < 6; i++) _box('tile$i'),
                ],
                onColumnsChanged: (int count) => columns = count,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // ceil(700 / (320 + 12)) = 3: the delegate's own formula over this
      // skin's normal tile extent and grouped gutter.
      expect(columns, 3);
    });

    testWidgets('a language-owned tile takes the Windows wide-tile '
        'proportion', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 700,
          height: 400,
          child: _member(
            (BuildContext context) => facet.grid(
              context,
              GridSpec(
                children: <ContentPort>[_box('t0'), _box('t1'), _box('t2')],
              ),
            ),
          ),
        ),
      );
      final Size tile = tester.getSize(
        find.byKey(const ValueKey<String>('t0')),
      );
      // 310 x 150, the published Windows wide tile - visibly wider than
      // Material's 1.2:1 landscape card.
      expect(tile.width / tile.height, closeTo(310 / 150, 0.01));
    });

    testWidgets('content-owned tiles stand at their content, row lines '
        'level', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 700,
          height: 400,
          child: _member(
            (BuildContext context) => facet.grid(
              context,
              GridSpec(
                tileHeight: TileHeight.content,
                children: <ContentPort>[
                  _box('short', height: 30),
                  _box('tall', height: 90),
                ],
              ),
            ),
          ),
        ),
      );
      // The two tiles share one row: the short one's BOX is stretched to
      // the row's tallest, so the row line stays level...
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey<String>('short'))).dy,
        tester.getBottomLeft(find.byKey(const ValueKey<String>('tall'))).dy,
      );
      // ...and nothing is clipped: the tall tile got all 90 it asked for.
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('tall'))).height,
        90,
      );
    });
  });
}
