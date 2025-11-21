import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_button.dart';
import '../dialogs/advanced_filters_dialog.dart';
import '../services/tags_service.dart';

/// Active filters row for tags screen
class TagsActiveFilters extends StatelessWidget {
  final DateRangeFilter dateFilter;
  final String? authorFilter;
  final bool useRegex;
  final VoidCallback onClearDateFilter;
  final VoidCallback onClearAuthorFilter;
  final VoidCallback onClearRegexFilter;
  final VoidCallback onClearAllFilters;
  final TagsService tagsService;

  const TagsActiveFilters({
    super.key,
    required this.dateFilter,
    required this.authorFilter,
    required this.useRegex,
    required this.onClearDateFilter,
    required this.onClearAuthorFilter,
    required this.onClearRegexFilter,
    required this.onClearAllFilters,
    required this.tagsService,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (dateFilter != DateRangeFilter.all)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.paddingS),
              child: BaseBadge(
                label: tagsService.getDateFilterLabel(dateFilter),
                icon: PhosphorIconsRegular.calendar,
                variant: BadgeVariant.neutral,
                size: BadgeSize.medium,
                onDeleted: onClearDateFilter,
              ),
            ),
          if (authorFilter != null && authorFilter!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.paddingS),
              child: BaseBadge(
                label: AppLocalizations.of(context)!.authorFilter(authorFilter!),
                icon: PhosphorIconsRegular.user,
                variant: BadgeVariant.neutral,
                size: BadgeSize.medium,
                onDeleted: onClearAuthorFilter,
              ),
            ),
          if (useRegex)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.paddingS),
              child: BaseBadge(
                label: AppLocalizations.of(context)!.regex,
                icon: PhosphorIconsRegular.code,
                variant: BadgeVariant.neutral,
                size: BadgeSize.medium,
                onDeleted: onClearRegexFilter,
              ),
            ),
          BaseButton(
            label: AppLocalizations.of(context)!.clearAll,
            variant: ButtonVariant.tertiary,
            size: ButtonSize.small,
            leadingIcon: PhosphorIconsRegular.x,
            onPressed: onClearAllFilters,
          ),
        ],
      ),
    );
  }
}
