import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/git_providers.dart';
import '../../../shared/components/base_layout.dart';

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
      icon: IconRole.floppyDisk,
      variant: DialogVariant.normal,
      // A message and two switches: fields the user fills in, so the `form`
      // extent, and how wide that is belongs to the skin.
      // The message field is multiline; Enter inside it writes a newline,
      // Enter anywhere else stashes.
      onSubmit: _selectedFiles.isEmpty && !_stashAllFiles
          ? null
          : () => Navigator.of(context).pop({
              'message': _messageController.text.trim(),
              'includeUntracked': _includeUntracked,
              'keepIndex': _keepIndex,
              'stashAllFiles': _stashAllFiles,
              'selectedFiles': _selectedFiles.toList(),
            }),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseLabel(l10n.saveChangesToStash, role: TextRole.body),
          const BaseGap(Proximity.grouped),
          BaseTextField(
            controller: _messageController,
            label: l10n.messageOptional,
            hintText: l10n.describeWork,
            maxLines: 2,
            autofocus: true,
          ),
          const BaseGap(Proximity.grouped),

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
            title: BaseLabel(l10n.stashAllFiles, role: TextRole.body),
            subtitle: BaseLabel(
              l10n.stashAllFilesToggle,
              role: TextRole.detail,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),

          // File selection list (only show when not stashing all files)
          if (!_stashAllFiles && allStatuses.isNotEmpty) ...[
            const BaseGap(Proximity.grouped),
            Row(
              children: [
                BaseLabel(
                  l10n.selectFilesToStash(
                    _selectedFiles.length,
                    allStatuses.length,
                  ),
                  role: TextRole.sectionTitle,
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
            const BaseGap(Proximity.related),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
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
                    title: BaseLabel(file.path, role: TextRole.body),
                    subtitle: BaseLabel(
                      file.primaryStatus.displayName,
                      role: TextRole.detail,
                      tone: file.primaryStatus.toneOf,
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
            const BaseGap(Proximity.grouped),
            BaseLabel(
              l10n.noFilesToStash,
              role: TextRole.detail,
              tone: Tone.danger,
            ),
          ],

          const BaseGap(Proximity.grouped),
          CheckboxListTile(
            value: _includeUntracked,
            onChanged: (value) {
              setState(() {
                _includeUntracked = value ?? false;
              });
            },
            title: BaseLabel(l10n.includeUntrackedFiles, role: TextRole.body),
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
            title: BaseLabel(l10n.keepStagedChanges, role: TextRole.body),
            subtitle: BaseLabel(
              l10n.keepStagedChangesSubtitle,
              role: TextRole.detail,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.create,
          role: DialogActionRole.affirmative,
          enabled: _selectedFiles.isNotEmpty || _stashAllFiles,
          onPressed: () => Navigator.of(context).pop({
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
