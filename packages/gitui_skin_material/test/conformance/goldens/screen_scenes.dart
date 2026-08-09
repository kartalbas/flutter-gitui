/// The screen half of the golden matrix: the app's densest bars, rendered at
/// several widths.
///
/// ## Why these exist at all
///
/// A component golden freezes a control in isolation and is therefore blind to
/// the failure mode that actually reaches users: a control that grew — a
/// button that went from a 32 dp visual container to a 40 dp one, an icon
/// button whose padded tap target widened from 40 to 48 — inside a `Row` whose
/// width arithmetic was written for the old number. Nothing in
/// `component_scenes.dart` can see that, because in isolation the grown
/// control looks perfectly correct. These scenes exist to see it.
///
/// ## Why they are reconstructions rather than the real screens
///
/// The two densest bars in the application are `AppShell`'s top toolbar
/// (lib/core/navigation/app_shell.dart, 14-16 interactive controls in one row)
/// and `BrowseScreen`'s search toolbar
/// (lib/features/browse/browse_screen.dart). Neither can be instantiated in a
/// widget test: `AppShell` watches eleven Riverpod providers, starts timers and
/// runs a post-frame fetch sweep against a live repository, and `BrowseScreen`
/// builds its toolbar in a private method behind a provider-backed file tree
/// over a real directory. Rendering either would mean mocking most of the
/// application, and the resulting baseline would be a picture of the mocks.
///
/// What these scenes do instead is reproduce the *layout contract* of those
/// bars from the same widgets the real ones are built out of, with the same
/// constants, and lay it out under the same kind of width constraint. The
/// switchers are the one substitution: `WorkspaceSwitcher` and its three
/// siblings are zero-parameter `ConsumerWidget`s that render a `BaseSwitcher`
/// with provider-supplied text, so the scene uses `BaseSwitcher` directly with
/// fixed text. Everything that decides the geometry — `BaseShrinkingRow` with
/// `BaseSwitcher.minShrunkWidth`, the `ConstrainedBox` ceiling built from
/// `OverflowActionBar.menuExtent`, the real `OverflowActionBar` with its
/// `itemExtent` arithmetic — is the shipping code.
///
/// ## Why each scene is one image at three widths
///
/// A responsive bar has no single correct appearance; it has a rule. Stacking
/// the same bar at a wide, a medium and a narrow width inside one image makes
/// the rule itself reviewable — you can see actions migrate into the overflow
/// menu and labels start to ellipsize — and it keeps one baseline per scene
/// per brightness instead of three.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gitui/core/git/models/file_status.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/features/changes/widgets/file_list_item.dart';
import 'package:flutter_gitui/features/tags/tags_screen.dart';
import 'package:flutter_gitui/features/tags/widgets/tag_filter_chips.dart';
import 'package:flutter_gitui/features/tags/widgets/tags_batch_operations_bar.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_shrinking_row.dart';
import 'package:flutter_gitui/shared/components/base_switcher.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_gitui/shared/widgets/inline_search_field.dart';
import 'package:flutter_gitui/shared/widgets/overflow_action_bar.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, MenuAnchorSpec, MenuChoice, MenuEntry, Overlays;

import 'golden_scene.dart';

/// The widths every screen scene is rendered at, widest first.
///
/// 1240 is the content column of a maximised window on a 1280 surface, 900 a
/// half-screen window, and 640 the narrowest width the shell is expected to
/// stay usable at. The last one is where a bar that grew by a few dp stops
/// fitting, which is the whole reason the narrow case is in the picture.
const List<double> _kBarWidths = <double>[1240, 900, 640];

/// Fixed width of every screen scene's image, wide enough for the widest bar
/// plus the scene padding.
final double _kSceneWidth = _kBarWidths.first + 2 * kGoldenScenePadding;

