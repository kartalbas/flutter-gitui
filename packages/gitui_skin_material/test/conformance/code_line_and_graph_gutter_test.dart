/// Pins the #438 answers for the code-line and commit-graph family.
///
///  * `SkinRequest.codeScale` - the size half of the user's code-font
///    decision - reaches `TextRole.code` through `MaterialTypeResolution`,
///    and ONLY `TextRole.code`: the interface ramp must not move with it.
///  * `CodeLineSpec.paired` decides the gutter's shape: a paired line
///    reserves both number columns even where one number is absent (a diff's
///    alignment lives in the blank column), an unpaired line draws only the
///    column it has (a whole file must not be pushed sideways for a column
///    that can never fill).
///  * `surfaces.commitGraphGutter` answers the row's reservation from the
///    painter's own lane arithmetic - 12 dp per lane, capped at eight - so
///    the width the application used to reproduce by hand cannot drift from
///    the graph it reserves room for.
///  * The graph specs carry value equality, which is what lets the painter's
///    `shouldRepaint` skip a rebuild-identical row.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';
import 'package:gitui_skin_material/src/material_theme.dart';

import 'support/conformance_harness.dart';

/// The fixed width of one number column: iconXL + spaceM + spaceXS.
const double _kGutterColumn = 52;

/// Renders [spec] through `surfaces.codeLine` under the conformance root.
Future<void> _pumpCodeLine(WidgetTester tester, CodeLineSpec spec) =>
    pumpConformance(
      tester,
      Builder(
        builder: (BuildContext context) => SkinScope.render(
          context,
          (Skin skin, BuildContext inner) =>
              skin.surfaces.codeLine(inner, spec),
        ),
      ),
    );

/// The number columns the pumped line reserved: fixed-width boxes of the
/// gutter's own width.
Finder _gutterColumns() => find.byWidgetPredicate(
  (Widget widget) => widget is SizedBox && widget.width == _kGutterColumn,
);

