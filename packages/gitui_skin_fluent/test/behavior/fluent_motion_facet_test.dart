/// The motion facet, measured from the clock: a state change IS animated,
/// it runs on Fluent's published durations - 167 feedback, 250 transition,
/// 358 emphasis - and a zero animation scale makes every change simply
/// true. The blueprint answers the same members with zero, so a test that
/// can tell the two skins apart here is what proves the facet carries
/// design at all.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_motion_facet.dart';
import 'package:gitui_skin_fluent/src/fluent_request_scope.dart';

import 'support/fluent_behavior_harness.dart';
import 'support/fluent_overlay_harness.dart';

const FluentMotionFacet facet = FluentMotionFacet();

void main() {
  group('reveal', () {
    testWidgets('leaving takes the feedback step: still fading at 100 ms, '
        'gone after 167', (WidgetTester tester) async {
      late StateSetter setOuter;
      bool visible = true;
      await pumpFluentBehavior(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuter = setState;
            return facet.reveal(
              context,
              child: const ContentPort(Text('appearing')),
              visible: visible,
            );
          },
        ),
      );
      expect(find.text('appearing'), findsOneWidget);
      setOuter(() => visible = false);
      await tester.pump();
      // Mid-fade: the outgoing content is still on screen - the change is
      // ANIMATED, which is what the blueprint's instant answer is not.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('appearing'), findsOneWidget);
      // Past 167 ms (FluentMotion.fast): the end state is the blueprint's.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('appearing'), findsNothing);
    });

    testWidgets('a zero animation scale is simply true: no interval between '
        'the states', (WidgetTester tester) async {
      late StateSetter setOuter;
      bool visible = true;
      await pumpFluentBehavior(
        tester,
        FluentRequestScope(
          request: fluentOverlayRequest(Brightness.light, animationScale: 0),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setOuter = setState;
              return facet.reveal(
                context,
                child: const ContentPort(Text('appearing')),
                visible: visible,
              );
            },
          ),
        ),
      );
      setOuter(() => visible = false);
      await tester.pump();
      expect(find.text('appearing'), findsNothing);
    });
  });

  group('swap', () {
    testWidgets('a changed stateKey cross-fades on the transition step - '
        'both children on screen at 200 ms, one at 260', (
      WidgetTester tester,
    ) async {
      late StateSetter setOuter;
      String commit = 'aaa';
      await pumpFluentBehavior(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuter = setState;
            return facet.swap(
              context,
              child: ContentPort(Text(commit)),
              stateKey: commit,
            );
          },
        ),
      );
      setOuter(() => commit = 'bbb');
      await tester.pump();
      // MotionRole.transition is Fluent's medium, 250 ms: at 200 the old
      // content is still fading out beside the new.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('aaa'), findsOneWidget);
      expect(find.text('bbb'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('aaa'), findsNothing);
      expect(find.text('bbb'), findsOneWidget);
    });

    testWidgets('the same stateKey means the same thing rebuilding: no '
        'cross-fade is staged', (WidgetTester tester) async {
      late StateSetter setOuter;
      String label = 'first';
      await pumpFluentBehavior(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuter = setState;
            return facet.swap(
              context,
              child: ContentPort(Text(label)),
              stateKey: 'same',
            );
          },
        ),
      );
      setOuter(() => label = 'second');
      await tester.pump();
      // One thing merely rebuilt: the old words are gone the same frame.
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('the emphasis role takes the slowest published step: still '
        'running at 300 ms, done after 358', (WidgetTester tester) async {
      late StateSetter setOuter;
      String label = 'one';
      await pumpFluentBehavior(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setOuter = setState;
            return facet.swap(
              context,
              child: ContentPort(Text(label)),
              stateKey: label,
              role: MotionRole.emphasis,
            );
          },
        ),
      );
      setOuter(() => label = 'two');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('one'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('one'), findsNothing);
    });
  });
}
