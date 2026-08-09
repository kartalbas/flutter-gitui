import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ContentPort, IconRole, Proximity, Skin, SkinScope, TextRole;

import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
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

  const AdvancedSearchDialog({super.key, this.initialFilter});

  @override
  ConsumerState<AdvancedSearchDialog> createState() =>
      _AdvancedSearchDialogState();
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
      // Drawn at Phosphor BOLD before the conversion: the same magnifying
      // glass, heavier stroke. A role carries no weight by design (#249
      // conflict C3) and `BaseDialog` resolves it at the ordinary stroke, so
      // this site's stroke changed. It is one of the twelve the whole
      // application has, each of them recorded and pinned by
      // `test/shared/icons/icon_weight_census_test.dart`, which also carries
      // the measurement behind the decision.
      //
      // The measurement, for this site: `BaseDialog.icon` had 72 call sites,
      // 6 of them bold. And this dialog draws the magnifying glass three
      // times — bold here, ordinary as the query field's prefix and ordinary
      // again on its own Search button — so the heavier stroke was never
      // saying anything the other two were not. That is why the weight is let
      // go rather than smuggled back across the seam as a flag.
      icon: IconRole.magnifyingGlass,
      title: AppLocalizations.of(context)!.advancedSearch,
      // Fields the user fills in - a query, an author, a date range - so the
      // dialog's extent is `form` and the 800 it used to name is the skin's
      // answer now (650 under Material).
      onSubmit: _applySearch,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General query
            _buildSectionTitle(AppLocalizations.of(context)!.generalSearch),
            BaseTextField(
              controller: _queryController,
              label: AppLocalizations.of(context)!.searchQuery,
              hintText: AppLocalizations.of(
                context,
              )!.searchInCommitOrAuthorOrHash,
              prefixIcon: IconRole.magnifyingGlass,
              autofocus: true,
            ),
            // A field and the options qualifying it are members of one
            // group: `grouped`.
            const BaseGap(Proximity.grouped),

            // Search options: three independent qualifiers on one query, so
            // they are a run of equals allowed onto a second line when the
            // labels are long - `layout.row(wrap: true)`. The rung is
            // `grouped`, which is the 16 that stood here exactly.
            _wrappingRun(
              gap: Proximity.grouped,
              children: [
                BaseFilterChip(
                  label: AppLocalizations.of(context)!.caseSensitive,
                  selected: _caseSensitive,
                  onSelected: (value) => setState(() => _caseSensitive = value),
                  icon: _caseSensitive
                      ? PhosphorIconsBold.textAa
                      : PhosphorIconsRegular.textAa,
                ),
                BaseFilterChip(
                  label: AppLocalizations.of(context)!.regularExpression,
                  selected: _useRegex,
                  onSelected: (value) => setState(() => _useRegex = value),
                  icon: _useRegex
                      ? PhosphorIconsBold.asterisk
                      : PhosphorIconsRegular.asterisk,
                ),
                BaseFilterChip(
                  label: AppLocalizations.of(context)!.fuzzyMatch,
                  selected: _fuzzyMatch,
                  onSelected: (value) => setState(() => _fuzzyMatch = value),
                  icon: _fuzzyMatch
                      ? PhosphorIconsBold.target
                      : PhosphorIconsRegular.target,
                ),
              ],
            ),
            // Two groups inside one form: `separate`.
            const BaseGap(Proximity.separate),

            // Specific filters
            _buildSectionTitle(AppLocalizations.of(context)!.specificFilters),

            // Author dropdown
            _buildAuthorDropdown(context),
            const BaseGap(Proximity.grouped),

            BaseTextField(
              controller: _filePathController,
              label: AppLocalizations.of(context)!.filePathLabel,
              hintText: AppLocalizations.of(context)!.filterByFilePathExample,
              prefixIcon: IconRole.file,
            ),
            const BaseGap(Proximity.grouped),

            BaseTextField(
              controller: _hashController,
              label: AppLocalizations.of(context)!.commitHashLabel,
              hintText: AppLocalizations.of(context)!.filterByCommitHashPrefix,
              prefixIcon: IconRole.hash,
            ),
            const BaseGap(Proximity.separate),

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
                const BaseGap(Proximity.grouped),
                Expanded(
                  child: BaseDateField(
                    label: AppLocalizations.of(context)!.toDate,
                    value: _toDate,
                    onChanged: (date) => setState(() => _toDate = date),
                  ),
                ),
              ],
            ),
            const BaseGap(Proximity.grouped),

            // Quick date filters: four shortcuts into the same date range,
            // one run of equals that may take a second line. `related` is
            // the 8 that stood here exactly.
            _wrappingRun(
              gap: Proximity.related,
              children: [
                BaseButton(
                  label: AppLocalizations.of(context)!.today,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: IconRole.calendar,
                  onPressed: () =>
                      _applyQuickFilter(HistorySearchFilter.today()),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.thisWeek,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: IconRole.calendar,
                  onPressed: () =>
                      _applyQuickFilter(HistorySearchFilter.thisWeek()),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.thisMonth,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: IconRole.calendar,
                  onPressed: () =>
                      _applyQuickFilter(HistorySearchFilter.thisMonth()),
                ),
                BaseButton(
                  label: AppLocalizations.of(context)!.last30Days,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: IconRole.calendar,
                  onPressed: () =>
                      _applyQuickFilter(HistorySearchFilter.last30Days()),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        // Clearing the filters resets the form and leaves the dialog open, so
        // it is a peer of searching rather than a way to finish.
        DialogAction(
          label: AppLocalizations.of(context)!.clearFiltersButton,
          role: DialogActionRole.neutral,
          onPressed: _clearFilters,
        ),
        DialogAction(
          label: AppLocalizations.of(context)!.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: AppLocalizations.of(context)!.advancedSearchButton,
          role: DialogActionRole.affirmative,
          icon: IconRole.magnifyingGlass,
          onPressed: _applySearch,
        ),
      ],
    );
  }

  /// A run of equals that is allowed to take a second line, stated once.
  ///
  /// The two runs in this dialog were bare `Wrap`s naming their own item
  /// distance and saying nothing at all about the distance BETWEEN two lines,
  /// which left every wrapped line touching the one above it. `layout.row(wrap:
  /// true)` answers both with one rung, so the line distance follows the item
  /// distance instead of staying at zero - the one thing this conversion moves,
  /// and only in the wrapped state.
  Widget _wrappingRun({
    required Proximity gap,
    required List<Widget> children,
  }) {
    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      return skin.layout.row(
        inner,
        [for (final Widget child in children) ContentPort(child)],
        gap: gap,
        // What the bare `Wrap` did: a run whose members hang from their own
        // top edge rather than being centred on the tallest of them.
        cross: CrossAxisAlignment.start,
        wrap: true,
      );
    });
  }

  Widget _buildSectionTitle(String title) {
    // A section header and the fields under it are two parts of one
    // statement, which is a GAP after the header rather than a one-sided
    // padding around it - the same relationship every other form in the
    // application states, said with the same word.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The brand tint said nothing a section header was not already
        // saying, so it disappears rather than being renamed as a meaning.
        BaseLabel(title, role: TextRole.sectionTitle),
        const BaseGap(Proximity.related),
      ],
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
      filePath: _filePathController.text.isEmpty
          ? null
          : _filePathController.text,
      fromDate: _fromDate,
      toDate: _toDate,
      hashPrefixes: hashPrefixes.isEmpty ? null : hashPrefixes,
      caseSensitive: _caseSensitive,
      useRegex: _useRegex,
      fuzzyMatch: _fuzzyMatch,
    );

    // Apply filter
    ref.read(historySearchFilterProvider.notifier).state = filter;

    Navigator.of(context).pop();
  }

  Widget _buildAuthorDropdown(BuildContext context) {
    final commitsAsync = ref.watch(commitHistoryProvider);

    return commitsAsync.when(
      data: (commits) {
        // Extract unique author-email combinations
        final authorMap = <String, String>{};
        for (final commit in commits) {
          if (commit.author.isNotEmpty &&
              !authorMap.containsKey(commit.author)) {
            authorMap[commit.author] = commit.authorEmail;
          }
        }

        // Sort by author name
        final sortedAuthors = authorMap.keys.toList()..sort();

        return BaseDropdown<String?>(
          initialValue: _selectedAuthor,
          labelText: AppLocalizations.of(context)!.authorLabel,
          hintText: AppLocalizations.of(context)!.filterByAuthorNameOrEmail,
          prefixIcon: IconRole.user,
          items: [
            BaseDropdownItem<String?>.simple(
              value: null,
              label: AppLocalizations.of(context)!.allAuthors,
            ),
            ...sortedAuthors.map((author) {
              final email = authorMap[author]!;
              final displayText = email.isNotEmpty
                  ? '$author ($email)'
                  : author;
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
        prefixIcon: IconRole.user,
        items: const [],
        onChanged: null,
      ),
      error: (error, stack) => BaseDropdown<String?>(
        labelText: AppLocalizations.of(context)!.authorLabel,
        prefixIcon: IconRole.user,
        items: const [],
        onChanged: null,
      ),
    );
  }
}
