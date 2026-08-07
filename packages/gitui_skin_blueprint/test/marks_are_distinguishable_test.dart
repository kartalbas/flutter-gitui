/// What the naked square must render DIFFERENTLY, and what it must still do.
///
/// The obligation in `docs/SKIN-CONTRACT-MEMBERS.md` §9 has two halves. That
/// every field of every spec is read is checked by
/// `spec_field_coverage_test.dart`, over the contract's own source. This file
/// checks the other half, which no source scan can see: that two values of one
/// vocabulary do not render the SAME. A blueprint whose `Emphasis.primary` and
/// `Emphasis.quiet` drew the same box would accept every parameter and falsify
/// nothing, because a skin that collapsed the two would look exactly like the
/// instrument that was supposed to catch it.
///
/// The second group is the "naked, not inert" half of §3.1: the marks are
/// beside the content and never inside it, so `find.text('Delete')` still
/// matches, and every control is still operable.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart';

void main() {
  group('the marks stay distinguishable', () {
    test('a checkbox and a switch never render the same three states', () {
      for (final bool? value in <bool?>[true, false, null]) {
        expect(
          BlueprintMarks.check(value),
          isNot(BlueprintMarks.switching(value)),
          reason:
              'Two members that render identically hide a mis-wired call '
              'site, which is the opposite of what this skin is for.',
        );
      }
    });

    test('every Emphasis is told apart by weight or by dash', () {
      final Set<String> seen = <String>{};
      for (final Emphasis emphasis in Emphasis.values) {
        final String rendering =
            '${BlueprintVocabulary.standard.stroke(emphasis)}/'
            '${BlueprintGeometry.dashed(emphasis)}';
        expect(
          seen.add(rendering),
          isTrue,
          reason:
              'Two values of Emphasis render identically, so the blueprint '
              'could not falsify a skin that collapsed them.',
        );
      }
    });

    test('every ControlScale is told apart by its box', () {
      final Set<double> seen = <double>{};
      for (final ControlScale scale in ControlScale.values) {
        expect(seen.add(BlueprintVocabulary.standard.extent(scale)), isTrue);
      }
    });

    test('progress says both the extent and the fraction', () {
      expect(BlueprintMarks.progress(0.5, ProgressExtent.inline), '[####----]');
      expect(BlueprintMarks.progress(0.45, ProgressExtent.block), '(45%)');
      expect(
        BlueprintMarks.progress(null, ProgressExtent.inline),
        '[????????]',
      );
      expect(BlueprintMarks.progress(null, ProgressExtent.block), '(??%)');
    });

    test('a tone is a mark beside the content and never inside it', () {
      expect(BlueprintMarks.tone(Tone.neutral), isEmpty);
      expect(BlueprintMarks.tone(Tone.danger), '!');
      expect(BlueprintMarks.tone(Tone.warning), '?');
      expect(BlueprintMarks.tone(Tone.gitAdded), '+');
      expect(BlueprintMarks.tone(const Tone.series(7)), '7');
      expect(BlueprintMarks.tone(Tone.success), '[success]');
    });

    test('every rung collapses at distance zero and separates at 64', () {
      for (final Proximity proximity in Proximity.values) {
        expect(BlueprintDistance.zero.gap(proximity), 0);
      }
      for (final Inset inset in Inset.values) {
        expect(BlueprintDistance.zero.inset(inset), 0);
      }
      final Set<double> gaps = <double>{
        for (final Proximity p in Proximity.values)
          const BlueprintDistance(64).gap(p),
      };
      expect(gaps.length, Proximity.values.length);
    });
  });

  group('the controls are operable and say what they are', () {
    testWidgets('a button keeps its label findable beside its marks', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await tester.pumpWidget(
        _under(
          Builder(
            builder: (BuildContext context) =>
                const BlueprintControls(BlueprintDistance.zero).button(
                  context,
                  ButtonSpec(
                    label: 'Delete',
                    tone: Tone.danger,
                    emphasis: Emphasis.secondary,
                    onPressed: () => pressed++,
                  ),
                ),
          ),
        ),
      );

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('!'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      expect(pressed, 1);
    });

    testWidgets('an unavailable button says so and does nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _under(
          Builder(
            builder: (BuildContext context) => const BlueprintControls(
              BlueprintDistance.zero,
            ).button(context, const ButtonSpec(label: 'Push', onPressed: null)),
          ),
        ),
      );

      expect(find.text('[disabled]'), findsOneWidget);
    });

    testWidgets(
      'a checkbox shows all three states and resolves the mixed one',
      (WidgetTester tester) async {
        bool? reported;
        await tester.pumpWidget(
          _under(
            Builder(
              builder: (BuildContext context) =>
                  const BlueprintControls(BlueprintDistance.zero).checkbox(
                    context,
                    ToggleSpec(
                      value: null,
                      onChanged: (bool? value) => reported = value,
                    ),
                  ),
            ),
          ),
        );

        expect(find.text('[-]'), findsOneWidget);
        await tester.tap(find.text('[-]'));
        expect(
          reported,
          isTrue,
          reason:
              'Operating a mixed toggle means "make it true": the mixed state '
              'is what the application reports, never something the user asks '
              'for.',
        );
      },
    );

    testWidgets('an icon role renders as its own name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _under(
          Builder(
            builder: (BuildContext context) =>
                const BlueprintControls(BlueprintDistance.zero).iconButton(
                  context,
                  IconButtonSpec(
                    icon: IconRole.gitBranch,
                    tooltip: 'Branches',
                    onPressed: _nothing,
                    selected: true,
                    badgeCount: 3,
                  ),
                ),
          ),
        ),
      );

      expect(find.text('[gitBranch]'), findsOneWidget);
      expect(find.text('[*]'), findsOneWidget);
      expect(find.text('(3)'), findsOneWidget);
    });

    testWidgets('a filter toggle reports the switch the user asked for', (
      WidgetTester tester,
    ) async {
      bool? reported;
      await tester.pumpWidget(
        _under(
          Builder(
            builder: (BuildContext context) =>
                const BlueprintControls(BlueprintDistance.zero).filterToggle(
                  context,
                  FilterToggleSpec(
                    label: 'Modified',
                    selected: false,
                    count: 12,
                    onSelected: (bool value) => reported = value,
                  ),
                ),
          ),
        ),
      );

      expect(find.text('(12)'), findsOneWidget);
      await tester.tap(find.text('Modified'));
      expect(reported, isTrue);
    });

    testWidgets('a series picker offers exactly the skin\'s own length', (
      WidgetTester tester,
    ) async {
      int? chosen;
      await tester.pumpWidget(
        _under(
          Builder(
            builder: (BuildContext context) =>
                const BlueprintControls(BlueprintDistance.zero).seriesPicker(
                  context,
                  SeriesPickerSpec(
                    selectedIndex: 2,
                    onSelected: (int index) => chosen = index,
                  ),
                ),
          ),
        ),
      );

      expect(
        find.byType(BlueprintMark),
        findsNWidgets(BlueprintInk.seriesLength),
      );
      await tester.tap(find.text('5'));
      expect(chosen, 5);
    });
  });
}

/// Nothing at all, for the specs that need a callback to be enabled.
void _nothing() {}

/// The least a naked control needs above it: a reading direction and the ink
/// defaults `chrome.wrapRoot` installs in a running application.
Widget _under(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: DefaultTextStyle(
    style: const TextStyle(color: BlueprintInk.standardInk, fontSize: 14),
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);
