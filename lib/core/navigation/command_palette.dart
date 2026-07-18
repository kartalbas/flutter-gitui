import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import '../../generated/app_localizations.dart';
import '../../shared/components/base_badge.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_list_item.dart';
import '../../shared/components/base_text_field.dart';
import '../../shared/theme/app_theme.dart';
import 'git_commands.dart';

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
      final titleScore = ratio(query.toLowerCase(), command.getTitle(l10n).toLowerCase());
      final descScore = ratio(query.toLowerCase(), command.getDescription(l10n).toLowerCase());
      final categoryScore = ratio(query.toLowerCase(), command.category.getLocalizedName(l10n).toLowerCase());

      final maxScore = [titleScore, descScore, categoryScore].reduce((a, b) => a > b ? a : b);

      if (maxScore > 40) {
        // Threshold for fuzzy match
        results.add(command);
      }
    }

    // Sort by relevance
    results.sort((a, b) {
      final aScore = ratio(query.toLowerCase(), a.getTitle(l10n).toLowerCase());
      final bScore = ratio(query.toLowerCase(), b.getTitle(l10n).toLowerCase());
      return bScore.compareTo(aScore);
    });

    setState(() {
      _filteredCommands = results;
      _selectedIndex = 0;
    });
  }

  void _executeCommand(GitCommand command) async {
    // Close palette first to restore context to the main screen
    Navigator.of(context).pop();

    // Give the navigation time to complete so context is valid
    await Future.delayed(const Duration(milliseconds: 50));

    // Execute command with restored context
    if (mounted) {
      command.onExecute(context, ref);
    }
  }

  void _moveSelection(int delta) {
    if (_filteredCommands.isEmpty) return;

    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _filteredCommands.length - 1);
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
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Focus(
          onKeyEvent: _handleKeyEvent,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusL),
              ),
            ),
            child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: AppTheme.paddingS),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                child: BaseTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: AppLocalizations.of(context)!.hintTextCommandPalette,
                  prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                  variant: TextFieldVariant.filled,
                  onSubmitted: (_) {
                    if (_filteredCommands.isNotEmpty) {
                      _executeCommand(_filteredCommands[_selectedIndex]);
                    }
                  },
                ),
              ),

              // Results count
              if (_controller.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingM),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BodySmallLabel(
                      '${_filteredCommands.length} results',
                    ),
                  ),
                ),

              const SizedBox(height: AppTheme.paddingS),

              // Command list
              Expanded(
                child: _filteredCommands.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIconsRegular.magnifyingGlass,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppTheme.paddingM),
                            TitleMediumLabel(
                              'No commands found',
                            ),
                            const SizedBox(height: AppTheme.paddingS),
                            BodySmallLabel(
                              'Try a different search term',
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredCommands.length,
                        itemBuilder: (context, index) {
                          final command = _filteredCommands[index];
                          final isSelected = index == _selectedIndex;

                          final l10n = AppLocalizations.of(context)!;
                          return BaseListItem(
                            isSelected: isSelected,
                            leading: Icon(command.icon),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BodyMediumLabel(command.getTitle(l10n)),
                                BodySmallLabel(command.getDescription(l10n)),
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
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildKeyHint(context, '↑↓', 'Navigate'),
                    const SizedBox(width: AppTheme.paddingM),
                    _buildKeyHint(context, '↵', 'Execute'),
                    const SizedBox(width: AppTheme.paddingM),
                    _buildKeyHint(context, 'Esc', 'Close'),
                    const Spacer(),
                    BodySmallLabel(
                      '${GitCommands.all.length} commands available',
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildKeyHint(BuildContext context, String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingS,
            vertical: AppTheme.paddingXS,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: LabelSmallLabel(
            key,
          ),
        ),
        const SizedBox(width: AppTheme.paddingXS),
        BodySmallLabel(
          label,
        ),
      ],
    );
  }
}
