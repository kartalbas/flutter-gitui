import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/commit.dart';
import '../../core/git/models/tag.dart';
import '../components/base_dialog.dart';
import '../components/base_dropdown.dart';
import '../components/base_layout.dart';

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
      icon: IconRole.tag,
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
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: BaseInset(
                  child: Row(
                    children: [
                      // The mark of an ordinary notice, at the ordinary size:
                      // it belongs to the line beside it rather than standing
                      // over it.
                      const BaseIcon(IconRole.info),
                      const BaseGap(Proximity.related),
                      Expanded(
                        child: BaseLabel(
                          l10n.createTagDialogDescription,
                          role: TextRole.detail,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const BaseGap(Proximity.separate),

              // Template selector: prefill from a recent tag
              if (recentTags.isNotEmpty) ...[
                BaseDropdown<GitTag?>(
                  labelText: l10n.useRecentTagAsTemplate,
                  hintText: l10n.selectTagTemplate,
                  prefixIcon: IconRole.tag,
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
                const BaseGap(Proximity.grouped),
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
                prefixIcon: IconRole.tag,
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
              const BaseGap(Proximity.grouped),

              // Target commit
              BaseLabel(l10n.targetCommit, role: TextRole.sectionTitle),
              const BaseGap(Proximity.related),
              commitsAsync.when(
                data: (commits) => _buildCommitDropdown(commits),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    BaseLabel(l10n.errorLoadingCommits, role: TextRole.body),
              ),
              const BaseGap(Proximity.separate),

              // Annotated tag option
              SwitchListTile(
                title: BaseLabel(l10n.annotatedTag, role: TextRole.body),
                subtitle: BaseLabel(
                  l10n.includeMessageWithTag,
                  role: TextRole.detail,
                ),
                value: _isAnnotated,
                onChanged: (value) {
                  setState(() => _isAnnotated = value);
                },
              ),
              const BaseGap(Proximity.grouped),

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
                const BaseGap(Proximity.grouped),
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

  // Decided in #438: this chip does not become `surfaces.badge`. Its fill
  // names a Material container role, which no contract tone should carry -
  // neither Fluent nor macOS has a paired-container concept - and its label
  // rides the type ramp where a badge's deliberately sits below it. See the
  // fuller argument at the blame panel's hash chip
  // (file_blame_panel.dart, the same construction with a tap).
  Widget _hashChip(BuildContext context, String shortHash) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: BaseLabel(shortHash, role: TextRole.detail),
    );
  }

  BaseDropdownItem<String> _commitItem(GitCommit commit) {
    return BaseDropdownItem<String>(
      value: commit.hash,
      builder: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hashChip(context, commit.shortHash),
          const BaseGap(Proximity.related),
          Flexible(
            fit: FlexFit.loose,
            child: BaseLabel(commit.message, role: TextRole.body, maxLines: 1),
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
              // A dense mark inside a menu entry: the row is one line tall and
              // the mark is part of the line.
              const BaseIcon(IconRole.arrowUp, scale: ControlScale.compact),
              const BaseGap(Proximity.related),
              BaseLabel(
                AppLocalizations.of(context)!.headCurrentCommit,
                role: TextRole.body,
              ),
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
            // A surface FILL, not a foreground: this is what the notice is
            // painted in, and its words are paired against it. The whole
            // `SnackBar` is `overlays.notify`, and the fill leaves with it.
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
