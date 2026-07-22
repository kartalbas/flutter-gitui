/// Runs one commit action through the sequence every action must share, and
/// returns null on success or the failure description for the caller to show.
///
/// Cherry-pick, revert, reset, tag creation and force-push all have the same
/// lifecycle - invoke git once, reload what the screen shows, then decide what
/// the outcome means for the selection. Kept as one pure function because each
/// action used to hand-roll this sequence, so error handling only existed
/// where a one-off fix had added it: four of the five actions threw into
/// nothing and skipped their reload on failure.
///
/// [refresh] runs whether [invoke] succeeded or failed. A failed action can
/// still have changed the repository - a reset that moved HEAD before its
/// working-tree step failed, a cherry-pick interrupted mid-sequence - so
/// skipping the reload on failure is exactly how the view was left stale on
/// top of a silent error.
///
/// [clearSelection] runs only on success. After a failure the commits are
/// still on screen and still selected, which shows what the failed action was
/// aimed at and lets the user retry without re-selecting.
Future<String?> runCommitAction({
  required Future<void> Function() invoke,
  required void Function() refresh,
  required void Function() clearSelection,
}) async {
  String? failure;
  try {
    await invoke();
  } catch (e) {
    failure = e.toString();
  }

  refresh();

  if (failure != null) return failure;

  clearSelection();
  return null;
}
