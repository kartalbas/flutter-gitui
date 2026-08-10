import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, ToggleKind, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_toggle_row.dart';
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
          BaseToggleRow(
            value: _stashAllFiles,
            // `switching`: flipping it re-selects the file list immediately,
            // so it is in force the moment it moves rather than something the
            // dialog's confirm button applies later.
            kind: ToggleKind.switching,
            onChanged: (value) {
              setState(() {
                _stashAllFiles = value ?? false;
                if (_stashAllFiles) {
                  // Select all files when switching to "all files" mode
                  _selectedFiles.clear();
                  _selectedFiles.addAll(allStatuses.map((f) => f.path));
                }
              });
            },
            label: l10n.stashAllFiles,
            description: l10n.stashAllFilesToggle,
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
            // The bordered box round the file list is a CARD, and `Inset.none`
            // is the rung `BaseCard`'s own doc names for the case: "a list
            // that must reach the card's border". The stroke and the 4 dp
            // corner were the card's edge drawn by hand - and the identical
            // list in `squash_commits_dialog.dart` drew the same edge at 8,
            // which is what a corner named in a screen costs. Both are the
            // member's corner now.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: BaseCard(
                isSelectable: false,
                inset: Inset.none,
                content: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allStatuses.length,
                  itemBuilder: (context, index) {
                    final file = allStatuses[index];
                    final isSelected = _selectedFiles.contains(file.path);

                    // NOT `BaseToggleRow`, and the reason is a contract gap
                    // rather than an oversight: this row's subtitle carries the
                    // file's git status TONE, and `ToggleRowSpec.description`
                    // is a bare String. Converting would silently drop the
                    // colour that tells added from deleted at a glance, which
                    // is an appearance change hiding inside a rename. Reported
                    // against `controls.toggleRow` instead.
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
          BaseToggleRow(
            value: _includeUntracked,
            onChanged: (value) {
              setState(() {
                _includeUntracked = value ?? false;
              });
            },
            label: l10n.includeUntrackedFiles,
          ),
          BaseToggleRow(
            value: _keepIndex,
            onChanged: (value) {
              setState(() {
                _keepIndex = value ?? false;
              });
            },
            label: l10n.keepStagedChanges,
            description: l10n.keepStagedChangesSubtitle,
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
