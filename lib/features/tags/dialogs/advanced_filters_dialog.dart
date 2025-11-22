import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/git/models/tag.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_date_field.dart';
import '../../../shared/components/base_dropdown.dart';

/// Date range filter options
enum DateRangeFilter {
  all,
  today,
  lastWeek,
  lastMonth,
  lastYear,
  custom,
}

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
    final authors = widget.allTags
        .where((tag) => tag.taggerName != null)
        .map((tag) => tag.taggerName!)
        .toSet()
        .toList()
      ..sort();

    return BaseDialog(
      title: loc.advancedFiltersDialog,
      icon: PhosphorIconsRegular.funnel,
      variant: DialogVariant.normal,
      maxWidth: 500,
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
              prefixIcon: PhosphorIconsRegular.calendar,
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
                      onChanged: (date) => setState(() => _customDateStart = date),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: BaseDateField(
                      label: loc.endDate,
                      value: _customDateEnd,
                      onChanged: (date) => setState(() => _customDateEnd = date),
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
                prefixIcon: PhosphorIconsRegular.user,
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
        BaseButton(
          label: loc.resetAll,
          variant: ButtonVariant.tertiary,
          onPressed: () {
            Navigator.of(context).pop({
              'reset': true,
            });
          },
        ),
        BaseButton(
          label: loc.done,
          variant: ButtonVariant.primary,
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
