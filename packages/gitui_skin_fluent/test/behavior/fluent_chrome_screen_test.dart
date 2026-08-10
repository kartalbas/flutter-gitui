/// chrome.screen, measured: the PageHeader idiom - a title over content,
/// because Fluent has NO app bar to put one in.
///
/// The header's metrics are the reference's (fluent_ui@4.16.1
/// controls/layout/page.dart): the title in the Title ramp step (:279),
/// the commands aligned at the end (:283-292), the page gutter of 24
/// (`kPageDefaultVerticalPadding`, :5). The strip's controls are the
/// CommandBar's (surfaces/commandbar.dart:646-683), the choice entry is
/// the CommandBar toggle set the contract names for this language, and
/// the selection strip sits at the TOP - where Fluent's commands live,
/// and where Material's batch bar deliberately does not.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_button.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_icon_button.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_chrome.dart';

import 'support/fluent_behavior_harness.dart';
import 'support/fluent_chrome_harness.dart';

// The Windows default accent's resting brush on light grounds
// (fluent_ui color.dart:171, :347-352): the checked toggle's fill and the
// accent button's.
const Color _accentRestLight = Color(0xff0066b4);

Future<void> _pumpScreen(WidgetTester tester, ScreenSpec spec) =>
    pumpFluentChrome(
      tester,
      (BuildContext context) => const FluentChrome().screen(context, spec),
    );

ScreenSpec _screenSpec({
  List<ToolbarGroup> toolbar = const <ToolbarGroup>[],
  List<ToolbarActionEntry> primaryActions = const <ToolbarActionEntry>[],
  SelectionBarSpec? selectionBar,
  ContentPort? footer,
}) => ScreenSpec(
  title: 'Repositories',
  body: const ContentPort(Text('screen-body')),
  toolbar: toolbar,
  primaryActions: primaryActions,
  selectionBar: selectionBar,
  footer: footer,
);

void main() {
  testWidgets('the title renders at the Title step - the window-scale rung '
      'the PageHeader owns - with the body below it', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, _screenSpec());
    final RenderParagraph title = tester.renderObject<RenderParagraph>(
      find.text('Repositories'),
    );
    expect(
      title.text.style?.fontSize,
      28,
      reason:
          'the PageHeader title is typography.title (page.dart:279): '
          '28/36 Semibold (SPEC type-ramp table)',
    );
    expect(title.text.style?.fontWeight, FontWeight.w600);
    expect(find.text('screen-body'), findsOneWidget);
  });

  testWidgets('the screen\'s own actions live IN the header - there is no '
      'bar - and stay visible without a target when unavailable', (
    WidgetTester tester,
  ) async {
    int fetched = 0;
    await _pumpScreen(
      tester,
      _screenSpec(
        toolbar: <ToolbarGroup>[
          ToolbarGroup(<ToolbarEntry>[
            ToolbarActionEntry(
              icon: IconRole.x,
              label: 'Fetch',
              tooltip: 'Fetch from origin',
              onPressed: () => fetched++,
            ),
            const ToolbarActionEntry(
              icon: IconRole.x,
              label: 'Push',
              tooltip: 'Nothing to push',
              onPressed: null,
            ),
          ]),
        ],
      ),
    );
    // Both actions share the header row with the title.
    expect(
      tester.getCenter(find.text('Fetch')).dy,
      closeTo(tester.getCenter(find.text('Repositories')).dy, 20),
      reason:
          'the commands sit beside the title (page.dart:283-292), not '
          'in a second bar',
    );
    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();
    expect(fetched, 1);
    expect(
      find.text('Push'),
      findsOneWidget,
      reason:
          'an unavailable action stays visible; a bar that silently '
          'drops what it cannot do explains nothing',
    );
    await tester.tap(find.text('Push'), warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('the primary action - what the screen is FOR - wears the '
      'accent, the one louder control this language has', (
    WidgetTester tester,
  ) async {
    int committed = 0;
    await _pumpScreen(
      tester,
      _screenSpec(
        primaryActions: <ToolbarActionEntry>[
          ToolbarActionEntry(
            icon: IconRole.x,
            label: 'Commit',
            tooltip: 'Commit staged changes',
            onPressed: () => committed++,
          ),
        ],
      ),
    );
    expect(
      singleFillOf(
        tester,
        find.descendant(
          of: find.widgetWithText(FluentButton, 'Commit'),
          matching: find.byType(AnimatedContainer),
        ),
      ).toARGB32(),
      _accentRestLight.toARGB32(),
      reason:
          'ScreenSpec.primaryActions is the need behind Material\'s FAB; '
          'Fluent has no FAB, so the answer is the accent button in the '
          'header - emphasis by fill, placement by idiom',
    );
    await tester.tap(find.text('Commit'));
    await tester.pumpAndSettle();
    expect(committed, 1);
  });

  testWidgets('"the same subject, shown a different way" is ONE toggle '
      'set: the chosen option wears the checked-input accent and a press '
      'reports', (WidgetTester tester) async {
    final List<String> chosen = <String>[];
    await _pumpScreen(
      tester,
      _screenSpec(
        toolbar: <ToolbarGroup>[
          ToolbarGroup(<ToolbarEntry>[
            ToolbarChoiceEntry<String>(
              ChoiceGroupSpec<String>(
                options: const <ChoiceOption<String>>[
                  ChoiceOption<String>(value: 'grid', label: 'Grid'),
                  ChoiceOption<String>(value: 'list', label: 'List'),
                ],
                selected: 'grid',
                onSelected: chosen.add,
                label: 'View mode',
              ),
            ),
          ]),
        ],
      ),
    );
    expect(
      singleFillOf(
        tester,
        find.ancestor(
          of: find.text('Grid'),
          matching: find.byType(AnimatedContainer),
        ),
      ).toARGB32(),
      _accentRestLight.toARGB32(),
      reason:
          'the chosen segment wears WinUI\'s checked-input treatment '
          '(inputs/toggle_button.dart:162-169) - one CommandBar toggle '
          'set, not N chips',
    );
    expect(
      singleFillOf(
        tester,
        find.ancestor(
          of: find.text('List'),
          matching: find.byType(AnimatedContainer),
        ),
      ).a,
      0,
      reason: 'the unchosen segment rests transparent on the subtle ladder',
    );
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(chosen, <String>['list']);
  });

  testWidgets('the selection strip sits at the TOP - Fluent\'s commands '
      'live over the content, not under it - with the count, the clear '
      'affordance and the batch actions', (WidgetTester tester) async {
    int cleared = 0;
    int deleted = 0;
    await _pumpScreen(
      tester,
      _screenSpec(
        selectionBar: SelectionBarSpec(
          selectedCount: 3,
          onClear: () => cleared++,
          actions: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              ToolbarActionEntry(
                icon: IconRole.x,
                label: 'Delete',
                tooltip: 'Delete selected tags',
                tone: Tone.danger,
                onPressed: () => deleted++,
              ),
            ]),
          ],
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.getCenter(find.text('3')).dy,
      lessThan(tester.getCenter(find.text('screen-body')).dy),
      reason:
          'the strip is above the content - the mirror of Material\'s '
          'bottom bar, from the same spec',
    );
    await tester.tap(find.byType(FluentIconButton));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('the footer closes the screen below the body', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      _screenSpec(footer: const ContentPort(Text('screen-footer'))),
    );
    expect(find.text('screen-footer'), findsOneWidget);
    expect(
      tester.getCenter(find.text('screen-footer')).dy,
      greaterThan(tester.getCenter(find.text('screen-body')).dy),
    );
  });
}
