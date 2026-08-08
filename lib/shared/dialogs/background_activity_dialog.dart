import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../core/workspace/models/repository_status.dart';
import '../../core/workspace/repository_status_provider.dart';
import '../../core/workspace/workspace_provider.dart';
import '../../generated/app_localizations.dart';
import '../components/base_dialog.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_layout.dart';

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
      icon: IconRole.pulse,
      title: 'Background activity',
      onSubmit: () => Navigator.of(context).pop(),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BaseLabel(
              running == 0
                  ? 'Nothing is running right now.'
                  : '$running of ${rows.length} repositories are being checked.',
              role: TextRole.detail,
              tone: Tone.muted,
            ),
            const BaseGap(Proximity.grouped),
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
    final state = _stateOf(status);

    // What the row's state MEANS, said once for the mark and the words
    // together. The `Color` this record used to carry was the same statement
    // written as Material's answer to it, and it was written twice — once into
    // a glyph and once into a label — which is how the two drift apart.
    final (IconRole icon, Tone tone, String label) = switch (state) {
      _ActivityState.running => (
        IconRole.circleNotch,
        Tone.accent,
        'Checking…',
      ),
      _ActivityState.checked => (IconRole.checkCircle, Tone.accent, 'Checked'),
      _ActivityState.failed => (
        IconRole.warningCircle,
        Tone.danger,
        _failureLabel(status!),
      ),
      _ActivityState.local => (IconRole.hardDrives, Tone.muted, 'Local only'),
      _ActivityState.pending => (
        IconRole.clockCountdown,
        Tone.muted,
        'Not checked',
      ),
    };

    // Where it lives answers the question a failure raises: which account.
    final identity = status?.remoteIdentity;

    return BaseInset(
      x: Inset.none,
      y: Inset.tight,
      child: Row(
        children: [
          BaseIcon(icon, scale: ControlScale.compact, tone: tone),
          const BaseGap(Proximity.related),
          // One line: this is one repository's row in a list of them, and a
          // long name that wrapped would make its row taller than the rest.
          Expanded(child: BaseLabel(name, role: TextRole.body, maxLines: 1)),
          if (identity != null) ...[
            const BaseGap(Proximity.related),
            BaseLabel(identity.label, role: TextRole.detail, tone: Tone.muted),
          ],
          const BaseGap(Proximity.grouped),
          BaseLabel(label, role: TextRole.detail, tone: tone),
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