List<GoldenScene> screenGoldenScenes() => <GoldenScene>[
  GoldenScene(
    name: 'screen_shell_toolbar',
    width: _kSceneWidth,
    build: (BuildContext context) =>
        _atEachWidth(context, (BuildContext context) => _shellToolbar(context)),
  ),
  GoldenScene(
    name: 'screen_changes_file_rows',
    width: _kSceneWidth,
    build: (BuildContext context) =>
        _atEachWidth(context, (BuildContext context) => _changesFileRows()),
  ),
  GoldenScene(
    name: 'screen_tags_filter_band',
    width: _kSceneWidth,
    build: (BuildContext context) =>
        _atEachWidth(context, (BuildContext context) => _tagsFilterBand()),
  ),
];

/// Stacks [bar] once per entry in [_kBarWidths], each under a hard width
/// constraint and captioned with the width it was laid out at.
Widget _atEachWidth(BuildContext context, WidgetBuilder bar) {
  final ThemeData theme = Theme.of(context);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppTheme.paddingL,
    children: <Widget>[
      for (final double width in _kBarWidths)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppTheme.paddingXS,
          children: <Widget>[
            Text(
              '${width.toStringAsFixed(0)} dp',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: width, child: bar(context)),
          ],
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// AppShell top toolbar
// ---------------------------------------------------------------------------

/// The densest bar in the application, reconstructed from the shipping
/// widgets and the shipping constants.
///
/// Mirrors lib/core/navigation/app_shell.dart: a `surfaceContainerLow`
/// container with a bottom outline, an outer `LayoutBuilder` that splits the
/// row between the left cluster and a right cluster capped at a quarter of the
/// bar, and an inner `LayoutBuilder` that gives the switcher group everything
/// except one reserved overflow-menu button before the git actions claim what
/// is left.
///
/// The two `OverflowActionBar`s are the real widget, so its `itemExtent`
/// arithmetic — documented as "the 48 dp tap target the button pads itself out
/// to, not its 32 dp visual container" — is exercised against whatever
/// `BaseIconButton` actually lays out. That coupling is precisely what a
/// component golden cannot check.
Widget _shellToolbar(BuildContext context) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppTheme.paddingM,
      vertical: AppTheme.paddingS,
    ),
    decoration: BoxDecoration(
      color: colors.surfaceContainerLow,
      border: Border(bottom: BorderSide(color: colors.outlineVariant)),
    ),
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Row(
        children: <Widget>[
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints inner) => Row(
                children: <Widget>[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          (inner.maxWidth -
                                  AppTheme.paddingM -
                                  OverflowActionBar.menuExtent)
                              .clamp(0.0, inner.maxWidth),
                    ),
                    child: const BaseShrinkingRow(
                      spacing: AppTheme.paddingM,
                      minChildWidth: BaseSwitcher.minShrunkWidth,
                      children: <Widget>[
                        BaseSwitcher(
                          icon: PhosphorIconsRegular.folder,
                          label: 'Default workspace',
                          tooltip: 'Workspace',
                          showDropdown: true,
                        ),
                        BaseSwitcher(
                          icon: PhosphorIconsRegular.folder,
                          label: 'flutter-gitui',
                          tooltip: 'Repository',
                          showDropdown: true,
                        ),
                        BaseSwitcher(
                          icon: PhosphorIconsRegular.gitBranch,
                          label: 'master',
                          tooltip: 'Branch',
                          showDropdown: true,
                        ),
                        BaseSwitcher(
                          icon: PhosphorIconsRegular.gitBranch,
                          label: 'All repositories',
                          tooltip: 'Global branch',
                          showDropdown: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OverflowActionBar(actions: _gitActions),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppTheme.paddingS),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (constraints.maxWidth * 0.25).clamp(
                OverflowActionBar.menuExtent,
                // The shell derives this ceiling from its own utility action
                // count; three actions at one item extent each plus their gaps
                // is the same arithmetic.
                _utilityActions.length * OverflowActionBar.itemExtent +
                    (_utilityActions.length - 1) * OverflowActionBar.spacing,
              ),
            ),
            child: OverflowActionBar(actions: _utilityActions),
          ),
        ],
      ),
    ),
  );
}

