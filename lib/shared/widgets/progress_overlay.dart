import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_card.dart';
import '../../core/services/progress_service.dart';

/// Global progress overlay that shows when operations are in progress
class ProgressOverlay extends ConsumerWidget {
  const ProgressOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    if (progress == null) {
      return const SizedBox.shrink();
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
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingL),
            child: BaseCard(
              content: Container(
                constraints: const BoxConstraints(
                  minWidth: 400,
                  maxWidth: 500,
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Operation name
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.circleNotch,
                        size: 24,
                      ),
                      const SizedBox(width: AppTheme.paddingM),
                      Expanded(
                        child: TitleLargeLabel(progress.operationName),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.paddingL),

                  // Progress bar
                  if (!progress.isIndeterminate) ...[
                    LinearProgressIndicator(
                      value: progress.progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: AppTheme.paddingM),
                    // Progress text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BodyMediumLabel('${progress.currentStep} of ${progress.totalSteps}'),
                        BodyMediumLabel('${(progress.progress * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                  ] else ...[
                    LinearProgressIndicator(
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],

                  // Status message
                  if (progress.statusMessage != null) ...[
                    const SizedBox(height: AppTheme.paddingM),
                    BodySmallLabel(
                      progress.statusMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

