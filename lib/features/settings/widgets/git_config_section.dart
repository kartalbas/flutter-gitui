import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_list_item.dart';
import 'settings_section.dart';
import '../../../shared/components/base_layout.dart';

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
      icon: IconRole.gitBranch,
      children: [
        // Tool auto-detection button (Windows and Linux)
        if (onDetectTools != null) ...[
          BaseInset(
            all: Inset.normal,
            child: BaseButton(
              label: l10n.searchToolsAutoDetect,
              variant: ButtonVariant.primary,
              leadingIcon: IconRole.magnifyingGlass,
              onPressed: onDetectTools,
              fullWidth: true,
            ),
          ),
          const BaseSeparator(),
        ],
        BaseListItem(
          // The row's own mark. The prominent scale is what a bare `Icon`
          // rendered at under the row's ambient icon theme, and the neutral
          // tone leaves the colour to the row, as before.
          leading: const BaseIcon(
            IconRole.fileCode,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.gitExecutablePath, role: TextRole.body),
              // Tone.invalid, not Tone.danger: an unset executable destroys
              // nothing, it is a value the user must supply before the
              // feature works.
              BaseLabel(
                git.executablePath ?? l10n.gitExecutableNotSet,
                role: TextRole.detail,
                tone: git.executablePath == null ? Tone.invalid : Tone.neutral,
              ),
              if (git.gitVersion != null) ...[
                const BaseGap(Proximity.hairline),
                BaseLabel(
                  l10n.gitVersion(git.gitVersion!),
                  role: TextRole.detail,
                  tone: Tone.accent,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (git.executablePath != null)
                BaseIconButton(
                  icon: IconRole.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref
                        .read(configProvider.notifier)
                        .setGitExecutablePath(null, version: null);
                  },
                ),
              BaseIconButton(
                icon: IconRole.folder,
                tooltip: l10n.browse,
                onPressed: onSelectGitExecutable,
              ),
            ],
          ),
        ),
        const BaseSeparator(),
        BaseListItem(
          leading: const BaseIcon(
            IconRole.textT,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.preferredTextEditor, role: TextRole.body),
              BaseLabel(
                tools.textEditor ?? l10n.textEditorNotSet,
                role: TextRole.detail,
                tone: tools.textEditor == null ? Tone.invalid : Tone.neutral,
              ),
              if (tools.textEditorVersion != null) ...[
                const BaseGap(Proximity.hairline),
                BaseLabel(
                  l10n.version(tools.textEditorVersion!),
                  role: TextRole.detail,
                  tone: Tone.accent,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tools.textEditor != null)
                BaseIconButton(
                  icon: IconRole.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref
                        .read(configProvider.notifier)
                        .setTextEditor(null, version: null);
                  },
                ),
              BaseIconButton(
                icon: IconRole.folder,
                tooltip: l10n.browse,
                onPressed: onSelectTextEditor,
              ),
            ],
          ),
        ),
        const BaseSeparator(),
        BaseListItem(
          leading: const BaseIcon(
            IconRole.gitDiff,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.diffToolTitle, role: TextRole.body),
              BaseLabel(
                tools.diffTool?.displayName ?? l10n.diffToolNotSet,
                role: TextRole.detail,
                tone: tools.diffTool == null ? Tone.invalid : Tone.neutral,
              ),
              if (tools.diffToolVersion != null) ...[
                const BaseGap(Proximity.hairline),
                BaseLabel(
                  l10n.version(tools.diffToolVersion!),
                  role: TextRole.detail,
                  tone: Tone.accent,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tools.diffTool != null)
                BaseIconButton(
                  icon: IconRole.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref.read(configProvider.notifier).setDiffTool(null);
                  },
                ),
              BaseIconButton(
                icon: IconRole.folder,
                tooltip: l10n.browse,
                onPressed: onSelectDiffTool,
              ),
            ],
          ),
        ),
        const BaseSeparator(),
        BaseListItem(
          leading: const BaseIcon(
            IconRole.gitMerge,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.mergeToolTitle, role: TextRole.body),
              BaseLabel(
                tools.mergeTool?.displayName ?? l10n.mergeToolNotSet,
                role: TextRole.detail,
                tone: tools.mergeTool == null ? Tone.invalid : Tone.neutral,
              ),
              if (tools.mergeToolVersion != null) ...[
                const BaseGap(Proximity.hairline),
                BaseLabel(
                  l10n.version(tools.mergeToolVersion!),
                  role: TextRole.detail,
                  tone: Tone.accent,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tools.mergeTool != null)
                BaseIconButton(
                  icon: IconRole.x,
                  tooltip: l10n.clear,
                  size: ButtonSize.small,
                  onPressed: () {
                    ref.read(configProvider.notifier).setMergeTool(null);
                  },
                ),
              BaseIconButton(
                icon: IconRole.folder,
                tooltip: l10n.browse,
                onPressed: onSelectMergeTool,
              ),
            ],
          ),
        ),
        const BaseSeparator(),
        BaseListItem(
          leading: const BaseIcon(IconRole.user, scale: ControlScale.prominent),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.defaultUserName, role: TextRole.body),
              BaseLabel(
                git.defaultUserName ?? l10n.userNameNotSet,
                role: TextRole.detail,
                tone: git.defaultUserName == null ? Tone.invalid : Tone.neutral,
              ),
            ],
          ),
          trailing: BaseIconButton(
            icon: IconRole.pencil,
            tooltip: l10n.edit,
            onPressed: onEditUserName,
          ),
        ),
        BaseListItem(
          leading: const BaseIcon(IconRole.at, scale: ControlScale.prominent),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.defaultUserEmail, role: TextRole.body),
              BaseLabel(
                git.defaultUserEmail ?? l10n.userEmailNotSet,
                role: TextRole.detail,
                tone: git.defaultUserEmail == null
                    ? Tone.invalid
                    : Tone.neutral,
              ),
            ],
          ),
          trailing: BaseIconButton(
            icon: IconRole.pencil,
            tooltip: l10n.edit,
            onPressed: onEditUserEmail,
          ),
        ),
      ],
    );
  }
}
