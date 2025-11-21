import 'package:flutter/material.dart';
import 'package:riverpod/legacy.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
  IconData get icon {
    switch (this) {
      case AppDestination.workspaces:
        return PhosphorIconsRegular.house;
      case AppDestination.repositories:
        return PhosphorIconsRegular.gitCommit;
      case AppDestination.changes:
        return PhosphorIconsRegular.pencilSimple;
      case AppDestination.history:
        return PhosphorIconsRegular.chartLine;
      case AppDestination.browse:
        return PhosphorIconsRegular.folderOpen;
      case AppDestination.branches:
        return PhosphorIconsRegular.gitBranch;
      case AppDestination.stashes:
        return PhosphorIconsRegular.package;
      case AppDestination.tags:
        return PhosphorIconsRegular.tag;
      case AppDestination.settings:
        return PhosphorIconsRegular.gear;
    }
  }

  /// Selected icon for the destination
  IconData get iconSelected {
    switch (this) {
      case AppDestination.workspaces:
        return PhosphorIconsFill.house;
      case AppDestination.repositories:
        return PhosphorIconsFill.gitCommit;
      case AppDestination.changes:
        return PhosphorIconsFill.pencilSimple;
      case AppDestination.history:
        return PhosphorIconsFill.chartLine;
      case AppDestination.browse:
        return PhosphorIconsFill.folderOpen;
      case AppDestination.branches:
        return PhosphorIconsFill.gitBranch;
      case AppDestination.stashes:
        return PhosphorIconsFill.package;
      case AppDestination.tags:
        return PhosphorIconsFill.tag;
      case AppDestination.settings:
        return PhosphorIconsFill.gear;
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
