import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../generated/app_localizations.dart';
import '../services/batch_operations_service.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';

/// Progress state for a single repository operation
class RepositoryProgress {
  final WorkspaceRepository repository;
  final String status;
  final bool completed;
  final bool success;
  final String? error;

  const RepositoryProgress({
    required this.repository,
    required this.status,
    this.completed = false,
    this.success = false,
    this.error,
  });

  RepositoryProgress copyWith({
    String? status,
    bool? completed,
    bool? success,
    String? error,
  }) {
    return RepositoryProgress(
      repository: repository,
      status: status ?? this.status,
      completed: completed ?? this.completed,
      success: success ?? this.success,
      error: error ?? this.error,
    );
  }
}

/// Dialog showing progress of batch operations
class BatchOperationProgressDialog extends StatefulWidget {
  final String title;
  final List<WorkspaceRepository> repositories;
  final Future<List<BatchOperationResult>> Function(
    void Function(WorkspaceRepository, int, int, String)?
  ) operation;

  const BatchOperationProgressDialog({
    super.key,
    required this.title,
    required this.repositories,
    required this.operation,
  });

  @override
  State<BatchOperationProgressDialog> createState() => _BatchOperationProgressDialogState();
}

class _BatchOperationProgressDialogState extends State<BatchOperationProgressDialog> {
  late Map<String, RepositoryProgress> _progress;
  bool _isRunning = true;
  List<BatchOperationResult>? _results;
  int _successCount = 0;
  int _failureCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize progress for all repositories with default status
    _progress = {
      for (final repo in widget.repositories)
        repo.path: RepositoryProgress(
          repository: repo,
          status: 'In progress...',
        ),
    };

    // Start the operation
    _runOperation();
  }

  Future<void> _runOperation() async {
    try {
      final results = await widget.operation(_onProgress);

      if (mounted) {
        setState(() {
          _results = results;
          _isRunning = false;
          _successCount = results.where((r) => r.success).length;
          _failureCount = results.where((r) => !r.success).length;

          // Update final progress for all repositories
          final l10n = AppLocalizations.of(context)!;
          for (final result in results) {
            _progress[result.repository.path] = RepositoryProgress(
              repository: result.repository,
              status: result.success
                  ? (result.message ?? l10n.completed)
                  : (result.error ?? l10n.failed),
              completed: true,
              success: result.success,
              error: result.error,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  void _onProgress(
    WorkspaceRepository repository,
    int current,
    int total,
    String status,
  ) {
    if (mounted) {
      setState(() {
        _progress[repository.path] = _progress[repository.path]!.copyWith(
          status: status,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final completedCount = _progress.values.where((p) => p.completed).length;
    final totalCount = widget.repositories.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return BaseDialog(
      title: widget.title,
      icon: _isRunning
          ? PhosphorIconsRegular.spinner
          : _failureCount == 0
              ? PhosphorIconsRegular.checkCircle
              : PhosphorIconsRegular.warningCircle,
      variant: DialogVariant.normal,
      barrierDismissible: !_isRunning,
      maxWidth: 600,
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall progress
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _isRunning ? null : progress,
                    minHeight: AppTheme.paddingS,
                    borderRadius: BorderRadius.circular(AppTheme.paddingXS),
                  ),
                ),
                const SizedBox(width: AppTheme.paddingM),
                TitleMediumLabel(
                  '$completedCount / $totalCount',
                ),
              ],
            ),

            const SizedBox(height: AppTheme.paddingL),

            // Summary (shown when completed)
            if (!_isRunning) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: _failureCount == 0
                      ? AppTheme.gitAdded.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: _failureCount == 0 ? AppTheme.gitAdded : Theme.of(context).colorScheme.secondary,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _failureCount == 0
                          ? PhosphorIconsBold.checkCircle
                          : PhosphorIconsBold.warningCircle,
                      color: _failureCount == 0 ? AppTheme.gitAdded : Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: AppTheme.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleSmallLabel(
                            _failureCount == 0
                                ? l10n.operationsCompleted(_successCount, _successCount + _failureCount)
                                : l10n.operationsCompletedWithErrors(_successCount, _failureCount, _successCount + _failureCount),
                          ),
                          const SizedBox(height: AppTheme.paddingXS),
                          BodySmallLabel(
                            l10n.successCount(_successCount, _failureCount, _successCount),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.paddingM),
            ],

            // Repository list with status
            TitleSmallLabel(
              l10n.repositories,
            ),
            const SizedBox(height: AppTheme.paddingS),

            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.repositories.length,
                itemBuilder: (context, index) {
                  final repo = widget.repositories[index];
                  final progress = _progress[repo.path]!;

                  return BaseListItem(
                    leading: _buildStatusIcon(progress),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BodyMediumLabel(
                          repo.displayName,
                        ),
                        LabelMediumLabel(
                          progress.status,
                          color: progress.error != null
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ],
                    ),
                    trailing: progress.completed
                        ? Icon(
                            progress.success
                                ? PhosphorIconsBold.checkCircle
                                : PhosphorIconsBold.xCircle,
                            size: AppTheme.paddingM,
                            color: progress.success ? AppTheme.gitAdded : Theme.of(context).colorScheme.error,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      actions: !_isRunning
          ? [
              BaseButton(
                label: l10n.close,
                variant: ButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(_results),
              ),
            ]
          : null,
    );
  }

  Widget _buildStatusIcon(RepositoryProgress progress) {
    if (!progress.completed) {
      return SizedBox(
        width: AppTheme.paddingM,
        height: AppTheme.paddingM,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return Icon(
      progress.success
          ? PhosphorIconsRegular.checkCircle
          : PhosphorIconsRegular.xCircle,
      size: AppTheme.paddingM,
      color: progress.success ? AppTheme.gitAdded : Theme.of(context).colorScheme.error,
    );
  }
}

/// Show batch operation progress dialog
Future<List<BatchOperationResult>?> showBatchOperationProgressDialog(
  BuildContext context, {
  required String title,
  required List<WorkspaceRepository> repositories,
  required Future<List<BatchOperationResult>> Function(
    void Function(WorkspaceRepository, int, int, String)?
  ) operation,
}) {
  return showDialog<List<BatchOperationResult>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BatchOperationProgressDialog(
      title: title,
      repositories: repositories,
      operation: operation,
    ),
  );
}

