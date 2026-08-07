import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/commit.dart';
import '../../core/git/models/tag.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';

/// The app's single create-tag dialog.
///
/// Both entry points share it: the command palette opens it without a target
/// (the dropdown defaults to HEAD) and the history screen preselects the
/// chosen commit through [initialCommit]. The target is a plain revision
/// string, so no caller needs a particular model type to open the dialog.
/// The dialog validates its form, creates the tag through the actions layer
/// (which surfaces git failures and refreshes the tag providers), and pops
/// `true` on success.
class CreateTagDialog extends ConsumerStatefulWidget {
  /// Revision to preselect as the tag target; defaults to HEAD.
  final String? initialCommit;

  const CreateTagDialog({super.key, this.initialCommit});

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

  /// Prefill name and message from an existing tag, so a release tag can be
  /// derived from the previous one instead of retyped.
  void _applyTemplate(GitTag template) {
    setState(() {
      _tagNameController.text = template.name;
      if (template.isAnnotated && template.message != null) {
        _messageController.text = template.message!;
        _isAnnotated = true;
      }
    });
  }

  /// Last 10 tags, newest first, offered as prefill templates.
  List<GitTag> _recentTags(AsyncValue<List<GitTag>> tagsAsync) {
    final sorted =
        tagsAsync.whenData((tags) {
          final sortedTags = List<GitTag>.from(tags);
          sortedTags.sort((a, b) {
            if (a.date == null && b.date == null) return 0;
            if (a.date == null) return 1;
            if (b.date == null) return -1;
            return b.date!.compareTo(a.date!);
          });
          return sortedTags;
        }).value ??
        [];
    return sorted.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final commitsAsync = ref.watch(commitHistoryProvider);
    final recentTags = _recentTags(ref.watch(tagsProvider));

    return BaseDialog(
      icon: PhosphorIconsRegular.tag,
      title: l10n.createTag,
      // The message field is multiline; Enter inside it writes a newline,
      // Enter anywhere else creates. _createTag validates the form itself.
      onSubmit: _isCreating ? null : _createTag,
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.info, size: 20),
                    const SizedBox(width: AppTheme.paddingS),
                    Expanded(
                      child: BodySmallLabel(l10n.createTagDialogDescription),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.paddingL),

              // Template selector: prefill from a recent tag
              if (recentTags.isNotEmpty) ...[
                BaseDropdown<GitTag?>(
                  labelText: l10n.useRecentTagAsTemplate,
                  hintText: l10n.selectTagTemplate,
                  prefixIcon: PhosphorIconsRegular.tag,
                  items: [
                    BaseDropdownItem<GitTag?>.simple(
                      value: null,
                      label: l10n.noTemplate,
                      icon: PhosphorIconsRegular.x,
                    ),
                    ...recentTags.map(
                      (tag) => BaseDropdownItem<GitTag?>.withBadge(
                        value: tag,
                        label: tag.name,
                        icon: tag.isAnnotated
                            ? PhosphorIconsBold.tag
                            : PhosphorIconsRegular.tag,
                        badgeText: tag.isAnnotated ? l10n.annotated : null,
                      ),
                    ),
                  ],
                  onChanged: (tag) {
                    if (tag != null) {
                      _applyTemplate(tag);
                    } else {
                      setState(() {
                        _tagNameController.clear();
                        _messageController.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: AppTheme.paddingM),
              ],

              // Tag name. Keyed because the template selector above it and
              // the commit dropdown below it both appear only once their
              // providers resolve, a frame or two after the dialog opened.
              // Without a key the reshuffle replaces this field's element,
              // which throws away the focus its `autofocus` had just won, and
              // the dialog ends up with nothing focused to type into.
              BaseTextField(
                key: const ValueKey('createTag.tagName'),
                controller: _tagNameController,
                label: l10n.tagName,
                hintText: l10n.tagNameHint,
                prefixIcon: PhosphorIconsRegular.tag,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.enterTagName;
                  }
                  if (value.contains(' ')) {
                    return l10n.tagNameNoSpaces;
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: AppTheme.paddingM),

              // Target commit
              TitleSmallLabel(l10n.targetCommit),
              const SizedBox(height: AppTheme.paddingS),
              commitsAsync.when(
                data: (commits) => _buildCommitDropdown(commits),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => BodyMediumLabel(l10n.errorLoadingCommits),
              ),
              const SizedBox(height: AppTheme.paddingL),

              // Annotated tag option
              SwitchListTile(
                title: BodyMediumLabel(l10n.annotatedTag),
                subtitle: BodySmallLabel(l10n.includeMessageWithTag),
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
                  label: l10n.message,
                  hintText: l10n.releaseNotesPlaceholder,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.enterTagMessage;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.paddingM),
              ],
            ],
          ),
        ),
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          enabled: !_isCreating,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.createTag,
          role: DialogActionRole.affirmative,
          isLoading: _isCreating,
          onPressed: _createTag,
        ),
      ],
    );
  }

  String _shortHash(String hash) =>
      hash.length > 7 ? hash.substring(0, 7) : hash;

  Widget _hashChip(BuildContext context, String shortHash) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: LabelMediumLabel(shortHash),
    );
  }

  BaseDropdownItem<String> _commitItem(GitCommit commit) {
    return BaseDropdownItem<String>(
      value: commit.hash,
      builder: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hashChip(context, commit.shortHash),
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
  }

  Widget _buildCommitDropdown(List<GitCommit> commits) {
    final listed = commits.take(50).toList();

    // DropdownButtonFormField asserts that its value matches exactly one
    // item, so a preselected revision outside the listed window must still
    // get an item: the full history is searched first, and a revision the
    // provider does not know at all falls back to a bare hash entry.
    final selected = _selectedCommit;
    BaseDropdownItem<String>? bareSelectedItem;
    if (selected != null &&
        selected != 'HEAD' &&
        !listed.any((commit) => commit.hash == selected)) {
      final known = commits
          .where((commit) => commit.hash == selected)
          .firstOrNull;
      if (known != null) {
        listed.insert(0, known);
      } else {
        bareSelectedItem = BaseDropdownItem<String>(
          value: selected,
          builder: (context) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [_hashChip(context, _shortHash(selected))],
          ),
        );
      }
    }

    return BaseDropdown<String>(
      initialValue: selected,
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
        ?bareSelectedItem,
        ...listed.map(_commitItem),
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
      final actions = ref.read(gitActionsProvider);
      final tagName = _tagNameController.text.trim();
      final message = _messageController.text.trim();
      final commit = _selectedCommit ?? 'HEAD';

      // The actions layer unwraps the git result (a failed `git tag` becomes
      // the exception caught below) and refreshes every tag provider.
      if (_isAnnotated) {
        await actions.createAnnotatedTag(
          tagName,
          message: message,
          commitHash: commit,
        );
      } else {
        await actions.createLightweightTag(tagName, commitHash: commit);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.tagCreatedError(e.toString()),
            ),
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
