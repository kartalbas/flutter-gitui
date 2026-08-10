/// The type facet, measured: the nine roles landing on the Windows 11
/// ramp's four rungs, colour following the surface, the tones, Fluent's
/// end-ellipsis confinement, the reserved glyph slots, and runs.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_type.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';

import 'support/fluent_behavior_harness.dart';

const FluentType facet = FluentType();
const FluentResources _light = FluentResources.light();

/// Builds one facet member under the harness.
Widget _member(Widget Function(BuildContext context) build) =>
    Builder(builder: (BuildContext context) => build(context));

/// The style the paragraph rendering [text] actually carries.
TextStyle _renderedStyle(WidgetTester tester, String text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(text),
  );
  return paragraph.text.style!;
}

void main() {
  group('roles land on the Windows ramp', () {
    testWidgets('pageTitle is Subtitle - 20 Semibold - never window-scale '
        'Title, because four of five uses are an empty state\'s headline', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) =>
              facet.text(context, 'No repositories', role: TextRole.pageTitle),
        ),
      );
      final TextStyle style = _renderedStyle(tester, 'No repositories');
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('the quiet collapses are Fluent speaking: itemTitle and '
        'control are Regular body, emphasis is Body Strong, micro shares '
        'Caption with detail', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => Column(
            children: <Widget>[
              facet.text(context, 'item', role: TextRole.itemTitle),
              facet.text(context, 'control', role: TextRole.control),
              facet.text(context, 'emphasis', role: TextRole.emphasis),
              facet.text(context, 'detail', role: TextRole.detail),
              facet.text(context, 'micro', role: TextRole.micro),
            ],
          ),
        ),
      );
      // Fluent names objects and operates controls in Regular body - no
      // per-job size step, no emboldened control label (Material gives the
      // same roles titleSmall / labelLarge at w500+).
      expect(_renderedStyle(tester, 'item').fontSize, 14);
      expect(_renderedStyle(tester, 'item').fontWeight, isNot(FontWeight.w600));
      expect(_renderedStyle(tester, 'control').fontSize, 14);
      expect(
        _renderedStyle(tester, 'control').fontWeight,
        isNot(FontWeight.w600),
      );
      // "Use Semibold instead of Bold for emphasis" - SPEC, verbatim.
      expect(_renderedStyle(tester, 'emphasis').fontSize, 14);
      expect(_renderedStyle(tester, 'emphasis').fontWeight, FontWeight.w600);
      // Caption is the ramp's floor: 12 Regular for both supporting roles.
      expect(_renderedStyle(tester, 'detail').fontSize, 12);
      expect(_renderedStyle(tester, 'micro').fontSize, 12);
    });

    testWidgets('code keeps its columns even unresolved: the fixed-width '
        'floor is Consolas over the engine monospace', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) =>
              facet.text(context, 'a1b2c3', role: TextRole.code),
        ),
      );
      final TextStyle style = _renderedStyle(tester, 'a1b2c3');
      expect(style.fontFamily, 'Consolas');
      expect(style.fontFamilyFallback, contains('monospace'));
    });
  });

  group('colour follows the surface', () {
    testWidgets('a neutral line takes the ambient foreground, whatever the '
        'enclosing surface published', (WidgetTester tester) async {
      const Color published = Color(0xFF123456);
      await pumpFluentBehavior(
        tester,
        DefaultTextStyle(
          style: const TextStyle(color: published),
          child: _member(
            (BuildContext context) =>
                facet.text(context, 'follows', role: TextRole.body),
          ),
        ),
      );
      expect(_renderedStyle(tester, 'follows').color, published);
    });

    testWidgets('tones stamp the language\'s own inks: critical for danger, '
        'the red swatch brush - NOT critical - for invalid', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => Column(
            children: <Widget>[
              facet.text(
                context,
                'danger',
                role: TextRole.body,
                tone: Tone.danger,
              ),
              facet.text(
                context,
                'invalid',
                role: TextRole.body,
                tone: Tone.invalid,
              ),
            ],
          ),
        ),
      );
      expectPaintedColor(
        _renderedStyle(tester, 'danger').color!,
        _light.systemFillColorCritical,
      );
      // The separation the vocabulary predicted: Fluent validates fields
      // with the red swatch's brush (red.dark on light), not with
      // SystemFillColorCritical.
      expectPaintedColor(
        _renderedStyle(tester, 'invalid').color!,
        const Color(0xFFB90D1C),
      );
    });

    testWidgets('muted answers RELATIVE to what it sits beside: secondary '
        'on the page, on-accent secondary over an accent fill', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => Column(
            children: <Widget>[
              facet.text(
                context,
                'on page',
                role: TextRole.body,
                tone: Tone.muted,
              ),
              DefaultTextStyle(
                style: TextStyle(color: _light.textOnAccentFillColorPrimary),
                child: _member(
                  (BuildContext context) => facet.text(
                    context,
                    'on accent',
                    role: TextRole.body,
                    tone: Tone.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      expectPaintedColor(
        _renderedStyle(tester, 'on page').color!,
        _light.textFillColorSecondary,
      );
      // The genuinely Fluent improvement over Material's collapse: the
      // dictionary has a quieter on-accent word.
      expectPaintedColor(
        _renderedStyle(tester, 'on accent').color!,
        _light.textOnAccentFillColorSecondary,
      );
    });
  });

  group('confinement', () {
    const String prose =
        'A rather long line of prose that cannot possibly fit a narrow '
        'column without wrapping onto several lines.';

    testWidgets('uncapped text wraps freely; capped text trims to its lines '
        'with the character ellipsis', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 150,
          child: _member(
            (BuildContext context) => Column(
              children: <Widget>[
                facet.text(context, prose, role: TextRole.body),
                facet.text(context, prose, role: TextRole.body, maxLines: 1),
              ],
            ),
          ),
        ),
      );
      final List<Element> lines = find.text(prose).evaluate().toList();
      final Size uncapped = lines.first.size!;
      final Size capped = lines.last.size!;
      // Body is 14/20: one line stands 20 tall; free prose stands taller.
      expect(capped.height, 20);
      expect(uncapped.height, greaterThan(20));
      // The cap is what turns the ellipsis on - it never causes a cut on
      // the free paragraph.
      final RenderParagraph cappedParagraph =
          lines.last.renderObject! as RenderParagraph;
      expect(cappedParagraph.overflow, TextOverflow.ellipsis);
      final RenderParagraph freeParagraph =
          lines.first.renderObject! as RenderParagraph;
      expect(freeParagraph.overflow, TextOverflow.clip);
    });
  });

  group('icon', () {
    testWidgets('reserves its exact box on the published 12/16/20 icon '
        'ramp - the registered glyph-table gap, geometry already final', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              facet.icon(
                context,
                IconRole.gitBranch,
                scale: ControlScale.compact,
                semanticsLabel: 'compact',
              ),
              facet.icon(context, IconRole.gitBranch, semanticsLabel: 'normal'),
              facet.icon(
                context,
                IconRole.gitBranch,
                scale: ControlScale.prominent,
                semanticsLabel: 'prominent',
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.bySemanticsLabel('compact')),
        const Size.square(12),
      );
      expect(
        tester.getSize(find.bySemanticsLabel('normal')),
        const Size.square(16),
      );
      expect(
        tester.getSize(find.bySemanticsLabel('prominent')),
        const Size.square(20),
      );
      semantics.dispose();
    });
  });

  group('runs', () {
    testWidgets('an emphasised run takes Semibold, a toned run its ink, and '
        'the rest of the line follows the surface', (
      WidgetTester tester,
    ) async {
      const Color published = Color(0xFF654321);
      await pumpFluentBehavior(
        tester,
        DefaultTextStyle(
          style: const TextStyle(color: published),
          child: _member(
            (BuildContext context) => facet.runs(context, const <TextRun>[
              TextRun('plain '),
              TextRun('hit', emphasised: true),
              TextRun(' gone', tone: Tone.gitDeleted),
            ], role: TextRole.code),
          ),
        ),
      );
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.textContaining('plain'),
      );
      final List<TextStyle> styles = <TextStyle>[];
      paragraph.text.visitChildren((InlineSpan span) {
        if (span is TextSpan && span.text != null) {
          styles.add(span.style ?? const TextStyle());
        }
        return true;
      });
      expect(styles, hasLength(3));
      // The plain run carries no colour of its own - the surface's merge
      // supplies it.
      expect(styles[0].color, isNull);
      expect(styles[1].fontWeight, FontWeight.w600);
      // gitDeleted on light: SystemFillColorCritical light, the palette's
      // own citation.
      expectPaintedColor(styles[2].color!, const Color(0xFFC42B1C));
    });

    testWidgets('selectable text selects with no toolbar - the registered '
        'flyout gap, selection itself working', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        // SelectableRegion asserts an Overlay ancestor for its magnifier
        // plumbing; the application always has one (the navigator's), and
        // the harness deliberately has no navigator, so the test supplies
        // the bare Overlay the app root would.
        Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) => Center(
                child: _member(
                  (BuildContext context) => facet.text(
                    context,
                    'copy me',
                    role: TextRole.code,
                    selectable: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      expect(find.byType(SelectableRegion), findsOneWidget);
      final SelectableRegion region = tester.widget<SelectableRegion>(
        find.byType(SelectableRegion),
      );
      expect(region.selectionControls, emptyTextSelectionControls);
    });
  });
}
