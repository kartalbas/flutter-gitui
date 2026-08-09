/// Conformance for the two words #438 grew on the badge family.
///
/// `BadgeSpec.secondary` is the paired statistic - two facts in one mark,
/// `+12` beside `-3` - and everything visual about the pairing is the skin's
/// to answer. This suite pins Material's answer behaviourally, because the
/// blueprint's source-mention coverage can prove the field is consulted but
/// not what consulting it draws: both facts render, each fact's own tone
/// paints its foreground, and the shared surface takes the neutral chip fill
/// (one wash cannot mean two things), while the single-fact badge keeps the
/// toned wash it has always had - so the pairing changes the fill decision
/// and this suite would fail if either answer collapsed into the other.
///
/// `TagSpec` refuses a removable tag with an unnamed removal at construction:
/// "required in spirit" let two skins disagree about what null means, so the
/// contract throws instead of letting each skin decide. The refusal is a
/// contract behaviour, and the affirmative half - the removal control carries
/// exactly the name the application gave - is Material's.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../support/conformance_harness.dart';

/// The badge under measurement, rendered through the one door application
/// code has.
Widget _badge(BadgeSpec spec) => Builder(
  builder: (BuildContext context) => SkinScope.render(
    context,
    (Skin skin, BuildContext inner) => skin.surfaces.badge(inner, spec),
  ),
);

/// The tag under measurement, by the same door.
Widget _tag(TagSpec spec) => Builder(
  builder: (BuildContext context) => SkinScope.render(
    context,
    (Skin skin, BuildContext inner) => skin.surfaces.tag(inner, spec),
  ),
);

/// The colour a rendered fact's words carry.
Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

/// The fill of the pill behind [text].
Color _pillFill(WidgetTester tester, String text) {
  final Container pill = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (pill.decoration! as BoxDecoration).color!;
}

void main() {
  group('BadgeSpec.secondary, the paired statistic', () {
    testWidgets('renders both facts, each in its own tone\'s foreground', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _badge(
          const BadgeSpec(
            label: '+12',
            tone: Tone.gitAdded,
            secondary: BadgeFact(label: '-3', tone: Tone.gitDeleted),
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('+12'));
      expect(
        _textColor(tester, '+12'),
        MaterialInk.foreground(context, Tone.gitAdded),
        reason:
            'The first fact\'s own tone is what carries its meaning on the '
            'shared surface.',
      );
      expect(
        _textColor(tester, '-3'),
        MaterialInk.foreground(context, Tone.gitDeleted),
        reason:
            'The second fact is not a suffix of the first: it carries its '
            'own meaning through its own foreground.',
      );
    });

    testWidgets('the paired pill takes the neutral chip fill', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _badge(
          const BadgeSpec(
            label: '+12',
            tone: Tone.gitAdded,
            secondary: BadgeFact(label: '-3', tone: Tone.gitDeleted),
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('+12'));
      expect(
        _pillFill(tester, '+12'),
        Theme.of(context).colorScheme.surfaceContainerHighest,
        reason:
            'One wash cannot mean two things: a pill carrying two facts '
            'keeps its surface quiet and lets the two foregrounds carry the '
            'distinction.',
      );
    });

    testWidgets('a single toned fact keeps its toned wash', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _badge(const BadgeSpec(label: '+12', tone: Tone.gitAdded)),
      );

      final BuildContext context = tester.element(find.text('+12'));
      final Color fill = _pillFill(tester, '+12');
      expect(
        fill,
        isNot(Theme.of(context).colorScheme.surfaceContainerHighest),
        reason:
            'The one-fact badge has always sat on its own tone\'s wash; if '
            'it took the chip fill too, the pairing decision above would be '
            'no decision at all.',
      );
      expect(
        fill,
        MaterialInk.foreground(context, Tone.gitAdded).withValues(alpha: 0.15),
        reason:
            'The wash is the measured 15% behind the badge\'s own '
            'foreground, the alpha git_colors_contrast_test.dart proves '
            'readable on every surface the application paints a badge on.',
      );
    });
  });

  group('TagSpec refuses an unnamed removal', () {
    test('a removable tag without a removal name does not construct', () {
      expect(
        () => TagSpec(label: 'branch: master', onRemoved: () {}),
        throwsAssertionError,
        reason:
            'The removal is a mark-only control, and this repository '
            'requires every mark-only control to say what it does. The '
            'contract refuses the construction instead of letting each skin '
            'decide what null means.',
      );
    });

    testWidgets('the removal control carries exactly the name given', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _tag(
          TagSpec(
            label: 'branch: master',
            onRemoved: () {},
            removeTooltip: 'Remove branch filter',
          ),
        ),
      );

      expect(
        find.byTooltip('Remove branch filter'),
        findsOneWidget,
        reason:
            'The name on the removal is the application\'s own, verbatim: '
            'the generic deleteButtonTooltip fallback that once stood here '
            'was this skin naming an action the application never named.',
      );
    });
  });
}
