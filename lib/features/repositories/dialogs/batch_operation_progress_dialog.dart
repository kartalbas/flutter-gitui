import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ControlScale,
        DialogRouteSpec,
        IconRole,
        Inset,
        Overlays,
        ProgressExtent,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../generated/app_localizations.dart';
import '../services/batch_operations_service.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_layout.dart';

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
          ? IconRole.spinner
          : _failureCount == 0
          ? IconRole.checkCircle
          : IconRole.warningCircle,
      variant: DialogVariant.normal,
      barrierDismissible: !_isRunning,
      onSubmit: _isRunning ? null : () => Navigator.of(context).pop(_results),
      // `form` is the middle rung, taken here for want of a better one: this
      // dialog holds no fields and is not something to look through either -
      // it is a running progress with a per-repository result list. See the
      // reported DialogExtent gap. This WIDENS the dialog: it was shown at
      // 600 before the migration (`maxWidth: 600`), and the middle rung is
      // 650 under Material - a named change, not a preserved width.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall progress
          Row(
            children: [
              Expanded(
                // `controls.progress`, which is what a bar in this application
                // is now. The application states the two facts it owns - how
                // far along the batch is, and that saying so may take a line
                // of content rather than a region of its own - and the skin
                // answers with its language's indicator. `ProgressExtent
                // .inline` is the rung the vocabulary defines as "beside a
                // label", which is literally the arrangement here: the bar
                // shares its row with the "3 / 10" count. The `block` rung
                // would have been the wrong word twice over - Material draws
                // it as a centred ring and the blueprint skin as a bare
                // percentage.
                //
                // A determinate fraction, even at zero, tells the user how far
                // along the batch is; the indeterminate animation hid that for
                // the whole run, so the fraction is passed rather than null.
                child: SkinScope.render(context, (
                  Skin skin,
                  BuildContext inner,
                ) {
                  return skin.controls.progress(
                    inner,
                    fraction: progress,
                    extent: ProgressExtent.inline,
                  );
                }),
              ),
              const BaseGap(Proximity.grouped),
              BaseLabel(
                '$completedCount / $totalCount',
                role: TextRole.emphasis,
              ),
            ],
          ),

          // The row list can scroll the active repository out of view, so the
          // name of the one being worked on is pinned under the bar to keep a
          // slow repository distinguishable from a stalled run.
          if (_isRunning && _activeRepositoryPath != null) ...[
            const BaseGap(Proximity.related),
            BaseLabel(
              _progress[_activeRepositoryPath]!.repository.displayName,
              role: TextRole.detail,
            ),
          ],

          const BaseGap(Proximity.separate),

          // Summary (shown when completed)
          if (!_isRunning) ...[
            // How the run ended is `surfaces.banner`, and it is the shape the
            // member was specified for: a tone, a statement, the longer form
            // under it and a mark beside them. The whole hand-painted callout
            // goes - the wash, the 1 px edge, the corner, the inset, the two
            // `Color`s that painted the fill and the mark, and the Column and
            // Row that arranged them - because every one of them is what
            // `BannerSpec` says once.
            //
            // The two tones are the meanings the colours were spelling out.
            // A clean run "finished, and it finished well", which is
            // `Tone.success` and resolves to the same git `added` colour this
            // callout painted by hand; a run with failures is `Tone.warning`
            // - the operations completed and some did not, which is a doubt
            // rather than a destruction - and that lands on the git palette's
            // modified colour where the dialog used `colorScheme.secondary`.
            // Both are washed at the member's 12 % rather than 10 %, the edge
            // is gone (a banner is a strip, not a box), the corner with it,
            // and the two lines are set at `titleMedium` over `bodySmall`.
            //
            // The Bold marks do NOT survive. Both branches drew Bold, so the
            // weight distinguished nothing between them; the same
            // check-circle and warning-circle already stand at the ordinary
            // stroke in `git_output_dialog.dart` and eight lines further down
            // this same file. Recorded in
            // test/shared/icons/icon_weight_census_test.dart.
            SkinScope.render(context, (Skin skin, BuildContext inner) {
              return skin.surfaces.banner(
                inner,
                BannerSpec(
                  tone: _failureCount == 0 ? Tone.success : Tone.warning,
                  icon: _failureCount == 0
                      ? IconRole.checkCircle
                      : IconRole.warningCircle,
                  title: _failureCount == 0
                      ? l10n.operationsCompleted(
                          _successCount,
                          _successCount + _failureCount,
                        )
                      : l10n.operationsCompletedWithErrors(
                          _successCount,
                          _failureCount,
                          _successCount + _failureCount,
                        ),
                  body: l10n.successCount(_successCount, _failureCount),
                ),
              );
            }),
            const BaseGap(Proximity.grouped),
          ],

          // Repository list with status
          BaseLabel(l10n.repositories, role: TextRole.sectionTitle),
          const BaseGap(Proximity.related),

          // The frame round the bounded scroll region is a CARD, and
          // `Inset.none` is the rung `BaseCard`'s own doc names for it: "a
          // list that must reach the card's border". The previous note here
          // reached for `surfaces.panel`, rejected it (rightly - a panel is a
          // NAMED region with a header row) and concluded no member draws the
          // frame; the member it was looking for is the card, and the same
          // construction had already become one in
          // `squash_commits_dialog.dart` in the very change that wrote the
          // note. Its other twin, `create_branch_dialog.dart`'s repository
          // list, converts with this one, so the pattern the note identified
          // now has one treatment.
          //
          // What moves: the box gains the card's `surfaceContainerHigh` fill
          // where it drew none, the 1 px stroke goes from `outline` to
          // `outlineVariant`, and the corner rounds at the skin's 12 instead
          // of the 8 named here. The member's answer is the right one because
          // the row list is clipped by it: at 8 the top and bottom rows'
          // hover and press layers overhung a corner narrower than every
          // other surface in this dialog.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: BaseCard(
              isSelectable: false,
              inset: Inset.none,
              content: ListView.builder(
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
                        BaseLabel(repo.displayName, role: TextRole.body),
                        // Tone.invalid, not Tone.danger: this repository did
                        // not complete and needs attention, but nothing was
                        // destroyed.
                        BaseLabel(
                          statusText,
                          role: TextRole.detail,
                          tone: progress.error != null
                              ? Tone.invalid
                              : Tone.neutral,
                        ),
                      ],
                    ),
                    // Now the SAME expression as `_buildStatusIcon` below,
                    // which draws this dialog's other copy of the very same
                    // outcome mark and converted a phase earlier. One dialog
                    // was stating one fact two ways: `Tone.success` is exactly
                    // what `context.gitColors.added` resolved to
                    // (material_ink.dart:169), and `Tone.invalid` is the
                    // reading both that helper and this row's own status line
                    // already give the failure - it needs attention, but
                    // nothing was destroyed, so it is not `danger`.
                    // `AppTheme.iconS` is the 16 dp `compact` rung, so neither
                    // mark changes size.
                    //
                    // The Bold stroke does not survive. It was the same on
                    // both branches, so it distinguished nothing, and the twin
                    // below has been drawing this outcome at the ordinary
                    // stroke since it converted. Recorded in
                    // test/shared/icons/icon_weight_census_test.dart.
                    trailing: progress.success != null
                        ? BaseIcon(
                            progress.success == true
                                ? IconRole.checkCircle
                                : IconRole.xCircle,
                            scale: ControlScale.compact,
                            tone: progress.success == true
                                ? Tone.success
                                : Tone.invalid,
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // While the batch runs the dialog offers no action at all - not even a
      // disabled one - because there is nothing the user may do until it
      // finishes; afterwards, taking the results away is what completes it.
      actions: _isRunning
          ? null
          : [
              DialogAction(
                label: l10n.close,
                role: DialogActionRole.affirmative,
                onPressed: () => Navigator.of(context).pop(_results),
              ),
            ],
    );
  }

  Widget _buildStatusIcon(RepositoryProgress progress) {
    if (!progress.completed) {
      // Only the repository the service is on gets a spinner; spinning every
      // row made a stalled run indistinguishable from a busy one.
      if (progress.repository.path == _activeRepositoryPath) {
        // The colour is GONE rather than translated: it restated the ambient
        // default instead of stating a meaning. `CircularProgressIndicator`
        // resolves `valueColor ?? color ?? ProgressIndicatorTheme.color ??
        // defaults.color`; this application installs no
        // `ProgressIndicatorTheme` and every M3 default class answers
        // `defaults.color` with `colorScheme.primary`, so the deleted line and
        // the ambient default hand the painter the same Color - measured in
        // both themes. See `repository_card.dart` for the full note.
        //
        // The box and the stroke stay: neither facade can carry them, and they
        // leave with `controls.progress` at the inline extent.
        return const SizedBox(
          width: AppTheme.iconS,
          height: AppTheme.iconS,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      // A repository the run has not reached yet. Same glyph, same rung -
      // `IconRole.circle` is Phosphor's Regular circle (0xe18a) and
      // `ControlScale.compact` is the 16 dp this named - so the mark does not
      // move or change shape.
      //
      // Its COLOUR does, and that is the repair the sibling comparison found
      // rather than a side effect of converting a size. Every one of these
      // marks is the `leading` of a `BaseListItem`, and that row already
      // publishes an `IconTheme` for its whole width
      // (material_surfaces.dart:1878) whose colour is `onSurfaceVariant` -
      // M3's own list-item icon role - dropping to a readable fallback on a
      // selected tile, where the plain role measures 2.86 : 1. Naming
      // `colorScheme.outline` here overpainted that: `outline` is Material's
      // role for BORDERS and dividers, and it was the one thing in this column
      // still coloured for something other than a row glyph, sitting directly
      // above two twins (`_buildStatusIcon`'s outcome branch and the row's own
      // `trailing`) that had already stopped restating it. `Tone.neutral` is
      // `BaseIcon`'s way of saying "take what the control around me has already
      // published", which is exactly what these two want to say.
      return const BaseIcon(IconRole.circle, scale: ControlScale.compact);
    }

    if (progress.success == null) {
      // Finished mid-run: the outcome only arrives with the final results,
      // so a neutral check avoids claiming success or failure prematurely.
      // Same conversion, same reasoning as the pending mark above.
      return const BaseIcon(IconRole.checkCircle, scale: ControlScale.compact);
    }

    // The outcome the run reached for this repository, at the dense scale the
    // list reads at. Tone.invalid rather than Tone.danger for the failure, the
    // same reading the row's own status line above already uses: the operation
    // did not complete and needs attention, but nothing was destroyed.
    return BaseIcon(
      progress.success == true ? IconRole.checkCircle : IconRole.xCircle,
      scale: ControlScale.compact,
      tone: progress.success == true ? Tone.success : Tone.invalid,
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
  return Overlays.dialogFrom<List<BatchOperationResult>>(
    context,
    // The caller names the operation, so the caller names the route too - the
    // dialog reads the same string off its own widget.
    route: DialogRouteSpec(title: title, barrierDismissible: false),
    builder: (context) => BatchOperationProgressDialog(
      title: title,
      repositories: repositories,
      operation: operation,
    ),
  );
}
