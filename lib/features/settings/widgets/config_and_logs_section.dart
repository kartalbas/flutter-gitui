import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/editor_launcher_service.dart';
import 'settings_section.dart';

/// Config and Logs section - Open log files and config folder
class ConfigAndLogsSection extends ConsumerWidget {
  const ConfigAndLogsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textEditor = ref.watch(preferredTextEditorProvider);

    return SettingsSection(
      title: l10n.configAndLogs,
      icon: PhosphorIconsRegular.folder,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Wrap(
            spacing: AppTheme.paddingM,
            runSpacing: AppTheme.paddingM,
            children: [
              // Open app.log
              BaseButton(
                onPressed: textEditor != null ? () => _openAppLog(context, textEditor) : null,
                label: l10n.openAppLog,
                leadingIcon: PhosphorIconsRegular.fileText,
                variant: ButtonVariant.secondary,
              ),
              // Open git.log
              BaseButton(
                onPressed: textEditor != null ? () => _openGitLog(context, textEditor) : null,
                label: l10n.openGitLog,
                leadingIcon: PhosphorIconsRegular.gitBranch,
                variant: ButtonVariant.secondary,
              ),
              // Open user flutter-gitui folder
              BaseButton(
                onPressed: () => _openConfigFolder(context),
                label: l10n.openConfigFolder,
                leadingIcon: PhosphorIconsRegular.folderOpen,
                variant: ButtonVariant.secondary,
              ),
              // Delete app.log
              BaseButton(
                onPressed: () => _deleteAppLog(context),
                label: l10n.deleteAppLog,
                leadingIcon: PhosphorIconsRegular.trash,
                variant: ButtonVariant.danger,
              ),
              // Delete git.log
              BaseButton(
                onPressed: () => _deleteGitLog(context),
                label: l10n.deleteGitLog,
                leadingIcon: PhosphorIconsRegular.trash,
                variant: ButtonVariant.danger,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAppLog(BuildContext context, String textEditor) async {
    try {
      final logPath = Logger.logFilePath;
      if (logPath != null) {
        await EditorLauncherService.launch(
          editorPath: textEditor,
          targetPath: logPath,
        );
      } else {
        if (context.mounted) {
          NotificationService.showWarning(context, 'Log file path not available');
        }
      }
    } catch (e) {
      Logger.error('Failed to open app.log', e);
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to open app.log: $e');
      }
    }
  }

  Future<void> _openGitLog(BuildContext context, String textEditor) async {
    try {
      final gitLogPath = Logger.gitLogFilePath;
      if (gitLogPath != null) {
        await EditorLauncherService.launch(
          editorPath: textEditor,
          targetPath: gitLogPath,
        );
      } else {
        if (context.mounted) {
          NotificationService.showWarning(context, 'Git log file path not available');
        }
      }
    } catch (e) {
      Logger.error('Failed to open git.log', e);
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to open git.log: $e');
      }
    }
  }

  Future<void> _openConfigFolder(BuildContext context) async {
    try {
      // Get the user's home directory
      final homeDir = Platform.isWindows
          ? Platform.environment['USERPROFILE']
          : Platform.environment['HOME'];

      if (homeDir == null) {
        if (context.mounted) {
          NotificationService.showError(context, 'Could not determine home directory');
        }
        return;
      }

      // Construct path to .flutter-gitui folder
      final configFolder = Directory('$homeDir${Platform.pathSeparator}.flutter-gitui');

      if (!await configFolder.exists()) {
        if (context.mounted) {
          NotificationService.showError(context, 'Config folder does not exist: ${configFolder.path}');
        }
        return;
      }

      // Open folder in file explorer
      if (Platform.isWindows) {
        await Process.start('explorer', [configFolder.path], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [configFolder.path], mode: ProcessStartMode.detached);
      } else if (Platform.isLinux) {
        // Try xdg-open first, fall back to common file managers
        try {
          await Process.start('xdg-open', [configFolder.path], mode: ProcessStartMode.detached);
        } catch (e) {
          // Try nautilus (GNOME)
          try {
            await Process.start('nautilus', [configFolder.path], mode: ProcessStartMode.detached);
          } catch (e) {
            // Try dolphin (KDE)
            try {
              await Process.start('dolphin', [configFolder.path], mode: ProcessStartMode.detached);
            } catch (e) {
              if (context.mounted) {
                NotificationService.showError(context, 'Could not open file manager. Please install xdg-utils.');
              }
            }
          }
        }
      }
    } catch (e) {
      Logger.error('Failed to open config folder', e);
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to open config folder: $e');
      }
    }
  }

  Future<void> _deleteAppLog(BuildContext context) async {
    try {
      final logPath = Logger.logFilePath;
      if (logPath == null) {
        if (context.mounted) {
          NotificationService.showWarning(context, 'Log file path not available');
        }
        return;
      }

      final logFile = File(logPath);
      if (!await logFile.exists()) {
        if (context.mounted) {
          NotificationService.showWarning(context, 'app.log does not exist');
        }
        return;
      }

      // Delete the log file
      await logFile.delete();

      if (context.mounted) {
        NotificationService.showSuccess(context, 'app.log deleted successfully');
      }
    } catch (e) {
      Logger.error('Failed to delete app.log', e);
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to delete app.log: $e');
      }
    }
  }

  Future<void> _deleteGitLog(BuildContext context) async {
    try {
      final gitLogPath = Logger.gitLogFilePath;
      if (gitLogPath == null) {
        if (context.mounted) {
          NotificationService.showWarning(context, 'Git log file path not available');
        }
        return;
      }

      final gitLogFile = File(gitLogPath);
      if (!await gitLogFile.exists()) {
        if (context.mounted) {
          NotificationService.showWarning(context, 'git.log does not exist');
        }
        return;
      }

      // Delete the git log file
      await gitLogFile.delete();

      if (context.mounted) {
        NotificationService.showSuccess(context, 'git.log deleted successfully');
      }
    } catch (e) {
      Logger.error('Failed to delete git.log', e);
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to delete git.log: $e');
      }
    }
  }
}
