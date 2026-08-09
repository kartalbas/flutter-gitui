import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ControlScale,
        IconRole,
        Inset,
        ProgressExtent,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../theme/app_theme.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_layout.dart';
import '../components/base_card.dart';
import '../dialogs/background_activity_dialog.dart';
import '../../core/services/progress_service.dart';

/// The caption under the background activity line.
///
/// Deliberately small and low-contrast: it has to be readable when looked at
/// without competing with the content for attention, since it appears for work
/// the user did not start.
///
/// **Stays hand-painted, and the blocker is `chrome.shell` — not a missing
/// word.** What stood here argued that the strip could be re-composed in
/// application code out of `surfaces.badge` plus `surfaces.pressable`, and
/// that it could not be, because `BadgeSpec.icon` is a single LEADING mark
/// while this caret is trailing. That asked the wrong member. This strip is
/// not the application's to compose at all: [ProgressOverlay] is mounted by
/// the shell (`app_shell.dart`), and the contract already carries the whole
/// thing as `ShellSpec.activity` — `ActivitySpec` states operation,
/// currentStep, totalSteps, indeterminate and onShowDetail, which is exactly
/// the fact set this class renders and nothing more. The shipped Material
/// skin already contains the extraction, caret included, as
/// `_MaterialActivityLine` in
/// packages/gitui_skin_material/lib/src/facets/material_chrome.dart. So
/// nothing here waits for a vocabulary decision: the two corners, the strip's
/// inset and the caret's own 12 all die in one move, the moment `chrome
/// .shell` is wired and this widget states an `ActivitySpec` instead of
/// drawing one.
///
/// **The extraction has drifted from this copy, and that is worth knowing
/// before the swap rather than after it**, because nothing reaches it: the
/// member has no caller in `lib/` and no test in its own package, so no gate
/// compares the two. Measured today, `_MaterialActivityLine` writes the
/// caption at `labelMedium` where this one says [TextRole.detail]
/// (`bodySmall`), and hand-builds its bar at `minHeight: 3` — the thickness
/// the branch above deliberately gave up when it moved to `controls
/// .progress`, whose `inline` rung is Material's stock 4. Wiring the shell
/// without reconciling those two would silently take both back.
///
/// The 12 dp caret's own recorded blocker is gone, and it is recorded here so
/// it is not re-derived: it read "no `ControlScale` rung reaches it, the
/// smallest being 16", which is true of the ICON scale but not of a badge's
/// mark — the compact pill draws its glyph at 10. The member settles it
/// either way: the skin draws its own caret at `iconXS`, which is this 12.
class _BackgroundProgressLabel extends StatelessWidget {
  const _BackgroundProgressLabel({required this.progress});

