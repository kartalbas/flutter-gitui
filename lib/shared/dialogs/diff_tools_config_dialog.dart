import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        DialogRouteSpec,
        IconRole,
        Inset,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;
import '../components/base_dialog.dart';
import '../components/base_progress.dart';

import '../../generated/app_localizations.dart';
import '../components/base_badge.dart';
import '../components/base_label.dart';
import '../components/base_card.dart';
import '../theme/app_theme.dart';
import '../../core/diff/diff_providers.dart';
import '../../core/diff/models/diff_tool.dart';
import '../../core/config/config_providers.dart';
import '../components/base_layout.dart';
import '../widgets/empty_state.dart';
import '../../core/services/notification_service.dart';

/// One standing statement about the whole dialog, drawn by the skin.
///
/// The same move the bisect and merge dialogs already made: a tinted fill, a
/// corner, a 16 dp inset, a mark and a line of words are `surfaces.banner` —
/// *something about this whole surface needs saying* — so the hand-painted
/// container leaves whole and its corner leaves with it.
Widget _banner(BuildContext context, BannerSpec spec) => SkinScope.render(
  context,
  (Skin skin, BuildContext inner) => skin.surfaces.banner(inner, spec),
);

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
        loading: () => const BaseProgress.block(),
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
          // How many tools were found and what to do about them, said once
          // and standing while the dialog is open: `surfaces.banner`.
          //
          // The fill and the mark used to disagree. The mark said `info` and
          // the box under it was painted `surfaceContainerHighest` — the
          // scheme's role for "no particular meaning" — so the surface
          // contradicted the very thing the glyph on it claimed. A tone says
          // it once and the member paints the container AND the foreground
          // that goes on it as one measured pairing, which is the half no
          // hand-painted copy of this ever stated.
          //
          // Louder than it was, in every part, and deliberately: the 8 dp
          // corner goes to the member's square 0, the quiet box becomes a
          // full-strength `primaryContainer` strip, the words rise from
          // `detail` to the banner's `titleMedium`, and the 20 dp mark grows
          // to the ambient 24. The volume is the repair rather than a side
          // effect - a notice worth a standing mark was being whispered on a
          // meaningless fill, and the member states it at the one strength
          // every previously converted notice already uses.
          _banner(
            context,
            BannerSpec(
              tone: Tone.info,
              icon: IconRole.info,
              title: AppLocalizations.of(
                context,
              )!.configureYourPreferredTools(tools.length),
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
            // That this tool is on the machine is a mark riding on the tool's
            // row: `surfaces.badge`, through the facade the application
            // already names its badges in.
            //
            // The wait recorded here was stale rather than open. It said the
            // badge's measure and its check mark were held until a member
            // owned "a badge's measure and the mark inside it" — that member
            // ships, and `BaseBadge` has been its facade since P5: a wash of
            // the tone, the tone as foreground, and a padding, a glyph size, a
            // type step and a corner that move together per `ControlScale`,
            // which is exactly why this pill could not convert one half at a
            // time. `small` is the rung the hand-painted copy was aiming at —
            // its 8 dp across is the compact rung's own inset to the pixel.
            if (tool.isAvailable)
              BaseBadge(
                label: AppLocalizations.of(context)!.available,
                variant: BadgeVariant.primary,
                size: BadgeSize.small,
                icon: IconRole.check,
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
      NotificationService.showSuccess(
        context,
        AppLocalizations.of(context)!.diffMergeToolSettingsSaved,
      );
    }
  }
}

/// Show diff tools configuration dialog
Future<void> showDiffToolsConfigDialog(BuildContext context) {
  return Overlays.dialogFrom(
    context,
    route: DialogRouteSpec(
      title: AppLocalizations.of(context)!.configureDiffMergeTools,
    ),
    builder: (context) => const DiffToolsConfigDialog(),
  );
}
