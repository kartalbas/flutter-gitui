import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_providers.dart';
import '../../core/workspace/models/repository_status.dart';
import '../../core/workspace/models/workspace_repository.dart';
import '../../core/workspace/repository_status_provider.dart';
import 'dialogs/batch_operation_progress_dialog.dart';
import 'repository_batch_error_provider.dart';
import 'services/batch_operations_service.dart';

/// Brings one repository in line with its remote: pull, then push when it has
/// commits of its own to send.
///
/// Reached by double-clicking a repository's status badge, so it runs as a
/// user-started operation - credential prompts are expected here, unlike in the
/// background sweep - and reports through the same progress dialog the toolbar
/// batch actions use, so a problem reads the same wherever it came from.
Future<void> syncRepository(
  BuildContext context,
  WidgetRef ref,
  WorkspaceRepository repository,
) async {
  final statusNotifier = ref.read(workspaceRepositoryStatusProvider.notifier);
  final status = ref.read(workspaceRepositoryStatusProvider)[repository.path];

  // Nothing to sync against, and pushing would only fail.
  if (status != null && !status.hasRemote) return;

  final service = BatchOperationsService(
    gitExecutablePath: ref.read(gitExecutablePathProvider),
  );
  final repositories = [repository];
  final statuses = <String, RepositoryStatus>{repository.path: ?status};

  final results = await showBatchOperationProgressDialog(
    context,
    title: 'Sync ${repository.displayName}',
    repositories: repositories,
    operation: (onProgress) async {
      final pulled = await service.pullAll(
        repositories,
        statuses,
        onProgress: onProgress,
      );

      // Only push what the pull left in a state worth pushing: pushing after a
      // failed pull would either be rejected or, worse, succeed on a branch the
      // user has not seen the remote side of yet.
      final pullFailed = pulled.any((result) => !result.success);
      if (pullFailed || !(status?.hasOutgoing ?? false)) {
        return pulled;
      }

      final pushed = await service.pushAll(
        repositories,
        statuses,
        onProgress: onProgress,
      );
      return [...pulled, ...pushed];
    },
  );

  if (results == null || !context.mounted) return;

  // Keep the outcome on the card rather than in a snackbar that scrolls away.
  final batchResults = <String, RepositoryBatchResult>{};
  for (final result in results) {
    batchResults[result.repository.path] = RepositoryBatchResult(
      success: result.success,
      message: result.success
          ? (result.message ?? 'Synced successfully')
          : (result.error ?? 'Unknown error'),
    );
  }
  if (batchResults.isNotEmpty) {
    ref.read(repositoryBatchErrorProvider.notifier).setResults(batchResults);
  }

  // The sync contacted the remote, so the card can report a verified state.
  await statusNotifier.refreshStatus(
    repository,
    fetchRemote: true,
    allowPrompts: true,
  );
}
