/// The notice, measured: WinUI's InfoBar popped up over the page, on the
/// reference's own clock.
///
/// What a reimplementation gets wrong is what is asserted here: that the bar
/// is the skin's OWN banner rather than a second drawing of one, that it
/// arrives a medium step late and lingers three seconds rather than
/// Material's two, that a notice which must be read never leaves on its own
/// but carries the cross that takes it away, and that a second notice
/// replaces the first instead of landing on top of it.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_control_marks.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';

import 'support/fluent_behavior_harness.dart';
import 'support/fluent_overlay_harness.dart';

const FluentResources _light = FluentResources.light();

/// The medium step the notice fades on (FluentMotion.medium), and one frame
/// past it so the switcher has finished.
const Duration _fade = Duration(milliseconds: 260);

/// Pumps the harness app and returns a door onto its notice member.
Future<NoticeHandle Function(NoticeSpec spec)> _pumpNoticeHost(
  WidgetTester tester,
) async {
  late BuildContext host;
  await pumpFluentOverlayApp(tester, (BuildContext context) {
    host = context;
    return const SizedBox.shrink();
  });
  return (NoticeSpec spec) => Overlays.notify(host, spec);
}

/// The InfoBar box: the one widget painting a severity ground at the control
/// corner. The overlay member draws no box of its own, so finding it proves
/// the banner is what stands in the overlay.
Finder _infoBar(Color ground) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).color == ground,
);

