// The RED criterion, answered with running code.
//
// RED fires, among other things, "if the skins cannot coexist in one running
// app". These tests pump the lab - ONE MaterialApp root, ONE Navigator, three
// SkinScopes alive simultaneously - and assert that each skin's canonical
// widgets actually appear, and that each skin's overlay opens through that one
// shared Navigator.
//
// They also pin the four hard findings, so a later change that "fixes" one
// without changing the API fails here instead of quietly invalidating the
// report.
library;

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skin_lab/frozen/frozen_base_button.dart';
import 'package:skin_lab/frozen/frozen_base_dialog.dart';
import 'package:skin_lab/frozen/frozen_base_filter_chip.dart';
import 'package:skin_lab/frozen/frozen_base_text_field.dart';
import 'package:skin_lab/lab_app.dart';
import 'package:skin_lab/skin.dart';
import 'package:skin_lab/skins/cupertino_skin.dart';
import 'package:skin_lab/skins/fluent_skin.dart';
import 'package:skin_lab/skins/material_skin.dart';

void main() {
  group('three skins coexist in one running app', () {
    testWidgets('every skin renders its own canonical widgets side by side', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const SkinLabApp());
      await tester.pump();

      // Material's canonical button family.
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.byType(OutlinedButton), findsWidgets);
      // Cupertino's.
      expect(find.byType(CupertinoButton), findsWidgets);
      // Fluent's. fluent.FilledButton is a distinct class from Material's.
      expect(find.byType(fluent.Button), findsWidgets);

      // The three pattern-level answers to single choice, all alive at once.
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
        findsOneWidget,
      );
      expect(find.byType(fluent.RadioButton<int>), findsWidgets);

      // The three shells.
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(CupertinoListSection), findsOneWidget);
      expect(find.byType(fluent.NavigationView), findsOneWidget);
    });

    testWidgets('each skin opens its own dialog through the shared Navigator', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final (int index, Type expected) in <(int, Type)>[
        (0, AlertDialog),
        (1, CupertinoAlertDialog),
        (2, fluent.ContentDialog),
      ]) {
        await tester.pumpWidget(const SkinLabApp());
        await tester.pump();

        final Finder opener = find.text('Open dialog');
        expect(opener, findsNWidgets(3));
        await tester.ensureVisible(opener.at(index));
        await tester.pump();
        await tester.tap(opener.at(index));
        // Not pumpAndSettle: the lab renders a loading button in every column,
        // and CircularProgressIndicator / CupertinoActivityIndicator /
        // fluent.ProgressRing all animate forever, so nothing ever settles.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byType(expected),
          findsOneWidget,
          reason:
              'skin ${kSkins[index].id} must open its own canonical dialog '
              'through the single shared Navigator',
        );

        // Close it again so the next iteration starts clean.
        await tester.tap(find.text('Cancel').first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    });
  });

  group('pinned findings', () {
    testWidgets(
      'FINDING dialog.actions: no skin can reorder an opaque List<Widget>',
      (tester) async {
        // Fluent 2 puts the affirmative action on the LEFT. The Fluent skin
        // receives `actions` as List<Widget> and can therefore only preserve
        // call order. This test pins the consequence: the rendered order under
        // Fluent is [Cancel, Delete] - Material's order, not Fluent's.
        await _pumpUnder(tester, const FluentSkin(), (BuildContext context) {
          return FrozenBaseButton(
            label: 'open',
            onPressed: () => FrozenBaseDialog.show<void>(
              context: context,
              dialog: FrozenBaseDialog(
                title: 'Delete?',
                content: const Text('x'),
                actions: <Widget>[
                  FrozenBaseButton(label: 'Cancel', onPressed: () {}),
                  FrozenBaseButton(label: 'Delete', onPressed: () {}),
                ],
              ),
            ),
          );
        });

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final double cancelX = tester.getCenter(find.text('Cancel')).dx;
        final double deleteX = tester.getCenter(find.text('Delete')).dx;
        expect(
          cancelX < deleteX,
          isTrue,
          reason:
              'Fluent 2 requires the affirmative action on the LEFT. It is on '
              'the right because List<Widget> gives the skin no way to tell '
              'which action is affirmative. If this ever flips, the API was '
              'changed and the finding must be re-measured.',
        );
      },
    );

    testWidgets('FINDING dialog.maxWidth: Cupertino pins the alert at 270 pt', (
      tester,
    ) async {
      await _pumpUnder(tester, const CupertinoSkin(), (BuildContext context) {
        return FrozenBaseButton(
          label: 'open',
          onPressed: () => FrozenBaseDialog.show<void>(
            context: context,
            dialog: const FrozenBaseDialog(
              title: 'Wide',
              content: Text('x'),
              // The app default, and what 15 call sites pass a value for.
              maxWidth: 650,
            ),
          ),
        );
      });

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // CupertinoPopupSurface is the public widget that sits directly inside
      // the hard-coded SizedBox(width: _kCupertinoDialogWidth) in
      // cupertino/dialog.dart:458-463, so its width IS the alert's width.
      final double width = tester
          .getSize(find.byType(CupertinoPopupSurface))
          .width;
      expect(
        width,
        lessThan(300),
        reason:
            'CupertinoAlertDialog is hard-pinned to _kCupertinoDialogWidth = '
            '270 in cupertino/dialog.dart. maxWidth: 650 has no effect and no '
            'parameter to bind to.',
      );
    });

    testWidgets(
      'FINDING textField: Cupertino has no suffix slot on the form row',
      (tester) async {
        // showClearButton, showPasswordToggle, suffixIcon, onSuffixTap and
        // suffixTooltip are five public parameters that all target one missing
        // slot. Under Cupertino none of them produces anything.
        await _pumpUnder(tester, const CupertinoSkin(), (BuildContext context) {
          return const Form(
            child: FrozenBaseTextField(
              initialValue: 'some text',
              showClearButton: true,
              suffixTooltip: 'Clear',
            ),
          );
        });
        await tester.pump();

        expect(find.byType(CupertinoTextFormFieldRow), findsOneWidget);
        expect(
          find.byIcon(CupertinoIcons.clear),
          findsNothing,
          reason:
              'CupertinoTextFormFieldRow has prefix but no suffix. The clear '
              'affordance cannot be delegated - only hand-painted, which this '
              'spike refuses to do.',
        );
      },
    );

    testWidgets('FINDING chips: the skinnable unit is the pattern, not the '
        'widget', (tester) async {
      // One choice chip has no counterpart in either language. The GROUP maps
      // 1:1 onto CupertinoSlidingSegmentedControl. Same information, different
      // unit - this is the whole argument for a pattern-level seam.
      await _pumpUnder(tester, const CupertinoSkin(), (BuildContext context) {
        return const Column(
          children: <Widget>[
            FrozenBaseChoiceChip(
              label: 'orphan chip',
              selected: true,
              onSelected: _noop,
            ),
            FrozenChoiceChipGroup(
              options: <ChoiceOption>[
                ChoiceOption(label: 'a'),
                ChoiceOption(label: 'b'),
              ],
              selectedIndex: 0,
              onSelected: _noopInt,
            ),
          ],
        );
      });
      await tester.pump();

      // The single chip fell through to Material: no dispatch line exists for
      // it, because a skin has nothing to return.
      expect(find.byType(FilterChip), findsOneWidget);
      // The group delegated to the canonical Cupertino control.
      expect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
        findsOneWidget,
      );
    });

    test(
      'FINDING contextMenuItems: PopupMenuEntry is not a Fluent menu item',
      () {
        // The static half of Probe A is recorded in probe/probe_a_context_menu
        // .dart.txt (it cannot live in analysable code). This is the part that
        // can be asserted at runtime: the two hierarchies are disjoint.
        const PopupMenuEntry<dynamic> entry = PopupMenuItem<dynamic>(
          child: Text('Edit'),
        );
        expect(entry, isNot(isA<fluent.MenuFlyoutItemBase>()));
        expect(
          fluent.MenuFlyoutItem(text: const Text('Edit'), onPressed: null),
          isNot(isA<Widget>()),
          reason:
              'MenuFlyoutItemBase is not even a Widget, so no adapter, cast or '
              'covariance gets from List<PopupMenuEntry> to List<MenuFlyoutItem'
              'Base>.',
        );
      },
    );
  });
}

void _noop(bool _) {}
void _noopInt(int _) {}

/// Pumps [builder] under [skin] inside one MaterialApp root, with every
/// registered skin's localization delegates installed - the same arrangement
/// the lab uses.
Future<void> _pumpUnder(
  WidgetTester tester,
  Skin skin,
  WidgetBuilder builder,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kAllSkinDelegates,
      home: Scaffold(
        body: SkinScope(
          skin: skin,
          child: Builder(
            builder: (BuildContext context) =>
                skin.wrapTheme(context, builder(context)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Referenced so the Material skin is exercised by the imports above too.
// ignore: unused_element
const Skin _materialSkin = MaterialSkin();
