import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/git/models/tag.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_date_field.dart';
import '../../../shared/components/base_dropdown.dart';

/// Date range filter options
enum DateRangeFilter { all, today, lastWeek, lastMonth, lastYear, custom }

/// Advanced filters dialog for tags
class AdvancedFiltersDialog extends StatefulWidget {
  final List<GitTag> allTags;
  final DateRangeFilter initialDateFilter;
  final DateTime? initialCustomDateStart;
  final DateTime? initialCustomDateEnd;
  final String? initialAuthorFilter;
  final bool initialUseRegex;

  const AdvancedFiltersDialog({
    super.key,
    required this.allTags,
    this.initialDateFilter = DateRangeFilter.all,
    this.initialCustomDateStart,
    this.initialCustomDateEnd,
    this.initialAuthorFilter,
    this.initialUseRegex = false,
  });

  @override
  State<AdvancedFiltersDialog> createState() => _AdvancedFiltersDialogState();
}

class _AdvancedFiltersDialogState extends State<AdvancedFiltersDialog> {
  late DateRangeFilter _dateFilter;
  late DateTime? _customDateStart;
  late DateTime? _customDateEnd;
  late String? _authorFilter;
  late bool _useRegex;

  @override
  void initState() {
    super.initState();
    _dateFilter = widget.initialDateFilter;
    _customDateStart = widget.initialCustomDateStart;
    _customDateEnd = widget.initialCustomDateEnd;
    _authorFilter = widget.initialAuthorFilter;
    _useRegex = widget.initialUseRegex;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Get unique authors from tags
    final authors =
        widget.allTags
            .where((tag) => tag.taggerName != null)
            .map((tag) => tag.taggerName!)
            .toSet()
            .toList()
          ..sort();

    return BaseDialog(
      title: loc.advancedFiltersDialog,
      icon: IconRole.funnel,
      variant: DialogVariant.normal,
      maxWidth: 500,
      onSubmit: () => Navigator.of(context).pop({
        'dateFilter': _dateFilter,
        'customDateStart': _customDateStart,
        'customDateEnd': _customDateEnd,
        'authorFilter': _authorFilter,
        'useRegex': _useRegex,
      }),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Filter
            TitleSmallLabel(loc.dateRange),
            const SizedBox(height: AppTheme.paddingS),
            BaseDropdown<DateRangeFilter>(
              initialValue: _dateFilter,
              prefixIcon: IconRole.calendar,
              items: DateRangeFilter.values.map((filter) {
                return BaseDropdownItem<DateRangeFilter>.simple(
                  value: filter,
                  label: _getDateFilterLabel(filter),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _dateFilter = value;
                  });
                }
              },
            ),
            if (_dateFilter == DateRangeFilter.custom) ...[
              const SizedBox(height: AppTheme.paddingM),
              Row(
                children: [
                  Expanded(
                    child: BaseDateField(
                      label: loc.startDate,
                      value: _customDateStart,
                      onChanged: (date) =>
                          setState(() => _customDateStart = date),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: BaseDateField(
                      label: loc.endDate,
                      value: _customDateEnd,
                      onChanged: (date) =>
                          setState(() => _customDateEnd = date),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.paddingL),

            // Author Filter
            TitleSmallLabel(loc.authorTagger),
            const SizedBox(height: AppTheme.paddingS),
            if (authors.isNotEmpty)
              BaseDropdown<String?>(
                initialValue: _authorFilter,
                prefixIcon: IconRole.user,
                hintText: loc.allAuthors,
                items: [
                  BaseDropdownItem<String?>.simple(
                    value: null,
                    label: loc.allAuthors,
                  ),
                  ...authors.map((author) {
                    return BaseDropdownItem<String?>.simple(
                      value: author,
                      label: author,
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _authorFilter = value;
                  });
                },
              )
            else
              BodyMediumLabel(loc.noAuthorsFound),
            const SizedBox(height: AppTheme.paddingL),

            // Regex Search Toggle
            SwitchListTile(
              value: _useRegex,
              onChanged: (value) {
                setState(() {
                  _useRegex = value;
                });
              },
              title: BodyMediumLabel(loc.useRegularExpressions),
              subtitle: BodySmallLabel(loc.enableRegexPatternMatching),
              secondary: const Icon(PhosphorIconsRegular.code),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        // Resetting every filter is a second, opposite way to leave with a
        // result, not the one the dialog is asking about.
        DialogAction(
          label: loc.resetAll,
          role: DialogActionRole.neutral,
          onPressed: () {
            Navigator.of(context).pop({'reset': true});
          },
        ),
        DialogAction(
          label: loc.done,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop({
            'dateFilter': _dateFilter,
            'customDateStart': _customDateStart,
            'customDateEnd': _customDateEnd,
            'authorFilter': _authorFilter,
            'useRegex': _useRegex,
          }),
        ),
      ],
    );
  }

  String _getDateFilterLabel(DateRangeFilter filter) {
    final loc = AppLocalizations.of(context)!;
    switch (filter) {
      case DateRangeFilter.today:
        return loc.today;
      case DateRangeFilter.lastWeek:
        return loc.lastWeek;
      case DateRangeFilter.lastMonth:
        return loc.lastMonth;
      case DateRangeFilter.lastYear:
        return loc.lastYear;
      case DateRangeFilter.custom:
        return loc.customRange;
      case DateRangeFilter.all:
        return loc.allTime;
    }
  }
}
