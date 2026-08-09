// The app's single create-tag dialog serves both entry points (#354): the
// command palette opens it without a target (HEAD), the history screen
// preselects a commit hash. Its validators gate submission (#360): an empty
// tag name, a tag name with spaces, or a missing annotated-tag message each
// show their error and keep the dialog open — for the dialog-wide Enter path
// and the Create Tag button alike — and nothing reaches GitService; valid
// input still creates the tag and closes. The keyboard contract holds: the
// tag name field autofocuses, Enter submits from it, Esc cancels.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/shared/components/base_dropdown.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/dialogs/create_tag_dialog.dart';
import '../../skin/pump_under_skin.dart';

/// Records tag creations instead of running git, so the tests can assert an
/// invalid form never reaches the service and a valid one targets the right
/// revision.
class _RecordingGitService extends GitService {
  _RecordingGitService() : super('.');

  final annotated = <(String name, String message, String? commit)>[];
  final lightweight = <(String name, String? commit)>[];

  @override
  Future<Result<void>> createAnnotatedTag(
    String tagName, {
    required String message,
    String? commitHash,
  }) async {
    annotated.add((tagName, message, commitHash));
    return const Success(null);
  }

  @override
  Future<Result<void>> createLightweightTag(
    String tagName, {
    String? commitHash,
  }) async {
    lightweight.add((tagName, commitHash));
    return const Success(null);
  }
}

GitCommit _commit(String hash, String subject) => GitCommit(
  hash: hash,
  shortHash: hash.substring(0, 7),
  author: 'author',
  authorEmail: 'author@example.com',
  authorDate: DateTime(2026),
  committer: 'author',
  committerEmail: 'author@example.com',
  committerDate: DateTime(2026),
  subject: subject,
  body: '',
  parents: const [],
  refs: const [],
);

