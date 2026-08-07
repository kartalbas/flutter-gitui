// The keyboard contract of #290, held against *every* dialog in the app
// rather than against the three that were checked by hand.
//
// The contract, from the project's CLAUDE.md: "Every dialog and screen is
// fully operable from the keyboard. A dialog autofocuses its first field,
// Tab/Shift+Tab walk the controls in reading order, Enter triggers the primary
// action from anywhere in the dialog, Esc cancels, and a list is navigated
// with the arrow keys and confirmed with Enter." Each clause is one test per
// dialog below.
//
// The population comes from dialog_population.dart, shared with
// base_dialog_flex_sweep_test.dart, and the census at the bottom of this file
// is what makes this a sweep rather than a long list: it enumerates every
// lib/ file that constructs a BaseDialog or a BaseViewerDialog and fails when
// one of them is neither covered by a case nor carried by a documented
// exclusion. A dialog therefore cannot be added to the app without this test
// noticing.
//
// How "the dialog claimed this key" is observed: the host app inserts a key
// recorder through MaterialApp.builder, which sits below the app's own
// Shortcuts and above the navigator. Key events travel from the focused node
// upwards, so a key only reaches the recorder after every focus node inside
// the dialog ignored it. An empty recorder means the dialog handled the key;
// a recorded key means it let the key escape to the app. That is a direct
// reading of the contract rather than a proxy for it, and it works the same
// for a dialog that closes on Enter and one that only validates.
//
// Two dialogs of the population are opened through their show function
// because their widget is private (create-branch, squash-commits), and three
// read a file from disk (the markdown, CSV and image viewers), for which the
// population writes real fixtures into a temp directory.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/components/base_dialog.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/components/base_viewer_dialog.dart';

import 'dialog_population.dart';

/// One opened dialog, plus what the keyboard did to it.
class _Session {
  /// Keys no focus node inside the dialog claimed.
  final List<LogicalKeyboardKey> escapedKeys = <LogicalKeyboardKey>[];

  /// What the dialog reported when it closed, and whether it closed at all.
  Object? result;
  bool hasClosed = false;
}

/// Opens [dialogCase] over the host page and asserts it opened cleanly, so a
/// keyboard failure below is never really a crash on open in disguise.
Future<_Session> _open(WidgetTester tester, DialogCase dialogCase) async {
  // A desktop-sized window, not the 800x600 the test binding defaults to.
  // Traversal order is computed from where the controls currently are, and a
  // dialog that has to scroll inside a window smaller than any real one moves
  // its own controls under Tab's scroll-into-view - so the order Tab walks
  // would be an artifact of the test window rather than what the app does.
  tester.view.physicalSize = const Size(1280, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final session = _Session();
  await tester.pumpWidget(
    dialogHostApp(
      dialogCase: dialogCase,
      onOpened: (result) {
        result.then((value) {
          session.result = value;
          session.hasClosed = true;
        });
      },
      appBuilder: (context, child) => Focus(
        // A pure observer: it never takes focus and is never a Tab stop, it
        // only sees what bubbled past the dialog.
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) session.escapedKeys.add(event.logicalKey);
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    ),
  );
  expect(
    await openDialogOfCase(tester),
    isNull,
    reason: '${dialogCase.name} threw while opening',
  );
  return session;
}

/// The dialog's root widget, whichever of the two components it is built on.
Finder _dialogRoot() {
  final base = find.byType(BaseDialog);
  return base.evaluate().isEmpty ? find.byType(BaseViewerDialog) : base;
}

bool _dialogIsOpen() => _dialogRoot().evaluate().isNotEmpty;

/// Whether primary focus currently sits anywhere inside the dialog - the
/// question behind both "autofocus landed somewhere useful" and "Tab did not
/// escape to the screen behind the barrier".
bool _focusIsInsideTheDialog(WidgetTester tester) {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  final dialog = tester.element(_dialogRoot());
  if (identical(focusContext, dialog)) return true;
  var inside = false;
  focusContext.visitAncestorElements((element) {
    if (!identical(element, dialog)) return true;
    inside = true;
    return false;
  });
  return inside;
}

/// The editable text field holding primary focus, if any.
EditableText? _focusedEditable() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  return focusContext?.findAncestorWidgetOfExactType<EditableText>();
}

