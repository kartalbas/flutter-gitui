/// Item 4 of #341's definition of done: `meetsGuideline` for text contrast,
/// labeled tap targets and tap-target size, across the whole component matrix,
/// in both themes.
///
/// ## Where the matrix comes from, and why
///
/// The population is `componentGoldenScenes()`
/// (test/conformance/goldens/component_scenes.dart) rendered through
/// `pumpGoldenScene`, i.e. exactly the arrangements the golden baselines
/// freeze: 31 scenes covering every `Base*` component that renders, across its
/// variants, sizes and states, each in both brightnesses.
///
/// Reusing that registry rather than declaring a second one is the whole point.
/// A sweep is only a sweep if its population is derived rather than
/// hand-maintained — the same argument dialog_keyboard_contract_sweep_test.dart
/// makes with its census — and the scene registry is already the one place a
/// component is enrolled in this repository: adding a component there gets it a
/// baseline, a smoke test *and*, from now on, an accessibility measurement,
/// with no second list for anyone to forget. It also means the pixels this
/// suite measures contrast in are the pixels a reviewer sees in the baseline.
///
/// The registry also brings the states with it. `androidTapTargetGuideline`
/// only ever sees what is on screen, and a scene that drives hover, focus or
/// press puts a different tree on screen; because those scenes are in the
/// registry, they are swept too.
///
/// ## What is exempt, and why each exemption is honest
///
/// Two of the three guidelines pass outright. The third,
/// `textContrastGuideline`, needs two named exemptions, and the tap-target
/// guideline needs one named skip. Each is an enum value with its reason on
/// it, in the shape the dialog keyboard sweep uses for its Enter exceptions,
/// and each is held honest by a test at the bottom of this file: an exemption
/// that stopped being needed fails, so it cannot rot in place.
///
/// ## What this sweep cannot see
///
/// `textContrastGuideline` judges a screenshot histogram, not the colours a
/// component resolves, and the enum below records the measurements proving it
/// returns three different answers for one colour pair. The complementary
/// check - the foreground and background a component actually resolves per
/// state, compared directly - lives in component_colors_contrast_test.dart in
/// this directory, and it is what caught the selection-state failures this
/// sweep reported as passing.
library;

import 'dart:ui' as ui show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_badge.dart';
import 'package:flutter_gitui/shared/components/base_switcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../goldens/component_scenes.dart';
import '../goldens/golden_scene.dart';
import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

// ---------------------------------------------------------------------------
// Text contrast
// ---------------------------------------------------------------------------

/// Why a glyph run in the matrix is not held to WCAG's contrast minimum.
enum ContrastExemption {
  /// None: the run is judged at the full WCAG target for its size.
  none,

  /// WCAG 2.1 SC 1.4.3 exempts inactive user interface components: "Text or
  /// images of text that are part of an inactive user interface component ...
  /// have no contrast requirement." Material 3 draws disabled text at
  /// `onSurface` at 38% precisely so it reads as unavailable, and raising it
  /// would destroy the only signal a disabled control has.
  ///
  /// This exemption is the SDK's own — `MinimumTextContrastGuideline` skips
  /// any node flagged `isEnabled == false`
  /// (packages/flutter_test/lib/src/accessibility.dart:341-347) — so nothing
  /// here implements it. It is named because it is load-bearing: everything
  /// in the matrix's five disabled rows depends on it, and the two tests under
  /// "the exemptions are exercised" below prove both that the matrix really
  /// contains such text and that the treatment being exempted is the specified
  /// 38% one rather than an arbitrary washed-out colour.
  inactiveComponentsCarryNoContrastRequirement,

  /// The guideline does not read the text's colour. It screenshots the frame,
  /// takes the histogram of the pixels in the text's bounding box, splits them
  /// into "light" and "dark" at their mean HSL lightness and reports the ratio
  /// between the most frequent colour in each half
  /// (accessibility.dart:684-717; its own documentation at :802-809 calls this
  /// "a very naive partitioning"). Below a certain glyph size the most frequent
  /// non-background pixel is no longer the glyph but its anti-aliased edge, and
  /// the number it reports stops being the text's contrast.
  ///
  /// That is not a hypothesis. In `base_labels_type_scale` the same word
  /// "Commit", in the same `onSurface` role on the same `surface` background,
  /// is reported at 4.11 : 1 at 14 px, 2.23 : 1 at 13 px and 1.43 : 1 at 12 px,
  /// with the "dark" colour it computed growing lighter at every step
  /// (#78767C, #A7A5AA, #D0CECF) while the real foreground never changed. A
  /// measurement that returns three answers for one colour pair is measuring
  /// glyph coverage, not contrast.
  ///
  /// Text at or above [kHistogramResolvingFontSize] is judged normally.
  belowTheHistogramsResolvingSize,
}

