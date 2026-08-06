// The create-tag dialog's validators gate submission (#360): an empty tag
// name, a tag name with spaces, or a missing annotated-tag message each show
// their error and keep the dialog open — for the dialog-wide Enter path and
// the Create Tag button alike — and nothing reaches GitService; valid input
// still creates the tag and closes. Before the fix the validators were
// accepted but never executed, because BaseTextField built a plain TextField
// that no Form could see.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/dialogs/create_tag_dialog.dart';

/// Records tag creations instead of running git, so the tests can assert an
/// invalid form never reaches the service.
class _RecordingGitService extends GitService {
  _RecordingGitService() : super('.');

  final annotated = <(String, String)>[];
  final lightweight = <String>[];

  @override
  Future<Result<void>> createAnnotatedTag(
    String tagName, {
    required String message,
    String? commitHash,
  }) async {
    annotated.add((tagName, message));
    return const Success(null);
  }

  @override
  Future<Result<void>> createLightweightTag(
    String tagName, {
    String? commitHash,
  }) async {
    lightweight.add(tagName);
    return const Success(null);
  }
}

Future<void> _openDialog(
  WidgetTester tester,
  _RecordingGitService gitService,
  void Function(bool?) onClosed,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gitServiceProvider.overrideWith((ref) => gitService),
        commitHistoryProvider.overrideWith((ref) async => const <GitCommit>[]),
        tagsProvider.overrideWith((ref) async => const <GitTag>[]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => BaseButton(
              label: 'open',
              onPressed: () {
                showCreateTagDialog(context).then(onClosed);
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

void main() {
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
    await tester.tap(find.widgetWithText(BaseButton, 'Create Tag'));
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
    await tester.tap(find.widgetWithText(BaseButton, 'Create Tag'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTagDialog), findsOneWidget);
    expect(find.text('Tag name cannot contain spaces'), findsOneWidget);
    expect(closed, isFalse);
    expect(gitService.annotated, isEmpty);
  });

  testWidgets('a valid name and message create the tag through Enter', (
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
    expect(gitService.annotated, [('v9.9', 'Release notes')]);
  });
}
