// The tags screen as the keyboard drives it (#290): the tag list is one focus
// stop whose roving highlight starts on the newest tag, where the arrows and
// Home/End move it and Enter opens and closes that tag's details; the search
// field filters without ever letting a keystroke reach the list, hands
// ArrowUp/Down and Enter to it while the caret stays put, and stops offering
// anything to activate once nothing matches; the multi-select mode is entered,
// driven and left without touching the mouse; and Escape walks the ladder —
// clear the search, leave the mode, then nothing at all.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/features/tags/tags_screen.dart';
import 'package:flutter_gitui/shared/widgets/standard_app_bar.dart';

import '../../skin/pump_under_skin.dart';

/// The app bar's own overflow anchor, addressed by its place rather than by
/// its name. The name used to be unique on this screen only by accident: the
/// tag rows' menus were Material `PopupMenuButton`s wearing the framework's
/// default "Show menu" tooltip, so 'More actions' matched exactly the app
/// bar. Now that the rows' menus are `Overlays.anchor`s too, each row trigger
/// carries the app's own overflow name ('More actions' — the vocabulary the
/// repository cards already used), and only the scope to [StandardAppBar]
/// says which overflow the test means.
final Finder _appBarMoreActions = find.descendant(
  of: find.byType(StandardAppBar),
  matching: find.byTooltip('More actions'),
);

GitTag _tag(String name, String hash, DateTime date) => GitTag(
  name: name,
  commitHash: hash,
  type: GitTagType.lightweight,
  commitMessage: 'commit for $name',
  date: date,
);

/// The three tags the screen is driven over, in the order the default sort
/// (newest first) puts them: v2.0.0, v1.1.0, v1.0.0. Distinct dates make that
/// order the fixture's, not the sort's tie-breaking, and the leading run of
/// each commit hash identifies exactly one row.
final List<GitTag> _tags = [
  _tag('v1.0.0', 'aaaaaaa1111111', DateTime(2026, 1, 1)),
  _tag('v1.1.0', 'bbbbbbb2222222', DateTime(2026, 2, 1)),
  _tag('v2.0.0', 'ccccccc3333333', DateTime(2026, 3, 1)),
];

/// The commit row of an opened tag. A tag's short hash is printed in its
/// details and nowhere else, so this reads exactly which row stands open.
Finder _detailsOf(String shortHash) => find.text(shortHash);

/// The label every opened tag's commit row carries, so an assertion can say
/// "no tag is open" without naming one.
final Finder _anyOpenDetails = find.text('Commit:');

