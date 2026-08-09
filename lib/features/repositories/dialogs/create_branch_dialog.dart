import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ControlScale,
        IconRole,
        Inset,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_filter_chip.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_layout.dart';

/// Branch prefix options
enum BranchPrefix {
  none('', 'No prefix'),
  feature('feature/', 'Feature'),
  release('release/', 'Release'),
  hotfix('hotfix/', 'Hotfix'),
  bugfix('bugfix/', 'Bugfix'),
  custom('', 'Custom');

  final String prefix;
  final String label;

  const BranchPrefix(this.prefix, this.label);
}

/// Result of the create branch dialog
class CreateBranchDialogResult {
  final String branchName;
  final String prefix;
  final bool setUpstream;
  final bool checkout;

  const CreateBranchDialogResult({
    required this.branchName,
    required this.prefix,
    required this.setUpstream,
    required this.checkout,
  });

  String get fullBranchName =>
      prefix.isEmpty ? branchName : '$prefix$branchName';
}

/// Dialog for creating a branch across multiple repositories
Future<CreateBranchDialogResult?> showCreateBranchDialog(
  BuildContext context, {
  required List<WorkspaceRepository> repositories,
}) {
  return showDialog<CreateBranchDialogResult>(
    context: context,
    builder: (context) => _CreateBranchDialog(repositories: repositories),
  );
}

class _CreateBranchDialog extends StatefulWidget {
  final List<WorkspaceRepository> repositories;

  const _CreateBranchDialog({required this.repositories});

  @override
  State<_CreateBranchDialog> createState() => _CreateBranchDialogState();
}

class _CreateBranchDialogState extends State<_CreateBranchDialog> {
  late TextEditingController _branchNameController;
  late TextEditingController _customPrefixController;
  BranchPrefix _selectedPrefix = BranchPrefix.feature;
  bool _setUpstream = true;
  bool _checkout = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _branchNameController = TextEditingController();
    _customPrefixController = TextEditingController();