void main() {
  group('the clock', () {
    testWidgets('nothing is on screen for the first medium step - the '
        'reference schedules its own first swap one step out', (
      WidgetTester tester,
    ) async {
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      notify(const NoticeSpec(tone: Tone.success, title: 'Cloned'));
      await tester.pump();
      expect(
        find.text('Cloned'),
        findsNothing,
        reason: 'the switcher needs a previous child to animate away from',
      );

      await tester.pump(_fade);
      await tester.pump(_fade);
      expect(find.text('Cloned'), findsOneWidget);

      // Drain the brief notice's own three seconds plus its fade-out.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(_fade);
      await tester.pump(_fade);
    });

    testWidgets('a brief notice lingers three seconds - Fluent\'s number, '
        'where Material\'s snackbar says two', (WidgetTester tester) async {
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      notify(const NoticeSpec(tone: Tone.info, title: 'Fetched'));
      await tester.pump(_fade);
      await tester.pump(_fade);

      // Two seconds in - where a Material snackbar would already be leaving.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Fetched'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(_fade);
      await tester.pump(_fade);
      expect(find.text('Fetched'), findsNothing);
    });

    testWidgets('a notice that must be read never leaves on its own', (
      WidgetTester tester,
    ) async {
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      final NoticeHandle handle = notify(
        const NoticeSpec(
          tone: Tone.danger,
          title: 'Push rejected',
          lifetime: NoticeLifetime.persistent,
        ),
      );
      await tester.pump(_fade);
      await tester.pump(_fade);

      await tester.pump(const Duration(minutes: 5));
      expect(find.text('Push rejected'), findsOneWidget);
      expect(handle.isShowing, isTrue);

      handle.dismiss();
      await tester.pump(_fade);
      await tester.pump(_fade);
      expect(find.text('Push rejected'), findsNothing);
      expect(handle.isShowing, isFalse);
    });
  });

  group('the bar', () {
    testWidgets('is the skin\'s own banner: the severity ground, and the '
        'cross a notice that stays is taken away by', (
      WidgetTester tester,
    ) async {
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      final NoticeHandle handle = notify(
        const NoticeSpec(
          tone: Tone.danger,
          title: 'Push rejected',
          lifetime: NoticeLifetime.persistent,
        ),
      );
      await tester.pump(_fade);
      await tester.pump(_fade);

      // The critical InfoBar ground (info_bar.dart:585-601), which only
      // `surfaces.banner` paints - the overlay member draws no box.
      expect(
        _infoBar(_light.systemFillColorCriticalBackground),
        findsOneWidget,
      );
      // And the banner's own dismiss affordance, drawn as geometry.
      expect(find.byType(FluentDismissMark), findsOneWidget);

      // The 4 epx control corner the InfoBar wears, read off the painted
      // rounded rectangle - not the 8 epx overlay corner a flyout takes,
      // which is the mistake a popped-up bar invites.
      final List<RRect> corners = paintedRRects(
        tester,
        _infoBar(_light.systemFillColorCriticalBackground),
      );
      expect(
        corners.any((RRect rect) => (rect.tlRadiusX - 4).abs() < 0.01),
        isTrue,
        reason: 'painted corners were $corners',
      );

      handle.dismiss();
      await tester.pump(_fade);
      await tester.pump(_fade);
    });

    testWidgets('a brief notice carries no cross - it is gone before the '
        'pointer arrives', (WidgetTester tester) async {
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      notify(const NoticeSpec(tone: Tone.success, title: 'Cloned'));
      await tester.pump(_fade);
      await tester.pump(_fade);

      expect(_infoBar(_light.systemFillColorSuccessBackground), findsOneWidget);
      expect(find.byType(FluentDismissMark), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(_fade);
      await tester.pump(_fade);
    });

    testWidgets('an action the user can take about it reaches the bar', (
      WidgetTester tester,
    ) async {
      int copied = 0;
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      final NoticeHandle handle = notify(
        NoticeSpec(
          tone: Tone.warning,
          title: 'Nothing to push',
          lifetime: NoticeLifetime.persistent,
          actions: <NoticeAction>[
            NoticeAction(
              label: 'Copy',
              tooltip: 'Copy warning to clipboard',
              onPressed: () => copied++,
            ),
          ],
        ),
      );
      await tester.pump(_fade);
      await tester.pump(_fade);

      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, 1);
      // The action does NOT take the notice away: only the cross and the
      // application do, which is what persistent means.
      expect(find.text('Nothing to push'), findsOneWidget);

      handle.dismiss();
      await tester.pump(_fade);
      await tester.pump(_fade);
      await tester.pump(const Duration(milliseconds: 150));
    });
  });

  group('one at a time', () {
    testWidgets('a second notice takes the first away instead of landing on '
        'top of it', (WidgetTester tester) async {
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      final NoticeHandle first = notify(
        const NoticeSpec(
          tone: Tone.danger,
          title: 'First failure',
          lifetime: NoticeLifetime.persistent,
        ),
      );
      await tester.pump(_fade);
      await tester.pump(_fade);
      expect(find.text('First failure'), findsOneWidget);

      final NoticeHandle second = notify(
        const NoticeSpec(
          tone: Tone.danger,
          title: 'Second failure',
          lifetime: NoticeLifetime.persistent,
        ),
      );
      await tester.pump(_fade);
      await tester.pump(_fade);

      expect(find.text('First failure'), findsNothing);
      expect(first.isShowing, isFalse);
      expect(find.text('Second failure'), findsOneWidget);
      expect(second.isShowing, isTrue);
      // Exactly one bar, not two stacked at the same alignment.
      expect(
        _infoBar(_light.systemFillColorCriticalBackground),
        findsOneWidget,
      );

      second.dismiss();
      await tester.pump(_fade);
      await tester.pump(_fade);
    });

    testWidgets('dismissing before the first swap takes the entry straight '
        'away, with nothing faded in to fade out', (WidgetTester tester) async {
      final NoticeHandle Function(NoticeSpec) notify = await _pumpNoticeHost(
        tester,
      );
      final NoticeHandle handle = notify(
        const NoticeSpec(tone: Tone.info, title: 'Fetched'),
      );
      expect(handle.isShowing, isTrue);

      handle.dismiss();
      expect(handle.isShowing, isFalse);
      await tester.pump();
      expect(find.text('Fetched'), findsNothing);
    });
  });
}
