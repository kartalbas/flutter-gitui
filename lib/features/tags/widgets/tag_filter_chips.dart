import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_filter_chip.dart';
import '../../../core/git/models/tag.dart';
import '../tags_screen.dart';

/// Filter chips widget for filtering tags by type
class TagFilterChips extends StatelessWidget {
  final List<GitTag> allTags;
  final TagFilterType selectedFilter;
  final ValueChanged<TagFilterType> onFilterChanged;

  const TagFilterChips({
    super.key,
    required this.allTags,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          BaseFilterChip(
            label: 'All',
            count: allTags.length,
            showCount: true,
            selected: selectedFilter == TagFilterType.all,
            onSelected: (selected) => onFilterChanged(TagFilterType.all),
          ),
          const SizedBox(width: AppTheme.paddingS),
          BaseFilterChip(
            label: 'Annotated',
            count: allTags.where((t) => t.isAnnotated).length,
            showCount: true,
            selected: selectedFilter == TagFilterType.annotated,
            onSelected: (selected) => onFilterChanged(TagFilterType.annotated),
          ),
          const SizedBox(width: AppTheme.paddingS),
          BaseFilterChip(
            label: 'Lightweight',
            count: allTags.where((t) => t.isLightweight).length,
            showCount: true,
            selected: selectedFilter == TagFilterType.lightweight,
            onSelected: (selected) => onFilterChanged(TagFilterType.lightweight),
          ),
        ],
      ),
    );
  }
}
