// The no-shadowing contract behind every app-level binding of an unmodified
// key: focusedEditableOwnsKey must claim exactly the keys the focused editable
// interprets — character keys, Backspace/Delete, ArrowLeft/Right, Home/End in
// any field; ArrowUp/Down and Enter only in a multiline field — and nothing
// when focus is not in an editable at all. A wrong `true` makes navigation go
// dead next to a field; a wrong `false` types over the user's text.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/utils/keyboard_guards.dart';
import '../../skin/pump_under_skin.dart';

KeyEvent _keyDown(LogicalKeyboardKey key, {String? character}) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  character: character,
  timeStamp: Duration.zero,
);

/// One row of the matrix: a key event and where the editable owns it.
class _GuardCase {
  const _GuardCase(
    this.description,
    this.event, {
    required this.ownedInSingleLine,
    required this.ownedInMultiline,
  });

  final String description;
  final KeyEvent event;
  final bool ownedInSingleLine;
  final bool ownedInMultiline;
}

final List<_GuardCase> _matrix = [
  _GuardCase(
    'a letter',
    _keyDown(LogicalKeyboardKey.keyA, character: 'a'),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'space (it types a space)',
    _keyDown(LogicalKeyboardKey.space, character: ' '),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'Backspace',
    _keyDown(LogicalKeyboardKey.backspace),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'Delete',
    _keyDown(LogicalKeyboardKey.delete),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'ArrowLeft (caret movement)',
    _keyDown(LogicalKeyboardKey.arrowLeft),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'ArrowRight (caret movement)',
    _keyDown(LogicalKeyboardKey.arrowRight),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'Home (jump within the line)',
    _keyDown(LogicalKeyboardKey.home),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'End (jump within the line)',
    _keyDown(LogicalKeyboardKey.end),
    ownedInSingleLine: true,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'ArrowUp (only a multiline field has a line above)',
    _keyDown(LogicalKeyboardKey.arrowUp),
    ownedInSingleLine: false,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'ArrowDown (only a multiline field has a line below)',
    _keyDown(LogicalKeyboardKey.arrowDown),
    ownedInSingleLine: false,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'Enter (only a multiline field inserts a newline)',
    _keyDown(LogicalKeyboardKey.enter),
    ownedInSingleLine: false,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'Enter as the platform reports it, with a control character payload',
    _keyDown(LogicalKeyboardKey.enter, character: '\r'),
    ownedInSingleLine: false,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'numpad Enter',
    _keyDown(LogicalKeyboardKey.numpadEnter),
    ownedInSingleLine: false,
    ownedInMultiline: true,
  ),
  _GuardCase(
    'Escape (an editable never interprets it)',
    _keyDown(LogicalKeyboardKey.escape),
    ownedInSingleLine: false,
    ownedInMultiline: false,
  ),
  _GuardCase(
    'Tab, despite its control character payload (it is traversal)',
    _keyDown(LogicalKeyboardKey.tab, character: '\t'),
    ownedInSingleLine: false,
    ownedInMultiline: false,
  ),
  _GuardCase(
    'F2 (a function key is free for bindings)',
    _keyDown(LogicalKeyboardKey.f2),
    ownedInSingleLine: false,
    ownedInMultiline: false,
  ),
];

void main() {
  final singleLineFocus = FocusNode(debugLabel: 'singleLine');
  final multilineFocus = FocusNode(debugLabel: 'multiline');
  final plainFocus = FocusNode(debugLabel: 'plain');

  Future<void> pumpFields(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),

        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              BaseTextField(focusNode: singleLineFocus),
              BaseTextField(focusNode: multilineFocus, maxLines: 3),
              Focus(focusNode: plainFocus, child: const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('the matrix holds while a single-line field has focus', (
    tester,
  ) async {
    await pumpFields(tester);
    singleLineFocus.requestFocus();
    await tester.pump();

    for (final guardCase in _matrix) {
      expect(
        focusedEditableOwnsKey(guardCase.event),
        guardCase.ownedInSingleLine,
        reason: 'single-line field, ${guardCase.description}',
      );
    }
  });

  testWidgets('the matrix holds while a multiline field has focus', (
    tester,
  ) async {
    await pumpFields(tester);
    multilineFocus.requestFocus();
    await tester.pump();

    for (final guardCase in _matrix) {
      expect(
        focusedEditableOwnsKey(guardCase.event),
        guardCase.ownedInMultiline,
        reason: 'multiline field, ${guardCase.description}',
      );
    }
  });

  testWidgets('no key is owned while focus is outside any editable', (
    tester,
  ) async {
    await pumpFields(tester);
    plainFocus.requestFocus();
    await tester.pump();
    expect(plainFocus.hasPrimaryFocus, isTrue);

    for (final guardCase in _matrix) {
      expect(
        focusedEditableOwnsKey(guardCase.event),
        isFalse,
        reason: 'non-editable focus, ${guardCase.description}',
      );
    }
  });
}
