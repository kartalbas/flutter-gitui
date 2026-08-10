import 'package:flutter/widgets.dart';
import 'package:riverpod/legacy.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../generated/app_localizations.dart';

/// Current navigation destination provider
final navigationDestinationProvider = StateProvider<AppDestination>(
  (ref) => AppDestination.workspaces,
);

/// Navigation destination in the app
enum AppDestination {
  workspaces,
  repositories,
  changes,
  history,
  browse,
  branches,
  stashes,
  tags,
  settings;

  /// Display name for the destination
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case AppDestination.workspaces:
        return l10n.workspaces;
      case AppDestination.repositories:
        return l10n.repositories;
      case AppDestination.changes:
        return l10n.changes;
      case AppDestination.history:
        return l10n.history;
      case AppDestination.browse:
        return l10n.browse;
      case AppDestination.branches:
        return l10n.branches;
      case AppDestination.stashes:
        return l10n.stashes;
      case AppDestination.tags:
        return l10n.tags;
      case AppDestination.settings:
        return l10n.settings;
    }
  }

  /// Icon for the destination
  /// The destination's mark, as a MEANING.
  ///
  /// It was a `PhosphorIconsRegular` codepoint, and [iconSelected] the Fill
  /// codepoint of the same glyph - nine destinations separating "available"
  /// from "you are here" by weight alone, decided in application code. A role
  /// carries no weight, deliberately, because the three languages weight their
  /// marks differently; the SKIN re-decides it for the slot it is filling, and
  /// the navigation rail is such a slot (`MaterialGlyphs.filledOf`).
  IconRole get icon {
    switch (this) {
      case AppDestination.workspaces:
        return IconRole.house;
      case AppDestination.repositories:
        return IconRole.gitCommit;
      case AppDestination.changes:
        return IconRole.pencilSimple;
      case AppDestination.history:
        return IconRole.chartLine;
      case AppDestination.browse:
        return IconRole.folderOpen;
      case AppDestination.branches:
        return IconRole.gitBranch;
      case AppDestination.stashes:
        return IconRole.package;
      case AppDestination.tags:
        return IconRole.tag;
      case AppDestination.settings:
        return IconRole.gear;
    }
  }

  /// The same mark while this is the destination the user is on.
  ///
  /// The same ROLE, and that is the honest statement: the application never
  /// meant a different picture, it meant the same one drawn to say "here".
  /// Kept as its own member because the contract has the slot - a language
  /// that answers with a genuinely different glyph is allowed to.
  IconRole get iconSelected {
    switch (this) {
      case AppDestination.workspaces:
        return IconRole.house;
      case AppDestination.repositories:
        return IconRole.gitCommit;
      case AppDestination.changes:
        return IconRole.pencilSimple;
      case AppDestination.history:
        return IconRole.chartLine;
      case AppDestination.browse:
        return IconRole.folderOpen;
      case AppDestination.branches:
        return IconRole.gitBranch;
      case AppDestination.stashes:
        return IconRole.package;
      case AppDestination.tags:
        return IconRole.tag;
      case AppDestination.settings:
        return IconRole.gear;
    }
  }

  /// Keyboard shortcut
  String get shortcut {
    switch (this) {
      case AppDestination.workspaces:
        return 'Ctrl+1';
      case AppDestination.repositories:
        return 'Ctrl+2';
      case AppDestination.changes:
        return 'Ctrl+3';
      case AppDestination.history:
        return 'Ctrl+4';
      case AppDestination.browse:
        return 'Ctrl+5';
      case AppDestination.branches:
        return 'Ctrl+6';
      case AppDestination.stashes:
        return 'Ctrl+7';
      case AppDestination.tags:
        return 'Ctrl+8';
      case AppDestination.settings:
        return 'Ctrl+,';
    }
  }
}
