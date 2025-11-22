import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_dropdown.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/tag.dart';

/// Dialog for creating a new Git tag
class CreateTagDialog extends ConsumerStatefulWidget {
  final String? commitHash;
  final String? commitMessage;

  const CreateTagDialog({
    super.key,
    this.commitHash,
    this.commitMessage,
  });

  @override
  ConsumerState<CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends ConsumerState<CreateTagDialog> {
  final _tagNameController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isAnnotated = true;

  @override
  void dispose() {
    _tagNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _applyTemplate(GitTag template) {
    setState(() {
      _tagNameController.text = template.name;
      if (template.isAnnotated && template.message != null) {
        _messageController.text = template.message!;
        _isAnnotated = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final tagsAsync = ref.watch(tagsProvider);

    // Get last 10 tags sorted by date (newest first)
    final recentTags = tagsAsync.whenData((tags) {
      final sortedTags = List<GitTag>.from(tags);
      sortedTags.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });
      return sortedTags.take(10).toList();
    }).value ?? [];

    return BaseDialog(
      title: loc.createTagDialog,
      icon: PhosphorIconsRegular.tag,
      variant: DialogVariant.normal,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show commit info if provided
            if (widget.commitHash != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.gitCommit,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                        BodySmallLabel(
                          widget.commitHash!.substring(0, 7),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    if (widget.commitMessage != null) ...[
                      const SizedBox(height: AppTheme.paddingS),
                      BodyMediumLabel(widget.commitMessage!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.paddingM),
            ] else
              ...[
                BodyMediumLabel(loc.createNewTagAtHead),
                const SizedBox(height: AppTheme.paddingM),
              ],
            // Template selector
            if (recentTags.isNotEmpty) ...[
              LabelMediumLabel('Use Recent Tag as Template'),
              const SizedBox(height: AppTheme.paddingS),
              BaseDropdown<GitTag?>(
                labelText: 'Template',
                hintText: 'Select a tag template...',
                prefixIcon: PhosphorIconsRegular.tag,
                items: [
                  BaseDropdownItem<GitTag?>.simple(
                    value: null,
                    label: 'No template',
                    icon: PhosphorIconsRegular.x,
                  ),
                  ...recentTags.map((tag) => BaseDropdownItem<GitTag?>.withBadge(
                    value: tag,
                    label: tag.name,
                    icon: tag.isAnnotated ? PhosphorIconsBold.tag : PhosphorIconsRegular.tag,
                    badgeText: tag.isAnnotated ? 'annotated' : null,
                  )),
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
            BaseTextField(
              controller: _tagNameController,
              label: loc.tagName,
              hintText: loc.tagNameHint,
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.paddingM),
            SwitchListTile(
              value: _isAnnotated,
              onChanged: (value) {
                setState(() {
                  _isAnnotated = value;
                });
              },
              title: BodyMediumLabel(loc.annotatedTag),
              subtitle: BodySmallLabel(loc.includeMessageWithTag),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isAnnotated) ...[
              const SizedBox(height: AppTheme.paddingM),
              BaseTextField(
                controller: _messageController,
                label: loc.message,
                hintText: loc.releaseNotesHint,
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
      actions: [
        BaseButton(
          label: loc.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: loc.create,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop({
            'name': _tagNameController.text,
            'message': _messageController.text,
            'annotated': _isAnnotated,
          }),
        ),
      ],
    );
  }
}
