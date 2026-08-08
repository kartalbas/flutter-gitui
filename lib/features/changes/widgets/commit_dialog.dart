import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/services/exit_guard.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/widgets/file_status_badge.dart';

/// Dialog for committing staged changes
class CommitDialog extends ConsumerStatefulWidget {
  const CommitDialog({super.key});

  @override
  ConsumerState<CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends ConsumerState<CommitDialog> {
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAmend = false;
  bool _isCommitting = false;
  bool _showStagedFiles = false;

  // Captured in initState because ref must not be touched from dispose.
  UnsavedInputNotifier? _unsavedInput;

  @override
  void initState() {
    super.initState();
    // A half-written commit message must be able to hold back a
    // restart-and-install, so its presence is mirrored into the app-wide
    // unsaved-input registry.
    _unsavedInput = ref.read(unsavedInputProvider.notifier);
    _messageController.addListener(_syncUnsavedInput);
    _loadLastCommitIfAmend();
  }

  @override
  void dispose() {
    // Whatever closes this dialog - commit, cancel, escape - takes the text
    // with it, so the registration must not outlive the field. Deferred to
    // after the frame: dispose runs while the tree is being finalized, and
    // notifying a provider's listeners during that phase trips riverpod's
    // build-phase assert. The mounted guard covers app teardown, where the
    // notifier dies in the same frame as this dialog.
    final unsavedInput = _unsavedInput;
    if (unsavedInput != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (unsavedInput.mounted) {
          unsavedInput.unregister(UnsavedInputKind.commitMessage);
        }
      });
    }
    _messageController.dispose();
    super.dispose();
  }

  void _syncUnsavedInput() {
    if (_messageController.text.trim().isEmpty) {
      _unsavedInput?.unregister(UnsavedInputKind.commitMessage);
    } else {
      _unsavedInput?.register(UnsavedInputKind.commitMessage);
    }
  }

  Future<void> _loadLastCommitIfAmend() async {
    if (_isAmend) {
      final gitService = ref.read(gitServiceProvider);
      if (gitService != null) {
        try {
          final result = await gitService.getLastCommitMessage();
          final lastMessage = result.unwrap();
          if (!mounted) return;
          _messageController.text = lastMessage;
        } catch (e) {
          // Ignore errors loading last commit
        }
      }
    }
  }

  Future<void> _commit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isCommitting = true);

    try {
      final message = _messageController.text.trim();
      // confirmed-by: the amend checkbox in this dialog is an explicit
      // opt-in the user just made.
      await ref.read(gitActionsProvider).commit(message, amend: _isAmend);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCommitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                // The mark and its `onError` stay together with the fill
                // below. `onError` is the paired foreground of a surface that
                // is still a hand-painted `Color`, and `Tone.onAccent` is the
                // ACCENT's pairing - saying it here would paint an
                // on-primary foreground over an error fill. Both halves leave
                // together when the notice becomes a skin member.
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  color: Theme.of(context).colorScheme.onError,
                ),
                const BaseGap(Proximity.related),
                Expanded(
                  child: BaseLabel(
                    AppLocalizations.of(context)!.commitFailed(e.toString()),
                    role: TextRole.control,
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stagedFiles = ref.watch(stagedFilesProvider);

    return BaseDialog(
      title: AppLocalizations.of(context)!.commitChanges,
      icon: IconRole.gitCommit,
      // The message field is multiline, so Enter inside it writes a newline;
      // Enter anywhere else commits. _commit validates the form itself.
      onSubmit: _isCommitting ? null : _commit,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staged files summary
            Container(
              // The summary's fill and corner stay: they are the surface, and
              // the surface leaves with `surfaces.card`. How far it holds its
              // content off its own edge is the language's question.
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                child: Row(
                  children: [
                    const BaseIcon(
                      IconRole.checkSquare,
                      scale: ControlScale.compact,
                      tone: Tone.accent,
                    ),
                    const BaseGap(Proximity.related),
                    BaseLabel(
                      AppLocalizations.of(context)!.messageFilesStaged(
                        stagedFiles.length,
                        stagedFiles.length == 1 ? '' : 's',
                      ),
                      role: TextRole.body,
                    ),
                    const Spacer(),
                    BaseButton(
                      label: AppLocalizations.of(context)!.viewFiles,
                      variant: ButtonVariant.tertiary,
                      leadingIcon: _showStagedFiles
                          ? IconRole.caretUp
                          : IconRole.caretDown,
                      onPressed: stagedFiles.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _showStagedFiles = !_showStagedFiles;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),

            // Kept collapsed by default so the message field stays the focus;
            // the height cap prevents a large stage from pushing the commit
            // button out of the dialog.
            if (_showStagedFiles && stagedFiles.isNotEmpty) ...[
              // The summary and the list it expands into are two parts of one
              // statement: `related`.
              const BaseGap(Proximity.related),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: stagedFiles.length,
                  itemBuilder: (context, index) {
                    final file = stagedFiles[index];
                    return BaseInset(
                      // The rows of a dense file list are barely set off from
                      // one another: `hairline` vertically, nothing
                      // horizontally, because the list already sits inside the
                      // dialog's own inset.
                      x: Inset.none,
                      y: Inset.hairline,
                      child: Row(
                        children: [
                          FileStatusBadge(
                            code: file.indexStatus.code,
                            color: file.indexStatus.colorOf(context),
                          ),
                          const BaseGap(Proximity.related),
                          Expanded(
                            child: BaseLabel(
                              file.path,
                              role: TextRole.detail,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            // The summary above and the field below belong to two different
            // groups inside one form: `separate`.
            const BaseGap(Proximity.separate),

            // Commit message field
            BaseLabel(
              AppLocalizations.of(context)!.labelCommitMessage,
              role: TextRole.sectionTitle,
            ),
            // A field label and its field are two parts of one statement.
            const BaseGap(Proximity.related),
            BaseTextField(
              controller: _messageController,
              hintText: AppLocalizations.of(context)!.hintTextCommitMessage,
              maxLines: 6,
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(
                    context,
                  )!.messageCommitMessageRequired;
                }
                return null;
              },
            ),

            const BaseGap(Proximity.grouped),

            // Amend checkbox
            CheckboxListTile(
              value: _isAmend,
              onChanged: (value) {
                setState(() {
                  _isAmend = value ?? false;
                });
                if (_isAmend) {
                  _loadLastCommitIfAmend();
                } else {
                  _messageController.clear();
                }
              },
              title: Text(
                AppLocalizations.of(context)!.checkboxAmendLastCommit,
              ),
              subtitle: BaseLabel(
                AppLocalizations.of(context)!.checkboxAmendLastCommitSubtitle,
                role: TextRole.detail,
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            // Commit tips
            const BaseGap(Proximity.related),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              // The tip is a dense note rather than a card: `tight`.
              child: BaseInset(
                all: Inset.tight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BaseIcon(
                      IconRole.lightbulb,
                      scale: ControlScale.compact,
                      tone: Tone.accent,
                    ),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        AppLocalizations.of(context)!.tipCommitMessage,
                        role: TextRole.detail,
                        tone: Tone.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        DialogAction(
          label: AppLocalizations.of(context)!.cancel,
          role: DialogActionRole.dismissive,
          enabled: !_isCommitting,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: _isAmend
              ? AppLocalizations.of(context)!.labelAmendCommit
              : AppLocalizations.of(context)!.commit,
          role: DialogActionRole.affirmative,
          icon: IconRole.check,
          isLoading: _isCommitting,
          onPressed: _commit,
        ),
      ],
    );
  }
}
