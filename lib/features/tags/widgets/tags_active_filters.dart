import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, Proximity;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_layout.dart';
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
          // Each chip's trailing space was an `EdgeInsets.only(right:)`, which
          // is a gap wearing a padding idiom: the distance belongs BETWEEN the
          // chip and the next control, not inside the chip. Stated as
          // composition, the run says it once per chip and the skin decides
          // how far "related" is.
          // Each removal is NAMED, per chip: the removal is a mark-only
          // control, and "what removing this does" is this site's copy
          // decision - TagSpec refuses an unnamed removal since #438, after
          // one skin papered over the absence with its own generic "Delete"
          // and another rendered a control with no name at all.
          if (dateFilter != DateRangeFilter.all) ...<Widget>[
            BaseBadge(
              label: tagsService.getDateFilterLabel(dateFilter),
              icon: IconRole.calendar,
              variant: BadgeVariant.neutral,
              size: BadgeSize.medium,
              onDeleted: onClearDateFilter,
              deleteTooltip: AppLocalizations.of(
                context,
              )!.removeDateFilterTooltip,
            ),
            const BaseGap(Proximity.related),
          ],
          if (authorFilter != null && authorFilter!.isNotEmpty) ...<Widget>[
            BaseBadge(
              label: AppLocalizations.of(context)!.authorFilter(authorFilter!),
              icon: IconRole.user,
              variant: BadgeVariant.neutral,
              size: BadgeSize.medium,
              onDeleted: onClearAuthorFilter,
              deleteTooltip: AppLocalizations.of(
                context,
              )!.removeAuthorFilterTooltip,
            ),
            const BaseGap(Proximity.related),
          ],
          if (useRegex) ...<Widget>[
            BaseBadge(
              label: AppLocalizations.of(context)!.regex,
              icon: IconRole.code,
              variant: BadgeVariant.neutral,
              size: BadgeSize.medium,
              onDeleted: onClearRegexFilter,
              deleteTooltip: AppLocalizations.of(
                context,
              )!.removeRegexFilterTooltip,
            ),
            const BaseGap(Proximity.related),
          ],
          BaseButton(
            label: AppLocalizations.of(context)!.clearAll,
            variant: ButtonVariant.tertiary,
            size: ButtonSize.small,
            leadingIcon: IconRole.x,
            onPressed: onClearAllFilters,
          ),
        ],
      ),
    );
  }
}
