/// What the naked text controls must still DO.
///
/// The blueprint drops appearance and keeps behaviour - `docs/SKIN-CONTRACT.md`
/// §3.1's "naked, not inert" - and text entry is where that distinction has
/// the most to lose. These tests pin the three things that would be invisible
/// under any skin's own rendering and catastrophic if they stopped working:
/// that a field registers with its enclosing `Form`, that Escape empties a
/// field with something in it and means what it always meant otherwise, and
/// that the in-field affordances act on the field rather than merely being
/// drawn beside it.
///
/// They go through `Fields`, not through the facet directly, because `Fields`
/// is the application's only text-entry API and the `FormField` host lives
/// inside it. A test that called `controls.textField` itself would prove the
/// blueprint renders and prove nothing about the seam.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart';

void main() {
  testWidgets('a field registers with its form, so validate() guards again', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FormState> form = GlobalKey<FormState>();
    await tester.pumpWidget(
      _underBlueprint(
        Form(
          key: form,
          child: Builder(
            builder: (BuildContext context) => Fields.text(
              context,
              FieldSpec(
                label: 'Name',
                validator: (String? value) =>
                    (value ?? '').isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      form.currentState!.validate(),
      isFalse,
      reason:
          'An empty required field must fail validation under every skin. '
          'macos_ui ships no FormField at all, which is why the contract '
          'package hosts one rather than leaving each skin to remember.',
    );
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'origin');
    await tester.pump();
    expect(form.currentState!.validate(), isTrue);
    expect(find.text('Required'), findsNothing);
  });

  testWidgets('Escape empties a field that has something in it', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: 'half-typed',
    );
    addTearDown(controller.dispose);
    int escapesThatGotPast = 0;

    await tester.pumpWidget(
      _underBlueprint(
        Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (DismissIntent _) {
                escapesThatGotPast++;
                return null;
              },
            ),
          },
          child: Builder(
            builder: (BuildContext context) => Fields.text(
              context,
              const FieldSpec(label: 'Filter'),
              handles: FieldHandles(controller: controller),
            ),
          ),
        ),
      ),
    );

    final BuildContext field = tester.element(find.byType(EditableText));
    Actions.invoke(field, const DismissIntent());
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(
      escapesThatGotPast,
      0,
      reason:
          'The first Escape emptied the field, so it must not also have '
          'reached the surface around it - that would close a dialog the '
          'user was only clearing a filter in.',
    );

    Actions.invoke(field, const DismissIntent());
    await tester.pump();
    expect(
      escapesThatGotPast,
      1,
      reason:
          'With nothing left to clear, Escape means what it always meant. '
          'Actions stops its walk at the first scope that MAPS the intent, '
          'enabled or not, so the field has to hand the intent on itself or '
          'the dialog stops closing.',
    );
  });

  testWidgets('a field that must not swallow Escape never does', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: 'DELETE',
    );
    addTearDown(controller.dispose);
    int escapesThatGotPast = 0;

    await tester.pumpWidget(
      _underBlueprint(
        Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (DismissIntent _) {
                escapesThatGotPast++;
                return null;
              },
            ),
          },
          child: Builder(
            builder: (BuildContext context) => Fields.text(
              context,
              const FieldSpec(label: 'Type the name', escapeClears: false),
              handles: FieldHandles(controller: controller),
            ),
          ),
        ),
      ),
    );

    Actions.invoke(
      tester.element(find.byType(EditableText)),
      const DismissIntent(),
    );
    await tester.pump();
    expect(controller.text, 'DELETE');
    expect(
      escapesThatGotPast,
      1,
      reason:
          'escapeClears is off for the confirmations where Escape must always '
          'mean leaving, and that is keyboard structure the application '
          'states and no skin may weaken.',
    );
  });

  testWidgets('the in-field affordances act on the field', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: 'secret',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _underBlueprint(
        Builder(
          builder: (BuildContext context) => Fields.text(
            context,
            const FieldSpec(
              label: 'Token',
              purpose: FieldPurpose.password,
              hint: 'ghp_...',
              helper: 'Needs repo scope',
              suffix: FieldRevealAffordance(),
            ),
            handles: FieldHandles(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('[password]'), findsOneWidget);
    expect(find.text('Needs repo scope'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );

    await tester.tap(find.text('[reveal]'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
    expect(find.text('[hide]'), findsOneWidget);
  });

  testWidgets('clearing a field tells the form as well as the application', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FormState> form = GlobalKey<FormState>();
    final TextEditingController controller = TextEditingController(
      text: 'origin',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _underBlueprint(
        Form(
          key: form,
          child: Builder(
            builder: (BuildContext context) => Fields.text(
              context,
              FieldSpec(
                label: 'Remote',
                suffix: const FieldClearAffordance(),
                validator: (String? value) =>
                    (value ?? '').isEmpty ? 'Required' : null,
              ),
              handles: FieldHandles(controller: controller),
            ),
          ),
        ),
      ),
    );

    expect(form.currentState!.validate(), isTrue);
    await tester.tap(find.text('[clear]'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(
      form.currentState!.validate(),
      isFalse,
      reason:
          'Text set programmatically - a clear affordance, an Escape, a '
          'generated value - has to reach the form too, or the original '
          'defect comes back in a new costume.',
    );
  });

  testWidgets('a date field reports only moments the application allows', (
    WidgetTester tester,
  ) async {
    final List<DateTime?> reported = <DateTime?>[];
    await tester.pumpWidget(
      _underBlueprint(
        Builder(
          builder: (BuildContext context) => Fields.date(
            context,
            DateFieldSpec(
              label: 'Since',
              value: DateTime.utc(2026, 1, 1),
              first: DateTime.utc(2026),
              last: DateTime.utc(2026, 12, 31),
              onChanged: reported.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('[yyyy-mm-dd]'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '2026-06-01');
    await tester.pump();
    expect(
      reported.single,
      DateTime(2026, 6, 1),
      reason:
          'A typed date with no zone suffix is a local one, which is what '
          'DateTime.parse means by it. The range is compared at the '
          'precision instead of as two instants, so a UTC boundary does not '
          'reject the boundary day.',
    );

    await tester.enterText(find.byType(EditableText), '2030-06-01');
    await tester.pump();
    expect(
      reported.length,
      1,
      reason: 'A moment outside the allowed range is never reported.',
    );
    expect(find.text('[after last]'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '');
    await tester.pump();
    expect(
      reported.last,
      isNull,
      reason:
          'An empty field is a real answer: onChanged takes a nullable '
          'moment, so naming no moment has to be expressible.',
    );
  });

  testWidgets('a suggest field narrows its own list in place', (
    WidgetTester tester,
  ) async {
    final List<String> chosen = <String>[];
    await tester.pumpWidget(
      _underBlueprint(
        Builder(
          builder: (BuildContext context) => Fields.suggest<String>(
            context,
            SuggestFieldSpec<String>(
              label: 'Branch',
              value: null,
              minQueryLength: 2,
              emptyLabel: 'No branches match',
              items: const <SuggestItem<String>>[
                SuggestItem<String>(value: 'main', label: 'main'),
                SuggestItem<String>(value: 'feature', label: 'feature/skins'),
              ],
              onSelected: chosen.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('[min 2]'), findsOneWidget);
    expect(
      find.text('main'),
      findsNothing,
      reason:
          'Nothing is suggested until the query is long enough to be '
          'worth suggesting from.',
    );

    await tester.enterText(find.byType(EditableText), 'fea');
    await tester.pump();
    expect(find.text('feature/skins'), findsOneWidget);
    expect(find.text('main'), findsNothing);

    await tester.tap(find.text('feature/skins'));
    expect(chosen.single, 'feature');
  });
}

/// A tree with the blueprint installed, and nothing else.
///
/// No `MaterialApp`, no theme, no localisations: the whole point of the
/// instrument is that it needs none of them. The reading direction and the ink
/// default text style are what `chrome.wrapRoot` installs in a running
/// application, stood in for here so that these tests measure the controls and
/// not the frame.
Widget _underBlueprint(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: DefaultTextStyle(
    style: const TextStyle(color: BlueprintInk.standardInk, fontSize: 14),
    child: SkinScope(
      skin: const BlueprintSkin(),
      request: const SkinRequest(
        brightness: Brightness.light,
        accentSeed: 0,
        textScale: 1,
        animationScale: 0,
        monoFamily: 'monospace',
        uiFamily: 'sans-serif',
      ),
      dialogKeyboardHost:
          (BuildContext context, DialogSpec spec, Widget surface) => surface,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);
