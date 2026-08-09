import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, NoticeSpec, Overlays, Proximity, TextRole, Tone;
import '../components/base_dialog.dart';

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_card.dart';
import '../theme/app_theme.dart';
import '../../core/diff/diff_providers.dart';
import '../../core/diff/models/diff_tool.dart';
import '../../core/config/config_providers.dart';
import '../components/base_layout.dart';
import '../widgets/empty_state.dart';

/// Dialog for configuring external diff/merge tools
class DiffToolsConfigDialog extends ConsumerStatefulWidget {
  const DiffToolsConfigDialog({super.key});

  @override
  ConsumerState<DiffToolsConfigDialog> createState() =>
      _DiffToolsConfigDialogState();
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
      icon: IconRole.gear,
      title: AppLocalizations.of(context)!.configureDiffMergeTools,
      onSubmit: _hasChanges ? _saveSettings : null,
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
        DialogAction(
          label: AppLocalizations.of(context)!.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: AppLocalizations.of(context)!.save,
          role: DialogActionRole.affirmative,
          enabled: _hasChanges,
          onPressed: _saveSettings,
        ),
      ],
    );
  }

  Widget _buildNoToolsFound(BuildContext context) {
    // The hero's colour is already the supporting foreground the empty-state
    // facade paints, so this is the one state here whose MARK could adopt it
    // (#430) - and the state's SHAPE is what stops it. `EmptyStateSpec` holds
    // a headline, one sentence and the ways out; this state says three things,
    // and the third ("install tools such as ...") is a hint rather than an
    // action, so the facade has no slot for it. Adopting would mean dropping a
    // line or promoting a hint into the action row, which is a change of
    // content rather than a rename. The size and the colour stay together
    // until the member grows a slot for the third line.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.noDiffToolsFound,
            role: TextRole.pageTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            AppLocalizations.of(context)!.noExternalDiffMergeToolsDetected,
            role: TextRole.body,
            align: TextAlign.center,
          ),
          const BaseGap(Proximity.grouped),
          BaseLabel(
            AppLocalizations.of(context)!.installToolsSuchAs,
            role: TextRole.detail,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    // The facade rather than a hand-built copy of it (#430). This column was
    // shaped exactly as the facade draws - hero, headline, sentence - and was
    // held back by one fact: the hero had no tone slot, so adopting it would
    // have turned a red failure mark grey. The hero carries a tone now
    // (#431), and the mark stays the failure colour because the state SAYS
    // failure. The `64` and the sentence's treatment go to the member with
    // it. `_buildNoToolsFound` above stays hand-rolled for its own reason:
    // its shape, not its colour.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(context)!.errorDetectingTools,
      message: error.toString(),
      tone: Tone.danger,
    );
  }

  Widget _buildToolsConfig(BuildContext context, List<DiffTool> tools) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: BaseInset(
              child: Row(
                children: [
                  // The mark of an ordinary notice, at the ordinary size: it
                  // belongs to the line beside it rather than standing over it.
                  const BaseIcon(IconRole.info),
                  const BaseGap(Proximity.related),
                  Expanded(
                    child: BaseLabel(
                      AppLocalizations.of(
                        context,
                      )!.configureYourPreferredTools(tools.length),
                      role: TextRole.detail,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const BaseGap(Proximity.separate),

          // Diff Tool Selection
          BaseLabel(
            AppLocalizations.of(context)!.diffTool,
            role: TextRole.sectionTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            AppLocalizations.of(context)!.usedForComparingFileChanges,
            role: TextRole.detail,
          ),
          const BaseGap(Proximity.grouped),

          RadioGroup<DiffToolType?>(
            groupValue: _selectedDiffTool,
            onChanged: (value) {
              setState(() {
                _selectedDiffTool = value;
                _hasChanges = true;
              });
            },
            child: Column(children: _toolOptions(context, tools)),
          ),

          const BaseGap(Proximity.separate),
          const BaseSeparator(),
          const BaseGap(Proximity.separate),

          // Merge Tool Selection
          BaseLabel(
            AppLocalizations.of(context)!.mergeTool,
            role: TextRole.sectionTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            AppLocalizations.of(context)!.usedForResolvingMergeConflicts,
            role: TextRole.detail,
          ),
          const BaseGap(Proximity.grouped),

          RadioGroup<DiffToolType?>(
            groupValue: _selectedMergeTool,
            onChanged: (value) {
              setState(() {
                _selectedMergeTool = value;
                _hasChanges = true;
              });
            },
            child: Column(children: _toolOptions(context, tools)),
          ),
        ],
      ),
    );
  }

  /// The tools as a run, with the closeness stated BETWEEN them.
  ///
  /// Each option used to carry its own bottom margin, which is a gap wearing a
  /// padding idiom: the space belongs between two options, not inside one, and
  /// the last option was left with a trailing margin nothing sat under.
  List<Widget> _toolOptions(BuildContext context, List<DiffTool> tools) =>
      <Widget>[
        for (int i = 0; i < tools.length; i++) ...<Widget>[
          if (i > 0) const BaseGap(Proximity.related),
          _buildToolOption(context, tools[i]),
        ],
      ];

  Widget _buildToolOption(BuildContext context, DiffTool tool) {
    return BaseCard(
      inset: Inset.none,
      content: RadioListTile<DiffToolType?>(
        value: tool.type,
        contentPadding: const EdgeInsets.all(AppTheme.paddingM),
        secondary: Icon(_getToolIcon(tool.type), size: 32),
        title: BaseLabel(tool.displayName, role: TextRole.itemTitle),
        subtitle: Row(
          children: [
            Expanded(
              child: BaseLabel(
                tool.executablePath,
                role: TextRole.detail,
                maxLines: 1,
              ),
            ),
            const BaseGap(Proximity.related),
            // Available badge
            if (tool.isAvailable)
              Container(
                // The badge's inset stays a literal: across it is `tight`
                // exactly, but its vertical 4 is on no `Inset` rung, and
                // rounding it up would grow the badge 8px taller. Its check
                // mark stays a literal beside it - 14 sits between two glyph
                // rungs the same way. Both wait for `surfaces.badge`, whose
                // skin owns a badge's measure and the mark inside it.
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.paddingS,
                  vertical: AppTheme.paddingXS,
                ),
                decoration: BoxDecoration(
                  // A 10% wash of the accent is the badge's FILL, not a
                  // foreground, so it is not a tone: no member can tint a
                  // surface from a `Tone` today. It waits for
                  // `surfaces.badge` with the badge's measure above.
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.check,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const BaseGap(Proximity.hairline),
                    BaseLabel(
                      AppLocalizations.of(context)!.available,
                      role: TextRole.micro,
                      tone: Tone.accent,
                    ),
                  ],
                ),
              ),
          ],
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
      // The settings are written: something that finished, and finished well.
      Overlays.notify(
        context,
        NoticeSpec(
          tone: Tone.success,
          title: AppLocalizations.of(context)!.diffMergeToolSettingsSaved,
        ),
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