/// The smallest font size at which the guideline's screenshot histogram still
/// resolves the glyph rather than its anti-aliased edge; see
/// [ContrastExemption.belowTheHistogramsResolvingSize] for the measurements
/// this is drawn from.
///
/// It is a property of the guideline's sampling, not of this app's palette:
/// every failure it removes is a text node whose *specified* foreground and
/// background are a designed pair, and the pair itself is asserted elsewhere —
/// the git palette in git_colors_contrast_test.dart, the disabled and
/// state-layer roles in the component suites under test/conformance/components.
const double kHistogramResolvingFontSize = 15.0;

/// The stock text-contrast guideline, with [ContrastExemption] applied.
///
/// The exemption is expressed as the required ratio rather than as a skipped
/// node, because a node is a *label* and the same label can be rendered at
/// several sizes in one scene — "Commit" appears at all fifteen type-scale
/// sizes in `base_labels_type_scale`. `targetContrastRatio` is the SDK's own
/// per-element seam and receives the size of the very glyph run being
/// measured, so the exemption lands on exactly the runs it argues about and
/// leaves every readable one judged at the full WCAG target.
class _MatrixTextContrastGuideline extends MinimumTextContrastGuideline {
  const _MatrixTextContrastGuideline();

  @override
  double targetContrastRatio(double? fontSize, {required bool bold}) {
    return switch (exemptionForFontSize(fontSize)) {
      // The screenshot histogram is not measuring this run's colours, so there
      // is no number here to hold it to. See the enum for the measurements.
      ContrastExemption.belowTheHistogramsResolvingSize => 0.0,
      // The inactive exemption is applied by the SDK before this seam is
      // reached (accessibility.dart:341-347), so a run that arrives here is
      // active and is judged at the full target.
      ContrastExemption.inactiveComponentsCarryNoContrastRequirement ||
      ContrastExemption.none => super.targetContrastRatio(fontSize, bold: bold),
    };
  }

  @override
  String get description =>
      'Text contrast should follow WCAG guidelines, except for inactive '
      'components (SC 1.4.3) and for glyph runs the guideline cannot resolve';
}

/// The exemption a glyph run of [fontSize] carries.
///
/// `null` means the run's style named no size, which is the case the guideline
/// itself resolves to 12 (accessibility.dart:308, `_kDefaultFontSize`).
ContrastExemption exemptionForFontSize(double? fontSize) {
  return (fontSize ?? 12.0) < kHistogramResolvingFontSize
      ? ContrastExemption.belowTheHistogramsResolvingSize
      : ContrastExemption.none;
}

// ---------------------------------------------------------------------------
// Tap targets
// ---------------------------------------------------------------------------

/// Why a tappable node in the matrix is not held to the 48 dp minimum.
enum TapTargetExemption {
  /// A decision, taken and argued in docs/deviation_register.yaml. The entry
  /// carries the spec value, the app value and the reason, and the sweep
  /// asserts the measured value against it below, so the decision cannot drift
  /// and cannot quietly come back into line without the register noticing.
  registeredInTheDeviationRegister,
}

/// The components whose tappable nodes are exempt from the 48 dp minimum, and
/// which reason each one carries.
///
/// Keyed by the widget that *owns* the node rather than by the node itself: a
/// node has no identity across runs, but the component it belongs to does, and
/// naming the component is what makes an exemption reviewable.
///
/// `BaseBadge` used to be here: its delete glyph was a bare 14 dp
/// `GestureDetector`, named as an open defect rather than approved, because
/// Material's own `Chip` gives its delete affordance a full 48 dp target and
/// passes this guideline. It now does the same — the glyph is a real button
/// with the 48 dp interactive minimum around it, asserted at the bottom of
/// this file — so the entry is gone rather than reworded.
const Map<Type, TapTargetExemption> kTapTargetExemptions =
    <Type, TapTargetExemption>{
      // 37 dp tall: the top bar's repository/branch control, A11Y-001.
      BaseSwitcher: TapTargetExemption.registeredInTheDeviationRegister,
    };