/// The seven git actions the shell's primary bar carries. Two are disabled, so
/// the baseline also freezes the greyed-out treatment the toolbar uses to
/// explain an unavailable action rather than hiding it (#303).
final List<ToolbarAction> _gitActions = <ToolbarAction>[
  ToolbarAction(
    icon: IconRole.arrowsClockwise,
    label: 'Fetch',
    tooltip: 'Fetch from remote',
    onPressed: _noop,
  ),
  ToolbarAction(
    icon: IconRole.arrowDown,
    label: 'Pull',
    tooltip: 'Pull from remote',
    onPressed: _noop,
  ),
  ToolbarAction(
    icon: IconRole.arrowUp,
    label: 'Push',
    tooltip: 'Push to remote',
    onPressed: _noop,
  ),
  ToolbarAction(
    icon: IconRole.gitBranch,
    label: 'Branch',
    tooltip: 'Create a branch',
    onPressed: _noop,
  ),
  ToolbarAction(
    icon: IconRole.gitMerge,
    label: 'Merge',
    tooltip: 'No branch selected',
    onPressed: null,
  ),
  ToolbarAction(
    icon: IconRole.tag,
    label: 'Tag',
    tooltip: 'Create a tag',
    onPressed: _noop,
  ),
  ToolbarAction(
    icon: IconRole.archive,
    label: 'Stash',
    tooltip: 'Nothing to stash',
    onPressed: null,
  ),
];

final List<ToolbarAction> _utilityActions = <ToolbarAction>[
  ToolbarAction(
    icon: IconRole.terminal,
    label: 'Command log',
    tooltip: 'Command log',
    onPressed: _noop,
  ),
  ToolbarAction(
    icon: IconRole.bell,
    label: 'Notifications',
    tooltip: 'Notifications',
    onPressed: _noop,
  ),
  ToolbarAction(
    icon: IconRole.downloadSimple,
    label: 'Update',
    tooltip: 'An update is available',
    onPressed: _noop,
  ),
];

// ---------------------------------------------------------------------------
// Changes screen file rows
// ---------------------------------------------------------------------------

