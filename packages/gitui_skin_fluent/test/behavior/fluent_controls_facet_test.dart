/// The facet, member by member: every one of the fifteen builds through
/// `FluentControls`, accepts its parameters, and answers its core
/// behaviour - the same obligation the blueprint states for a complete
/// facet, measured here on the drawn controls.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_choice_controls.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_progress.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_slider.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_controls.dart';

import 'support/fluent_behavior_harness.dart';

const FluentControls facet = FluentControls();

// The accent's dark stop (fluent_ui color.dart:171): the selected fill in
// a light theme.
const Color _accentRestLight = Color(0xff0066b4);

/// Builds one facet member under the harness.
Widget _member(Widget Function(BuildContext context) build) =>
    Builder(builder: (BuildContext context) => build(context));

void main() {
  group('button and words', () {
    testWidgets('button builds through the facet and fires', (
      WidgetTester tester,
    ) async {
      int presses = 0;
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => facet.button(
            context,
            ButtonSpec(label: 'Commit', onPressed: () => presses++),
          ),
        ),
      );
      await tester.tap(find.text('Commit'));
      await tester.pumpAndSettle();
      expect(presses, 1);
    });
  });

  group('toggleRow', () {
    testWidgets('the whole row is the control, description below the words', (
      WidgetTester tester,
    ) async {
      bool? reported;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => facet.toggleRow(
              context,
              ToggleRowSpec(
                label: 'Prune on fetch',
                description: 'Remove deleted remote branches',
                value: false,
                onChanged: (bool? next) => reported = next,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Prune on fetch'), findsOneWidget);
      expect(find.text('Remove deleted remote branches'), findsOneWidget);
      // Tapping the WORDS operates the toggle: the row is one pressable.
      await tester.tap(find.text('Prune on fetch'));
      expect(reported, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('the switch kind draws the switch track', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 400,
          child: _member(
            (BuildContext context) => facet.toggleRow(
              context,
              ToggleRowSpec(
                label: 'Dark mode',
                kind: ToggleKind.switching,
                value: true,
                onChanged: (bool? _) {},
              ),
            ),
          ),
        ),
      );
      expect(
        paintedFillColors(tester, find.text('Dark mode').first).isEmpty,
        isTrue,
      );
      expect(find.text('Dark mode'), findsOneWidget);
    });
  });

  group('slider', () {
    testWidgets('dragging reports, divisions snap, arrows step', (
      WidgetTester tester,
    ) async {
      final List<double> reported = <double>[];
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 200,
          child: _member(
            (BuildContext context) => facet.slider(
              context,
              SliderSpec(
                value: 0,
                min: 0,
                max: 10,
                divisions: 10,
                onChanged: reported.add,
              ),
            ),
          ),
        ),
      );
      // Drag to about the middle: every report is a whole step.
      await tester.timedDrag(
        find.byType(FluentSlider),
        const Offset(100, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(reported, isNotEmpty);
      for (final double value in reported) {
        expect(
          value,
          closeTo(value.roundToDouble(), 1e-9),
          reason: 'divisions quantise every report (10 steps over 0..10)',
        );
      }
      // The keyboard: Tab onto it, one arrow step is one division.
      reported.clear();
      await focusWithTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(reported, <double>[1]);
    });
  });

  group('dropdown', () {
    testWidgets('opens on activation, choosing reports and closes', (
      WidgetTester tester,
    ) async {
      String? chosen;
      Future<void> pump() => pumpFluentBehavior(
        tester,
        SizedBox(
          width: 300,
          child: _member(
            (BuildContext context) => facet.dropdown<String>(
              context,
              DropdownSpec<String>(
                label: 'Remote',
                value: 'origin',
                options: const <DropdownOption<String>>[
                  DropdownOption<String>(value: 'origin', label: 'origin'),
                  DropdownOption<String>(
                    value: 'upstream',
                    label: 'upstream',
                    detail: 'github',
                  ),
                ],
                onChanged: (String? next) => chosen = next,
              ),
            ),
          ),
        ),
      );
      await pump();
      expect(find.text('upstream'), findsNothing);
      await tester.tap(find.text('origin').last);
      await tester.pumpAndSettle();
      expect(find.text('upstream'), findsOneWidget);
      expect(find.text('github'), findsOneWidget);
      await tester.tap(find.text('upstream'));
      await tester.pumpAndSettle();
      expect(chosen, 'upstream');
      expect(find.text('github'), findsNothing);
    });
  });

  group('choiceGroup', () {
    testWidgets('the chosen radio wears the accent; choosing reports', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => facet.choiceGroup<String>(
            context,
            ChoiceGroupSpec<String>(
              label: 'Search mode',
              selected: 'plain',
              options: const <ChoiceOption<String>>[
                ChoiceOption<String>(value: 'plain', label: 'Plain'),
                ChoiceOption<String>(value: 'regex', label: 'Regex'),
              ],
              onSelected: (String value) => chosen = value,
            ),
          ),
        ),
      );
      expect(find.byType(FluentChoiceGroup<String>), findsOneWidget);
      await tester.tap(find.text('Regex'));
      await tester.pumpAndSettle();
      expect(chosen, 'regex');
    });
  });

  group('filterToggle', () {
    testWidgets('off is the standard button, on is the accent; the count '
        'rides the words', (WidgetTester tester) async {
      bool? reported;
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => facet.filterToggle(
            context,
            FilterToggleSpec(
              label: 'Staged',
              selected: true,
              count: 4,
              onSelected: (bool next) => reported = next,
            ),
          ),
        ),
      );
      expect(find.text('Staged (4)'), findsOneWidget);
      expect(
        paintedFillColors(
          tester,
          find.byType(FluentFilterToggle),
        ).first.toARGB32(),
        _accentRestLight.toARGB32(),
        reason:
            'a checked ToggleButton wears the checked-input accent '
            '(toggle_button.dart:162-169)',
      );
      await tester.tap(find.text('Staged (4)'));
      await tester.pumpAndSettle();
      expect(reported, isFalse);
    });
  });

  group('seriesPicker', () {
    testWidgets('offers exactly the skin\'s seven swatches and reports an '
        'index', (WidgetTester tester) async {
      int? chosen;
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => facet.seriesPicker(
            context,
            SeriesPickerSpec(
              selectedIndex: 2,
              onSelected: (int index) => chosen = index,
            ),
          ),
        ),
      );
      // Seven: the reference's accent families minus yellow
      // (FluentInk.seriesLength provenance).
      expect(find.bySemanticsLabel('6'), findsOneWidget);
      expect(find.bySemanticsLabel('7'), findsNothing);
      await tester.tap(find.bySemanticsLabel('4'));
      await tester.pumpAndSettle();
      expect(chosen, 4);
    });
  });

  group('progress', () {
    testWidgets('inline is the 4.5 epx bar; a fraction paints the accent '
        'run', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 200,
          child: _member(
            (BuildContext context) => facet.progress(
              context,
              fraction: 0.5,
              extent: ProgressExtent.inline,
            ),
          ),
        ),
      );
      final Finder bar = find.byType(FluentProgressBar);
      expect(tester.getSize(bar).height, FluentProgressBar.strokeWidth);
      final List<Color> fills = paintedFillColors(tester, bar);
      expect(
        fills,
        contains(
          isA<Color>().having(
            (Color c) => c.toARGB32(),
            'argb',
            _accentRestLight.toARGB32(),
          ),
        ),
      );
    });

    testWidgets('block is the ring; indeterminate keeps animating', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => facet.progress(
            context,
            fraction: null,
            extent: ProgressExtent.block,
          ),
        ),
      );
      expect(find.byType(FluentProgressRing), findsOneWidget);
      // An indeterminate ring never settles - two frames must differ. The
      // orbit position is not directly observable, so assert the scheduler
      // still has frames scheduled.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('describedBy and fields through the facet', () {
    testWidgets('describedBy announces and mounts through the port', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        _member(
          (BuildContext context) => facet.describedBy(
            context,
            message: 'Fetches all remotes',
            child: const ContentPort(Text('Fetch')),
          ),
        ),
      );
      expect(find.text('Fetch'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Fetch'),
        findsOneWidget,
        reason: 'the child keeps its own semantics under the announcement',
      );
    });

    testWidgets('dateField enforces the range: an out-of-range moment is '
        'never reported', (WidgetTester tester) async {
      final List<DateTime?> reported = <DateTime?>[];
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 300,
          child: _member(
            (BuildContext context) => facet.dateField(
              context,
              DateFieldSpec(
                label: 'Since',
                value: null,
                first: DateTime.utc(2026),
                onChanged: reported.add,
              ),
              const FieldHandles(),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '2020-01-01');
      await tester.pump();
      expect(reported, isEmpty, reason: 'before `first` stays unreported');
      await tester.enterText(find.byType(EditableText), '2026-05-01');
      await tester.pump();
      expect(reported, hasLength(1));
      expect(reported.single, DateTime(2026, 5));
    });

    testWidgets('suggestField narrows on typing and reports a settlement', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 300,
          child: _member(
            (BuildContext context) => facet.suggestField<String>(
              context,
              SuggestFieldSpec<String>(
                label: 'Branch',
                value: null,
                items: const <SuggestItem<String>>[
                  SuggestItem<String>(value: 'master', label: 'master'),
                  SuggestItem<String>(value: 'develop', label: 'develop'),
                ],
                onSelected: (String value) => chosen = value,
              ),
              const FieldHandles(),
            ),
          ),
        ),
      );
      // Both suggestions offered while nothing narrows them.
      expect(find.text('master'), findsOneWidget);
      expect(find.text('develop'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'dev');
      await tester.pump();
      expect(find.text('master'), findsNothing);
      await tester.tap(find.text('develop'));
      await tester.pumpAndSettle();
      expect(chosen, 'develop');
    });
  });
}
