// The default workspace's name and description are the application's own
// words, not the user's, so they are never written into config.yaml and are
// resolved from the active locale every time they are shown.
//
// The defect this pins: an earlier build created that workspace with the
// English strings "Default" and "Default workspace for all repositories" and
// saved them the first time the user changed anything. From then on every
// launch rendered those two sentences straight from the file, in English,
// whichever of the six UI languages was selected.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/workspace/default_workspace_text.dart';
import 'package:flutter_gitui/core/workspace/models/workspace.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

Workspace workspace({
  String id = Workspace.defaultId,
  String name = '',
  String? description,
}) => Workspace(
  id: id,
  name: name,
  description: description,
  color: const Color(0xFF2196F3),
  repositoryPaths: const [],
  createdAt: DateTime.utc(2026),
);

void main() {
  late AppLocalizations english;
  late AppLocalizations german;

  setUpAll(() async {
    english = await AppLocalizations.delegate.load(const Locale('en'));
    german = await AppLocalizations.delegate.load(const Locale('de'));
  });

  group('the workspace the application creates for itself', () {
    test('carries no words of its own into the config file', () {
      final created = Workspace.createDefault();

      expect(created.id, Workspace.defaultId);
      expect(
        created.name,
        isEmpty,
        reason:
            'A name here is written to config.yaml on the first save and then '
            'rendered verbatim in every locale.',
      );
      expect(created.description, isNull);
    });

    test('is named and described in the language the user reads', () {
      final created = Workspace.createDefault();

      expect(created.displayName(english), 'Default');
      expect(
        created.displayDescription(english),
        'Default workspace for all repositories',
        reason: 'The English wording must be exactly what it always was.',
      );
      expect(created.displayName(german), 'Standard');
      expect(
        created.displayDescription(german),
        'Standard-Arbeitsbereich für alle Repositories',
      );
    });
  });

  group('a workspace the user has named', () {
    test('is shown exactly as typed, default workspace included', () {
      final renamed = workspace(name: 'Default', description: 'Mine');

      expect(renamed.displayName(german), 'Default');
      expect(renamed.displayDescription(german), 'Mine');
    });

    test('shows no description when it has none', () {
      final other = workspace(id: 'w1', name: 'Work');

      expect(other.displayName(german), 'Work');
      expect(other.displayDescription(german), isNull);
      expect(other.isDefaultWorkspace, isFalse);
    });
  });

  group('what the edit dialog submits', () {
    test(
      'goes back as absent while it is still the application\'s wording',
      () {
        expect(storedDefaultWorkspaceName('Standard', german), isEmpty);
        expect(
          storedDefaultWorkspaceDescription(
            'Standard-Arbeitsbereich für alle Repositories',
            german,
          ),
          isNull,
        );
      },
    );

    test('is stored as typed once the user has changed it', () {
      expect(storedDefaultWorkspaceName('Arbeit', german), 'Arbeit');
      expect(
        storedDefaultWorkspaceDescription('Meine Repositories', german),
        'Meine Repositories',
      );
    });

    test('is judged against the locale on screen, not against English', () {
      // The German word is the user's own choice while the UI is English, so
      // it is data and is kept; the English word is not.
      expect(storedDefaultWorkspaceName('Standard', english), 'Standard');
      expect(storedDefaultWorkspaceName('Default', english), isEmpty);
    });
  });
}
