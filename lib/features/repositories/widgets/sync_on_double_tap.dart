import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/workspace/models/workspace_repository.dart';
import '../../../shared/widgets/double_tap_tracker.dart';
import '../repository_sync.dart';

/// Syncs [repository] when its child is double-clicked, while keeping the
/// single click instant.
///
/// Wrapped around a repository's status badges in both the card and the list
/// row: seeing "↓2" is exactly the moment a user wants to act on that one
/// repository, without selecting it and reaching for the toolbar.
///
/// Flutter's own onDoubleTap cannot be used here. Registering one holds every
/// single tap for the 300 ms double-tap window, which would make selecting a
/// repository feel sluggish again - the very lag removed in #320. The interval
/// between taps is measured instead, so the single click still lands at once.
class SyncOnDoubleTap extends ConsumerStatefulWidget {
  const SyncOnDoubleTap({
    super.key,
    required this.repository,
    required this.child,
    this.onSingleTap,
  });

  final WorkspaceRepository repository;

  /// What a single click does - selecting the repository, as before.
  final VoidCallback? onSingleTap;

  final Widget child;

  @override
  ConsumerState<SyncOnDoubleTap> createState() => _SyncOnDoubleTapState();
}

class _SyncOnDoubleTapState extends ConsumerState<SyncOnDoubleTap> {
  final DoubleTapTracker _tapTracker = DoubleTapTracker();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_tapTracker.registerTap(this, DateTime.now())) {
          syncRepository(context, ref, widget.repository);
          return;
        }
        widget.onSingleTap?.call();
      },
      child: widget.child,
    );
  }
}
