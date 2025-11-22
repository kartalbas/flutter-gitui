import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../components/base_dialog.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../components/base_card.dart';
import '../theme/app_theme.dart';
import '../../core/diff/diff_providers.dart';
import '../../core/diff/models/diff_tool.dart';
import '../../core/config/config_providers.dart';

/// Dialog for configuring external diff/merge tools
class DiffToolsConfigDialog extends ConsumerStatefulWidget {
  const DiffToolsConfigDialog({super.key});

  @override
  ConsumerState<DiffToolsConfigDialog> createState() => _DiffToolsConfigDialogState();
}

class _DiffToolsConfigDialogState extends ConsumerState<DiffToolsConfigDialog> {
  DiffToolType? _selectedDiffTool;
  DiffToolType? _selectedMergeTool;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Load current settings from config
    Future.microtask(() {
      final preferredDiff = ref.read(preferredDiffToolProvider);
      final preferredMerge = ref.read(preferredMergeToolProvider);
      setState(() {
        _selectedDiffTool = preferredDiff;
        _selectedMergeTool = preferredMerge;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableToolsAsync = ref.watch(availableDiffToolsProvider);

    return BaseDialog(
      icon: PhosphorIconsRegular.gear,
      title: AppLocalizations.of(context)!.configureDiffMergeTools,
      content: availableToolsAsync.when(
          data: (tools) {
            if (tools.isEmpty) {
              return _buildNoToolsFound(context);
            }
            return _buildToolsConfig(context, tools);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildError(context, error),
        ),
      actions: [
        BaseButton(
          label: AppLocalizations.of(context)!.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.save,
          variant: ButtonVariant.primary,
          onPressed: _hasChanges ? _saveSettings : null,
        ),
      ],
    );
  }

  Widget _buildNoToolsFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.noDiffToolsFound),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(AppLocalizations.of(context)!.noExternalDiffMergeToolsDetected, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.paddingM),
          BodySmallLabel(AppLocalizations.of(context)!.installToolsSuchAs, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.errorDetectingTools),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(error.toString(), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildToolsConfig(BuildContext context, List<DiffTool> tools) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.paddingS),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.info, size: 20),
                const SizedBox(width: AppTheme.paddingS),
                Expanded(
                  child: BodySmallLabel(AppLocalizations.of(context)!.configureYourPreferredTools(tools.length)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.paddingL),

          // Diff Tool Selection
          TitleMediumLabel(AppLocalizations.of(context)!.diffTool),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(AppLocalizations.of(context)!.usedForComparingFileChanges),
          const SizedBox(height: AppTheme.paddingM),

          RadioGroup<DiffToolType?>(
            groupValue: _selectedDiffTool,
            onChanged: (value) {
              setState(() {
                _selectedDiffTool = value;
                _hasChanges = true;
              });
            },
            child: Column(
              children: tools.map((tool) => _buildToolOption(context, tool)).toList(),
            ),
          ),

          const SizedBox(height: AppTheme.paddingL),
          const Divider(),
          const SizedBox(height: AppTheme.paddingL),

          // Merge Tool Selection
          TitleMediumLabel(AppLocalizations.of(context)!.mergeTool),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(AppLocalizations.of(context)!.usedForResolvingMergeConflicts),
          const SizedBox(height: AppTheme.paddingM),

          RadioGroup<DiffToolType?>(
            groupValue: _selectedMergeTool,
            onChanged: (value) {
              setState(() {
                _selectedMergeTool = value;
                _hasChanges = true;
              });
            },
            child: Column(
              children: tools.map((tool) => _buildToolOption(context, tool)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolOption(
    BuildContext context,
    DiffTool tool,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.paddingS),
      child: BaseCard(
        padding: EdgeInsets.zero,
        content: RadioListTile<DiffToolType?>(
        value: tool.type,
        contentPadding: const EdgeInsets.all(AppTheme.paddingM),
        secondary: Icon(
          _getToolIcon(tool.type),
          size: 32,
        ),
        title: TitleSmallLabel(tool.displayName),
        subtitle: Row(
          children: [
            Expanded(
              child: LabelMediumLabel(
                tool.executablePath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.paddingS),
            // Available badge
            if (tool.isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.paddingS,
                  vertical: AppTheme.paddingXS,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.check,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppTheme.paddingXS),
                    LabelMediumLabel(
                      AppLocalizations.of(context)!.available,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  IconData _getToolIcon(DiffToolType type) {
    switch (type) {
      case DiffToolType.vscode:
      case DiffToolType.vscodium:
      case DiffToolType.intellijIdea:
        return PhosphorIconsRegular.code;
      case DiffToolType.beyondCompare:
      case DiffToolType.kdiff3:
      case DiffToolType.meld:
      case DiffToolType.winMerge:
      case DiffToolType.diffMerge:
        return PhosphorIconsRegular.gitDiff;
      case DiffToolType.p4merge:
      case DiffToolType.tortoiseGitMerge:
      case DiffToolType.araxis:
        return PhosphorIconsRegular.gitMerge;
      case DiffToolType.vimdiff:
      case DiffToolType.xxdiff:
      case DiffToolType.opendiff:
        return PhosphorIconsRegular.terminal;
      case DiffToolType.custom:
        return PhosphorIconsRegular.gear;
    }
  }

  Future<void> _saveSettings() async {
    final configNotifier = ref.read(configProvider.notifier);

    if (_selectedDiffTool != null) {
      await configNotifier.setDiffTool(_selectedDiffTool);
    }

    if (_selectedMergeTool != null) {
      await configNotifier.setMergeTool(_selectedMergeTool);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.diffMergeToolSettingsSaved)),
      );
    }
  }
}

/// Show diff tools configuration dialog
Future<void> showDiffToolsConfigDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const DiffToolsConfigDialog(),
  );
}

