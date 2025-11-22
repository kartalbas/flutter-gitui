import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/git_providers.dart';

/// Dialog for creating a new stash
class CreateStashDialog extends ConsumerStatefulWidget {
  const CreateStashDialog({super.key});

  @override
  ConsumerState<CreateStashDialog> createState() => _CreateStashDialogState();
}

class _CreateStashDialogState extends ConsumerState<CreateStashDialog> {
  final _messageController = TextEditingController();
  bool _includeUntracked = false;
  bool _keepIndex = false;
  bool _stashAllFiles = true;
  final Set<String> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    // Initialize selected files with all files
    final allStatuses = ref.read(repositoryStatusProvider).value ?? [];
    _selectedFiles.addAll(allStatuses.map((f) => f.path));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allStatuses = ref.watch(repositoryStatusProvider).value ?? [];

    return BaseDialog(
      title: l10n.createStashDialog,
      icon: PhosphorIconsRegular.floppyDisk,
      variant: DialogVariant.normal,
      maxWidth: 600,
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyMediumLabel(l10n.saveChangesToStash),
            const SizedBox(height: AppTheme.paddingM),
            BaseTextField(
              controller: _messageController,
              label: l10n.messageOptional,
              hintText: l10n.describeWork,
              maxLines: 2,
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.paddingM),

            // File selection mode toggle
            SwitchListTile(
              value: _stashAllFiles,
              onChanged: (value) {
                setState(() {
                  _stashAllFiles = value;
                  if (value) {
                    // Select all files when switching to "all files" mode
                    _selectedFiles.clear();
                    _selectedFiles.addAll(allStatuses.map((f) => f.path));
                  }
                });
              },
              title: BodyMediumLabel(l10n.stashAllFiles),
              subtitle: BodySmallLabel(l10n.stashAllFilesToggle),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            // File selection list (only show when not stashing all files)
            if (!_stashAllFiles && allStatuses.isNotEmpty) ...[
              const SizedBox(height: AppTheme.paddingM),
              Row(
                children: [
                  TitleSmallLabel(
                    l10n.selectFilesToStash(_selectedFiles.length, allStatuses.length),
                  ),
                  const Spacer(),
                  BaseButton(
                    label: l10n.selectAll,
                    variant: ButtonVariant.tertiary,
                    onPressed: () {
                      setState(() {
                        _selectedFiles.clear();
                        _selectedFiles.addAll(allStatuses.map((f) => f.path));
                      });
                    },
                  ),
                  BaseButton(
                    label: l10n.deselectAll,
                    variant: ButtonVariant.tertiary,
                    onPressed: () {
                      setState(() {
                        _selectedFiles.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingS),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allStatuses.length,
                  itemBuilder: (context, index) {
                    final file = allStatuses[index];
                    final isSelected = _selectedFiles.contains(file.path);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedFiles.add(file.path);
                          } else {
                            _selectedFiles.remove(file.path);
                          }
                        });
                      },
                      title: BodyMediumLabel(file.path),
                      subtitle: LabelMediumLabel(
                        file.primaryStatus.displayName,
                        color: file.primaryStatus.color,
                      ),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.paddingS,
                      ),
                    );
                  },
                ),
              ),
            ] else if (!_stashAllFiles && allStatuses.isEmpty) ...[
              const SizedBox(height: AppTheme.paddingM),
              BodySmallLabel(
                l10n.noFilesToStash,
                color: Theme.of(context).colorScheme.error,
              ),
            ],

            const SizedBox(height: AppTheme.paddingM),
            CheckboxListTile(
              value: _includeUntracked,
              onChanged: (value) {
                setState(() {
                  _includeUntracked = value ?? false;
                });
              },
              title: BodyMediumLabel(l10n.includeUntrackedFiles),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _keepIndex,
              onChanged: (value) {
                setState(() {
                  _keepIndex = value ?? false;
                });
              },
              title: BodyMediumLabel(l10n.keepStagedChanges),
              subtitle: BodySmallLabel(l10n.keepStagedChangesSubtitle),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: l10n.create,
          variant: ButtonVariant.primary,
          onPressed: _selectedFiles.isEmpty && !_stashAllFiles
              ? null
              : () => Navigator.of(context).pop({
                    'message': _messageController.text.trim(),
                    'includeUntracked': _includeUntracked,
                    'keepIndex': _keepIndex,
                    'stashAllFiles': _stashAllFiles,
                    'selectedFiles': _selectedFiles.toList(),
                  }),
        ),
      ],
    );
  }
}