/// Every field inside the dialog the user can type into, in tree order -
/// which for the dialogs' Column-based content is reading order.
///
/// Read-only editables are excluded on purpose: `SelectableText` is an
/// [EditableText] too, so the git output, the batch result and the changelog
/// would otherwise look like forms and be expected to autofocus a "field"
/// that takes no input.
Finder _inputFieldsInsideTheDialog() => find.descendant(
  of: _dialogRoot(),
  matching: find.byWidgetPredicate(
    (widget) => widget is EditableText && !widget.readOnly,
  ),
);

/// Whether the focused field will spend an Escape on clearing itself instead
/// of letting it reach the dialog.
///
/// This is `BaseTextField.escapeClears`, the deliberate "clear the text" rung
/// of the Escape ladder: correcting a typo must not throw the keyboard out of
/// the field, so a *filled* field consumes the first Escape and an empty one
/// lets it through. A dialog that opens with a prefilled field (a rename
/// dialog, a squash message) therefore needs two Escapes to leave, and the
/// sweep walks that ladder rather than declaring the dialog broken.
bool _focusedFieldWillSwallowEscape() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  final editable = focusContext.findAncestorWidgetOfExactType<EditableText>();
  if (editable == null || editable.controller.text.isEmpty) return false;
  final field = focusContext.findAncestorWidgetOfExactType<BaseTextField>();
  return field != null && field.escapeClears;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> _pressShiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// Runs the frames a closing dialog needs: the pop, its exit transition, and
