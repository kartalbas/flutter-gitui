/// Conformance for the two words #438 grew on `surfaces.tree`.
///
/// `TreeSpec.revealed` is the reveal said as data - which node must be inside
/// the viewport - with everything about honouring it left on this side of the
/// seam. The suite drives the three facts that make that a contract rather
/// than a convenience: a far-away node's row IS brought into the viewport, a
/// node already in view moves NOTHING (minimal motion, so the member cannot
/// jitter the tree on every selection), and a rebuild with the SAME revealed
/// id leaves a user's own scrolling alone.
///
/// `TreeNodeSpec.leadingTone` is a stated meaning on the node's mark. The
/// member answers it through the same tone resolution every other surface
/// uses ([MaterialInk.foreground]), a stated tone wins over the row's own
/// treatment, and an unstated one keeps the language's answer - the accent on
/// a branch, because the hierarchy is what the eye has to find first.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../support/conformance_harness.dart';

/// Rows tall enough to overflow the probe viewport many times over.
List<TreeNodeSpec> _flatRoots(int count) => <TreeNodeSpec>[
  for (int index = 0; index < count; index++)
    TreeNodeSpec(id: 'node $index', content: ContentPort(Text('node $index'))),
];

/// A tree inside a bounded viewport, the shape both floor sites give it.
const ValueKey<String> _viewportKey = ValueKey<String>('tree viewport');

Widget _boundedTree(TreeSpec spec) => SizedBox(
  key: _viewportKey,
  width: 300,
  height: 240,
  child: Builder(
    builder: (BuildContext context) => SkinScope.render(
      context,
      (Skin skin, BuildContext inner) => skin.surfaces.tree(inner, spec),
    ),
  ),
);

/// The tree's own scroll offset.
double _offsetOf(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

/// Pumps the frames a reveal needs: the post-frame estimate jump, then the
/// post-frame correction against the row's real geometry.
Future<void> _settleReveal(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  TreeSpec spec(List<TreeNodeSpec> roots, {Object? revealed}) => TreeSpec(
    roots: roots,
    expanded: const <Object>{},
    selected: const <Object>{},
    onToggleExpanded: (_) {},
    onSelect: (_) {},
    revealed: revealed,
  );

  group('TreeSpec.revealed', () {
    testWidgets('brings a far node into the viewport', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _boundedTree(spec(_flatRoots(80), revealed: 'node 70')),
      );
      await _settleReveal(tester);

      expect(_offsetOf(tester), greaterThan(0));
      final Finder revealed = find.text('node 70');
      expect(revealed, findsOneWidget);
      final Rect viewport = tester.getRect(find.byKey(_viewportKey));
      final Rect row = tester.getRect(revealed);
      expect(row.top, greaterThanOrEqualTo(viewport.top - 1));
      expect(row.bottom, lessThanOrEqualTo(viewport.bottom + 1));
    });

    testWidgets('moves nothing for a node already in view', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _boundedTree(spec(_flatRoots(80), revealed: 'node 1')),
      );
      await _settleReveal(tester);

      expect(_offsetOf(tester), 0);
    });

    testWidgets('honours a change of node, not a rebuild of the same one', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _boundedTree(spec(_flatRoots(80), revealed: 'node 70')),
      );
      await _settleReveal(tester);
      final double atFirstReveal = _offsetOf(tester);
      expect(atFirstReveal, greaterThan(0));

      // The user scrolls away; a rebuild carrying the SAME revealed id must
      // not drag them back.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await pumpConformance(
        tester,
        _boundedTree(spec(_flatRoots(80), revealed: 'node 70')),
      );
      await _settleReveal(tester);
      expect(_offsetOf(tester), 0);

      // A DIFFERENT node is a new claim, and it is honoured.
      await pumpConformance(
        tester,
        _boundedTree(spec(_flatRoots(80), revealed: 'node 40')),
      );
      await _settleReveal(tester);
      expect(_offsetOf(tester), greaterThan(0));
      expect(find.text('node 40'), findsOneWidget);
    });

    testWidgets('is a no-op for a node hidden under a collapsed ancestor', (
      WidgetTester tester,
    ) async {
      final List<TreeNodeSpec> roots = <TreeNodeSpec>[
        TreeNodeSpec(
          id: 'closed',
          content: ContentPort(const Text('closed')),
          children: <TreeNodeSpec>[
            TreeNodeSpec(
              id: 'hidden',
              content: ContentPort(const Text('hidden')),
            ),
          ],
        ),
        ..._flatRoots(3),
      ];
      await pumpConformance(
        tester,
        _boundedTree(spec(roots, revealed: 'hidden')),
      );
      await _settleReveal(tester);

      // Expansion is application state; the member does not open branches to
      // honour a reveal, so nothing moved and nothing appeared.
      expect(_offsetOf(tester), 0);
      expect(find.text('hidden'), findsNothing);
    });
  });

  group('TreeNodeSpec.leadingTone', () {
    Color glyphColor(WidgetTester tester, IconRole role) => tester
        .widget<Icon>(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is Icon && widget.icon == MaterialGlyphs.of(role),
          ),
        )
        .color!;

    testWidgets('a stated meaning wins over the row treatment', (
      WidgetTester tester,
    ) async {
      final List<TreeNodeSpec> roots = <TreeNodeSpec>[
        TreeNodeSpec(
          id: 'a.dart',
          content: ContentPort(const Text('a.dart')),
          leading: IconRole.file,
          leadingTone: Tone.gitDeleted,
        ),
      ];
      await pumpConformance(tester, _boundedTree(spec(roots)));

      final BuildContext context = tester.element(find.text('a.dart'));
      expect(
        glyphColor(tester, IconRole.file),
        MaterialInk.foreground(context, Tone.gitDeleted),
      );
    });

    testWidgets('unstated keeps the accent on a branch', (
      WidgetTester tester,
    ) async {
      final List<TreeNodeSpec> roots = <TreeNodeSpec>[
        TreeNodeSpec(
          id: 'src',
          content: ContentPort(const Text('src')),
          leading: IconRole.folder,
          children: <TreeNodeSpec>[
            TreeNodeSpec(id: 'src/a', content: ContentPort(const Text('a'))),
          ],
        ),
      ];
      await pumpConformance(tester, _boundedTree(spec(roots)));

      final BuildContext context = tester.element(find.text('src'));
      expect(
        glyphColor(tester, IconRole.folder),
        Theme.of(context).colorScheme.primary,
      );
    });
  });
}
