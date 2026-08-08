import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;
import '../../generated/app_localizations.dart';

import '../../shared/widgets/standard_app_bar.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_menu_item.dart';
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
import 'widgets/history_section.dart';
import 'widgets/updates_section.dart';
import 'widgets/config_and_logs_section.dart';
import '../../shared/components/base_layout.dart';

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
              icon: IconRole.arrowCounterClockwise,
              label: l10n.resetToDefaults,
              scale: ControlScale.normal,
              tone: Tone.danger,
              labelColor: Theme.of(context).colorScheme.error,
            ),
            onTap: () => _confirmReset(context, ref),
          ),
        ],
      ),
      // Deliberately not a ListView: a lazy list destroys the focus nodes of
      // every section scrolled out of the viewport, and the traversal policy
      // only sees nodes that are currently built. Tabbing to the bottom of the
      // form therefore trapped the keyboard there - Tab cycled between the last
      // two sections and never returned to Git Configuration. The form is a
      // fixed handful of sections, so building all of them keeps every control
      // in one complete Tab cycle; the policy scrolls the focused control into
      // view on its own.
      //
      // The form is its own traversal group so the app bar keeps a fixed place
      // in the Tab cycle. Reading order sorts by on-screen position, and a
      // scrolled form moves its controls past the app bar's fixed rect, which
      // made the overflow button surface in the middle of the sequence; as a
      // group the form is sorted as one block that always sits below the bar.
      body: FocusTraversalGroup(
        // A scroll view's padding is the inset its CONTENT owes the
        // viewport's edge - it scrolls with the content, exactly as a
        // `Padding` around the child does - so it is stated as one.
        child: SingleChildScrollView(
          child: BaseInset(
            all: Inset.roomy,
            child: Column(
              // A Column centers its children, while the ListView it replaces
              // stretched every section card to the full width.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GitConfigSection(
                  onSelectGitExecutable: () =>
                      _selectGitExecutable(context, ref),
                  onSelectTextEditor: () => _selectTextEditor(context, ref),
                  onDetectTools: () => _detectTools(context, ref),
                  onSelectDiffTool: () => _selectDiffTool(context, ref),
                  onSelectMergeTool: () => _selectMergeTool(context, ref),
                  onEditUserName: () => _editUserName(context, ref),
                  onEditUserEmail: () => _editUserEmail(context, ref),
                ),
                const BaseGap(Proximity.sectioned),
                ThemeSection(
                  getColorSchemeName: (scheme) =>
                      _getColorSchemeName(context, scheme),
                  getFontSizeName: (size) => _getFontSizeName(context, size),
                ),
                const BaseGap(Proximity.sectioned),
                const AnimationSection(),
                const BaseGap(Proximity.sectioned),
                HistorySection(
                  onEditCommitHistoryLimit: () =>
                      _editCommitHistoryLimit(context, ref),
                ),
                const BaseGap(Proximity.sectioned),
                const UpdatesSection(),
                const BaseGap(Proximity.sectioned),
                const ConfigAndLogsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Methods

  Future<void> _selectGitExecutable(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.pickFiles(
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
            final versionMatch = RegExp(
              r'git version ([\d.]+(?:\.\w+)?(?:\.\d+)?)',
            ).firstMatch(output);
            final version = versionMatch?.group(1) ?? output;

            // Save git path with version
            try {
              await ref
                  .read(configProvider.notifier)
                  .setGitExecutablePath(selectedPath, version: version);
            } catch (e) {
              if (!context.mounted) return;
              NotificationService.showError(
                context,
                'Failed to save git executable path: $e',
              );
              return;
            }
          } else {
            // Not git - show error
            if (!context.mounted) return;
            showDialog(
              context: context,
              builder: (dialogContext) => BaseDialog(
                title: l10n.invalidGitExecutable,
                onSubmit: () => Navigator.of(dialogContext).pop(),
                content: BaseLabel(
                  l10n.invalidGitExecutableMessage(
                    selectedPath,
                    output,
                    output,
                  ),
                  role: TextRole.body,
                ),
                actions: [
                  // A result sheet with nothing to answer: acknowledging it
                  // completes it, which is what onSubmit fires too.
                  DialogAction(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    label: l10n.ok,
                    role: DialogActionRole.affirmative,
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
              onSubmit: () => Navigator.of(dialogContext).pop(),
              content: BaseLabel(
                l10n.executionFailedMessage(
                  selectedPath,
                  processResult.stderr.toString(),
                ),
                role: TextRole.body,
              ),
              actions: [
                // Likewise a result sheet: acknowledging it is all there is.
                DialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  label: l10n.ok,
                  role: DialogActionRole.affirmative,
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
              onSubmit: () => Navigator.of(dialogContext).pop(),
              content: BaseLabel(
                l10n.validationErrorMessage(selectedPath, e.toString()),
                role: TextRole.body,
              ),
              actions: [
                // Likewise a result sheet: acknowledging it is all there is.
                DialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  label: l10n.ok,
                  role: DialogActionRole.affirmative,
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

    final result = await FilePicker.pickFiles(
      dialogTitle: l10n.selectTextEditor,
      type: Platform.isWindows ? FileType.custom : FileType.any,
      // .cmd/.bat wrappers are the only entry point for CLI-installed editors
      // (e.g. Scoop's code.cmd), which EditorLauncherService prefers.
      allowedExtensions: Platform.isWindows ? ['exe', 'cmd', 'bat'] : null,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;

      // Verify the selection exists. macOS GUI editors are `.app` bundle
      // directories, which File.exists() never reports as present.
      final exists =
          await File(selectedPath).exists() ||
          (Platform.isMacOS && await Directory(selectedPath).exists());
      if (!exists) {
        if (context.mounted) {
          _showError(context, l10n.selectedFileDoesNotExist);
        }
        return;
      }

      final fileName = selectedPath
          .split(Platform.pathSeparator)
          .last
          .toLowerCase();

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
      final isKnownEditor = knownEditors.any(
        (editor) =>
            fileName == editor || fileName.contains(editor.split('.')[0]),
      );

      if (!isKnownEditor) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => BaseDialog(
              title: l10n.unknownTextEditor,
              onSubmit: () async {
                Navigator.of(dialogContext).pop();
                await ref
                    .read(configProvider.notifier)
                    .setTextEditor(selectedPath, version: version);
              },
              content: BaseLabel(
                l10n.unknownTextEditorMessage(fileName),
                role: TextRole.body,
              ),
              actions: [
                DialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  label: l10n.cancel,
                  role: DialogActionRole.dismissive,
                ),
                DialogAction(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await ref
                        .read(configProvider.notifier)
                        .setTextEditor(selectedPath, version: version);
                  },
                  label: l10n.useAnyway,
                  role: DialogActionRole.affirmative,
                ),
              ],
            ),
          );
        }
        return;
      }

      // File passed validation - set it
      await ref
          .read(configProvider.notifier)
          .setTextEditor(selectedPath, version: version);
    }
  }

  Future<void> _selectDiffTool(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.pickFiles(
      dialogTitle: l10n.selectDiffTool,
      type: Platform.isWindows ? FileType.custom : FileType.any,
      // .cmd/.bat wrappers are the only entry point for CLI-installed tools
      // (e.g. Scoop's code.cmd), which DiffToolService already resolves.
      allowedExtensions: Platform.isWindows ? ['exe', 'cmd', 'bat'] : null,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;

      // Verify file exists
      final file = File(selectedPath);
      if (!await file.exists()) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Selected file does not exist',
          );
        }
        return;
      }

      // Detect version
      final version = await VersionDetector.detectVersion(selectedPath);

      // Try to match with known diff tool types
      final fileName = selectedPath
          .split(Platform.pathSeparator)
          .last
          .toLowerCase();
      DiffToolType? detectedType;

      for (final type in DiffToolType.values) {
        if (type == DiffToolType.custom) continue;
        final name = type.name.toLowerCase();
        if (fileName.contains(name) ||
            fileName.contains(
              type.displayName.toLowerCase().replaceAll(' ', ''),
            )) {
          detectedType = type;
          break;
        }
      }

      // If no match found, use custom
      detectedType ??= DiffToolType.custom;

      try {
        await ref
            .read(configProvider.notifier)
            .setDiffTool(detectedType, path: selectedPath, version: version);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to save diff tool: $e',
          );
        }
      }
    }
  }

  Future<void> _selectMergeTool(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.pickFiles(
      dialogTitle: l10n.selectMergeTool,
      type: Platform.isWindows ? FileType.custom : FileType.any,
      // .cmd/.bat wrappers are the only entry point for CLI-installed tools
      // (e.g. Scoop's code.cmd), which DiffToolService already resolves.
      allowedExtensions: Platform.isWindows ? ['exe', 'cmd', 'bat'] : null,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;

      // Verify file exists
      final file = File(selectedPath);
      if (!await file.exists()) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Selected file does not exist',
          );
        }
        return;
      }

      // Detect version
      final version = await VersionDetector.detectVersion(selectedPath);

      // Try to match with known merge tool types
      final fileName = selectedPath
          .split(Platform.pathSeparator)
          .last
          .toLowerCase();
      DiffToolType? detectedType;

      for (final type in DiffToolType.values) {
        if (type == DiffToolType.custom) continue;
        final name = type.name.toLowerCase();
        if (fileName.contains(name) ||
            fileName.contains(
              type.displayName.toLowerCase().replaceAll(' ', ''),
            )) {
          detectedType = type;
          break;
        }
      }

      // If no match found, use custom
      detectedType ??= DiffToolType.custom;

      try {
        await ref
            .read(configProvider.notifier)
            .setMergeTool(detectedType, path: selectedPath, version: version);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(
            context,
            'Failed to save merge tool: $e',
          );
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
        await ref
            .read(configProvider.notifier)
            .setGitExecutablePath(gitPath, version: version);
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(
          context,
          'Failed to save git executable path: $e',
        );
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
        await ref
            .read(configProvider.notifier)
            .setDiffTool(
              diffTool.type,
              path: diffTool.executablePath,
              version: version,
            );
        await ref
            .read(configProvider.notifier)
            .setMergeTool(
              diffTool.type,
              path: diffTool.executablePath,
              version: version,
            );
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(
          context,
          'Failed to save diff/merge tool settings: $e',
        );
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
        await ref
            .read(configProvider.notifier)
            .setTextEditor(editorPath, version: version);
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(
          context,
          'Failed to save text editor settings: $e',
        );
        return;
      }
    }
  }

  Future<void> _editUserName(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final git = ref.read(gitConfigProvider);
    // The field owns its controller. One created here would have to outlive
    // the dialog's exit transition, and disposing it once showDialog's future
    // completes - which is when that transition starts - rebuilt the outgoing
    // dialog against a disposed controller. The typed text arrives through
    // onChanged instead.
    var name = git.defaultUserName ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.defaultUserName,
        icon: IconRole.user,
        onSubmit: () => Navigator.of(dialogContext).pop(name.trim()),
        content: BaseTextField(
          initialValue: name,
          onChanged: (value) => name = value,
          autofocus: true,
          label: l10n.userName,
          hintText: l10n.userNameHint,
          prefixIcon: IconRole.user,
        ),
        actions: [
          DialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: l10n.cancel,
            role: DialogActionRole.dismissive,
          ),
          // Clearing the stored default is a second way to leave with a
          // result - the opposite one - not the way this dialog is asking
          // about, so it is a peer of saving rather than a second primary.
          DialogAction(
            onPressed: () {
              ref.read(configProvider.notifier).setDefaultUserName(null);
              Navigator.of(dialogContext).pop();
            },
            label: l10n.clear,
            role: DialogActionRole.neutral,
          ),
          DialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(name.trim()),
            label: l10n.save,
            role: DialogActionRole.affirmative,
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
    // See _editUserName: the field owns its controller so nothing outlives it.
    var email = git.defaultUserEmail ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.defaultUserEmail,
        icon: IconRole.at,
        onSubmit: () => Navigator.of(dialogContext).pop(email.trim()),
        content: BaseTextField(
          initialValue: email,
          onChanged: (value) => email = value,
          autofocus: true,
          label: l10n.email,
          hintText: l10n.emailHint,
          prefixIcon: IconRole.at,
        ),
        actions: [
          DialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: l10n.cancel,
            role: DialogActionRole.dismissive,
          ),
          // As above: clearing the stored default is the opposite outcome to
          // saving one, and a peer of it.
          DialogAction(
            onPressed: () {
              ref.read(configProvider.notifier).setDefaultUserEmail(null);
              Navigator.of(dialogContext).pop();
            },
            label: l10n.clear,
            role: DialogActionRole.neutral,
          ),
          DialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(email.trim()),
            label: l10n.save,
            role: DialogActionRole.affirmative,
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ref.read(configProvider.notifier).setDefaultUserEmail(result);
    }
  }

  Future<void> _editCommitHistoryLimit(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.read(historyConfigProvider);
    // See _editUserName: the field owns its controller so nothing outlives it.
    var limit = history.defaultCommitLimit.toString();

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: l10n.defaultCommitLimit,
        icon: IconRole.listNumbers,
        onSubmit: () {
          final value = int.tryParse(limit);
          if (value != null && value > 0) {
            Navigator.of(dialogContext).pop(value);
          }
        },
        content: BaseTextField(
          initialValue: limit,
          onChanged: (value) => limit = value,
          autofocus: true,
          label: l10n.commits,
          hintText: l10n.commitsHint,
          prefixIcon: IconRole.listNumbers,
        ),
        actions: [
          DialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: l10n.cancel,
            role: DialogActionRole.dismissive,
          ),
          DialogAction(
            onPressed: () {
              final value = int.tryParse(limit);
              if (value != null && value > 0) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            label: l10n.save,
            role: DialogActionRole.affirmative,
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
        icon: IconRole.warning,
        variant: DialogVariant.destructive,
        content: BaseLabel(l10n.resetSettingsMessage, role: TextRole.body),
        actions: [
          DialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: l10n.cancel,
            role: DialogActionRole.dismissive,
          ),
          DialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: l10n.reset,
            role: DialogActionRole.destructive,
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
