import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

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

  /// Null until the outcome is known: the service moves past a repository
  /// before its result is delivered, so a row can be finished while its
  /// success or failure is still pending.
  final bool? success;
  final String? error;

  const RepositoryProgress({
    required this.repository,
    required this.status,
    this.completed = false,
    this.success,
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
    void Function(WorkspaceRepository, int, int, String)?,
  )
  operation;

  const BatchOperationProgressDialog({
    super.key,
    required this.title,
    required this.repositories,
    required this.operation,
  });

  @override
  State<BatchOperationProgressDialog> createState() =>
      _BatchOperationProgressDialogState();
}

class _BatchOperationProgressDialogState
    extends State<BatchOperationProgressDialog> {
  late Map<String, RepositoryProgress> _progress;
  bool _isRunning = true;
  List<BatchOperationResult>? _results;
  int _successCount = 0;
  int _failureCount = 0;
  String? _activeRepositoryPath;

  @override
  void initState() {
    super.initState();

    // Localizations are not accessible from initState, so rows start with an
    // empty status and the build method substitutes the localized waiting
    // text until the service reports on a repository.
    _progress = {
      for (final repo in widget.repositories)
        repo.path: RepositoryProgress(repository: repo, status: ''),
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
          // A throw aborts the batch before any per-repository result exists, so
          // every repository has to be surfaced as failed. Otherwise the summary
          // renders as a success and callers read the null result as a plain
          // dismissal, hiding the failure completely.
          final error = e.toString();
          _results = [
            for (final repo in widget.repositories)
              BatchOperationResult(
                repository: repo,
                success: false,
                error: error,
              ),
          ];
          _isRunning = false;
          _successCount = 0;
          _failureCount = widget.repositories.length;

          for (final repo in widget.repositories) {
            _progress[repo.path] = RepositoryProgress(
              repository: repo,
              status: error,
              completed: true,
              success: false,
              error: error,
            );
          }
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
    if (!mounted) return;
    setState(() {
      // The service reports repository `current` (1-based) before working on
      // it, so every repository ahead of it in the list is already finished.
      // Marking them here is what moves the counter and the bar during the
      // run instead of letting everything snap to done at the end. Outcomes
      // are not known yet, so `success` stays null until the results arrive.
      for (var i = 0; i < current - 1 && i < widget.repositories.length; i++) {
        final path = widget.repositories[i].path;
        final entry = _progress[path]!;
        if (!entry.completed) {
          _progress[path] = entry.copyWith(completed: true);
        }
      }
      _activeRepositoryPath = repository.path;
      _progress[repository.path] = _progress[repository.path]!.copyWith(
        status: status,
      );
    });
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
                  // A determinate fraction, even at zero, tells the user how
                  // far along the batch is; the indeterminate animation hid
                  // that for the whole run.
                  value: progress,
                  minHeight: AppTheme.paddingS,
                  borderRadius: BorderRadius.circular(AppTheme.paddingXS),
                ),
              ),
              const SizedBox(width: AppTheme.paddingM),
              TitleMediumLabel('$completedCount / $totalCount'),
            ],
          ),

          // The row list can scroll the active repository out of view, so the
          // name of the one being worked on is pinned under the bar to keep a
          // slow repository distinguishable from a stalled run.
          if (_isRunning && _activeRepositoryPath != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            BodySmallLabel(
              _progress[_activeRepositoryPath]!.repository.displayName,
            ),
          ],

          const SizedBox(height: AppTheme.paddingL),

          // Summary (shown when completed)
          if (!_isRunning) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: _failureCount == 0
                    ? AppTheme.gitAdded.withValues(alpha: 0.1)
                    : Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: _failureCount == 0
                      ? AppTheme.gitAdded
                      : Theme.of(context).colorScheme.secondary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _failureCount == 0
                        ? PhosphorIconsBold.checkCircle
                        : PhosphorIconsBold.warningCircle,
                    color: _failureCount == 0
                        ? AppTheme.gitAdded
                        : Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TitleSmallLabel(
                          _failureCount == 0
                              ? l10n.operationsCompleted(
                                  _successCount,
                                  _successCount + _failureCount,
                                )
                              : l10n.operationsCompletedWithErrors(
                                  _successCount,
                                  _failureCount,
                                  _successCount + _failureCount,
                                ),
                        ),
                        const SizedBox(height: AppTheme.paddingXS),
                        BodySmallLabel(
                          l10n.successCount(_successCount, _failureCount),
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
          TitleSmallLabel(l10n.repositories),
          const SizedBox(height: AppTheme.paddingS),

          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.repositories.length,
              itemBuilder: (context, index) {
                final repo = widget.repositories[index];
                final progress = _progress[repo.path]!;

                // A repository can be finished before its outcome is known
                // (the service only delivers results at the end), and a row
                // the service has not reached yet is waiting, not working.
                final String statusText;
                if (progress.completed) {
                  statusText = progress.success == null
                      ? l10n.completed
                      : progress.status;
                } else {
                  statusText = repo.path == _activeRepositoryPath
                      ? progress.status
                      : l10n.operationInProgress;
                }

                return BaseListItem(
                  leading: _buildStatusIcon(progress),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BodyMediumLabel(repo.displayName),
                      LabelMediumLabel(
                        statusText,
                        color: progress.error != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ],
                  ),
                  trailing: progress.success != null
                      ? Icon(
                          progress.success == true
                              ? PhosphorIconsBold.checkCircle
                              : PhosphorIconsBold.xCircle,
                          size: AppTheme.paddingM,
                          color: progress.success == true
                              ? AppTheme.gitAdded
                              : Theme.of(context).colorScheme.error,
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
      // Only the repository the service is on gets a spinner; spinning every
      // row made a stalled run indistinguishable from a busy one.
      if (progress.repository.path == _activeRepositoryPath) {
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
        PhosphorIconsRegular.circle,
        size: AppTheme.paddingM,
        color: Theme.of(context).colorScheme.outline,
      );
    }

    if (progress.success == null) {
      // Finished mid-run: the outcome only arrives with the final results,
      // so a neutral check avoids claiming success or failure prematurely.
      return Icon(
        PhosphorIconsRegular.checkCircle,
        size: AppTheme.paddingM,
        color: Theme.of(context).colorScheme.outline,
      );
    }

    return Icon(
      progress.success == true
          ? PhosphorIconsRegular.checkCircle
          : PhosphorIconsRegular.xCircle,
      size: AppTheme.paddingM,
      color: progress.success == true
          ? AppTheme.gitAdded
          : Theme.of(context).colorScheme.error,
    );
  }
}

/// Show batch operation progress dialog
Future<List<BatchOperationResult>?> showBatchOperationProgressDialog(
  BuildContext context, {
  required String title,
  required List<WorkspaceRepository> repositories,
  required Future<List<BatchOperationResult>> Function(
    void Function(WorkspaceRepository, int, int, String)?,
  )
  operation,
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