/// the microtask that completes the route's future.
Future<void> _settleClose(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

/// Where each control sits in the dialog's element tree, depth first - the
/// order the dialog is written in, and therefore the order it reads in: title
/// row (with its close button), then the content top to bottom, then the
/// actions.
///
/// Reading order is checked against this rather than against focus-node
/// rectangles, because a rectangle is not the control: a text field's focus
/// node measures only its text line while the action button inside the same
/// field measures a full 48dp touch target that starts higher up, and a
/// scrollable dialog moves everything under Tab's own scroll-into-view. Both
/// make geometric comparison report an order the user never sees. Document
/// order has neither problem and is what a screen reader announces.
Map<Element, int> _readingOrderOfDialogControls(WidgetTester tester) {
  final order = <Element, int>{};
  void visit(Element element) {
    order[element] = order.length;
    element.visitChildren(visit);
  }

  visit(tester.element(_dialogRoot()));
  return order;
}

/// Walks the whole forward traversal cycle from wherever focus currently is,
/// asserting at every stop that focus is still inside the dialog. Returns the
/// nodes of one full cycle, in the order Tab visited them.
Future<List<FocusNode>> _walkForwardCycle(
  WidgetTester tester,
  String name,
) async {
  // The dialog's key host is focusable but deliberately not a Tab stop, so
  // when it holds the initial focus the cycle starts at the first real
  // control instead.
  var origin = FocusManager.instance.primaryFocus!;
  if (origin.skipTraversal) {
    await _press(tester, LogicalKeyboardKey.tab);
    expect(
      _focusIsInsideTheDialog(tester),
      isTrue,
      reason: 'Tab left $name and landed on the screen behind the barrier',
    );
    origin = FocusManager.instance.primaryFocus!;
  }

  final cycle = <FocusNode>[origin];
  // A generous ceiling: the widest dialog in the population has well under
  // this many controls, so overrunning it means Tab never came back.
  for (var step = 0; step < 60; step++) {
    await _press(tester, LogicalKeyboardKey.tab);
    expect(
      _focusIsInsideTheDialog(tester),
      isTrue,
      reason: 'Tab left $name and landed on the screen behind the barrier',
    );
    final node = FocusManager.instance.primaryFocus!;
    if (identical(node, origin)) return cycle;
    cycle.add(node);
  }
  fail(
    'Tab never returned to where it started in $name; it visited '
    '${cycle.length} nodes without wrapping',
  );
}

void main() {
  setUpAll(prepareDialogFixtures);
  tearDownAll(disposeDialogFixtures);

  for (final dialogCase in dialogPopulation()) {
    final name = dialogCase.name;

    // --- 1. Autofocus ------------------------------------------------------
    testWidgets('$name autofocuses something the keyboard can use', (
      tester,
    ) async {
      await _open(tester, dialogCase);

      expect(
        _focusIsInsideTheDialog(tester),
        isTrue,
        reason:
            '$name opened with focus outside itself, so the user has to '
            'reach for the mouse before the keyboard does anything',
      );

      final fields = _inputFieldsInsideTheDialog();
      if (fields.evaluate().isEmpty) return;

      // With a field present, focus belongs in the first one: opening a form
      // and having to Tab into it before typing is the same defect as not
      // being focused at all.
      final first = tester.widget<EditableText>(fields.first);
      expect(
        first.focusNode.hasPrimaryFocus,
        isTrue,
        reason:
            '$name has an editable field but did not put focus in the first '
            'one on open',
      );
    });

    // --- 2. Escape ---------------------------------------------------------
    testWidgets('$name treats Escape as cancel', (tester) async {
      final session = await _open(tester, dialogCase);

      if (_focusedFieldWillSwallowEscape()) {
        // The first rung of the Escape ladder: a filled field clears itself
        // and keeps focus, so the dialog is still there afterwards.
        await _press(tester, LogicalKeyboardKey.escape);
        expect(
          _dialogIsOpen(),
          isTrue,
          reason:
              '$name opens with a prefilled field, so its first Escape must '
              'clear the field rather than close the dialog',
        );
        expect(_focusedEditable()?.controller.text, isEmpty);
      }

      await _press(tester, LogicalKeyboardKey.escape);
      await _settleClose(tester);

      switch (dialogCase.escape) {
        case EscapeExpectation.cancels:
          expect(
            _dialogIsOpen(),
            isFalse,
            reason: 'Escape did not close $name',
          );
          expect(
            session.result,
            anyOf(isNull, isFalse),
            reason:
                'Escaping out of $name reported ${session.result}, which the '
                'caller will read as a confirmation - dismissing a dialog '
                'must always cancel',
          );
        case EscapeExpectation.withheldWhileTheOperationRuns:
          expect(
            _dialogIsOpen(),
            isTrue,
            reason:
                '$name declares itself non-dismissible while it runs, so '
                'Escape must not abandon the operation half-way',
          );
          expect(session.hasClosed, isFalse);
      }
    });

    // --- 3. Enter ----------------------------------------------------------
    testWidgets('$name handles Enter as ${dialogCase.enter.name}', (
      tester,
    ) async {
      final session = await _open(tester, dialogCase);
      session.escapedKeys.clear();

      switch (dialogCase.enter) {
        case EnterExpectation.claimedByTheDialog:
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            session.escapedKeys,
            isNot(contains(LogicalKeyboardKey.enter)),
            reason:
                'Enter escaped $name unhandled, so its primary action cannot '
                'be reached from the keyboard where focus happened to be',
          );

        case EnterExpectation.ownedByAMultilineEditable:
          // Half one: the exception only applies while a multiline editable
          // really holds focus, so a dialog that merely forgot its onSubmit
          // cannot claim it.
          final editable = _focusedEditable();
          expect(
            editable,
            isNotNull,
            reason:
                '$name claims the multiline exception but opens with focus '
                'outside any editable',
          );
          expect(
            editable!.maxLines,
            isNot(1),
            reason:
                '$name claims the multiline exception but its focused field '
                'is single-line, where Enter has no newline to insert',
          );
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            session.escapedKeys,
            contains(LogicalKeyboardKey.enter),
            reason:
                'Enter inside the multiline field of $name was swallowed by '
                'the dialog, so the field cannot be given a second line',
          );
          expect(_dialogIsOpen(), isTrue);
          expect(session.hasClosed, isFalse);

          // Half two: the dialog does arm Enter - it just leaves it to the
          // field. Once focus moves off the field, Enter submits again.
          for (var step = 0; step < 10 && _focusedEditable() != null; step++) {
            await _press(tester, LogicalKeyboardKey.tab);
          }
          expect(
            _focusedEditable(),
            isNull,
            reason: 'could not move focus off the multiline field of $name',
          );
          session.escapedKeys.clear();
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            session.escapedKeys,
            isNot(contains(LogicalKeyboardKey.enter)),
            reason:
                '$name left Enter unhandled outside its multiline field too, '
                'so its primary action has no keyboard path at all',
          );

        case EnterExpectation.withheldSoEnterCannotDestroy:
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            session.escapedKeys,
            contains(LogicalKeyboardKey.enter),
            reason:
                '$name consumed Enter, and a destructive prompt must not: '
                'the key repeat of the keystroke that opened it would wave '
                'the loss through',
          );
          expect(
            _dialogIsOpen(),
            isTrue,
            reason: 'Enter closed the destructive prompt $name',
          );
          expect(
            session.result,
            isNot(isTrue),
            reason: 'Enter confirmed the destructive action of $name',
          );

        case EnterExpectation.gatedByTheConfirmationToken:
          // Enter is armed here (unlike the permanent tier), but runs through
          // the type-to-confirm check, so it does nothing until the token has
          // actually been retyped.
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            _dialogIsOpen(),
            isTrue,
            reason: 'Enter confirmed $name before the token was typed',
          );
          expect(session.hasClosed, isFalse);

          await tester.enterText(
            _inputFieldsInsideTheDialog().first,
            'origin/main',
          );
          await tester.pump();
          await _press(tester, LogicalKeyboardKey.enter);
          await _settleClose(tester);
          expect(
            session.result,
            isTrue,
            reason:
                'with the token retyped, Enter must confirm $name - a gate '
                'that cannot be passed from the keyboard is not keyboard '
                'operable',
          );

        case EnterExpectation.noPrimaryAction:
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            session.escapedKeys,
            contains(LogicalKeyboardKey.enter),
            reason:
                '$name has no single primary action, so Enter must not pick '
                'one of its actions for the user',
          );
          expect(_dialogIsOpen(), isTrue);

        case EnterExpectation.inertUntilSomethingIsChosen:
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            session.escapedKeys,
            contains(LogicalKeyboardKey.enter),
            reason:
                '$name opens with nothing chosen, so Enter must not run its '
                'primary action on an empty selection',
          );
          expect(
            _dialogIsOpen(),
            isTrue,
            reason: 'Enter closed $name before anything was chosen',
          );
          expect(session.hasClosed, isFalse);
      }
    });

    // --- 4. Tab / Shift+Tab ------------------------------------------------
    testWidgets('$name keeps Tab and Shift+Tab inside itself', (tester) async {
      await _open(tester, dialogCase);

      final cycle = await _walkForwardCycle(tester, name);

      // Reading order. The cycle is a ring, so the check is not "every step
      // reads forwards" - one step has to be the wrap from the last control
      // back to the first - but "at most one step reads backwards".
      if (cycle.length > 1) {
        final reading = _readingOrderOfDialogControls(tester);
        final positions = [
          for (final node in cycle) reading[node.context!] ?? -1,
        ];
        expect(
          positions,
          isNot(contains(-1)),
          reason: 'a control Tab visited in $name is not in its element tree',
        );
        final backwardSteps = [
          for (var i = 0; i < positions.length; i++)
            if (positions[i] > positions[(i + 1) % positions.length])
              '${positions[i]} -> ${positions[(i + 1) % positions.length]}',
        ];
        expect(
          backwardSteps,
          hasLength(lessThanOrEqualTo(1)),
          reason:
              'Tab does not walk $name in reading order: a ring of controls '
              'may step backwards exactly once, where it wraps from the last '
              'control to the first, but this one steps back at '
              '$backwardSteps of the document positions $positions',
        );
      }

      // Shift+Tab is the same ring backwards: one step back from where the
      // walk ended must land on the control before it.
      final beforeBack = FocusManager.instance.primaryFocus;
      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusIsInsideTheDialog(tester), isTrue);
      await _pressShiftTab(tester);
      expect(
        _focusIsInsideTheDialog(tester),
        isTrue,
        reason:
            'Shift+Tab left $name and landed on the screen behind the barrier',
      );
      expect(
        FocusManager.instance.primaryFocus,
        same(beforeBack),
        reason: 'Shift+Tab did not undo Tab in $name',
      );

      // And it wraps backwards too rather than falling out of the dialog.
      for (var step = 0; step < cycle.length + 2; step++) {
        await _pressShiftTab(tester);
        expect(
          _focusIsInsideTheDialog(tester),
          isTrue,
          reason:
              'Shift+Tab left $name and landed on the screen behind the '
              'barrier',
        );
      }
    });
  }

  // --- The census ----------------------------------------------------------
  //
  // What makes the above a sweep instead of a long list: the population is
  // checked against the source tree, so a dialog cannot be added to the app
  // without either joining the population or being excluded on the record.

  group('the dialog population', () {
    test('covers every dialog source file under lib/', () {
      final covered = {for (final c in dialogPopulation()) c.source};
      final uncovered = [
        for (final file in dialogSourceFilesUnderLib())
          if (!covered.contains(file) &&
              !dialogSourceExclusions.containsKey(file))
            file,
      ];
      expect(
        uncovered,
        isEmpty,
        reason:
            'These files build a dialog that no sweep ever opens. Add a '
            'DialogCase for each in test/shared/dialogs/dialog_population.dart '
            '(which covers it in the layout sweep and the keyboard sweep at '
            'once), or, if it genuinely cannot be pumped, add it to '
            'dialogSourceExclusions with the reason.',
      );
    });

    test('names only files that really build a dialog', () {
      final census = dialogSourceFilesUnderLib().toSet();
      final phantom = [
        for (final c in dialogPopulation())
          if (!census.contains(c.source)) '${c.name} -> ${c.source}',
      ];
      expect(
        phantom,
        isEmpty,
        reason:
            'These cases point at a file that no longer constructs a dialog, '
            'so the case and the census have drifted apart.',
      );
    });

    test('carries no exclusion that has outlived its reason', () {
      final census = dialogSourceFilesUnderLib().toSet();
      final stale = [
        for (final file in dialogSourceExclusions.keys)
          if (!census.contains(file)) file,
      ];
      expect(
        stale,
        isEmpty,
        reason:
            'These files are excluded from the population but no longer '
            'build a dialog at all. Drop the exclusion so the next reader is '
            'not told about a problem that is gone.',
      );
    });

    test('lets no dialog hide behind the inline-in-a-surface exclusion', () {
      // The inline exclusion covers dialogs written inside a screen method,
      // which are only reachable by pumping that whole screen and are covered
      // by that screen's own keyboard test. A file under a dialogs/ directory
      // is by definition not that, so it may never take this exclusion - or a
      // new dialog could be kept out of the sweep by filing it in the wrong
      // drawer.
      final misfiled = [
        for (final entry in dialogSourceExclusions.entries)
          if (entry.value.kind == DialogExclusionKind.inlineInASurface &&
              entry.key.contains('/dialogs/'))
            entry.key,
      ];
      expect(misfiled, isEmpty);
    });

    test('names each case exactly once', () {
      final names = <String>{};
      final duplicates = [
        for (final c in dialogPopulation())
          if (!names.add(c.name)) c.name,
      ];
      expect(
        duplicates,
        isEmpty,
        reason: 'Two cases with the same name produce two identical tests.',
      );
    });
  });
}