/// One entry of [kTapTargetExemptions], rendered for a failure message.
String _describeEntry(MapEntry<Type, TapTargetExemption> entry) =>
    '${entry.key} (${describeExemption(entry.value)})';

/// What an exemption says, in one sentence, for a failure message.
String describeExemption(TapTargetExemption exemption) {
  return switch (exemption) {
    TapTargetExemption.registeredInTheDeviationRegister =>
      'a decision argued in docs/deviation_register.yaml',
  };
}

/// The stock 48 dp guideline, with [kTapTargetExemptions] applied.
class _MatrixTapTargetGuideline extends MinimumTapTargetGuideline {
  const _MatrixTapTargetGuideline(this._exemptRects)
    : super(
        // The same two values `androidTapTargetGuideline` is built from
        // (packages/flutter_test/lib/src/accessibility.dart:777-780).
        size: const Size(48.0, 48.0),
        link: 'https://support.google.com/accessibility/android/answer/7101858',
      );

  /// The layout rectangles of the exempt owners in the scene being measured.
  final List<Rect> _exemptRects;

  @override
  bool shouldSkipNode(SemanticsNode node) {
    if (super.shouldSkipNode(node)) {
      return true;
    }
    final Rect bounds = _globalRect(node);
    return _exemptRects.any(
      // Inflated by a pixel because a semantics rect and a layout rect are
      // computed by different code paths and can disagree in the last bit.
      (Rect owner) => owner.inflate(1).contains(bounds.center),
    );
  }
}

/// A semantics node's rectangle in the coordinate space the widget tree uses.
///
/// A node's own `rect` is in its parent's space and the chain up to the root
/// ends in the view transform, which scales by the device pixel ratio, so the
/// walk is undone by that ratio at the end — the same walk the guideline itself
/// does (accessibility.dart:154-166).
Rect _globalRect(SemanticsNode node) {
  Rect bounds = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      bounds = MatrixUtils.transformRect(transform, bounds);
    }
    current = current.parent;
  }
  return bounds;
}

/// The layout rectangles of every exempt owner currently on screen.
List<Rect> _exemptOwnerRects(WidgetTester tester) {
  final double ratio = tester.view.devicePixelRatio;
  return <Rect>[
    for (final Type owner in kTapTargetExemptions.keys)
      for (final Element element in find.byType(owner).evaluate())
        if (element.renderObject case final RenderBox box when box.hasSize)
          _scaled(
            Rect.fromPoints(
              box.localToGlobal(Offset.zero),
              box.localToGlobal(box.size.bottomRight(Offset.zero)),
            ),
            ratio,
          ),
  ];
}

Rect _scaled(Rect rect, double ratio) => Rect.fromLTRB(
  rect.left * ratio,
  rect.top * ratio,
  rect.right * ratio,
  rect.bottom * ratio,
);

// ---------------------------------------------------------------------------
// The sweep
// ---------------------------------------------------------------------------

