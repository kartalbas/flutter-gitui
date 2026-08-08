import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/diff/diff_providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_button.dart';
import 'settings_section.dart';

/// Diff and merge tools section for settings screen
class DiffToolsSection extends ConsumerWidget {
  final VoidCallback onSelectCustomDiffTool;
  final VoidCallback onSelectCustomMergeTool;
  final void Function(String message) onShowSuccess;

  const DiffToolsSection({
    super.key,
    required this.onSelectCustomDiffTool,
    required this.onSelectCustomMergeTool,
    required this.onShowSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tools = ref.watch(toolsConfigProvider);
    final availableToolsAsync = ref.watch(availableDiffToolsProvider);

    return SettingsSection(
      title: l10n.diffAndMergeTools,
      icon: IconRole.gitDiff,
      children: [
        availableToolsAsync.when(
          data: (availableTools) {
            return Column(
              children: [
                BaseListItem(
                  leading: const Icon(PhosphorIconsRegular.magnifyingGlass),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(l10n.preferredDiffTool, role: TextRole.body),
                      // Tone.invalid, not Tone.danger: an unset tool path
                      // destroys nothing, it is a value the user must supply
                      // before the feature works.
                      BaseLabel(
                        tools.customDiffToolPath ?? l10n.diffToolNotSet,
                        role: TextRole.detail,
                        tone: tools.customDiffToolPath == null
                            ? Tone.invalid
                            : Tone.neutral,
                      ),
                      if (tools.customDiffToolVersion != null) ...[
                        const SizedBox(height: AppTheme.paddingXS),
                        BaseLabel(
                          l10n.version(tools.customDiffToolVersion!),
                          role: TextRole.detail,
                          tone: Tone.accent,
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tools.customDiffToolPath != null)
                        BaseIconButton(
                          icon: IconRole.x,
                          tooltip: l10n.clear,
                          size: ButtonSize.small,
                          onPressed: () async {
                            await ref
                                .read(configProvider.notifier)
                                .setCustomDiffToolPath(null, version: null);
                            onShowSuccess(l10n.diffToolCleared);
                          },
                        ),
                      BaseIconButton(
                        icon: IconRole.folder,
                        tooltip: l10n.browseForDiffTool,
                        onPressed: onSelectCustomDiffTool,
                      ),
                    ],
                  ),
                ),
                BaseListItem(
                  leading: const Icon(PhosphorIconsRegular.gitMerge),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(l10n.preferredMergeTool, role: TextRole.body),
                      BaseLabel(
                        tools.customMergeToolPath ?? l10n.mergeToolNotSet,
                        role: TextRole.detail,
                        tone: tools.customMergeToolPath == null
                            ? Tone.invalid
                            : Tone.neutral,
                      ),
                      if (tools.customMergeToolVersion != null) ...[
                        const SizedBox(height: AppTheme.paddingXS),
                        BaseLabel(
                          l10n.version(tools.customMergeToolVersion!),
                          role: TextRole.detail,
                          tone: Tone.accent,
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tools.customMergeToolPath != null)
                        BaseIconButton(
                          icon: IconRole.x,
                          tooltip: l10n.clear,
                          size: ButtonSize.small,
                          onPressed: () async {
                            await ref
                                .read(configProvider.notifier)
                                .setCustomMergeToolPath(null, version: null);
                            onShowSuccess(l10n.mergeToolCleared);
                          },
                        ),
                      BaseIconButton(
                        icon: IconRole.folder,
                        tooltip: l10n.browseForMergeTool,
                        onPressed: onSelectCustomMergeTool,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => BaseListItem(
            leading: const CircularProgressIndicator(),
            content: BaseLabel(l10n.loadingAvailableTools, role: TextRole.body),
          ),
          error: (error, stack) => BaseListItem(
            leading: Icon(
              PhosphorIconsRegular.warning,
              color: Theme.of(context).colorScheme.error,
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLabel(l10n.failedToLoadTools(error), role: TextRole.body),
                BaseLabel(error.toString(), role: TextRole.detail),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
