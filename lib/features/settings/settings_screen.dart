import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../generated/app_localizations.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/components/base_button.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_providers.dart';
import '../../core/diff/models/diff_tool.dart';
import '../../core/services/logger_service.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/dialogs/detect_tools_dialog.dart';
import '../../core/tools/version_detector.dart';
import '../../core/services/notification_service.dart';
import 'widgets/git_config_section.dart';
import 'widgets/theme_section.dart';
import 'widgets/animation_section.dart';
import 'widgets/behavior_section.dart';
import 'widgets/history_section.dart';
import 'widgets/updates_section.dart';
import 'widgets/config_and_logs_section.dart';

/// Settings screen - Application configuration
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: StandardAppBar(
        title: l10n.settings,
        moreMenuItems: [
          // Reset to defaults (destructive action)
          PopupMenuItem(
            child: MenuItemContent(
              icon: PhosphorIconsRegular.arrowCounterClockwise,
              label: l10n.resetToDefaults,
              iconSize: AppTheme.iconM,
              iconColor: Theme.of(context).colorScheme.error,
              labelColor: Theme.of(context).colorScheme.error,
            ),
            onTap: () => _confirmReset(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        children: [
          GitConfigSection(
            onSelectGitExecutable: () => _selectGitExecutable(context, ref),
            onSelectTextEditor: () => _selectTextEditor(context, ref),
            onDetectTools: () => _detectTools(context, ref),
            onSelectDiffTool: () => _selectDiffTool(context, ref),
            onSelectMergeTool: () => _selectMergeTool(context, ref),
            onEditUserName: () => _editUserName(context, ref),
            onEditUserEmail: () => _editUserEmail(context, ref),
          ),
          const SizedBox(height: AppTheme.paddingXL),
          ThemeSection(
            getColorSchemeName: (scheme) => _getColorSchemeName(context, scheme),
            getFontSizeName: (size) => _getFontSizeName(context, size),
          ),
          const SizedBox(height: AppTheme.paddingXL),
          const AnimationSection(),
          const SizedBox(height: AppTheme.paddingXL),
          BehaviorSection(
            onEditAutoFetchInterval: () => _editAutoFetchInterval(context, ref),
          ),
          const SizedBox(height: AppTheme.paddingXL),
          HistorySection(
            onEditCommitHistoryLimit: () => _editCommitHistoryLimit(context, ref),
          ),
          const SizedBox(height: AppTheme.paddingXL),
          const UpdatesSection(),
          const SizedBox(height: AppTheme.paddingXL),
          const ConfigAndLogsSection(),
        ],
      ),
    );
  }

  // Helper Methods

  Future<void> _selectGitExecutable(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectGitExecutable,
      type: Platform.isWindows ? FileType.custom : FileType.any,
      allowedExtensions: Platform.isWindows ? ['exe'] : null,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;

      // Validate that the selected file is actually git
      try {
        final processResult = await Process.run(selectedPath, ['--version']);

        if (processResult.exitCode == 0) {
          final output = processResult.stdout.toString().trim();

          // Check if output contains "git version"
          if (output.toLowerCase().contains('git version')) {
            // Extract version number (e.g., "git version 2.43.0.windows.1")
            final versionMatch = RegExp(r'git version ([\d.]+(?:\.\w+)?(?:\.\d+)?)').firstMatch(output);
            final version = versionMatch?.group(1) ?? output;

            // Save git path with version
            try {
              await ref.read(configProvider.notifier).setGitExecutablePath(selectedPath, version: version);
            } catch (e) {
              if (!context.mounted) return;
              NotificationService.showError(context, 'Failed to save git executable path: $e');
              return;
            }
          } else {
            // Not git - show error
            if (!context.mounted) return;
            showDialog(
              context: context,
              builder: (dialogContext) => BaseDialog(
                title: l10n.invalidGitExecutable,
                content: BodyMediumLabel(l10n.invalidGitExecutableMessage(selectedPath, output, output)),
                actions: [
                  BaseButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    label: l10n.ok,
                    variant: ButtonVariant.tertiary,
                  ),
                ],
              ),
            );
          }
        } else {
          // Failed to execute
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (dialogContext) => BaseDialog(
              title: l10n.executionFailed,
              content: BodyMediumLabel(l10n.executionFailedMessage(selectedPath, processResult.stderr.toString())),
              actions: [
                BaseButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  label: l10n.ok,
                  variant: ButtonVariant.tertiary,
                ),
              ],
            ),
          );
        }
      } catch (e) {
        // Exception during validation
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => BaseDialog(
              title: l10n.validationError,
              content: BodyMediumLabel(l10n.validationErrorMessage(selectedPath, e.toString())),
              actions: [
                BaseButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  label: l10n.ok,
                  variant: ButtonVariant.tertiary,
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _selectTextEditor(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectTextEditor,
      type: Platform.isWindows ? FileType.custom : FileType.any,
      allowedExtensions: Platform.isWindows ? ['exe'] : null,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;

      // Verify file exists
      final file = File(selectedPath);
      if (!await file.exists()) {
        if (context.mounted) {
          _showError(context, l10n.selectedFileDoesNotExist);
        }
        return;
      }

      final fileName = selectedPath.split(Platform.pathSeparator).last.toLowerCase();

      // Known text editors
      final knownEditors = [
        'code.exe', 'code', // VS Code
        'notepad.exe', 'notepad', // Notepad
        'notepad++.exe', 'notepad++', // Notepad++
        'sublime_text.exe', 'subl.exe', 'sublime', 'subl', // Sublime Text
        'vim.exe', 'vim', 'gvim.exe', 'gvim', 'nvim.exe', 'nvim', // Vim family
        'emacs.exe', 'emacs', // Emacs
        'atom.exe', 'atom', // Atom
        'nano.exe', 'nano', // Nano
        'gedit', 'gedit.exe', // Gedit
        'kate', 'kate.exe', // Kate
        'textmate', 'mate', // TextMate
      ];

      // Detect version (do this before validation check)
      final version = await VersionDetector.detectVersion(selectedPath);

      // Check if it's a known editor
      final isKnownEditor = knownEditors.any((editor) => fileName == editor || fileName.contains(editor.split('.')[0]));

      if (!isKnownEditor) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => BaseDialog(
              title: l10n.unknownTextEditor,
              content: BodyMediumLabel(l10n.unknownTextEditorMessage(fileName)),
              actions: [
                BaseButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  label: l10n.cancel,
                  variant: ButtonVariant.tertiary,
                ),
                BaseButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await ref.read(configProvider.notifier).setTextEditor(selectedPath, version: version);
                  },
                  label: l10n.useAnyway,
                  variant: ButtonVariant.primary,
                ),
              ],
            ),
          );
        }
        return;
      }

      // File passed validation - set it
      await ref.read(configProvider.notifier).setTextEditor(selectedPath, version: version);
    }
  }

  Future<void> _selectDiffTool(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectDiffTool,
      type: Platform.isWindows ? FileType.custom : FileType.any,
      allowedExtensions: Platform.isWindows ? ['exe'] : null,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;

      // Verify file exists
      final file = File(selectedPath);
      if (!await file.exists()) {
        if (context.mounted) {
          NotificationService.showError(context, 'Selected file does not exist');
        }
        return;
      }

      // Detect version
      final version = await VersionDetector.detectVersion(selectedPath);

      // Try to match with known diff tool types
      final fileName = selectedPath.split(Platform.pathSeparator).last.toLowerCase();
      DiffToolType? detectedType;

      for (final type in DiffToolType.values) {
        if (type == DiffToolType.custom) continue;
        final name = type.name.toLowerCase();
        if (fileName.contains(name) || fileName.contains(type.displayName.toLowerCase().replaceAll(' ', ''))) {
          detectedType = type;
          break;
        }
      }

      // If no match found, use custom
      detectedType ??= DiffToolType.custom;

      try {
        await ref.read(configProvider.notifier).setDiffTool(
          detectedType,
          path: selectedPath,
          version: version,
        );
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to save diff tool: $e');
        }
      }
    }
  }

  Future<void> _selectMergeTool(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectMergeTool,
      type: Platform.isWindows ? FileType.custom : FileType.any,
      allowedExtensions: Platform.isWindows ? ['exe'] : null,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;

      // Verify file exists
      final file = File(selectedPath);
      if (!await file.exists()) {
        if (context.mounted) {
          NotificationService.showError(context, 'Selected file does not exist');
        }
        return;
      }

      // Detect version
      final version = await VersionDetector.detectVersion(selectedPath);

      // Try to match with known merge tool types
      final fileName = selectedPath.split(Platform.pathSeparator).last.toLowerCase();
      DiffToolType? detectedType;

      for (final type in DiffToolType.values) {
        if (type == DiffToolType.custom) continue;
        final name = type.name.toLowerCase();
        if (fileName.contains(name) || fileName.contains(type.displayName.toLowerCase().replaceAll(' ', ''))) {
          detectedType = type;
          break;
        }
      }

      // If no match found, use custom
      detectedType ??= DiffToolType.custom;

      try {
        await ref.read(configProvider.notifier).setMergeTool(
          detectedType,
          path: selectedPath,
          version: version,
        );
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to save merge tool: $e');
        }
      }
    }
  }

  Future<void> _detectTools(BuildContext context, WidgetRef ref) async {
    // Get current configuration to pre-select in dialog
    final git = ref.read(gitConfigProvider);
    final tools = ref.read(toolsConfigProvider);

    // Show detect tools dialog with current selections
    final result = await showDetectToolsDialog(
      context,
      currentGitPath: git.executablePath,
      currentDiffTool: tools.diffTool,
      currentTextEditor: tools.textEditor,
    );

    if (result == null || !context.mounted) return;

    // Apply selected tools
    final gitPath = result['git'] as String?;
    final diffTool = result['diffTool'] as DiffTool?;
    final textEditor = result['textEditor'];

    if (gitPath != null) {
      // Detect git version
      String? version;
      try {
        version = await VersionDetector.detectVersion(gitPath);
      } catch (e) {
        Logger.warning('Failed to detect git version', e);
      }

      try {
        await ref.read(configProvider.notifier).setGitExecutablePath(gitPath, version: version);
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(context, 'Failed to save git executable path: $e');
        return;
      }
    }

    if (diffTool != null) {
      // Detect tool version
      String? version;
      try {
        version = await VersionDetector.detectVersion(diffTool.executablePath);
      } catch (e) {
        Logger.warning('Failed to detect diff tool version', e);
      }

      try {
        await ref.read(configProvider.notifier).setDiffTool(diffTool.type, path: diffTool.executablePath, version: version);
        await ref.read(configProvider.notifier).setMergeTool(diffTool.type, path: diffTool.executablePath, version: version);
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(context, 'Failed to save diff/merge tool settings: $e');
        return;
      }
    }

    if (textEditor != null) {
      final editorPath = textEditor.path as String;

      // Detect editor version
      String? version;
      try {
        version = await VersionDetector.detectVersion(editorPath);
      } catch (e) {
        Logger.warning('Failed to detect editor version', e);
      }

      try {
        await ref.read(configProvider.notifier).setTextEditor(editorPath, version: version);
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(context, 'Failed to save text editor settings: $e');
        return;
      }
    }
  }

  Future<void> _editUserName(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final git = ref.read(gitConfigProvider);
    final controller = TextEditingController(text: git.defaultUserName ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.defaultUserName,
        icon: PhosphorIconsRegular.user,
        content: BaseTextField(
          controller: controller,
          autofocus: true,
          label: l10n.userName,
          hintText: l10n.userNameHint,
          prefixIcon: PhosphorIconsRegular.user,
        ),
        actions: [
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: l10n.cancel,
            variant: ButtonVariant.tertiary,
          ),
          BaseButton(
            onPressed: () {
              ref.read(configProvider.notifier).setDefaultUserName(null);
              Navigator.of(dialogContext).pop();
            },
            label: l10n.clear,
            variant: ButtonVariant.tertiary,
          ),
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            label: l10n.save,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ref.read(configProvider.notifier).setDefaultUserName(result);
    }
  }

  Future<void> _editUserEmail(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final git = ref.read(gitConfigProvider);
    final controller = TextEditingController(text: git.defaultUserEmail ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.defaultUserEmail,
        icon: PhosphorIconsRegular.at,
        content: BaseTextField(
          controller: controller,
          autofocus: true,
          label: l10n.email,
          hintText: l10n.emailHint,
          prefixIcon: PhosphorIconsRegular.at,
        ),
        actions: [
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: l10n.cancel,
            variant: ButtonVariant.tertiary,
          ),
          BaseButton(
            onPressed: () {
              ref.read(configProvider.notifier).setDefaultUserEmail(null);
              Navigator.of(dialogContext).pop();
            },
            label: l10n.clear,
            variant: ButtonVariant.tertiary,
          ),
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            label: l10n.save,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ref.read(configProvider.notifier).setDefaultUserEmail(result);
    }
  }

  Future<void> _editAutoFetchInterval(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final behavior = ref.read(behaviorConfigProvider);
    final controller = TextEditingController(text: behavior.autoFetchInterval.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.autoFetchInterval,
        icon: PhosphorIconsRegular.timer,
        content: BaseTextField(
          controller: controller,
          autofocus: true,
          label: l10n.minutes,
          hintText: l10n.minutesHint,
          prefixIcon: PhosphorIconsRegular.timer,
        ),
        actions: [
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: l10n.cancel,
            variant: ButtonVariant.tertiary,
          ),
          BaseButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            label: l10n.save,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );

    if (result != null) {
      await ref.read(configProvider.notifier).setAutoFetchInterval(result);
    }
  }

  Future<void> _editCommitHistoryLimit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.read(historyConfigProvider);
    final controller = TextEditingController(text: history.defaultCommitLimit.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.defaultCommitLimit,
        icon: PhosphorIconsRegular.listNumbers,
        content: BaseTextField(
          controller: controller,
          autofocus: true,
          label: l10n.commits,
          hintText: l10n.commitsHint,
          prefixIcon: PhosphorIconsRegular.listNumbers,
        ),
        actions: [
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: l10n.cancel,
            variant: ButtonVariant.tertiary,
          ),
          BaseButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            label: l10n.save,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );

    if (result != null) {
      await ref.read(configProvider.notifier).setDefaultCommitLimit(result);
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.resetSettings,
        icon: PhosphorIconsRegular.warning,
        variant: DialogVariant.destructive,
        content: BodyMediumLabel(l10n.resetSettingsMessage),
        actions: [
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: l10n.cancel,
            variant: ButtonVariant.tertiary,
          ),
          BaseButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: l10n.reset,
            variant: ButtonVariant.danger,
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(configProvider.notifier).resetToDefaults();
    }
  }

  /// Get display name for color scheme
  String _getColorSchemeName(BuildContext context, AppColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    switch (scheme) {
      case AppColorScheme.deepPurple:
        return l10n.colorSchemeDeepPurple;
      case AppColorScheme.indigo:
        return l10n.colorSchemeIndigo;
      case AppColorScheme.blue:
        return l10n.colorSchemeBlue;
      case AppColorScheme.teal:
        return l10n.colorSchemeTeal;
      case AppColorScheme.green:
        return l10n.colorSchemeGreen;
      case AppColorScheme.red:
        return l10n.colorSchemeRed;
      case AppColorScheme.pink:
        return l10n.colorSchemePink;
      case AppColorScheme.purple:
        return l10n.colorSchemePurple;
      case AppColorScheme.deepOrange:
        return l10n.colorSchemeDeepOrange;
      case AppColorScheme.blueGrey:
        return l10n.colorSchemeBlueGrey;
    }
  }

  /// Get display name for font size
  String _getFontSizeName(BuildContext context, AppFontSize size) {
    final l10n = AppLocalizations.of(context)!;
    switch (size) {
      case AppFontSize.tiny:
        return l10n.fontSizeTiny;
      case AppFontSize.small:
        return l10n.fontSizeSmall;
      case AppFontSize.medium:
        return l10n.fontSizeMedium;
      case AppFontSize.large:
        return l10n.fontSizeLarge;
    }
  }

  /// Convenience method for error notifications
  void _showError(BuildContext context, String message) {
    NotificationService.showError(context, message);
  }

}