Future<void> _openDialog(
  WidgetTester tester,
  _RecordingGitService gitService,
  void Function(bool?) onClosed, {
  String? initialCommit,
  List<GitCommit> commits = const [],
  List<GitTag> tags = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gitServiceProvider.overrideWith((ref) => gitService),
        commitHistoryProvider.overrideWith((ref) async => commits),
        tagsProvider.overrideWith((ref) async => tags),
      ],
      child: MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),

        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => BaseButton(
              label: 'open',
              onPressed: () {
                showCreateTagDialog(
                  context,
                  initialCommit: initialCommit,
                ).then(onClosed);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The tag name field is the first BaseTextField; the annotated message
/// field follows it (annotated is on by default).
Finder get _nameField => find.byType(BaseTextField).first;
Finder get _messageField => find.byType(BaseTextField).last;

/// The dialog's Create Tag ACTION. The dialog's title says the same two
/// words, so the bare label is ambiguous; the action row is rendered after
/// the title in the surface's document order, so the last match is the
/// button the skin drew for the affirmative `DialogAction`.
Finder get _createTagAction => find.text('Create Tag').last;

void main() {
  testWidgets('the tag name field autofocuses and Esc cancels', (tester) async {
    final gitService = _RecordingGitService();
    var closed = false;
    bool? result;
    await _openDialog(tester, gitService, (value) {
      closed = true;
      result = value;
    });

    final nameEditable = tester.widget<EditableText>(
      find.descendant(of: _nameField, matching: find.byType(EditableText)),
    );
    expect(nameEditable.focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(CreateTagDialog), findsNothing);
    expect(closed, isTrue);
    expect(result, isNull);
    expect(gitService.annotated, isEmpty);
    expect(gitService.lightweight, isEmpty);
  });

  testWidgets('an empty form is rejected on both fields and stays open', (
    tester,
  ) async {
    final gitService = _RecordingGitService();
    var closed = false;
    await _openDialog(tester, gitService, (_) => closed = true);

    // The name field autofocused; Enter must refuse to create and surface
    // both problems at once: no name, no annotated-tag message.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CreateTagDialog), findsOneWidget);
    expect(find.text('Please enter a tag name'), findsOneWidget);
    expect(
      find.text('Please enter a message for annotated tag'),
      findsOneWidget,
    );
    expect(closed, isFalse);

    // The Create Tag button must refuse too.
    await tester.tap(_createTagAction);
    await tester.pumpAndSettle();
    expect(find.byType(CreateTagDialog), findsOneWidget);
    expect(closed, isFalse);
    expect(gitService.annotated, isEmpty);
    expect(gitService.lightweight, isEmpty);
  });

  testWidgets('a tag name with spaces is rejected', (tester) async {
    final gitService = _RecordingGitService();
    var closed = false;
    await _openDialog(tester, gitService, (_) => closed = true);

    await tester.enterText(_nameField, 'v 1.0');
    await tester.enterText(_messageField, 'Release notes');
    await tester.tap(_createTagAction);
    await tester.pumpAndSettle();

    expect(find.byType(CreateTagDialog), findsOneWidget);
    expect(find.text('Tag name cannot contain spaces'), findsOneWidget);
    expect(closed, isFalse);
    expect(gitService.annotated, isEmpty);
  });

  testWidgets('without a target the tag is created at HEAD through Enter', (
    tester,
  ) async {
    final gitService = _RecordingGitService();
    bool? result;
    await _openDialog(tester, gitService, (value) => result = value);

    // Fill the message first so the final Enter is sent from the single-line
    // name field (Enter inside the multiline message writes a newline).
    await tester.enterText(_messageField, 'Release notes');
    await tester.enterText(_nameField, 'v9.9');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CreateTagDialog), findsNothing);
    expect(result, isTrue);
    expect(gitService.annotated, [('v9.9', 'Release notes', 'HEAD')]);
  });

  testWidgets('a commit from the history entry point is preselected', (
    tester,
  ) async {
    final gitService = _RecordingGitService();
    bool? result;
    const hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678';
    await _openDialog(
      tester,
      gitService,
      (value) => result = value,
      initialCommit: hash,
      commits: [_commit(hash, 'Fix the crash')],
    );

    // The dropdown shows the preselected commit, not HEAD.
    expect(find.text('a1b2c3d'), findsOneWidget);
    expect(find.text('Fix the crash'), findsOneWidget);

    await tester.enterText(_messageField, 'Release notes');
    await tester.enterText(_nameField, 'v9.9');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CreateTagDialog), findsNothing);
    expect(result, isTrue);
    expect(gitService.annotated, [('v9.9', 'Release notes', hash)]);
  });

  testWidgets('a target outside the loaded history still gets an item', (
    tester,
  ) async {
    final gitService = _RecordingGitService();
    bool? result;
    const hash = 'b1b2c3d4e5f60718293a4b5c6d7e8f9012345678';
    await _openDialog(
      tester,
      gitService,
      (value) => result = value,
      initialCommit: hash,
      commits: [_commit('c1c2c3c4c5c60718293a4b5c6d7e8f9012345678', 'Other')],
    );

    // The revision is unknown to the history provider, so the dropdown must
    // fall back to a bare hash entry instead of tripping the value assert.
    expect(find.byType(CreateTagDialog), findsOneWidget);
    expect(find.text('b1b2c3d'), findsOneWidget);

    await tester.enterText(_messageField, 'Release notes');
    await tester.enterText(_nameField, 'v9.9');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CreateTagDialog), findsNothing);
    expect(result, isTrue);
    expect(gitService.annotated, [('v9.9', 'Release notes', hash)]);
  });

  testWidgets('a recent tag prefills name and message as template', (
    tester,
  ) async {
    final gitService = _RecordingGitService();
    bool? result;
    await _openDialog(
      tester,
      gitService,
      (value) => result = value,
      tags: [
        GitTag(
          name: 'v1.0.0',
          commitHash: 'd1d2c3d4e5f60718293a4b5c6d7e8f9012345678',
          type: GitTagType.annotated,
          message: 'First release',
          date: DateTime(2026),
        ),
      ],
    );

    // Tap the dropdown itself rather than its hint: "No template" is a real
    // entry with a null value, so the field shows that entry and the hint
    // never renders.
    await tester.tap(find.byType(BaseDropdown<GitTag?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('v1.0.0').last);
    await tester.pumpAndSettle();

    // Name and message were prefilled from the selected tag.
    expect(find.text('First release'), findsOneWidget);

    await tester.enterText(_nameField, 'v1.0.1');
    await tester.tap(_createTagAction);
    await tester.pumpAndSettle();

    expect(find.byType(CreateTagDialog), findsNothing);
    expect(result, isTrue);
    expect(gitService.annotated, [('v1.0.1', 'First release', 'HEAD')]);
  });
}