  final ProgressInfo progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showsCount = !progress.isIndeterminate && progress.totalSteps > 0;
    final text = showsCount
        ? '${progress.operationName}… '
              '${progress.currentStep}/${progress.totalSteps}'
        : '${progress.operationName}…';

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppTheme.radiusS),
      ),
      // The count says how far the sweep got, not which repository is slow,
      // which already finished, or which failed and why. That is one click
      // away rather than absent.
      child: InkWell(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusS),
        ),
        onTap: () => showBackgroundActivityDialog(context),
        child: Padding(
          // Left alone deliberately: the caption reads at the ordinary
          // distance across, but down the page it is a thin strip floating
          // over the content, and no inset rung sits between "as close as
          // legible" and "barely set in". See the P3d report.
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingM,
            vertical: AppTheme.paddingXS,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BaseLabel(text, role: TextRole.detail, tone: Tone.muted),
              // The caption and the mark that says it can be opened are two
              // halves of one affordance.
              const BaseGap(Proximity.hairline),
              // Twelve, which `AppTheme.iconXS` documents as the size reserved
              // for a non-interactive inline indicator - and no `ControlScale`
              // rung reaches it, the smallest being 16. `BaseIcon` here would
              // grow this caret by a third inside a thin strip floating over
              // the user's content, which is the blame view's inset mistake
              // (#426) one axis over: a meaning rounded onto the nearest
              // available word. It is not waiting for a rung either: the
              // caret belongs to `ShellSpec.activity`, whose skin draws it
              // itself at its own `iconXS` - the same 12 - and decides on
              // `onShowDetail` alone whether there is anything to open.
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Global progress overlay that shows when operations run long enough for
/// the progress service to surface them
class ProgressOverlay extends ConsumerWidget {
  const ProgressOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    if (progress == null) {
      return const SizedBox.shrink();
    }

    // Background git commands must never steal input or attention, so they
    // get the thin activity line along the top edge that browsers and editors
    // use, instead of a dialog blocking the whole window (#288). Work the app
    // started by itself also carries a name and, where the total is known, a
    // count: an anonymous line cannot say what is running or whether it is
    // progressing at all.
    if (!progress.isBlocking) {
      return Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The line itself must not swallow clicks meant for the content
            // it floats over; only the caption is a target.
            //
            // The same `controls.progress` the blocking branch below already
            // calls, and the two were the odd pair of one file: that branch
            // argues in its own comment that "how thick a bar is and what its
            // ends look like is the language's arithmetic", and then this
            // branch went on hand-building a raw indicator at a 3 dp
            // thickness the application had picked. `ProgressExtent.inline`
            // is the rung whose own doc names this arrangement in as many
            // words — "inside a line of content: beside a label, inside a
            // button, ALONG AN EDGE" — and it is the same rung the blocking
            // card asks for, so one file now states one meaning once.
            // Material's answer for the rung is its stock indicator at the
            // M3 default 4 dp, so the strip floats one pixel thicker than
            // the hand-picked 3 it replaces — the same thickness the batch
            // dialog's bar already draws through this member.
            IgnorePointer(
              child: SkinScope.render(context, (Skin skin, BuildContext inner) {
                return skin.controls.progress(
                  inner,
                  fraction: progress.isIndeterminate || progress.totalSteps <= 0
                      ? null
                      : progress.progress,
                  extent: ProgressExtent.inline,
                );
              }),
            ),
            if (progress.operationName.isNotEmpty)
              _BackgroundProgressLabel(progress: progress),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Semi-transparent background
        ModalBarrier(
          dismissible: false,
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
        ),
        // Progress dialog
        Center(
          // The blocking card floats over the whole window and keeps
          // deliberately clear of its edges.
          child: BaseInset(
            all: Inset.roomy,
            child: BaseCard(
              content: Container(
                constraints: const BoxConstraints(minWidth: 400, maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Operation name
                    Row(
                      children: [
                        const BaseIcon(
                          IconRole.circleNotch,
                          scale: ControlScale.prominent,
                        ),
                        // The activity mark and the name of the work are
                        // members of one heading.
                        const BaseGap(Proximity.grouped),
                        Expanded(
                          child: BaseLabel(
                            progress.operationName,
                            role: TextRole.pageTitle,
                          ),
                        ),
                      ],
                    ),
                    // The heading and the measurement under it are two groups
                    // of one card.
                    const BaseGap(Proximity.separate),

                    // How far along the blocking work is, as
                    // `controls.progress`. The thickness and the corner are
                    // gone rather than converted: how thick a bar is and what
                    // its ends look like is the language's arithmetic, and an
                    // 8 dp bar with an 8 dp corner was this card deciding a
                    // length. `ProgressExtent.inline` is the rung the
                    // vocabulary defines as "inside a line of content", which
                    // is the arrangement here - the bar is one line of a
                    // column that also carries a heading, a readout and a
                    // status message. `block` would be the wrong word: it
                    // means "its own region, with nothing else competing for
                    // the space", and Material draws it as a centred ring,
                    // which would delete the linear read the "3 of 10 / 30 %"
                    // row underneath exists to spell out.
                    if (!progress.isIndeterminate) ...[
                      SkinScope.render(context, (
                        Skin skin,
                        BuildContext inner,
                      ) {
                        return skin.controls.progress(
                          inner,
                          fraction: progress.progress,
                          extent: ProgressExtent.inline,
                        );
                      }),
                      // The bar and the numbers that read it out belong to one
                      // group.
                      const BaseGap(Proximity.grouped),
                      // Progress text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          BaseLabel(
                            '${progress.currentStep} of ${progress.totalSteps}',
                            role: TextRole.body,
                          ),
                          BaseLabel(
                            '${(progress.progress * 100).toStringAsFixed(0)}%',
                            role: TextRole.body,
                          ),
                        ],
                      ),
                    ] else ...[
                      // The same member with no fraction, which is how the
                      // contract says "the end is unknowable" - each language
                      // then draws the indeterminate form it actually has,
                      // instead of this card implying a bar it cannot fill.
                      SkinScope.render(context, (
                        Skin skin,
                        BuildContext inner,
                      ) {
                        return skin.controls.progress(
                          inner,
                          extent: ProgressExtent.inline,
                        );
                      }),
                    ],

                    // Status message
                    if (progress.statusMessage != null) ...[
                      // The measurement and the line saying what it is doing
                      // right now belong to one group.
                      const BaseGap(Proximity.grouped),
                      BaseLabel(
                        progress.statusMessage!,
                        role: TextRole.detail,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