    // Listen to text changes to clear errors and update preview
    _branchNameController.addListener(_onTextChanged);
    _customPrefixController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _customPrefixController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // Clear error message if present
      if (_errorMessage != null) {
        _errorMessage = null;
      }
      // Trigger rebuild to update full branch name preview
    });
  }

  String _getCurrentPrefix() {
    if (_selectedPrefix == BranchPrefix.custom) {
      return _customPrefixController.text.trim();
    }
    return _selectedPrefix.prefix;
  }

  String _getFullBranchName() {
    final branchName = _branchNameController.text.trim();
    final prefix = _getCurrentPrefix();
    return prefix.isEmpty ? branchName : '$prefix$branchName';
  }

  String _getPrefixLabel(AppLocalizations l10n, BranchPrefix prefix) {
    switch (prefix) {
      case BranchPrefix.none:
        return l10n.noPrefix;
      case BranchPrefix.feature:
        return l10n.featurePrefix;
      case BranchPrefix.release:
        return l10n.releasePrefix;
      case BranchPrefix.hotfix:
        return l10n.hotfixPrefix;
      case BranchPrefix.bugfix:
        return l10n.bugfixPrefix;
      case BranchPrefix.custom:
        return l10n.customPrefix;
    }
  }

  void _createBranch() {
    final l10n = AppLocalizations.of(context)!;
    final branchName = _branchNameController.text.trim();

    if (branchName.isEmpty) {
      setState(() {
        _errorMessage = l10n.branchNameCannotBeEmpty;
      });
      return;
    }

    // Validate branch name (no spaces, special chars)
    final validBranchName = RegExp(r'^[a-zA-Z0-9_\-\.]+$');
    if (!validBranchName.hasMatch(branchName)) {
      setState(() {
        _errorMessage = l10n.branchNameInvalidCharacters;
      });
      return;
    }

    // Validate custom prefix if selected
    if (_selectedPrefix == BranchPrefix.custom) {
      final customPrefix = _customPrefixController.text.trim();
      if (customPrefix.isNotEmpty && !customPrefix.endsWith('/')) {
        setState(() {
          _errorMessage = l10n.customPrefixMustEndWithSlash;
        });
        return;
      }
    }

    Navigator.of(context).pop(
      CreateBranchDialogResult(
        branchName: branchName,
        prefix: _getCurrentPrefix(),
        setUpstream: _setUpstream,
        checkout: _checkout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fullBranchName = _getFullBranchName();

    return BaseDialog(
      title: l10n.createBranchDialogTitle,
      icon: IconRole.gitBranch,
      variant: DialogVariant.normal,
      // A name, a prefix and a start point: fields the user fills in, so the
      // `form` extent, and the 600 is the skin's number now.
      onSubmit: _createBranch,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            // The callout is `surfaces.banner`: "something about this whole
            // surface needs saying", said until the condition changes, which
            // is exactly what a rejected branch name is. The whole
            // construction goes with the member - the fill, the corner, the
            // inset, the mark, the gap beside it and the
            // `DefaultTextStyle.merge` that was pairing a foreground to a
            // container the dialog painted itself.
            //
            // `Tone.invalid` is kept rather than swapped for `danger`, for
            // the reason the note here already gave: the name the user typed
            // has to be corrected before the dialog can proceed, and nothing
            // has been destroyed. Material has no separate validation role,
            // so the member answers `invalid` with its generic wash - the
            // error colour at 12 % under a readable foreground - where the
            // hand-painted copy used the solid `errorContainer` pairing. The
            // corner goes with it: a banner is a full-width strip in
            // Material, so the 8 dp round this callout drew is gone, and the
            // sentence is set at the member's `titleMedium` rather than at
            // `TextRole.control`.
            SkinScope.render(context, (Skin skin, BuildContext inner) {
              return skin.surfaces.banner(
                inner,
                BannerSpec(
                  tone: Tone.invalid,
                  icon: IconRole.warningCircle,
                  title: _errorMessage!,
                ),
              );
            }),
            const BaseGap(Proximity.grouped),
          ],

          // Branch prefix selector
          BaseLabel(l10n.branchPrefixLabel, role: TextRole.sectionTitle),
          const BaseGap(Proximity.related),

          // One group, not a hand-assembled row of chips: picking a prefix is
          // a single-choice question, and the group is the unit every design
          // language has an answer for (see BaseChoiceGroup). The wrapping row
          // and its spacing now belong to the component, so every such
          // question lays out the same way.
          BaseChoiceGroup<BranchPrefix>(
            options: BranchPrefix.values
                .map(
                  (prefix) => ChoiceOption<BranchPrefix>(
                    value: prefix,
                    label: _getPrefixLabel(l10n, prefix),
                  ),
                )
                .toList(),
            selected: _selectedPrefix,
            onSelected: (prefix) => setState(() => _selectedPrefix = prefix),
          ),

          const BaseGap(Proximity.grouped),

          // Custom prefix input (only shown when custom is selected)
          if (_selectedPrefix == BranchPrefix.custom) ...[
            BaseTextField(
              controller: _customPrefixController,
              label: l10n.customPrefixLabel,
              hintText: l10n.customPrefixHint,
              helperText: l10n.customPrefixHelper,
            ),
            const BaseGap(Proximity.grouped),
          ],

          // Branch name input
          BaseTextField(
            controller: _branchNameController,
            label: l10n.branchNameLabel,
            hintText: l10n.branchNameHint,
            autofocus: true,
          ),

          const BaseGap(Proximity.grouped),

          // The branch this form will produce, shown as its own surface:
          // **here is one self-contained object**, which is `surfaces.card`
          // through the façade. The previous note here refused the member on
          // the grounds that "nothing is picked", but `CardSpec.onTap` says in
          // as many words that a null callback makes a card "only a
          // container", and its own siblings prove it: the identical
          // construction - a fill, an edge, a corner, a `normal` inset, a
          // `micro` caption and the object's name under it - is already
          // `BaseCard(isSelectable: false)` in
          // `create_branch_from_commit_dialog.dart` (the source commit) and in
          // `rebase_dialog.dart` (the current branch). One kind of read-out,
          // three screens, and this was the only one still hand-painting it.
          //
          // What moves: the fill goes one step quieter, from
          // `surfaceContainerHighest` to the card's `surfaceContainerHigh`;
          // the 1 px edge goes from `outline` to the card's `outlineVariant`;
          // and the corner rounds at the skin's 12 rather than the 8 this
          // dialog named. The member's answer is the right one because those
          // three numbers are what "a resting surface holding one object"
          // looks like in this language, decided once, where the two screens
          // above already read it - the 8 here was drift, and it made the same
          // read-out round differently depending on which dialog opened it.
          // The inset is unchanged: `Inset.normal` is 16 either way.
          BaseCard(
            isSelectable: false,
            inset: Inset.normal,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLabel(
                  l10n.fullBranchNameLabel,
                  role: TextRole.micro,
                  tone: Tone.muted,
                ),
                const BaseGap(Proximity.hairline),
                // Muted while nothing has been typed - a placeholder, whose
                // half-alpha was the same statement said twice - and the
                // accent once the preview names the branch that will exist.
                BaseLabel(
                  fullBranchName.isEmpty
                      ? l10n.enterBranchNameLabel
                      : fullBranchName,
                  role: TextRole.itemTitle,
                  tone: fullBranchName.isEmpty ? Tone.muted : Tone.accent,
                ),
              ],
            ),
          ),

          const BaseGap(Proximity.separate),

          // Repository list
          BaseLabel(
            l10n.willCreateInRepositories(widget.repositories.length),
            role: TextRole.sectionTitle,
          ),
          const BaseGap(Proximity.related),

          // The bordered box round the list is a CARD, and `Inset.none` is the
          // rung `BaseCard`'s own doc names for it: "a list that must reach
          // the card's border". Its exact twin - a `maxHeight` cap, an
          // `outline` stroke, an 8 dp corner and a `ListView.builder` of
          // `BaseListItem`s - became exactly this in
          // `squash_commits_dialog.dart`, so the frame does have a name and
          // the previous note here (that no member draws one) was answered in
          // the same change that wrote it.
          //
          // What moves: the box gains the card's `surfaceContainerHigh` fill
          // where it had none, the stroke goes from `outline` to
          // `outlineVariant`, and the corner rounds at 12 instead of 8. The
          // member's answer is the right one because the rows now clip to the
          // corner the language rounds its surfaces at - the hand-drawn 8 was
          // narrower than any card in this dialog and the top row overhung it.
          // The height cap stays application structure: it is what keeps a
          // long repository list from taking the dialog over.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: BaseCard(
              isSelectable: false,
              inset: Inset.none,
              content: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.repositories.length,
                itemBuilder: (context, index) {
                  final repo = widget.repositories[index];
                  return BaseListItem(
                    // The accent marks the repositories the branch will be
                    // created in, at the dense scale a preview list reads at.
                    leading: const BaseIcon(
                      IconRole.folderSimple,
                      scale: ControlScale.compact,
                      tone: Tone.accent,
                    ),
                    content: BaseLabel(repo.displayName, role: TextRole.body),
                  );
                },
              ),
            ),
          ),

          const BaseGap(Proximity.separate),

          // Options
          CheckboxListTile(
            value: _setUpstream,
            onChanged: (value) {
              setState(() {
                _setUpstream = value ?? false;
              });
            },
            title: BaseLabel(l10n.setUpstreamLabel, role: TextRole.body),
            subtitle: BaseLabel(
              l10n.setUpstreamDescription,
              role: TextRole.detail,
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),

          CheckboxListTile(
            value: _checkout,
            onChanged: (value) {
              setState(() {
                _checkout = value ?? false;
              });
            },
            title: BaseLabel(
              l10n.checkoutAfterCreationLabel,
              role: TextRole.body,
            ),
            subtitle: BaseLabel(
              l10n.checkoutAfterCreationDescription,
              role: TextRole.detail,
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
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
          label: l10n.createBranchButton,
          role: DialogActionRole.affirmative,
          onPressed: _createBranch,
        ),
      ],
    );
  }
}
