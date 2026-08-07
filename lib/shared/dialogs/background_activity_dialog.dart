import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../core/workspace/models/repository_status.dart';
import '../../core/workspace/repository_status_provider.dart';
import '../../core/workspace/workspace_provider.dart';
import '../../generated/app_localizations.dart';
import '../components/base_dialog.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';

/// How a single repository stands in the current sweep.
enum _ActivityState { running, checked, failed, pending, local }

/// What the activity line cannot say: which repository is slow, which already
/// finished, and which failed and why.
///
/// Built from the repository statuses rather than from a separate record of the
/// sweep, so it stays correct however the sweep was started and keeps updating
/// while it is open.
class BackgroundActivityDialog extends ConsumerWidget {
  const BackgroundActivityDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final repositories = ref.watch(workspaceProvider);
    final statuses = ref.watch(workspaceRepositoryStatusProvider);

    // Whatever is still working belongs at the top, then what went wrong -
    // the two things worth opening this for - and the settled ones below.
    final rows =
        repositories
            .map((repo) => (repo: repo, status: statuses[repo.path]))
            .toList()
          ..sort((a, b) {
            final left = _stateOf(a.status).index;
            final right = _stateOf(b.status).index;
            if (left != right) return left.compareTo(right);
            return a.repo.displayName.toLowerCase().compareTo(
              b.repo.displayName.toLowerCase(),
            );
          });

    final running = rows
        .where((row) => _stateOf(row.status) == _ActivityState.running)
        .length;

    return BaseDialog(
      icon: PhosphorIconsRegular.pulse,
      title: 'Background activity',
      onSubmit: () => Navigator.of(context).pop(),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodySmallLabel(
              running == 0
                  ? 'Nothing is running right now.'
                  : '$running of ${rows.length} repositories are being checked.',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.paddingM),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return _ActivityRow(
                    name: row.repo.displayName,
                    status: row.status,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        // A monitor with nothing to confirm: closing it IS completing it,
        // which is why Enter fires this action above.
        DialogAction(
          label: l10n.close,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

_ActivityState _stateOf(RepositoryStatus? status) {
  if (status == null) return _ActivityState.pending;
  if (status.isLoading) return _ActivityState.running;
  if (status.needsSignIn ||
      status.isRemoteUnreachable ||
      status.remoteCheckFailedUnknown) {
    return _ActivityState.failed;
  }
  if (!status.hasRemote) return _ActivityState.local;
  if (status.remoteCheckedAt != null) return _ActivityState.checked;
  return _ActivityState.pending;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.name, required this.status});

  final String name;
  final RepositoryStatus? status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = _stateOf(status);

    final (IconData icon, Color color, String label) = switch (state) {
      _ActivityState.running => (
        PhosphorIconsRegular.circleNotch,
        colorScheme.primary,
        'Checking…',
      ),
      _ActivityState.checked => (
        PhosphorIconsRegular.checkCircle,
        colorScheme.primary,
        'Checked',
      ),
      _ActivityState.failed => (
        PhosphorIconsRegular.warningCircle,
        colorScheme.error,
        _failureLabel(status!),
      ),
      _ActivityState.local => (
        PhosphorIconsRegular.hardDrives,
        colorScheme.onSurfaceVariant,
        'Local only',
      ),
      _ActivityState.pending => (
        PhosphorIconsRegular.clockCountdown,
        colorScheme.onSurfaceVariant,
        'Not checked',
      ),
    };

    // Where it lives answers the question a failure raises: which account.
    final identity = status?.remoteIdentity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.paddingXS),
      child: Row(
        children: [
          Icon(icon, size: AppTheme.iconS, color: color),
          const SizedBox(width: AppTheme.paddingS),
          Expanded(
            child: BodyMediumLabel(name, overflow: TextOverflow.ellipsis),
          ),
          if (identity != null) ...[
            const SizedBox(width: AppTheme.paddingS),
            BodySmallLabel(identity.label, color: colorScheme.onSurfaceVariant),
          ],
          const SizedBox(width: AppTheme.paddingM),
          BodySmallLabel(label, color: color),
        ],
      ),
    );
  }

  String _failureLabel(RepositoryStatus status) {
    if (status.needsSignIn) return 'Sign-in required';
    if (status.isRemoteUnreachable) return 'Unreachable';
    return 'Check failed';
  }
}

/// Opens the per-repository view of what the app is doing in the background.
Future<void> showBackgroundActivityDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const BackgroundActivityDialog(),
  );
}
