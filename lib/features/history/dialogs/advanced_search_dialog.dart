import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_filter_chip.dart';
import '../../../shared/components/base_date_field.dart';
import '../../../shared/components/base_dropdown.dart';
import '../models/history_search_filter.dart';
import '../providers/history_search_provider.dart';
import '../../../generated/app_localizations.dart';
import '../../../core/git/git_providers.dart';

/// Advanced search dialog for commit history
class AdvancedSearchDialog extends ConsumerStatefulWidget {
  final HistorySearchFilter? initialFilter;

  const AdvancedSearchDialog({
    super.key,
    this.initialFilter,
  });

  @override
  ConsumerState<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends ConsumerState<AdvancedSearchDialog> {
  late final TextEditingController _queryController;
  late final TextEditingController _filePathController;
  late final TextEditingController _hashController;

  String? _selectedAuthor;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _fuzzyMatch = true;

  @override
  void initState() {
    super.initState();

    final filter = widget.initialFilter ?? const HistorySearchFilter.empty();

    _queryController = TextEditingController(text: filter.query);
    _filePathController = TextEditingController(text: filter.filePath);
    _hashController = TextEditingController(
      text: filter.hashPrefixes?.join(', '),
    );

    _selectedAuthor = filter.author;
    _fromDate = filter.fromDate;
    _toDate = filter.toDate;
    _caseSensitive = filter.caseSensitive;
    _useRegex = filter.useRegex;
    _fuzzyMatch = filter.fuzzyMatch;
  }

  @override
  void dispose() {
    _queryController.dispose();
    _filePathController.dispose();
    _hashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      icon: PhosphorIconsBold.magnifyingGlass,
      title: AppLocalizations.of(context)!.advancedSearch,
      maxWidth: 800,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General query
            _buildSectionTitle(AppLocalizations.of(context)!.generalSearch),
            BaseTextField(
              controller: _queryController,
              label: AppLocalizations.of(context)!.searchQuery,
              hintText: AppLocalizations.of(context)!.searchInCommitOrAuthorOrHash,
              prefixIcon: PhosphorIconsRegular.magnifyingGlass,
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.paddingM),

            // Search options
            Wrap(
              spacing: AppTheme.paddingM,
              children: [
                BaseFilterChip(
                  label: AppLocalizations.of(context)!.caseSensitive,
                  selected: _caseSensitive,
                  onSelected: (value) => setState(() => _caseSensitive = value),
                  icon: _caseSensitive ? PhosphorIconsBold.textAa : PhosphorIconsRegular.textAa,
                ),
                BaseFilterChip(
                  label: AppLocalizations.of(context)!.regularExpression,
                  selected: _useRegex,
                  onSelected: (value) => setState(() => _useRegex = value),
                  icon: _useRegex ? PhosphorIconsBold.asterisk : PhosphorIconsRegular.asterisk,
                ),
                BaseFilterChip(
                  label: AppLocalizations.of(context)!.fuzzyMatch,
                  selected: _fuzzyMatch,
                  onSelected: (value) => setState(() => _fuzzyMatch = value),
                  icon: _fuzzyMatch ? PhosphorIconsBold.target : PhosphorIconsRegular.target,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingL),

            // Specific filters
            _buildSectionTitle(AppLocalizations.of(context)!.specificFilters),

            // Author dropdown
            _buildAuthorDropdown(context),
            const SizedBox(height: AppTheme.paddingM),

            BaseTextField(
              controller: _filePathController,
              label: AppLocalizations.of(context)!.filePathLabel,
              hintText: AppLocalizations.of(context)!.filterByFilePathExample,
              prefixIcon: PhosphorIconsRegular.file,
            ),
            const SizedBox(height: AppTheme.paddingM),

            BaseTextField(
              controller: _hashController,
              label: AppLocalizations.of(context)!.commitHashLabel,
              hintText: AppLocalizations.of(context)!.filterByCommitHashPrefix,
              prefixIcon: PhosphorIconsRegular.hash,
            ),
            const SizedBox(height: AppTheme.paddingL),

            // Date range
            _buildSectionTitle(AppLocalizations.of(context)!.dateRangeSection),
            Row(
              children: [
                Expanded(
                  child: BaseDateField(
                    label: AppLocalizations.of(context)!.fromDate,
                    value: _fromDate,
                    onChanged: (date) => setState(() => _fromDate = date),
                  ),
                ),
                const SizedBox(width: AppTheme.paddingM),
                Expanded(
                  child: BaseDateField(
                    label: AppLocalizations.of(context)!.toDate,
                    value: _toDate,
                    onChanged: (date) => setState(() => _toDate = date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingM),

            // Quick date filters
            Wrap(
              spacing: AppTheme.paddingS,
              children: [
                BaseButton(
                  label: AppLocalizations.of(context)!.today,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: PhosphorIconsRegular.calendar,
                  onPressed: () => _applyQuickFilter(HistorySearchFilter.today()),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.thisWeek,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: PhosphorIconsRegular.calendar,
                  onPressed: () => _applyQuickFilter(HistorySearchFilter.thisWeek()),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.thisMonth,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: PhosphorIconsRegular.calendar,
                  onPressed: () => _applyQuickFilter(HistorySearchFilter.thisMonth()),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.last30Days,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: PhosphorIconsRegular.calendar,
                  onPressed: () => _applyQuickFilter(HistorySearchFilter.last30Days()),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        BaseButton(
          label: AppLocalizations.of(context)!.clearFiltersButton,
          variant: ButtonVariant.tertiary,
          onPressed: _clearFilters,
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.advancedSearchButton,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.magnifyingGlass,
          onPressed: _applySearch,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.paddingS),
      child: TitleSmallLabel(
        title,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _applyQuickFilter(HistorySearchFilter quickFilter) {
    setState(() {
      _fromDate = quickFilter.fromDate;
      _toDate = quickFilter.toDate;
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _selectedAuthor = null;
      _filePathController.clear();
      _hashController.clear();
      _fromDate = null;
      _toDate = null;
      _caseSensitive = false;
      _useRegex = false;
      _fuzzyMatch = true;
    });
  }

  void _applySearch() {
    // Parse hash prefixes
    final hashPrefixes = _hashController.text
        .split(',')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    final filter = HistorySearchFilter(
      query: _queryController.text.isEmpty ? null : _queryController.text,
      author: _selectedAuthor,
      committer: null,
      filePath: _filePathController.text.isEmpty ? null : _filePathController.text,
      fromDate: _fromDate,
      toDate: _toDate,
      hashPrefixes: hashPrefixes.isEmpty ? null : hashPrefixes,
      caseSensitive: _caseSensitive,
      useRegex: _useRegex,
      fuzzyMatch: _fuzzyMatch,
    );

    // Apply filter
    ref.read(historySearchFilterProvider.notifier).state = filter;

    // Add to search history if there's a query
    if (filter.query != null && filter.query!.isNotEmpty) {
      ref.read(addSearchToHistoryProvider)(filter.query!);
    }

    Navigator.of(context).pop();
  }

  Widget _buildAuthorDropdown(BuildContext context) {
    final commitsAsync = ref.watch(commitHistoryProvider);

    return commitsAsync.when(
      data: (commits) {
        // Extract unique author-email combinations
        final authorMap = <String, String>{};
        for (final commit in commits) {
          if (commit.author.isNotEmpty && !authorMap.containsKey(commit.author)) {
            authorMap[commit.author] = commit.authorEmail;
          }
        }

        // Sort by author name
        final sortedAuthors = authorMap.keys.toList()..sort();

        return BaseDropdown<String?>(
          initialValue: _selectedAuthor,
          labelText: AppLocalizations.of(context)!.authorLabel,
          hintText: AppLocalizations.of(context)!.filterByAuthorNameOrEmail,
          prefixIcon: PhosphorIconsRegular.user,
          items: [
            BaseDropdownItem<String?>.simple(
              value: null,
              label: AppLocalizations.of(context)!.allAuthors,
            ),
            ...sortedAuthors.map((author) {
              final email = authorMap[author]!;
              final displayText = email.isNotEmpty ? '$author ($email)' : author;
              return BaseDropdownItem<String?>.simple(
                value: author,
                label: displayText,
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedAuthor = value;
            });
          },
        );
      },
      loading: () => BaseDropdown<String?>(
        labelText: AppLocalizations.of(context)!.authorLabel,
        prefixIcon: PhosphorIconsRegular.user,
        items: const [],
        onChanged: null,
      ),
      error: (error, stack) => BaseDropdown<String?>(
        labelText: AppLocalizations.of(context)!.authorLabel,
        prefixIcon: PhosphorIconsRegular.user,
        items: const [],
        onChanged: null,
      ),
    );
  }
}