/// The changes screen's file list, built from the real `FileListItem`.
///
/// Each row puts up to three small `BaseIconButton`s into a
/// `Row(mainAxisSize: min)` that shares its line with an ellipsizing path and a
/// status badge. It is the textbook case of the breakage these scenes exist
/// for: widen the small icon button and the action cluster starts eating the
/// path instead of the path ellipsizing sooner, and at the narrow width it
/// stops fitting altogether.
Widget _changesFileRows() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      FileListItem(
        file: const FileStatus(
          path: 'lib/shared/components/base_button.dart',
          indexStatus: FileStatusType.modified,
          workTreeStatus: FileStatusType.unchanged,
        ),
        isStaged: true,
        onUnstage: _noop,
        onDiff: _noop,
      ),
      FileListItem(
        file: const FileStatus(
          path: 'test/conformance/goldens/component_scenes.dart',
          indexStatus: FileStatusType.unchanged,
          workTreeStatus: FileStatusType.added,
        ),
        isStaged: false,
        isSelected: true,
        onStage: _noop,
        onDiscard: _noop,
        onDiff: _noop,
      ),
      FileListItem(
        file: const FileStatus(
          path: 'lib/features/history/widgets/history_list_footer.dart',
          oldPath: 'lib/features/history/history_footer.dart',
          indexStatus: FileStatusType.renamed,
          workTreeStatus: FileStatusType.unchanged,
        ),
        isStaged: true,
        onUnstage: _noop,
        onDiff: _noop,
      ),
      FileListItem(
        file: const FileStatus(
          path:
              'docs/a-deliberately-long-path/that-forces-the-label-to-'
              'ellipsize-before-the-action-cluster-does.md',
          indexStatus: FileStatusType.unchanged,
          workTreeStatus: FileStatusType.modified,
        ),
        isStaged: false,
        onStage: _noop,
        onDiscard: _noop,
        onDiff: _noop,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tags screen search-and-filter band
// ---------------------------------------------------------------------------

/// The tags screen's toolbar band (lib/features/tags/tags_screen.dart:342-437),
/// which is not one row but four stacked ones: a search row, the filter chips,
/// and the batch bar that appears once tags are selected.
///
/// It is the second-densest bar in the application and it fails differently
/// from the shell toolbar: the shell measures its own width and moves actions
/// into an overflow menu, whereas this row simply flexes the search field and
/// lets the four trailing controls take their natural width. A control that
/// grows here therefore does not migrate anywhere — it eats the search field
/// until the field can no longer show a query, which is a usability
/// regression a component golden cannot express and this baseline can.
///
/// The search field, the filter button and both menu anchors are the shipping
/// constructions - the anchors go through `Overlays.anchor` with the same
/// `MenuAnchorSpec`s the screen builds, because a reconstruction still holding
/// the old `BasePopupMenuButton` would keep this golden green while the real
/// bar changed. Only the data is fixed: real `GitTag` value objects, so
/// `TagFilterChips` counts them exactly as it does on the screen.
Widget _tagsFilterBand() {
  return Padding(
    padding: const EdgeInsets.all(AppTheme.paddingM),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppTheme.paddingS,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: InlineSearchField(
                controller: _tagSearchController,
                hintText: 'Search tags...',
                onChanged: _ignoreText,
                onClear: _noop,
              ),
            ),
            const SizedBox(width: AppTheme.paddingS),
            BaseIconButton(
              icon: IconRole.funnel,
              isSelected: true,
              tooltip: 'Advanced filters',
              variant: ButtonVariant.secondary,
              onPressed: _noop,
            ),
            const SizedBox(width: AppTheme.paddingS),
            Overlays.anchor(
              spec: const MenuAnchorSpec(
                icon: IconRole.sortAscending,
                tooltip: 'Sort tags',
              ),
              entries: _sortEntries,
            ),
            const SizedBox(width: AppTheme.paddingS),
            Overlays.anchor(
              spec: const MenuAnchorSpec(
                icon: IconRole.rows,
                tooltip: 'Group tags',
              ),
              entries: _sortEntries,
            ),
          ],
        ),
        TagFilterChips(
          allTags: _tags,
          selectedFilter: TagFilterType.annotated,
          onFilterChanged: _ignoreFilter,
        ),
        TagsBatchOperationsBar(
          selectedCount: 3,
          onPush: _noop,
          onDelete: _noop,
        ),
      ],
    ),
  );
}

/// A controller shared by every render of the band. `InlineSearchField`
/// requires one and does not own it; creating a fresh controller inside the
/// scene builder would leak one per rebuild, and a golden never types into it
/// anyway.
final TextEditingController _tagSearchController = TextEditingController(
  text: 'v0.5',
);

/// Fixed tag data, so `TagFilterChips` shows the same counts on every run.
final List<GitTag> _tags = <GitTag>[
  const GitTag(
    name: 'v0.5.14-alpha',
    commitHash: '690ec6d',
    type: GitTagType.annotated,
  ),
  const GitTag(
    name: 'v0.5.13-alpha',
    commitHash: 'f848304',
    type: GitTagType.annotated,
  ),
  const GitTag(
    name: 'nightly',
    commitHash: 'ad852c5',
    type: GitTagType.lightweight,
  ),
];

/// The choices behind the closed anchors, in the shipping shape
/// (`MenuChoice`, the skin drawing the selection signal). A golden never
/// opens the menu, so the anchor's resting pixels are all this feeds.
const List<MenuEntry> _sortEntries = <MenuEntry>[
  MenuChoice(
    label: 'Name A-Z',
    selected: true,
    icon: IconRole.sortAscending,
    onSelect: _noop,
  ),
  MenuChoice(
    label: 'Newest first',
    selected: false,
    icon: IconRole.sortDescending,
    onSelect: _noop,
  ),
];

void _ignoreText(String value) {}

void _ignoreFilter(TagFilterType value) {}

/// A callback that does nothing; a golden never fires one.
void _noop() {}
