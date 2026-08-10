import 'package:flutter/widgets.dart';

import '../../../shared/components/base_filter_chip.dart';
import '../../../core/git/models/tag.dart';
import '../tags_screen.dart';
import '../../../shared/components/base_layout.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity;

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
          const BaseGap(Proximity.related),
          BaseFilterChip(
            label: 'Annotated',
            count: allTags.where((t) => t.isAnnotated).length,
            showCount: true,
            selected: selectedFilter == TagFilterType.annotated,
            onSelected: (selected) => onFilterChanged(TagFilterType.annotated),
          ),
          const BaseGap(Proximity.related),
          BaseFilterChip(
            label: 'Lightweight',
            count: allTags.where((t) => t.isLightweight).length,
            showCount: true,
            selected: selectedFilter == TagFilterType.lightweight,
            onSelected: (selected) =>
                onFilterChanged(TagFilterType.lightweight),
          ),
        ],
      ),
    );
  }
}
