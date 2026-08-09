import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ContentPort, IconRole, Inset, Proximity, Skin, SkinScope, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/config/config_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/editor_launcher_service.dart';
import 'settings_section.dart';
import '../../../shared/components/base_layout.dart';

/// Config and Logs section - Open log files and config folder
class ConfigAndLogsSection extends ConsumerWidget {
  const ConfigAndLogsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textEditor = ref.watch(preferredTextEditorProvider);

    return SettingsSection(
      title: l10n.configAndLogs,
      icon: IconRole.folder,
      children: [
        BaseInset(
          all: Inset.normal,
          // The section's five actions are one run of equals that runs onto a
          // second line when the settings pane is narrow - `layout.row(wrap:
          // true)` - so the distance between two buttons and the distance
          // between two lines of them are the skin's one answer instead of the
          // two 16s written here. The buttons are all one height, so the run's
          // cross alignment is not visible; it is stated `start` because that
          // is what the bare `Wrap` did.
          child: SkinScope.render(context, (Skin skin, BuildContext inner) {
            return skin.layout.row(
              inner,
              [
                // Open app.log
                ContentPort(
                  BaseButton(
                    onPressed: textEditor != null
                        ? () => _openAppLog(context, textEditor)
                        : null,
                    label: l10n.openAppLog,
                    leadingIcon: IconRole.fileText,
                    variant: ButtonVariant.secondary,
                  ),
                ),
                // Open git.log
                ContentPort(
                  BaseButton(
                    onPressed: textEditor != null
                        ? () => _openGitLog(context, textEditor)
                        : null,
                    label: l10n.openGitLog,
                    leadingIcon: IconRole.gitBranch,
                    variant: ButtonVariant.secondary,
                  ),
                ),
                // Open user flutter-gitui folder
                ContentPort(
                  BaseButton(
                    onPressed: () => _openConfigFolder(context, textEditor),
                    label: l10n.openConfigFolder,
                    leadingIcon: IconRole.folderOpen,
                    variant: ButtonVariant.secondary,
                  ),
                ),
                // Delete app.log
                ContentPort(
                  BaseButton(
                    onPressed: () => _deleteAppLog(context),
                    label: l10n.deleteAppLog,
                    leadingIcon: IconRole.trash,
                    variant: ButtonVariant.danger,
                  ),
                ),
                // Delete git.log
                ContentPort(
                  BaseButton(
                    onPressed: () => _deleteGitLog(context),
                    label: l10n.deleteGitLog,
                    leadingIcon: IconRole.trash,
                    variant: ButtonVariant.danger,
                  ),
                ),
              ],
              gap: Proximity.grouped,
              cross: CrossAxisAlignment.start,
              wrap: true,
            );
          }),
        ),
      ],
    );
  }

  Future<void> _openAppLog(BuildContext context, String textEditor) async {
    try {
      final logPath = Logger.logFilePath;
      if (logPath != null) {
        // launch() is built on runCatchingAsync and never throws, so without
        // unwrapping the failure the catch below can never fire and the click
        // is silently swallowed.
        final launchResult = await EditorLauncherService.launch(
          editorPath: textEditor,
          targetPath: logPath,
        );
        launchResult.unwrap();
      } else {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Log file path not available',
          );
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
        final launchResult = await EditorLauncherService.launch(
          editorPath: textEditor,
          targetPath: gitLogPath,
        );
        launchResult.unwrap();
      } else {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Git log file path not available',
          );
        }
      }
    } catch (e) {
      Logger.error('Failed to open git.log', e);
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to open git.log: $e');
      }
    }
  }

  Future<void> _openConfigFolder(
    BuildContext context,
    String? textEditor,
  ) async {
    try {
      // Single source of truth for the config location, so this stays in sync
      // with the documents-directory fallback used when HOME/USERPROFILE is unset.
      final configFolderPath = await ConfigService.getConfigDirPath();
      final configFolder = Directory(configFolderPath);

      if (!await configFolder.exists()) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Config folder does not exist: $configFolderPath',
          );
        }
        return;
      }

      // Open folder in text editor if configured, otherwise use file explorer
      if (textEditor != null && textEditor.isNotEmpty) {
        final launchResult = await EditorLauncherService.launch(
          editorPath: textEditor,
          targetPath: configFolderPath,
        );
        launchResult.unwrap();
      } else {
        // Fall back to file explorer
        if (Platform.isWindows) {
          await Process.start('explorer', [
            configFolderPath,
          ], mode: ProcessStartMode.detached);
        } else if (Platform.isMacOS) {
          await Process.start('open', [
            configFolderPath,
          ], mode: ProcessStartMode.detached);
        } else if (Platform.isLinux) {
          // Try xdg-open first, fall back to common file managers
          try {
            await Process.start('xdg-open', [
              configFolderPath,
            ], mode: ProcessStartMode.detached);
          } catch (e) {
            // Try nautilus (GNOME)
            try {
              await Process.start('nautilus', [
                configFolderPath,
              ], mode: ProcessStartMode.detached);
            } catch (e) {
              // Try dolphin (KDE)
              try {
                await Process.start('dolphin', [
                  configFolderPath,
                ], mode: ProcessStartMode.detached);
              } catch (e) {
                if (context.mounted) {
                  NotificationService.showError(
                    context,
                    'Could not open file manager. Please install xdg-utils.',
                  );
                }
              }
            }
          }
        }
      }
    } catch (e) {
      Logger.error('Failed to open config folder', e);
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Failed to open config folder: $e',
        );
      }
    }
  }

  Future<void> _deleteAppLog(BuildContext context) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final logPath = Logger.logFilePath;

      if (logPath == null) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Log file path not available',
          );
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

      if (!context.mounted) return;

      // Show confirmation dialog
      final confirmed = await BaseDialog.show<bool>(
        context: context,
        dialog: BaseDialog(
          icon: IconRole.trash,
          title: l10n.deleteAppLog,
          variant: DialogVariant.destructive,
          content: const BaseLabel(
            'Are you sure you want to delete app.log? This action cannot be undone.',
            role: TextRole.body,
          ),
          actions: [
            DialogAction(
              label: l10n.cancel,
              role: DialogActionRole.dismissive,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            DialogAction(
              label: l10n.delete,
              role: DialogActionRole.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await logFile.delete();
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
      final l10n = AppLocalizations.of(context)!;
      final gitLogPath = Logger.gitLogFilePath;

      if (gitLogPath == null) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Git log file path not available',
          );
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

      if (!context.mounted) return;

      // Show confirmation dialog
      final confirmed = await BaseDialog.show<bool>(
        context: context,
        dialog: BaseDialog(
          icon: IconRole.trash,
          title: l10n.deleteGitLog,
          variant: DialogVariant.destructive,
          content: const BaseLabel(
            'Are you sure you want to delete git.log? This action cannot be undone.',
            role: TextRole.body,
          ),
          actions: [
            DialogAction(
              label: l10n.cancel,
              role: DialogActionRole.dismissive,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            DialogAction(
              label: l10n.delete,
              role: DialogActionRole.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await gitLogFile.delete();
      }
    } catch (e) {
      Logger.error('Failed to delete git.log', e);
      if (context.mounted) {
        NotificationService.showError(context, 'Failed to delete git.log: $e');
      }
    }
  }
}
