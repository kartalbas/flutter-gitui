import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_list_item.dart';
import 'settings_section.dart';

/// Git configuration section for settings screen
class GitConfigSection extends ConsumerWidget {
  final VoidCallback onSelectGitExecutable;
  final VoidCallback onSelectTextEditor;
  final VoidCallback? onDetectTools; // Auto-detect all tools
  final VoidCallback onSelectDiffTool; // File picker for diff tool
  final VoidCallback onSelectMergeTool; // File picker for merge tool
  final VoidCallback onEditUserName;
  final VoidCallback onEditUserEmail;

  const GitConfigSection({
    super.key,
    required this.onSelectGitExecutable,
    required this.onSelectTextEditor,
    this.onDetectTools,
    required this.onSelectDiffTool,
    required this.onSelectMergeTool,
    required this.onEditUserName,
    required this.onEditUserEmail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final git = ref.watch(gitConfigProvider);
    final tools = ref.watch(toolsConfigProvider);

    return SettingsSection(
      title: l10n.gitConfiguration,
      icon: PhosphorIconsRegular.gitBranch,
      children: [
        // Tool auto-detection button (Windows and Linux)
        if (onDetectTools != null) ...[
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            child: BaseButton(
              label: l10n.searchToolsAutoDetect,
              variant: ButtonVariant.primary,
              leadingIcon: PhosphorIconsRegular.magnifyingGlass,
              onPressed: onDetectTools,
              fullWidth: true,
            ),
          ),
          const Divider(),
        ],
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.fileCode),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.gitExecutablePath),
              BodySmallLabel(
                git.executablePath ?? l10n.gitExecutableNotSet,
                color: git.executablePath == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              if (git.gitVersion != null) ...[
                const SizedBox(height: AppTheme.paddingXS),
                BodySmallLabel(
                  l10n.gitVersion(git.gitVersion!),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (git.executablePath != null)
                BaseIconButton(
                  icon: PhosphorIconsRegular.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref
                        .read(configProvider.notifier)
                        .setGitExecutablePath(null, version: null);
                  },
                ),
              BaseIconButton(
                icon: PhosphorIconsRegular.folder,
                tooltip: l10n.browse,
                onPressed: onSelectGitExecutable,
              ),
            ],
          ),
        ),
        const Divider(),
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.textT),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.preferredTextEditor),
              BodySmallLabel(
                tools.textEditor ?? l10n.textEditorNotSet,
                color: tools.textEditor == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              if (tools.textEditorVersion != null) ...[
                const SizedBox(height: AppTheme.paddingXS),
                BodySmallLabel(
                  l10n.version(tools.textEditorVersion!),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tools.textEditor != null)
                BaseIconButton(
                  icon: PhosphorIconsRegular.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref
                        .read(configProvider.notifier)
                        .setTextEditor(null, version: null);
                  },
                ),
              BaseIconButton(
                icon: PhosphorIconsRegular.folder,
                tooltip: l10n.browse,
                onPressed: onSelectTextEditor,
              ),
            ],
          ),
        ),
        const Divider(),
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.gitDiff),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.diffToolTitle),
              BodySmallLabel(
                tools.diffTool?.displayName ?? l10n.diffToolNotSet,
                color: tools.diffTool == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              if (tools.diffToolVersion != null) ...[
                const SizedBox(height: AppTheme.paddingXS),
                BodySmallLabel(
                  l10n.version(tools.diffToolVersion!),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tools.diffTool != null)
                BaseIconButton(
                  icon: PhosphorIconsRegular.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref.read(configProvider.notifier).setDiffTool(null);
                  },
                ),
              BaseIconButton(
                icon: PhosphorIconsRegular.folder,
                tooltip: l10n.browse,
                onPressed: onSelectDiffTool,
              ),
            ],
          ),
        ),
        const Divider(),
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.gitMerge),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.mergeToolTitle),
              BodySmallLabel(
                tools.mergeTool?.displayName ?? l10n.mergeToolNotSet,
                color: tools.mergeTool == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              if (tools.mergeToolVersion != null) ...[
                const SizedBox(height: AppTheme.paddingXS),
                BodySmallLabel(
                  l10n.version(tools.mergeToolVersion!),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tools.mergeTool != null)
                BaseIconButton(
                  icon: PhosphorIconsRegular.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref.read(configProvider.notifier).setMergeTool(null);
                  },
                ),
              BaseIconButton(
                icon: PhosphorIconsRegular.folder,
                tooltip: l10n.browse,
                onPressed: onSelectMergeTool,
              ),
            ],
          ),
        ),
        const Divider(),
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.user),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.defaultUserName),
              BodySmallLabel(
                git.defaultUserName ?? l10n.userNameNotSet,
                color: git.defaultUserName == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ],
          ),
          trailing: BaseIconButton(
            icon: PhosphorIconsRegular.pencil,
            tooltip: l10n.edit,
            onPressed: onEditUserName,
          ),
        ),
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.at),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.defaultUserEmail),
              BodySmallLabel(
                git.defaultUserEmail ?? l10n.userEmailNotSet,
                color: git.defaultUserEmail == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ],
          ),
          trailing: BaseIconButton(
            icon: PhosphorIconsRegular.pencil,
            tooltip: l10n.edit,
            onPressed: onEditUserEmail,
          ),
        ),
      ],
    );
  }
}