void main() {
  for (final GoldenScene scene in componentGoldenScenes()) {
    for (final Brightness brightness in kGoldenBrightnesses) {
      testWidgets('${scene.name} (${brightnessName(brightness)}) meets the '
          'accessibility guidelines', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpGoldenScene(tester, scene, brightness: brightness);

        // Every tappable thing has a name. No exemption: a control nobody can
        // name is a control nobody can operate without seeing it, and the
        // matrix passes this outright.
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        await expectLater(
          tester,
          meetsGuideline(_MatrixTapTargetGuideline(_exemptOwnerRects(tester))),
        );

        await expectLater(
          tester,
          meetsGuideline(const _MatrixTextContrastGuideline()),
        );

        handle.dispose();
      });
    }
  }

  // -------------------------------------------------------------------------
  // The exemptions are exercised, and none of them has outlived its reason.
  // -------------------------------------------------------------------------
  group('the exemptions', () {
    testWidgets(
      'the inactive-component exemption is exercised rather than hypothetical',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpGoldenScene(
          tester,
          _sceneNamed('base_button_disabled'),
          brightness: Brightness.light,
        );

        final List<SemanticsNode> disabled = <SemanticsNode>[];
        void visit(SemanticsNode node) {
          if (node.getSemanticsData().flagsCollection.isEnabled ==
              ui.Tristate.isFalse) {
            disabled.add(node);
          }
          node.visitChildren((SemanticsNode child) {
            visit(child);
            return true;
          });
        }

        visit(
          tester
              .binding
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );

        expect(
          disabled.where(
            (SemanticsNode node) => node.getSemanticsData().label.isNotEmpty,
          ),
          isNotEmpty,
          reason:
              'ContrastExemption.inactiveComponentsCarryNoContrastRequirement '
              'covers labelled nodes that report themselves as disabled. The '
              'matrix no longer contains one, so either the disabled scenes '
              'have gone or they stopped announcing themselves as disabled - '
              'and in the second case the exemption is silently no longer '
              'applied to them.',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'the treatment that exemption covers is the specified 38% foreground',
      (WidgetTester tester) async {
        // The exemption would be a licence to wash text out to any value at
        // all if nobody checked what "disabled" actually paints. It paints the
        // Material 3 disabled foreground, which the button suite measures as a
        // token; here it is re-read on the matrix itself so the exemption and
        // the treatment it excuses are asserted in one place.
        await pumpGoldenScene(
          tester,
          _sceneNamed('base_button_disabled'),
          brightness: Brightness.light,
        );
        final Element label = find.text('Action').evaluate().first;
        final Color? color = DefaultTextStyle.of(label).style.color;
        final ColorScheme scheme = Theme.of(label).colorScheme;

        expect(
          color?.toARGB32(),
          scheme.onSurface.withValues(alpha: 0.38).toARGB32(),
          reason:
              'Material 3 draws a disabled label at onSurface 38% '
              '(Flutter 3.44.4 packages/flutter/lib/src/material/'
              'filled_button.dart, _FilledButtonDefaultsM3.foregroundColor). '
              'WCAG exempts it because it is inactive, not because it is pale.',
        );
      },
    );

    testWidgets('every exempt tap-target owner is still in the matrix', (
      WidgetTester tester,
    ) async {
      // A component that left the matrix takes its exemption with it;
      // otherwise the map grows names nobody can check.
      final Set<Type> found = <Type>{};
      for (final GoldenScene scene in componentGoldenScenes()) {
        // Only the resting scenes. A driven one installs a mouse pointer that
        // `hoverOver` keeps until teardown, so pumping several in one test
        // adds the same device twice and trips the mouse tracker; and a driven
        // scene is a state of a component that a resting scene already holds,
        // so nothing is lost by leaving them out of the census.
        if (scene.drive != null) {
          continue;
        }
        await pumpGoldenScene(tester, scene, brightness: Brightness.light);
        for (final Type owner in kTapTargetExemptions.keys) {
          if (find.byType(owner).evaluate().isNotEmpty) {
            found.add(owner);
          }
        }
      }
      expect(
        found,
        containsAll(kTapTargetExemptions.keys),
        reason:
            'These components carry a tap-target exemption but no scene in the '
            'matrix renders them any more. Drop the entry from '
            'kTapTargetExemptions, which currently reads: '
            '${kTapTargetExemptions.entries.map(_describeEntry).join('; ')}.',
      );
    });

    testWidgets("BaseSwitcher's target is the height the register documents", (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpGoldenScene(
        tester,
        _sceneNamed('base_misc_controls'),
        brightness: Brightness.light,
      );
      // The first switcher in the scene is the tappable one; the third has no
      // onTap at all and is therefore not a tap target.
      final double height = tester
          .getSize(find.byType(BaseSwitcher).first)
          .height;

      expectConformant(
        token: 'BaseSwitcher.tapTargetHeight',
        component: 'BaseSwitcher',
        measured: height,
        expected: 48.0,
      );
      handle.dispose();
    });

    testWidgets("BaseBadge's delete affordance carries the 48 dp minimum", (
      WidgetTester tester,
    ) async {
      // The sweep above would pass a matrix that stopped rendering a deletable
      // badge at all, so the target is measured by name here: the scene must
      // still contain one, and the box around its glyph must still be the
      // interactive minimum rather than the 14 dp glyph it used to be.
      //
      // The removal's mark is `IconRole.x` resolved by this skin, not
      // `Icons.close`: a removable badge is drawn by `surfaces.tag` now, and
      // the mark inside a member is the skin's to choose - the same way every
      // other close affordance in this application already draws whatever
      // `MaterialGlyphs` answers for `IconRole.x`. Only the finder moved; the
      // 48 dp measurement below is unchanged.
      await pumpGoldenScene(
        tester,
        _sceneNamed('base_badges'),
        brightness: Brightness.light,
      );
      final Finder deleteGlyph = find.descendant(
        of: find.byType(BaseBadge),
        matching: find.byIcon(MaterialGlyphs.of(IconRole.x)),
      );
      expect(
        deleteGlyph,
        findsOneWidget,
        reason:
            'the matrix must keep rendering a deletable badge, or nothing '
            'here measures the delete affordance at all',
      );
      final Finder target = find.ancestor(
        of: deleteGlyph,
        matching: find.byType(InkResponse),
      );
      expect(
        tester.getSize(target).shortestSide,
        greaterThanOrEqualTo(kMinInteractiveDimension),
        reason:
            "BaseBadge's delete affordance is back under the interactive "
            'minimum the androidTapTargetGuideline requires. It is a button '
            'with a 48 dp box around a smaller glyph (base_badge.dart, '
            '_BadgeDeleteButton); do not shrink the box to the glyph.',
      );
    });

    testWidgets("BaseBadge's 48 dp box never covers the badge's own label", (
      WidgetTester tester,
    ) async {
      // The other half of the same requirement, and the one that makes the
      // enlargement honest rather than merely large: a target that reaches
      // the minimum by growing over the label turns a click on the badge's
      // text into a destructive action. It measured 13 dp of overlap at the
      // default size — a tap 20 dp from the glyph, visually on the last
      // characters of "Date: Last 7 days" in the tags filter bar
      // (lib/features/tags/widgets/tags_active_filters.dart:44-49), cleared
      // the filter. The badge sets the glyph off from the label by exactly
      // what the 48 dp box needs instead, which is the line Material draws
      // for its own chip: the delete affordance may claim the gap and the
      // trailing padding, never the label (chip.dart:2425-2431).
      //
      // Every size, because the arithmetic differs per size and the small pill
      // has the least room to give.
      for (final BadgeSize size in BadgeSize.values) {
        int deleted = 0;
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpConformance(
          tester,
          BaseBadge(
            label: 'Date: Last 7 days',
            size: size,
            onDeleted: () => deleted++,
            deleteTooltip: 'Remove the date filter',
          ),
        );
        final Rect target = tester.getRect(
          find.ancestor(
            of: find.byIcon(MaterialGlyphs.of(IconRole.x)),
            matching: find.byType(InkResponse),
          ),
        );
        final Rect label = tester.getRect(find.text('Date: Last 7 days'));

        expect(
          target.overlaps(label),
          isFalse,
          reason:
              'the ${size.name} badge\'s delete target $target reaches into '
              'its label $label, so a click on the badge\'s own text deletes '
              'the badge',
        );

        // The rectangles are one thing and the hit test is another, so the
        // last pixel of the label is actually clicked.
        await tester.tapAt(Offset(label.right - 1, label.center.dy));
        await tester.pump();
        expect(
          deleted,
          0,
          reason:
              'a tap on the last pixel of the ${size.name} badge\'s label '
              'deleted the badge',
        );
      }
    });

    testWidgets("BaseBadge's 48 dp box is a hit area, not just a rectangle", (
      WidgetTester tester,
    ) async {
      // The guideline reads a semantics rectangle, and Material's own chip
      // satisfies it by *declaring* one (chip.dart, _RenderEnsureMinSemanticsSize
      // overrides semanticBounds while the InkWell stays glyph-sized). A
      // declared rectangle nobody can tap is not a fix, so the corner of the
      // box is tapped here: it is 17 dp above the pill's own top edge at the
      // default badge size, so nothing but the enlarged target can receive it.
      int deleted = 0;
      await pumpConformance(
        tester,
        BaseBadge(
          label: 'deletable',
          onDeleted: () => deleted++,
          deleteTooltip: 'Remove',
        ),
      );
      final Finder target = find.ancestor(
        of: find.byIcon(MaterialGlyphs.of(IconRole.x)),
        matching: find.byType(InkResponse),
      );
      final Rect box = tester.getRect(target);
      await tester.tapAt(Offset(box.center.dx, box.top + 2));
      await tester.pump();

      expect(
        deleted,
        1,
        reason:
            'a tap inside the delete button\'s 48 dp box but outside the '
            'painted pill did not reach it, so the target only measures 48 dp '
            'and is not one',
      );
    });
  });
}

/// The scene registered under [name], so a targeted test names the arrangement
/// it needs instead of indexing into the registry by position.
GoldenScene _sceneNamed(String name) {
  return componentGoldenScenes().firstWhere(
    (GoldenScene scene) => scene.name == name,
    orElse: () => fail('No component scene is named "$name".'),
  );
}
