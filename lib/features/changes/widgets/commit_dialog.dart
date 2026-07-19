import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/git/git_providers.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_menu_item.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLastCommitIfAmend();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  color: Theme.of(context).colorScheme.onError,
                ),
                const SizedBox(width: AppTheme.paddingS),
                Expanded(
                  child: MenuItemLabel(
                    AppLocalizations.of(context)!.commitFailed(e.toString()),
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
      icon: PhosphorIconsRegular.gitCommit,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staged files summary
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.checkSquare,
                    size: AppTheme.iconS,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  BodyMediumLabel(
                    AppLocalizations.of(context)!.messageFilesStaged(
                      stagedFiles.length,
                      stagedFiles.length == 1 ? '' : 's',
                    ),
                  ),
                  const Spacer(),
                  BaseButton(
                    label: AppLocalizations.of(context)!.viewFiles,
                    variant: ButtonVariant.tertiary,
                    leadingIcon: _showStagedFiles
                        ? PhosphorIconsRegular.caretUp
                        : PhosphorIconsRegular.caretDown,
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

            // Kept collapsed by default so the message field stays the focus;
            // the height cap prevents a large stage from pushing the commit
            // button out of the dialog.
            if (_showStagedFiles && stagedFiles.isNotEmpty) ...[
              const SizedBox(height: AppTheme.paddingS),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: stagedFiles.length,
                  itemBuilder: (context, index) {
                    final file = stagedFiles[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          FileStatusBadge(
                            code: file.indexStatus.code,
                            color: file.indexStatus.color,
                          ),
                          const SizedBox(width: AppTheme.paddingS),
                          Expanded(
                            child: BodySmallLabel(
                              file.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: AppTheme.paddingL),

            // Commit message field
            TitleSmallLabel(AppLocalizations.of(context)!.labelCommitMessage),
            const SizedBox(height: AppTheme.paddingS),
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
              onSubmitted: (_) {
                if (_formKey.currentState!.validate()) {
                  _commit();
                }
              },
            ),

            const SizedBox(height: AppTheme.paddingM),

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
              subtitle: BodySmallLabel(
                AppLocalizations.of(context)!.checkboxAmendLastCommitSubtitle,
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            // Commit tips
            const SizedBox(height: AppTheme.paddingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingS),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIconsRegular.lightbulb,
                    size: AppTheme.iconS,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodySmallLabel(
                      AppLocalizations.of(context)!.tipCommitMessage,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Cancel button
        BaseButton(
          label: AppLocalizations.of(context)!.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: _isCommitting ? null : () => Navigator.of(context).pop(),
        ),

        // Commit button
        BaseButton(
          label: _isAmend
              ? AppLocalizations.of(context)!.labelAmendCommit
              : AppLocalizations.of(context)!.commit,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.check,
          isLoading: _isCommitting,
          onPressed: _isCommitting ? null : _commit,
        ),
      ],
    );
  }
}
