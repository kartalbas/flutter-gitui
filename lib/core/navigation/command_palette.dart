import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../generated/app_localizations.dart';
import '../../shared/components/base_badge.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_icon.dart';
import '../../shared/components/base_list_item.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/utils/fuzzy_match.dart';
import '../../shared/widgets/empty_state.dart';
import 'git_commands.dart';
import '../../shared/components/base_layout.dart';
import '../../shared/components/base_dialog.dart';

/// Command palette for searching and executing Git operations
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<GitCommand> _filteredCommands = GitCommands.all;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    // Focus the text field when palette opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredCommands = GitCommands.all;
        _selectedIndex = 0;
      });
      return;
    }

    // Get localization for fuzzy search
    final l10n = AppLocalizations.of(context)!;

    // Fuzzy search
    final results = <GitCommand>[];
    for (final command in GitCommands.all) {
      final titleScore = similarityRatio(
        query.toLowerCase(),
        command.getTitle(l10n).toLowerCase(),
      );
      final descScore = similarityRatio(
        query.toLowerCase(),
        command.getDescription(l10n).toLowerCase(),
      );
      final categoryScore = similarityRatio(
        query.toLowerCase(),
        command.category.getLocalizedName(l10n).toLowerCase(),
      );

      final maxScore = [
        titleScore,
        descScore,
        categoryScore,
      ].reduce((a, b) => a > b ? a : b);

      if (maxScore > 40) {
        // Threshold for fuzzy match
        results.add(command);
      }
    }

    // Sort by relevance
    results.sort((a, b) {
      final aScore = similarityRatio(
        query.toLowerCase(),
        a.getTitle(l10n).toLowerCase(),
      );
      final bScore = similarityRatio(
        query.toLowerCase(),
        b.getTitle(l10n).toLowerCase(),
      );
      return bScore.compareTo(aScore);
    });

    setState(() {
      _filteredCommands = results;
      _selectedIndex = 0;
    });
  }

  void _executeCommand(GitCommand command) {
    // This State is disposed once the sheet's exit animation ends, so commands
    // that await dialogs cannot use its context or ref. Return the command as
    // the sheet result and let the palette's opener run it with a long-lived
    // context.
    Navigator.of(context).pop(command);
  }

  void _moveSelection(int delta) {
    if (_filteredCommands.isEmpty) return;

    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(
        0,
        _filteredCommands.length - 1,
      );
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The sheet is gone, and with it the fill, the top corner and the grip
    // its own note said would "leave with the surface that draws it". A
    // palette takes the application away until the user answers and then
    // reports the answer, which is a DIALOG; being a sheet that slides up
    // from the bottom edge was Material's answer to that, hard-wired here.
    // The surface is `chrome.dialogSurface` at `DialogExtent.browser` now, so
    // each language decides its own shape - a sheet on macOS, a ContentDialog
    // in Fluent, a centred surface here, which is also the shape a desktop
    // command palette conventionally takes.
    return BaseDialog(
      title: l10n.commandPalette,
      icon: IconRole.magnifyingGlass,
      // A thing to look through, which is what decides the surface's shape.
      extent: DialogExtent.browser,
      // Enter runs the highlighted command from ANYWHERE in the palette. It
      // used to work only while the search field held focus, through that
      // field's own onSubmitted - which nothing checked, because a bottom
      // sheet answers to no dialog contract. The sweep that every dialog goes
      // through reported it the moment the palette became one.
      onSubmit: _filteredCommands.isEmpty
          ? null
          : () => _executeCommand(_filteredCommands[_selectedIndex]),
      content: Focus(
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            // Search field
            BaseInset(
              all: Inset.normal,
              child: BaseTextField(
                controller: _controller,
                focusNode: _focusNode,
                hintText: l10n.hintTextCommandPalette,
                prefixIcon: IconRole.magnifyingGlass,
                variant: TextFieldVariant.emphasized,
                onSubmitted: (_) {
                  if (_filteredCommands.isNotEmpty) {
                    _executeCommand(_filteredCommands[_selectedIndex]);
                  }
                },
              ),
            ),

            // Results count
            if (_controller.text.isNotEmpty)
              BaseInset(
                x: Inset.normal,
                y: Inset.none,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BaseLabel(
                    l10n.commandPaletteResultsCount(_filteredCommands.length),
                    role: TextRole.detail,
                  ),
                ),
              ),

            const BaseGap(Proximity.related),

            // Command list
            Expanded(
              child: _filteredCommands.isEmpty
                  // A search that matched nothing stands in place of the
                  // palette's whole list, which is the empty-state hero and
                  // not a column this screen gets to arrange itself (#430).
                  // The 48 px glyph left with it: a member that accepts no
                  // size owns the size, so a hero glyph measured at a call
                  // site was a leak by construction rather than a rung this
                  // screen was entitled to pick.
                  ? EmptyStateWidget(
                      icon: PhosphorIconsRegular.magnifyingGlass,
                      title: l10n.commandPaletteNoCommandsFound,
                      message: l10n.commandPaletteTryDifferentSearchTerm,
                    )
                  : ListView.builder(
                      itemCount: _filteredCommands.length,
                      itemBuilder: (context, index) {
                        final command = _filteredCommands[index];
                        final isSelected = index == _selectedIndex;

                        final l10n = AppLocalizations.of(context)!;
                        return BaseListItem(
                          isSelected: isSelected,
                          // The command's mark, resolved by the skin. The
                          // prominent scale is Material's own default
                          // glyph size (24), which is exactly what the
                          // bare `Icon(command.icon)` this replaces
                          // rendered at under the row's ambient icon
                          // theme, so the conversion changes the
                          // vocabulary and not a pixel. The neutral tone
                          // leaves the colour to the row, as before.
                          leading: BaseIcon(
                            command.icon,
                            scale: ControlScale.prominent,
                          ),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BaseLabel(
                                command.getTitle(l10n),
                                role: TextRole.body,
                              ),
                              BaseLabel(
                                command.getDescription(l10n),
                                role: TextRole.detail,
                              ),
                            ],
                          ),
                          trailing: command.shortcut != null
                              ? BaseBadge(
                                  label: command.shortcut!,
                                  size: BadgeSize.small,
                                  variant: BadgeVariant.neutral,
                                )
                              : null,
                          onTap: () => _executeCommand(command),
                        );
                      },
                    ),
            ),

            // Footer with tips
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: BaseInset(
                all: Inset.normal,
                child: Row(
                  children: [
                    _buildKeyHint(
                      context,
                      '↑↓',
                      l10n.commandPaletteHintNavigate,
                    ),
                    const BaseGap(Proximity.grouped),
                    _buildKeyHint(context, '↵', l10n.commandPaletteHintExecute),
                    const BaseGap(Proximity.grouped),
                    _buildKeyHint(context, 'Esc', l10n.commandPaletteHintClose),
                    const BaseGap(Proximity.grouped),
                    // The sheet is capped at Material 3's 640px, so at the
                    // 800x600 minimum window the trailing count is the child
                    // that yields: it takes whatever width the key hints
                    // leave over and ellipsizes instead of overflowing.
                    Expanded(
                      child: BaseLabel(
                        l10n.commandPaletteCommandsAvailable(
                          GitCommands.all.length,
                        ),
                        role: TextRole.detail,
                        align: TextAlign.end,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One footer hint: the key, and what pressing it does.
  ///
  /// The key wears the SAME pill the command rows above already use for a
  /// command's own shortcut (`trailing: BaseBadge(...)`), and until now this
  /// file drew the two differently: the row's shortcut went through the
  /// member, and the footer hand-painted a lookalike at a 8 dp corner with a
  /// 1 px outline and an 8/8 inset. One meaning, two drawings, one file - and
  /// the footer could not see the mismatch, because the drawn copy has no way
  /// to ask what the member rounds at. Deleting the corner is what removes
  /// the ability to disagree; the outline goes with it, since the pill the
  /// footer was imitating has never had one.
  Widget _buildKeyHint(BuildContext context, String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BaseBadge(
          label: key,
          variant: BadgeVariant.neutral,
          size: BadgeSize.small,
        ),
        const BaseGap(Proximity.hairline),
        BaseLabel(label, role: TextRole.detail),
      ],
    );
  }
}