/// Whether the keyboard currently sits inside the widget [finder] matches.
bool _focusIsInside(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final targets = finder.evaluate().toSet();
  if (targets.contains(focused)) return true;
  var found = false;
  focused.visitAncestorElements((element) {
    if (targets.contains(element)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Whether the tag list's own node holds the keyboard. The collection is a
/// single Tab stop owned by the shared `ItemNavigationController`, and that
/// node carries the controller's debug label; matching the list's subtree
/// instead would also accept a row inside it, which is a different stop.
bool _tagListHasFocus() =>
    FocusManager.instance.primaryFocus?.debugLabel ==
    'ItemNavigationController';

/// Walks the Tab ring until [arrived] reports the keyboard is where the test
/// needs it. The walk is part of the assertion — everything driven here has to
/// be Tab-reachable — and the bound turns an unreachable control into a named
/// failure instead of a hang.
Future<void> _tabUntil(
  WidgetTester tester,
  bool Function() arrived, {
  required String target,
}) async {
  for (var press = 0; press < 40; press++) {
    if (arrived()) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  fail('Tab never reached $target');
}

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    // A desktop-sized window, so three tag cards and the details of the one
    // that is open all fit: a row scrolled out of the build window would fail
    // an assertion about text that the user can in fact see.
    await pumpUnderSkin(
      tester,
      home: const TagsScreen(),
      surface: const Size(1600, 1200),
      overrides: [
        currentRepositoryPathProvider.overrideWith((ref) => '/repo'),
        tagsProvider.overrideWith((ref) async => _tags),
        localOnlyTagsProvider.overrideWith((ref) async => <String>{}),
        remoteOnlyTagsProvider.overrideWith((ref) async => <String>{}),
        remoteNamesProvider.overrideWith((ref) async => const <String>[]),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the arrows and Home/End move the highlight and Enter opens the '
      'tag under it', (tester) async {
    await pumpScreen(tester);
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(_anyOpenDetails, findsNothing);

    // The list holds initial focus with the newest tag highlighted; Enter
    // opens exactly that tag's details.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('ccccccc'), findsOneWidget);

    // Enter again closes them, so the key toggles the row it is on.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_anyOpenDetails, findsNothing);

    // Two ArrowDowns walk to the oldest tag and Enter follows the highlight
    // there, not to the row it started on.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('aaaaaaa'), findsOneWidget);
    expect(_detailsOf('ccccccc'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // ArrowUp walks back one row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('bbbbbbb'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // End jumps to the last row from anywhere in the list.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('aaaaaaa'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Home jumps back to the first.
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('ccccccc'), findsOneWidget);
    expect(_detailsOf('aaaaaaa'), findsNothing);
  });

  testWidgets('typing filters the list without driving it, and ArrowDown hands '
      'off while the caret stays in the field', (tester) async {
    await pumpScreen(tester);

    // Typing is how a keyboard user filters, and it must leave the list
    // alone: two tags remain and nothing was activated on the way.
    await tester.enterText(find.byType(TextField), 'v1');
    await tester.pumpAndSettle();
    expect(find.text('v2.0.0'), findsNothing);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(_anyOpenDetails, findsNothing);

    // Letters and Space belong to the focused field, so they must not reach
    // the list as navigation or as an activation.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
    await tester.sendKeyEvent(LogicalKeyboardKey.space, character: ' ');
    await tester.pumpAndSettle();
    expect(_anyOpenDetails, findsNothing);

    // Home and End move the caret inside the field; they must not jump the
    // list's highlight to the last row behind the user's back.
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();

    // So the highlight is still on the first of the two filtered rows, and
    // Enter typed in the field opens that one.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('bbbbbbb'), findsOneWidget);
    expect(_detailsOf('aaaaaaa'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // ArrowDown is the one navigation key the field hands to the list, and
    // the caret stays where it was: typing goes on afterwards.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('aaaaaaa'), findsOneWidget);
    expect(_detailsOf('bbbbbbb'), findsNothing);
  });

  testWidgets(
    'a search that matches nothing leaves Enter nothing to activate',
    (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No tags match your search'), findsOneWidget);

      // The list the highlight indexed into is gone with the last match, so
      // Enter must resolve to no tag at all — not to whichever tag the index
      // used to name, which would open a row hidden behind the empty state.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_anyOpenDetails, findsNothing);

      // Escape in the filled field clears it — the field's own rung of the
      // ladder — and the tags come back with nothing opened behind the user's
      // back.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('v2.0.0'), findsOneWidget);
      expect(_anyOpenDetails, findsNothing);
    },
  );

  testWidgets('Escape clears the search from the list too, and a second '
      'Escape is dead', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'v1');
    await tester.pumpAndSettle();
    expect(find.text('v2.0.0'), findsNothing);

    // Walk the keyboard out of the field and onto the list, where a user who
    // filtered and then started arrowing actually is. Escape has to reach the
    // filter from there as well, or the only way back to the full list is to
    // tab into the field and empty it by hand.
    await _tabUntil(tester, _tagListHasFocus, target: 'the tag list');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'v1'), findsNothing);

    // Nothing is left to dismiss, so Escape changes nothing and breaks
    // nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selection mode is entered, driven and left from the '
      'keyboard alone', (tester) async {
    await pumpScreen(tester);

    // The mode lives behind the app bar's overflow menu, so the keyboard has
    // to reach that menu, open it and pick from it. The finder is scoped to
    // the app bar: the walk passes the tag rows' own 'More actions' anchors
    // on the way, and stopping at one of those would open a row menu with no
    // Select Tags in it.
    await _tabUntil(
      tester,
      () => _focusIsInside(_appBarMoreActions),
      target: "the app bar's overflow menu",
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Select Tags'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit Selection'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);

    // The app bar the menu lived in was replaced by the mode's own, so the
    // control that had focus is gone; the keyboard must land back on the list
    // instead of nowhere. Enter checks the highlighted tag straight away.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // The highlight roves in the mode as well, so a second tag is checked
    // without ever leaving the keyboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    // Enter toggles, so it also unchecks the tag it is on.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Escape leaves the mode and the ordinary app bar returns.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit Selection'), findsNothing);
    expect(_appBarMoreActions, findsOneWidget);

    // And the keyboard is still on the list afterwards: Enter opens the
    // details of the tag the highlight ended on.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_detailsOf('bbbbbbb'), findsOneWidget);
  });
}
