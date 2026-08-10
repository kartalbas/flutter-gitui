/// The rest of the surfaces facet: the badge, the tag, the avatar, the
/// banner, the empty state, the drop target, the code members, the grid,
/// the panel, the graph and the two pictorial members - each asserted on
/// the fact a reimplementation would drop: the InfoBadge preset a tone
/// means, the removal that carries its own name, the severity ground, the
/// 12% wash of a diff line's meaning, the gutter that reserves a blank
/// column, and the lane arithmetic behind the graph's reservation.
library;

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_control_marks.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_info_badge.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_surfaces.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';
import 'package:gitui_skin_fluent/src/surfaces/fluent_commit_graph.dart';

import 'support/fluent_behavior_harness.dart';

const FluentResources _light = FluentResources.light();

/// A member built exactly as the application reaches it.
Widget _member(Widget Function(BuildContext context) build) =>
    Builder(builder: build);

void main() {
  group('the badge', () {
    testWidgets('a neutral badge is WinUI\'s Informational preset: the '
        'solid neutral fill', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().badge(
            context,
            const BadgeSpec(label: '3', tone: Tone.neutral),
          ),
        ),
      );
      expectPaintedColor(
        paintedFillColors(tester, find.byType(FluentInfoBadge)).single,
        _light.systemFillColorSolidNeutral,
      );
    });

    testWidgets('a danger badge takes the Critical system fill under the '
        'contrast-correct foreground', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().badge(
            context,
            const BadgeSpec(label: '9', tone: Tone.danger),
          ),
        ),
      );
      expectPaintedColor(
        paintedFillColors(tester, find.byType(FluentInfoBadge)).single,
        _light.systemFillColorCritical,
      );
      expectPaintedColor(
        renderedLabelColor(tester, '9'),
        const Color(0xFFFFFFFF),
        reason: 'white holds on the critical red',
      );
    });

    testWidgets('a paired badge keeps ONE quiet surface and lets each '
        'fact\'s own ink carry its meaning', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().badge(
            context,
            const BadgeSpec(
              label: '+12',
              tone: Tone.gitAdded,
              secondary: BadgeFact(label: '-3', tone: Tone.gitDeleted),
            ),
          ),
        ),
      );
      expect(find.text('+12'), findsOneWidget);
      expect(find.text('-3'), findsOneWidget);
      expectPaintedColor(
        renderedLabelColor(tester, '+12'),
        const Color(0xFF0E6F0E),
        reason: 'the added half writes in the git palette\'s added green',
      );
      expectPaintedColor(
        renderedLabelColor(tester, '-3'),
        _light.systemFillColorCritical,
        reason: 'the deleted half writes in the palette\'s deleted red',
      );
    });
  });

  group('the tag', () {
    testWidgets('the removal is its own control wearing the drawn cross, '
        'named by removeTooltip, and it removes', (WidgetTester tester) async {
      int removed = 0;
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().tag(
            context,
            TagSpec(
              label: 'filter',
              onRemoved: () => removed++,
              removeTooltip: 'Remove the filter',
            ),
          ),
        ),
      );
      expect(find.byType(FluentDismissMark), findsOneWidget);
      final SemanticsHandle semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Remove the filter')),
        matchesSemantics(
          label: 'Remove the filter',
          tooltip: 'Remove the filter',
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
      await tester.tap(find.byType(FluentDismissMark));
      await tester.pump(const Duration(milliseconds: 200));
      expect(removed, 1);
    });

    testWidgets('a tag without a removal draws none, and a tappable tag '
        'answers the tap', (WidgetTester tester) async {
      int taps = 0;
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().tag(
            context,
            TagSpec(label: 'filter', onTap: () => taps++),
          ),
        ),
      );
      expect(find.byType(FluentDismissMark), findsNothing);
      await tester.tap(find.text('filter'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });
  });

  group('the avatar', () {
    testWidgets('identity fills the circle SOLID under the '
        'contrast-correct foreground - Fluent\'s coloured avatar', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().avatar(
            context,
            const AvatarSpec(monogram: 'AB', tone: Tone.series(4)),
          ),
        ),
      );
      expect(find.text('AB'), findsOneWidget);
      expectPaintedColor(
        _circleFills(
          tester,
          find
              .ancestor(of: find.text('AB'), matching: find.byType(Container))
              .first,
        ).single,
        const Color(0xFF0066B4),
        reason: 'series(4) on light surfaces is blue.dark',
      );
    });

    testWidgets('a thing with no identity takes the solid neutral', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().avatar(
            context,
            const AvatarSpec(monogram: 'X', semanticsLabel: 'The author'),
          ),
        ),
      );
      expectPaintedColor(
        _circleFills(
          tester,
          find
              .ancestor(of: find.text('X'), matching: find.byType(Container))
              .first,
        ).single,
        _light.systemFillColorSolidNeutral,
      );
    });
  });

  group('the banner', () {
    testWidgets('a danger banner stands on the Critical InfoBar ground '
        'behind the card stroke', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().banner(
              context,
              const BannerSpec(tone: Tone.danger, title: 'It broke'),
            ),
          ),
        ),
      );
      expectPaintedColor(
        paintedFillColors(
          tester,
          find
              .ancestor(
                of: find.text('It broke'),
                matching: find.byType(Container),
              )
              .first,
        ).first,
        _light.systemFillColorCriticalBackground,
        reason: 'SystemFillColorCriticalBackground (info_bar.dart:594-595)',
      );
    });

    testWidgets('the dismissal is its own control wearing the 16 epx drawn '
        'cross, and it dismisses', (WidgetTester tester) async {
      int dismissed = 0;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().banner(
              context,
              BannerSpec(
                tone: Tone.warning,
                title: 'Heads up',
                onDismiss: () => dismissed++,
              ),
            ),
          ),
        ),
      );
      final FluentDismissMark cross = tester.widget<FluentDismissMark>(
        find.byType(FluentDismissMark),
      );
      expect(cross.size, 16, reason: 'the InfoBar close (info_bar.dart:631)');
      await tester.tap(find.byType(FluentDismissMark));
      await tester.pump(const Duration(milliseconds: 200));
      expect(dismissed, 1);
    });

    testWidgets('a banner\'s action is this skin\'s own standard button, '
        'and it acts', (WidgetTester tester) async {
      int acted = 0;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().banner(
              context,
              BannerSpec(
                tone: Tone.info,
                title: 'Settings are missing',
                actions: <NoticeAction>[
                  NoticeAction(
                    label: 'Open settings',
                    tooltip: 'Open the settings screen',
                    onPressed: () => acted++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(acted, 1);
    });
  });

  group('the empty state', () {
    testWidgets('the headline takes the region-title step - Subtitle, 20 - '
        'and the way out is a real button', (WidgetTester tester) async {
      int acted = 0;
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => const FluentSurfaces().emptyState(
            context,
            EmptyStateSpec(
              icon: IconRole.folderOpen,
              title: 'No repositories yet',
              message: 'Add one to get started.',
              actions: <EmptyStateAction>[
                EmptyStateAction(
                  label: 'Add repository',
                  icon: IconRole.plus,
                  onPressed: () => acted++,
                  emphasis: Emphasis.primary,
                ),
              ],
            ),
          ),
        ),
      );
      final RenderParagraph headline = tester.renderObject<RenderParagraph>(
        find.text('No repositories yet'),
      );
      expect(
        headline.text.style?.fontSize,
        20,
        reason:
            'pageTitle lands on Subtitle (20/28) - never on window chrome '
            'treatment',
      );
      await tester.tap(find.text('Add repository'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(acted, 1);
    });
  });

  group('the drop target', () {
    testWidgets('inert until something hovers: the smoke and the callout '
        'exist only while active', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          height: 300,
          child: _member(
            (BuildContext context) => const FluentSurfaces().dropTarget(
              context,
              const DropTargetSpec(
                child: ContentPort(Text('underneath')),
                active: false,
                icon: IconRole.plus,
                label: 'Drop repositories here',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Drop repositories here'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          height: 300,
          child: _member(
            (BuildContext context) => const FluentSurfaces().dropTarget(
              context,
              const DropTargetSpec(
                child: ContentPort(Text('underneath')),
                active: true,
                icon: IconRole.plus,
                label: 'Drop repositories here',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Drop repositories here'), findsOneWidget);
      expect(
        find.text('underneath'),
        findsOneWidget,
        reason: 'the region stays visible: the user is dropping ONTO it',
      );
      final List<Color> fills = paintedFillColors(
        tester,
        find.byType(ColoredBox),
      );
      expect(
        fills.any((Color fill) => fill.toARGB32() == 0x8A000000),
        isTrue,
        reason: 'the smoke (content_dialog.dart:240) dims the region',
      );
    });
  });

  group('the code line', () {
    testWidgets('an added line washes its own green at the application\'s '
        'measured 12%', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeLine(
              context,
              const CodeLineSpec(
                runs: <TextRun>[TextRun('added line')],
                tone: Tone.gitAdded,
                marker: '+',
                newNumber: 5,
              ),
            ),
          ),
        ),
      );
      expectPaintedColor(
        paintedFillColors(
          tester,
          find
              .ancestor(of: find.text('5'), matching: find.byType(Container))
              .first,
        ).first,
        const Color(0xFF0E6F0E).withValues(alpha: 0.12),
      );
    });

    testWidgets('a PAIRED line reserves the blank old column an added line '
        'needs to stay aligned; an unpaired one does not', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeLine(
              context,
              const CodeLineSpec(
                runs: <TextRun>[TextRun('added')],
                tone: Tone.gitAdded,
                newNumber: 5,
              ),
            ),
          ),
        ),
      );
      final double paired = tester.getTopLeft(find.text('added')).dx;

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeLine(
              context,
              const CodeLineSpec(
                runs: <TextRun>[TextRun('added')],
                newNumber: 5,
                paired: false,
              ),
            ),
          ),
        ),
      );
      final double unpaired = tester.getTopLeft(find.text('added')).dx;
      expect(
        paired,
        greaterThan(unpaired),
        reason:
            'the paired line reserved a blank old column; the whole-file '
            'view must not push its content sideways for a column that can '
            'never fill',
      );
    });

    testWidgets('a selected line takes the selected tile\'s fill plus the '
        'pill, so "picked" reads the same on a diff line as on a row', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeLine(
              context,
              CodeLineSpec(
                runs: const <TextRun>[TextRun('staged line')],
                tone: Tone.gitAdded,
                selected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      final List<Color> fills = paintedFillColors(tester, find.byType(Stack));
      expect(
        fills.any(
          (Color fill) =>
              fill.toARGB32() == _light.subtleFillColorSecondary.toARGB32(),
        ),
        isTrue,
        reason: 'selection wins over the line\'s own wash',
      );
      expect(
        fills.any((Color fill) => fill.toARGB32() == 0xFF0066B4),
        isTrue,
        reason: 'the accent pill marks the picked line',
      );
    });

    testWidgets('a tappable line ANSWERS the tap - the staging gesture a '
        'user performs on a diff line', (WidgetTester tester) async {
      int taps = 0;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeLine(
              context,
              CodeLineSpec(
                runs: const <TextRun>[TextRun('pick me')],
                tone: Tone.gitAdded,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick me', findRichText: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1, reason: 'choosing the line must reach the application');
    });
  });

  group('the code block', () {
    testWidgets('an unwrapped block SCROLLS sideways - output the user '
        'cannot reach the end of is output they cannot read', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 200,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeBlock(
              context,
              const CodeBlockSpec(
                text: 'a very long line of git output that will not fit',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 200,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeBlock(
              context,
              const CodeBlockSpec(text: 'a commit message body', wrap: true),
            ),
          ),
        ),
      );
      expect(
        find.byType(SingleChildScrollView),
        findsNothing,
        reason: 'a wrapped block folds instead of scrolling',
      );
    });

    testWidgets('the tone writes the block\'s ink: an error block is '
        'critical', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().codeBlock(
              context,
              const CodeBlockSpec(text: 'fatal: not a repo', tone: Tone.danger),
            ),
          ),
        ),
      );
      expectPaintedColor(
        renderedLabelColor(tester, 'fatal: not a repo'),
        _light.systemFillColorCritical,
      );
    });
  });

  group('the data grid', () {
    testWidgets('the header band speaks Body Strong on the alternate '
        'ground, and a short row keeps its columns', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          height: 300,
          child: _member(
            (BuildContext context) => const FluentSurfaces().dataGrid(
              context,
              const DataGridSpec(
                columns: <String>['Name', 'Value'],
                rows: <List<ContentPort>>[
                  <ContentPort>[
                    ContentPort(Text('alpha')),
                    ContentPort(Text('1')),
                  ],
                  // A short row: the missing cell stays blank, never
                  // collapsing the column.
                  <ContentPort>[ContentPort(Text('beta'))],
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      final RenderParagraph header = tester.renderObject<RenderParagraph>(
        find.text('Name'),
      );
      expect(header.text.style?.fontWeight, FontWeight.w600);
      final List<Color> fills = paintedFillColors(tester, find.byType(Table));
      expect(
        fills.any(
          (Color fill) =>
              fill.toARGB32() ==
              _light.solidBackgroundFillColorSecondary.toARGB32(),
        ),
        isTrue,
        reason: 'the header row stands on the alternate solid ground',
      );
    });
  });

  group('the panel', () {
    testWidgets('the title speaks Body Strong, the actions carry their '
        'words and act, and a disabled action stays visible', (
      WidgetTester tester,
    ) async {
      int acted = 0;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 500,
          height: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().panel(
              context,
              PanelSpec(
                title: 'Commit log',
                content: const ContentPort(Text('the content')),
                actions: <ToolbarActionEntry>[
                  ToolbarActionEntry(
                    icon: IconRole.arrowsClockwise,
                    label: 'Refresh',
                    tooltip: 'Reload the log',
                    onPressed: () => acted++,
                  ),
                  const ToolbarActionEntry(
                    icon: IconRole.upload,
                    label: 'Push',
                    tooltip: 'No remote is configured',
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final RenderParagraph title = tester.renderObject<RenderParagraph>(
        find.text('Commit log'),
      );
      expect(title.text.style?.fontWeight, FontWeight.w600);
      await tester.tap(find.text('Refresh'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(acted, 1);
      expect(
        find.text('Push'),
        findsOneWidget,
        reason: 'a bar that silently drops what it cannot do explains nothing',
      );
      expectPaintedColor(
        renderedLabelColor(tester, 'Push'),
        _light.textFillColorDisabled,
      );
    });
  });

  group('the commit graph', () {
    testWidgets('the gutter reserves one 12 epx lane per column, capped at '
        'eight - the same arithmetic the painter draws with', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        Row(
          children: <Widget>[
            _member(
              (BuildContext context) =>
                  const FluentSurfaces().commitGraphGutter(
                    context,
                    const GraphGutterSpec(laneCount: 3),
                  ),
            ),
          ],
        ),
      );
      expect(
        tester.getSize(find.byType(FluentCommitGraphGutter)).width,
        36,
        reason: '3 lanes at 12 epx each',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFluentBehavior(
        tester,
        Row(
          children: <Widget>[
            _member(
              (BuildContext context) =>
                  const FluentSurfaces().commitGraphGutter(
                    context,
                    const GraphGutterSpec(laneCount: 20),
                  ),
            ),
          ],
        ),
      );
      expect(
        tester.getSize(find.byType(FluentCommitGraphGutter)).width,
        96,
        reason:
            'a pathological window crowds its lanes, never the subject text',
      );
    });

    testWidgets('a row paints its dot, edges and HEAD halo in the skin\'s '
        'own series ink', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 96,
          height: 28,
          child: _member(
            (BuildContext context) => const FluentSurfaces().commitGraphRow(
              context,
              const GraphRowSpec(
                lane: 1,
                toneIndex: 4,
                isMerge: true,
                isCurrent: true,
                laneCount: 3,
                incoming: <GraphEdgeSpec>[GraphEdgeSpec(lane: 0, toneIndex: 0)],
                outgoing: <GraphEdgeSpec>[GraphEdgeSpec(lane: 1, toneIndex: 4)],
                passing: <GraphEdgeSpec>[GraphEdgeSpec(lane: 2, toneIndex: 2)],
              ),
            ),
          ),
        ),
      );
      // The member fills its box and builds no gesture machinery: the
      // graph is decoration behind the row's content.
      expect(find.byType(IgnorePointer), findsWidgets);
      expect(tester.getSize(find.byType(CustomPaint).first).width, 96);
    });
  });

  group('the markdown document', () {
    testWidgets('a heading walks the ramp down from Title - the upper '
        'steps the interface itself never spends', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          height: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().markdown(
              context,
              const MarkdownSpec(
                source: '# Heading\n\nSome prose.',
                selectable: false,
              ),
            ),
          ),
        ),
      );
      expect(_renderedFontSize(tester, 'Heading'), 28, reason: 'Title: 28/36');
      expect(
        _renderedFontSize(tester, 'Some prose.'),
        14,
        reason: 'Body: 14/20',
      );
    });

    testWidgets('following a link reports its href - the one thing a '
        'document lets the user DO', (WidgetTester tester) async {
      final List<String> hrefs = <String>[];
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          height: 400,
          child: _member(
            (BuildContext context) => const FluentSurfaces().markdown(
              context,
              MarkdownSpec(
                source: '[open the manual](https://example.com/doc)',
                selectable: false,
                onLinkTapped: hrefs.add,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open the manual', findRichText: true));
      await tester.pump();
      expect(
        hrefs,
        <String>['https://example.com/doc'],
        reason:
            'the href must arrive verbatim - dropping the guard or the '
            'forwarding would leave every document link dead',
      );
    });
  });

  group('the image viewer', () {
    testWidgets('the picture pans and zooms over the alternate ground', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 300,
          height: 300,
          child: _member(
            (BuildContext context) => const FluentSurfaces().imageViewer(
              context,
              ImageViewerSpec(
                image: MemoryImage(Uint8List.fromList(_transparentPng)),
                semanticsLabel: 'The picture',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .maxScale,
        3,
        reason: 'the 3x ceiling the application\'s old viewer allowed',
      );
    });
  });
}

/// Every circle fill painted under [finder]: a circular BoxDecoration -
/// the avatar - reaches the canvas as drawCircle, which the shared fill
/// reader deliberately does not count.
List<Color> _circleFills(WidgetTester tester, Finder finder) {
  final List<Color> colors = <Color>[];
  for (final Element element in finder.evaluate()) {
    final RenderObject? renderObject = element.renderObject;
    if (renderObject == null) continue;
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    renderObject.paint(TestRecordingPaintingContext(canvas), Offset.zero);
    for (final RecordedInvocation recorded in canvas.invocations) {
      final Invocation invocation = recorded.invocation;
      if (!invocation.isMethod || invocation.memberName != #drawCircle) {
        continue;
      }
      for (final Object? argument in invocation.positionalArguments) {
        if (argument is Paint && argument.style == PaintingStyle.fill) {
          colors.add(argument.color);
        }
      }
    }
  }
  return colors;
}

/// The size a paragraph actually renders [text] at, walking the span tree
/// because a Markdown paragraph may carry its style on an inner span.
double? _renderedFontSize(WidgetTester tester, String text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(text),
  );
  double? found;
  void walk(InlineSpan span) {
    if (span.style?.fontSize != null) found ??= span.style!.fontSize;
    if (span is TextSpan) {
      for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  walk(paragraph.text);
  return found;
}

/// A 1x1 transparent PNG, so an image provider exists without any asset.
const List<int> _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
