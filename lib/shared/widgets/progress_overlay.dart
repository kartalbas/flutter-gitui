import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

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
            IgnorePointer(
              child: LinearProgressIndicator(
                minHeight: 3,
                value: progress.isIndeterminate || progress.totalSteps <= 0
                    ? null
                    : progress.progress,
              ),
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

                    // Progress bar
                    if (!progress.isIndeterminate) ...[
                      LinearProgressIndicator(
                        value: progress.progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
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
                      LinearProgressIndicator(
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
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
