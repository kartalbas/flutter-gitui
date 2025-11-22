import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/commit.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';

/// Dialog for creating a new Git tag
class CreateTagDialog extends ConsumerStatefulWidget {
  final String? initialCommit;

  const CreateTagDialog({
    super.key,
    this.initialCommit,
  });

  @override
  ConsumerState<CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends ConsumerState<CreateTagDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagNameController = TextEditingController();
  final _messageController = TextEditingController();

  String? _selectedCommit;
  bool _isAnnotated = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _selectedCommit = widget.initialCommit ?? 'HEAD';
  }

  @override
  void dispose() {
    _tagNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commitsAsync = ref.watch(commitHistoryProvider);

    return BaseDialog(
      icon: PhosphorIconsRegular.tag,
      title: AppLocalizations.of(context)!.createTag,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.info, size: 20),
                      const SizedBox(width: AppTheme.paddingS),
                      Expanded(
                        child: BodySmallLabel(AppLocalizations.of(context)!.createTagDialogDescription),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.paddingL),

                // Tag name
                BaseTextField(
                  controller: _tagNameController,
                  label: AppLocalizations.of(context)!.tagName,
                  hintText: AppLocalizations.of(context)!.tagNameHint,
                  prefixIcon: PhosphorIconsRegular.tag,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.enterTagName;
                    }
                    if (value.contains(' ')) {
                      return AppLocalizations.of(context)!.tagNameNoSpaces;
                    }
                    return null;
                  },
                  autofocus: true,
                ),
                const SizedBox(height: AppTheme.paddingM),

                // Target commit
                TitleSmallLabel(AppLocalizations.of(context)!.targetCommit),
                const SizedBox(height: AppTheme.paddingS),
                commitsAsync.when(
                  data: (commits) => _buildCommitDropdown(commits),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => BodyMediumLabel(AppLocalizations.of(context)!.errorLoadingCommits),
                ),
                const SizedBox(height: AppTheme.paddingL),

                // Annotated tag option
                SwitchListTile(
                  title: BodyMediumLabel(AppLocalizations.of(context)!.annotatedTag),
                  subtitle: BodySmallLabel(AppLocalizations.of(context)!.includeMessageWithTag),
                  value: _isAnnotated,
                  onChanged: (value) {
                    setState(() => _isAnnotated = value);
                  },
                ),
                const SizedBox(height: AppTheme.paddingM),

                // Tag message (only for annotated tags)
                if (_isAnnotated) ...[
                  BaseTextField(
                    controller: _messageController,
                    label: AppLocalizations.of(context)!.message,
                    hintText: AppLocalizations.of(context)!.releaseNotesPlaceholder,
                    maxLines: 3,
                    validator: _isAnnotated
                        ? (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context)!.enterTagMessage;
                            }
                            return null;
                          }
                        : null,
                  ),
                  const SizedBox(height: AppTheme.paddingM),
                ],
              ],
            ),
          ),
        ),
      actions: [
        BaseButton(
          label: AppLocalizations.of(context)!.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.createTag,
          variant: ButtonVariant.primary,
          isLoading: _isCreating,
          onPressed: _isCreating ? null : _createTag,
        ),
      ],
    );
  }

  Widget _buildCommitDropdown(List<GitCommit> commits) {
    return BaseDropdown<String>(
      initialValue: _selectedCommit,
      items: [
        BaseDropdownItem<String>(
          value: 'HEAD',
          builder: (context) => Row(
            children: [
              const Icon(PhosphorIconsRegular.arrowUp, size: 16),
              const SizedBox(width: AppTheme.paddingS),
              BodyMediumLabel(AppLocalizations.of(context)!.headCurrentCommit),
            ],
          ),
        ),
        ...commits.take(50).map((commit) {
          return BaseDropdownItem<String>(
            value: commit.hash,
            builder: (context) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: LabelMediumLabel(
                    commit.shortHash,
                  ),
                ),
                const SizedBox(width: AppTheme.paddingS),
                Flexible(
                  fit: FlexFit.loose,
                  child: BodyMediumLabel(
                    commit.message,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() => _selectedCommit = value);
      },
    );
  }

  Future<void> _createTag() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final gitService = ref.read(gitServiceProvider);
      if (gitService == null) return;

      final tagName = _tagNameController.text.trim();
      final message = _messageController.text.trim();
      final commit = _selectedCommit ?? 'HEAD';

      if (_isAnnotated) {
        await gitService.createAnnotatedTag(
          tagName,
          message: message,
          commitHash: commit,
        );
      } else {
        await gitService.createLightweightTag(
          tagName,
          commitHash: commit,
        );
      }

      // Refresh tags
      ref.invalidate(tagsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tagCreatedError(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Show create tag dialog
Future<bool?> showCreateTagDialog(
  BuildContext context, {
  String? initialCommit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CreateTagDialog(initialCommit: initialCommit),
  );
}