void main() {
  group('CodeLineSpec.paired decides the gutter shape', () {
    testWidgets('a paired line reserves BOTH columns even where one number '
        'is absent', (WidgetTester tester) async {
      // An added line of a diff: no old number, but the old column must stay,
      // blank, or the code loses its alignment against its neighbours.
      await _pumpCodeLine(
        tester,
        const CodeLineSpec(
          runs: <TextRun>[TextRun('added line')],
          tone: Tone.gitAdded,
          marker: '+',
          newNumber: 42,
        ),
      );
      expect(_gutterColumns(), findsNWidgets(2));
    });

    testWidgets('an unpaired line draws only the column it has', (
      WidgetTester tester,
    ) async {
      // A whole-file view: one line number, no absent side to reserve.
      await _pumpCodeLine(
        tester,
        const CodeLineSpec(
          runs: <TextRun>[TextRun('a whole-file line')],
          paired: false,
          newNumber: 7,
        ),
      );
      expect(_gutterColumns(), findsOneWidget);
    });

    testWidgets('a line with no numbers has no gutter at all, paired or not', (
      WidgetTester tester,
    ) async {
      // A hunk header: paired stays at its default and the gutter is still
      // absent, because the line carries no number on either side.
      await _pumpCodeLine(
        tester,
        const CodeLineSpec(
          runs: <TextRun>[TextRun('@@ -1,3 +1,4 @@')],
          tone: Tone.accent,
        ),
      );
      expect(_gutterColumns(), findsNothing);
    });
  });

  group(
    'SkinRequest.codeScale reaches the code role and only the code role',
    () {
      Future<(TextStyle?, TextStyle?)> resolveAt(
        WidgetTester tester,
        double codeScale,
      ) async {
        TextStyle? code;
        TextStyle? body;
        await tester.pumpWidget(
          MaterialApp(
            home: SkinScope.install(
              skin: const MaterialSkin(),
              request: SkinRequest(
                brightness: Brightness.light,
                accentSeed: 0,
                textScale: 1,
                codeScale: codeScale,
                animationScale: 1,
                monoFamily: 'JetBrains Mono',
                uiFamily: 'Inter',
              ),
              dialogKeyboardHost:
                  (BuildContext context, DialogSpec spec, Widget surface) =>
                      surface,
              app: ContentPort(
                Builder(
                  builder: (BuildContext context) {
                    code = MaterialTypeResolution.styleOf(
                      context,
                      TextRole.code,
                    );
                    body = MaterialTypeResolution.styleOf(
                      context,
                      TextRole.body,
                    );
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        return (code, body);
      }

      testWidgets('the code step multiplies, un-rounded, exactly as the diff '
          'viewer always rendered it', (WidgetTester tester) async {
        final (TextStyle? code, TextStyle? body) = await resolveAt(
          tester,
          1.15,
        );
        // bodyMedium is 13 at scale 1 in this skin; the code refinement rides
        // on top without rounding - the arithmetic the owner-verified baseline
        // was rendered with.
        expect(code?.fontSize, closeTo(13 * 1.15, 0.001));
        // The interface ramp must not move with the CODE size setting.
        expect(body?.fontSize, 13);
      });

      testWidgets('at the default scale the step passes through unchanged', (
        WidgetTester tester,
      ) async {
        final (TextStyle? code, _) = await resolveAt(tester, 1.0);
        expect(code?.fontSize, 13);
      });
    },
  );

  group('surfaces.commitGraphGutter reserves the painter\'s own width', () {
    Future<Size> reservedFor(WidgetTester tester, int laneCount) async {
      await pumpConformance(
        tester,
        Builder(
          builder: (BuildContext context) => SkinScope.render(
            context,
            (Skin skin, BuildContext inner) => skin.surfaces.commitGraphGutter(
              inner,
              GraphGutterSpec(laneCount: laneCount),
            ),
          ),
        ),
      );
      return tester.getSize(
        find.byWidgetPredicate(
          (Widget widget) => widget is SizedBox && widget.width != null,
        ),
      );
    }

    testWidgets('one 12 dp lane per column in play', (
      WidgetTester tester,
    ) async {
      expect((await reservedFor(tester, 3)).width, 36);
    });

    testWidgets('never narrower than one lane, capped at eight', (
      WidgetTester tester,
    ) async {
      expect((await reservedFor(tester, 0)).width, 12);
      expect((await reservedFor(tester, 20)).width, 96);
    });
  });

  group('the graph specs carry value equality', () {
    test('a rebuild-identical row compares equal, so shouldRepaint can skip '
        'it', () {
      const GraphRowSpec a = GraphRowSpec(
        lane: 1,
        toneIndex: 4,
        isMerge: true,
        laneCount: 3,
        incoming: <GraphEdgeSpec>[GraphEdgeSpec(lane: 0, toneIndex: 2)],
        passing: <GraphEdgeSpec>[GraphEdgeSpec(lane: 2, toneIndex: 5)],
        isCurrent: true,
      );
      // A separately constructed, field-identical spec - exactly what a
      // rebuild of CommitListItem produces.
      // ignore: prefer_const_constructors
      final GraphRowSpec b = GraphRowSpec(
        lane: 1,
        toneIndex: 4,
        isMerge: true,
        laneCount: 3,
        incoming: <GraphEdgeSpec>[
          // ignore: prefer_const_constructors
          GraphEdgeSpec(lane: 0, toneIndex: 2),
        ],
        passing: <GraphEdgeSpec>[
          // ignore: prefer_const_constructors
          GraphEdgeSpec(lane: 2, toneIndex: 5),
        ],
        isCurrent: true,
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a changed edge is a different row', () {
      const GraphRowSpec a = GraphRowSpec(
        lane: 1,
        toneIndex: 4,
        isMerge: false,
        laneCount: 3,
        passing: <GraphEdgeSpec>[GraphEdgeSpec(lane: 2, toneIndex: 5)],
      );
      const GraphRowSpec b = GraphRowSpec(
        lane: 1,
        toneIndex: 4,
        isMerge: false,
        laneCount: 3,
        passing: <GraphEdgeSpec>[GraphEdgeSpec(lane: 2, toneIndex: 6)],
      );
      expect(a, isNot(b));
    });

    test('the gutter spec compares by its count', () {
      const GraphGutterSpec three = GraphGutterSpec(laneCount: 3);
      // ignore: prefer_const_constructors
      final GraphGutterSpec alsoThree = GraphGutterSpec(laneCount: 3);
      expect(three, alsoThree);
      expect(three, isNot(const GraphGutterSpec(laneCount: 4)));
    });
  });
}
