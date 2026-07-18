import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
      icon: PhosphorIconsRegular.gitDiff,
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
                      BodyMediumLabel(l10n.preferredDiffTool),
                      BodySmallLabel(
                        tools.customDiffToolPath ?? l10n.diffToolNotSet,
                        color: tools.customDiffToolPath == null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      if (tools.customDiffToolVersion != null) ...[
                        const SizedBox(height: AppTheme.paddingXS),
                        BodySmallLabel(
                          l10n.version(tools.customDiffToolVersion!),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tools.customDiffToolPath != null)
                        BaseIconButton(
                          icon: PhosphorIconsRegular.x,
                          tooltip: l10n.clear,
                          size: ButtonSize.small,
                          onPressed: () async {
                            await ref.read(configProvider.notifier).setCustomDiffToolPath(null, version: null);
                            onShowSuccess(l10n.diffToolCleared);
                          },
                        ),
                      BaseIconButton(
                        icon: PhosphorIconsRegular.folder,
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
                      BodyMediumLabel(l10n.preferredMergeTool),
                      BodySmallLabel(
                        tools.customMergeToolPath ?? l10n.mergeToolNotSet,
                        color: tools.customMergeToolPath == null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      if (tools.customMergeToolVersion != null) ...[
                        const SizedBox(height: AppTheme.paddingXS),
                        BodySmallLabel(
                          l10n.version(tools.customMergeToolVersion!),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tools.customMergeToolPath != null)
                        BaseIconButton(
                          icon: PhosphorIconsRegular.x,
                          tooltip: l10n.clear,
                          size: ButtonSize.small,
                          onPressed: () async {
                            await ref.read(configProvider.notifier).setCustomMergeToolPath(null, version: null);
                            onShowSuccess(l10n.mergeToolCleared);
                          },
                        ),
                      BaseIconButton(
                        icon: PhosphorIconsRegular.folder,
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
            content: BodyMediumLabel(l10n.loadingAvailableTools),
          ),
          error: (error, stack) => BaseListItem(
            leading: Icon(
              PhosphorIconsRegular.warning,
              color: Theme.of(context).colorScheme.error,
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BodyMediumLabel(l10n.failedToLoadTools(error)),
                BodySmallLabel(error.toString()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
