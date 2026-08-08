/// The component half of the golden matrix: every `Base*` component that
/// renders, across its variants, sizes and states, in both brightnesses.
///
/// ## What a component golden can and cannot catch
///
/// A component golden freezes what a component looks like *on its own*. That
/// catches the class of change nothing else does — a corner that lost a
/// degree of rounding, a state layer that stopped painting, a disabled
/// treatment that leaked a semantic tint — but it is blind to the change that
/// actually breaks a screen: a control that grew by 8 dp and now overflows the
/// `Row` it shares with six others. That case is covered by
/// `screen_scenes.dart`; the two halves are complementary and neither
/// substitutes for the other.
///
/// ## How the matrix is organised
///
/// Scenes are grids, not single widgets. Rendering all seven button variants
/// at all three sizes as one image rather than twenty-one keeps the number of
/// baselines reviewable *and* makes the diff more informative: a change that
/// affects only the small size is visible as one row moving against five that
/// did not.
///
/// The exception is a *driven* state. Only one pointer and one focused widget
/// exist per frame, so hover, focus and press each need their own scene. Each
/// such scene renders the driven control on the LEFT and an identical resting
/// control on the RIGHT, so the baseline carries its own control group: a
/// state layer that stops painting shows up as the two halves becoming
/// identical, without anyone having to remember what "hovered" used to look
/// like.
///
/// ## What is deliberately not here
///
/// * **Dialogs** (`BaseDialog`, `BaseViewerDialog`). They are route-hosted and
///   their call-site API is being reworked, so a baseline taken now would
///   encode a shape that is about to change. They join the matrix once that
///   work lands.
/// * **`BaseDiffViewer`**, whose rendering is driven by parsed diff data
///   rather than by design tokens; it belongs with the diff feature's own
///   tests.
/// * **`BaseShrinkingRow`** and `BaseAnimatedWidgets`, which are layout and
///   motion primitives with no resting appearance of their own — the shrinking
///   row is exercised through the screen scenes, which is where its behaviour
///   is observable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/components/base_badge.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_card.dart';
import 'package:flutter_gitui/shared/components/base_date_field.dart';
import 'package:flutter_gitui/shared/components/base_dropdown.dart';
import 'package:flutter_gitui/shared/components/base_filter_chip.dart';
import 'package:flutter_gitui/shared/components/base_label.dart';
import 'package:flutter_gitui/shared/components/base_list_item.dart';
import 'package:flutter_gitui/shared/components/base_panel.dart';
import 'package:flutter_gitui/shared/components/base_select_all_button.dart';
import 'package:flutter_gitui/shared/components/base_speed_dial.dart';
import 'package:flutter_gitui/shared/components/base_switcher.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../support/conformance_harness.dart';
import 'golden_scene.dart';

/// Identifies the control a driven scene puts into the hovered, focused or
/// pressed state. Always the first focusable widget in the scene, so the
/// focus driver can reach it with a single Tab.
const Key kDrivenControlKey = ValueKey<String>('driven-control');

/// Every component scene, in the order the baselines are reviewed.
List<GoldenScene> componentGoldenScenes() => <GoldenScene>[
  ..._buttonScenes(),
  ..._iconButtonScenes(),
  ..._fieldScenes(),
  ..._containerScenes(),
  ..._displayScenes(),
];

// ---------------------------------------------------------------------------
// BaseButton
// ---------------------------------------------------------------------------

/// Every variant, in the order they are declared, so a new variant appears at
/// a stable place in the grid instead of shifting every row below it.
const List<ButtonVariant> _variants = ButtonVariant.values;

const List<ButtonSize> _sizes = ButtonSize.values;

String _variantName(ButtonVariant variant) => variant.name;

String _sizeName(ButtonSize size) => size.name;

List<GoldenScene> _buttonScenes() {
  return <GoldenScene>[
    GoldenScene(
      name: 'base_button_variants',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: _sizes.map(_sizeName).toList(),
        rowHeaders: _variants.map(_variantName).toList(),
        cell: (int row, int column) => BaseButton(
          onPressed: _noop,
          label: 'Action',
          variant: _variants[row],
          size: _sizes[column],
        ),
      ),
    ),
    GoldenScene(
      name: 'base_button_disabled',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: _sizes.map(_sizeName).toList(),
        rowHeaders: _variants.map(_variantName).toList(),
        // `onPressed: null` is the construction-time disabled state; there is
        // nothing to drive. Every variant must collapse onto the same M3
        // disabled treatment here, so a semantic tint surviving into disabled
        // is visible as one row differing from the other six.
        cell: (int row, int column) => BaseButton(
          onPressed: null,
          label: 'Action',
          variant: _variants[row],
          size: _sizes[column],
        ),
      ),
    ),
    GoldenScene(
      name: 'base_button_content',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: _sizes.map(_sizeName).toList(),
        rowHeaders: const <String>[
          'label only',
          'leading icon',
          'trailing icon',
          'both icons',
          'loading',
        ],
        cell: (int row, int column) => BaseButton(
          onPressed: _noop,
          label: 'Commit',
          size: _sizes[column],
          leadingIcon: row == 1 || row == 3 ? IconRole.check : null,
          trailingIcon: row == 2 || row == 3 ? IconRole.arrowRight : null,
          // The spinner animates indefinitely. `settleScene` advances a fixed
          // 400 ms rather than settling, so the baseline captures it at a
          // reproducible phase instead of hanging the test.
          isLoading: row == 4,
        ),
      ),
    ),
    GoldenScene(
      name: 'base_button_full_width',
      // A width constraint is the whole point of the variant, so the scene
      // declares one instead of laying out at an intrinsic width.
      width: 420,
      build: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppTheme.paddingM,
        children: <Widget>[
          for (final ButtonSize size in _sizes)
            BaseButton(
              onPressed: _noop,
              label: 'Full width ${_sizeName(size)}',
              size: size,
              fullWidth: true,
              leadingIcon: IconRole.floppyDisk,
            ),
        ],
      ),
    ),
    // One driven scene per (Material base family x state). The family decides
    // where the state layer comes from — filled derives it from `onPrimary`,
    // outlined and text from `primary`/`onSurface` — so covering one variant
    // per family covers every distinct state-layer treatment without
    // multiplying the baselines by seven.
    for (final _DrivenFamily family in _drivenFamilies)
      for (final _DrivenState state in _DrivenState.values)
        GoldenScene(
          name: 'base_button_${family.name}_${state.name}',
          drive: state.driver,
          build: (BuildContext context) => Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppTheme.paddingL,
            children: <Widget>[
              BaseButton(
                key: kDrivenControlKey,
                onPressed: _noop,
                label: state.name,
                variant: family.variant,
              ),
              // The control group: identical, never driven.
              BaseButton(
                onPressed: _noop,
                label: 'resting',
                variant: family.variant,
              ),
            ],
          ),
        ),
  ];
}

// ---------------------------------------------------------------------------
// BaseIconButton
// ---------------------------------------------------------------------------

List<GoldenScene> _iconButtonScenes() {
  return <GoldenScene>[
    GoldenScene(
      name: 'base_icon_button_variants',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: _sizes.map(_sizeName).toList(),
        rowHeaders: _variants.map(_variantName).toList(),
        cell: (int row, int column) => BaseIconButton(
          onPressed: _noop,
          icon: IconRole.trash,
          tooltip: 'Delete',
          variant: _variants[row],
          size: _sizes[column],
        ),
      ),
    ),
    GoldenScene(
      name: 'base_icon_button_disabled',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: _sizes.map(_sizeName).toList(),
        rowHeaders: _variants.map(_variantName).toList(),
        cell: (int row, int column) => BaseIconButton(
          onPressed: null,
          icon: IconRole.trash,
          tooltip: 'Delete',
          variant: _variants[row],
          size: _sizes[column],
        ),
      ),
    ),
    GoldenScene(
      name: 'base_icon_button_selected',
      // `isSelected` is the only state that is neither driven nor implied by
      // `onPressed`, and the register requires the selected tint to disappear
      // under disabled — which is only checkable if both appear in one image.
      //
      // **THIS SCENE'S TWO BASELINES ARE STALE AND HAVE TO BE REGENERATED ON
      // LINUX**: `base_icon_button_selected_light.png` and
      // `base_icon_button_selected_dark.png`. They were captured while
      // `BaseIconButton` built Material's `IconButton` directly and drew
      // `Icon(icon)` verbatim, so the two selected columns baked an OUTLINED
      // star into the image — an encoding of "selection does not change the
      // mark" that this application contradicts and always did.
      // `MaterialControls.iconButton` now resolves `MaterialGlyphs.filledOf`
      // when `spec.selected` is true, which is Material 3's own toggle
      // behaviour and is what keeps the favourite star on a repository card
      // and the engaged funnel on the tags screen solid, exactly as they were
      // written before the conversion. Those two columns therefore draw a
      // SOLID star now.
      //
      // The move is not avoidable by editing this scene: any role whose
      // filled variant equals its ordinary one draws a different mark from
      // the star and moves the image just the same, and dropping the fill to
      // hold the baseline would un-draw three marks the application has
      // always painted solid and move `screen_tags_filter_band` instead. Two
      // baselines is the cheapest correct answer, and the weight is asserted
      // on EVERY platform by `base_icon_button_conformance_test.dart` so a
      // stale image can never be the only thing that knows.
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: const <String>[
          'toggle off',
          'toggle on',
          'on + disabled',
        ],
        rowHeaders: _variants.map(_variantName).toList(),
        cell: (int row, int column) => BaseIconButton(
          onPressed: column == 2 ? null : _noop,
          icon: IconRole.star,
          tooltip: 'Favorite',
          variant: _variants[row],
          isSelected: column != 0,
        ),
      ),
    ),
    // The ghost variant is the toolbar default and carries by far the most
    // call sites, so it is the one whose state layers are frozen.
    for (final _DrivenState state in _DrivenState.values)
      GoldenScene(
        name: 'base_icon_button_ghost_${state.name}',
        drive: state.driver,
        build: (BuildContext context) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppTheme.paddingL,
          children: <Widget>[
            BaseIconButton(
              key: kDrivenControlKey,
              onPressed: _noop,
              icon: IconRole.arrowsClockwise,
              tooltip: 'Refresh',
            ),
            BaseIconButton(
              onPressed: _noop,
              icon: IconRole.arrowsClockwise,
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Input components
// ---------------------------------------------------------------------------

/// Fields are laid out at a fixed width: an `InputDecorator` has no useful
/// intrinsic width, and a field's appearance is only meaningful under the
/// constraint a form actually gives it.
const double _kFieldWidth = 260.0;

Widget _field(Widget child) => SizedBox(width: _kFieldWidth, child: child);

List<GoldenScene> _fieldScenes() {
  const List<TextFieldVariant> variants = TextFieldVariant.values;
  return <GoldenScene>[
    GoldenScene(
      name: 'base_text_field_states',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: variants.map((TextFieldVariant v) => v.name).toList(),
        rowHeaders: const <String>[
          'empty',
          'with value',
          'helper text',
          'error',
          'disabled',
        ],
        cell: (int row, int column) => _field(
          BaseTextField(
            label: 'Branch name',
            hintText: 'feature/...',
            variant: variants[column],
            initialValue: row == 0 ? null : 'feature/goldens',
            helperText: row == 2 ? 'Lowercase, no spaces' : null,
            errorText: row == 3 ? 'Branch already exists' : null,
            enabled: row != 4,
          ),
        ),
      ),
    ),
    GoldenScene(
      name: 'base_text_field_affordances',
      build: (BuildContext context) => _matrix(
        context,
        // The default variant, named as the enum now names it: these rows are
        // about the affordances inside the field, not about the variant.
        columnHeaders: const <String>['bordered'],
        rowHeaders: const <String>[
          'prefix icon',
          'suffix action',
          'clear button',
          'password toggle',
          'multiline',
        ],
        cell: (int row, int column) => _field(switch (row) {
          0 => const BaseTextField(
            label: 'Search',
            prefixIcon: IconRole.magnifyingGlass,
            initialValue: 'fix(ui)',
          ),
          1 => BaseTextField(
            label: 'Repository',
            initialValue: 'D:/repos/example',
            suffixIcon: IconRole.folder,
            suffixTooltip: 'Browse',
            onSuffixTap: _noop,
          ),
          2 => const BaseTextField(
            label: 'Filter',
            initialValue: 'README',
            showClearButton: true,
          ),
          3 => const BaseTextField(
            label: 'Token',
            initialValue: 'ghp_secret',
            obscureText: true,
            showPasswordToggle: true,
          ),
          _ => const BaseTextField(
            label: 'Commit message',
            initialValue:
                'feat(goldens): add the component matrix\n\n'
                'Freezes every Base component in both brightnesses.',
            maxLines: 4,
          ),
        }),
      ),
    ),
    // Focus is the state the old hand-painted components had no treatment for
    // at all, so it gets its own baseline: the driven field on the left, an
    // untouched one on the right.
    GoldenScene(
      name: 'base_text_field_focused',
      drive: _DrivenState.focused.driver,
      build: (BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppTheme.paddingL,
        children: <Widget>[
          _field(
            const BaseTextField(
              key: kDrivenControlKey,
              label: 'Focused',
              initialValue: 'main',
            ),
          ),
          _field(const BaseTextField(label: 'Resting', initialValue: 'main')),
        ],
      ),
    ),
    GoldenScene(
      name: 'base_dropdown',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: const <String>['closed'],
        rowHeaders: const <String>[
          'value selected',
          'hint only',
          'prefix icon',
          'disabled',
        ],
        cell: (int row, int column) => _field(
          BaseDropdown<String>(
            labelText: row == 1 ? null : 'Base branch',
            hintText: 'Choose a branch',
            initialValue: row == 1 ? null : 'main',
            prefixIcon: row == 2 ? IconRole.gitBranch : null,
            // A null `onChanged` is how a DropdownButtonFormField is disabled,
            // matching the `onPressed: null` convention of the buttons.
            onChanged: row == 3 ? null : (String? value) {},
            items: <BaseDropdownItem<String>>[
              BaseDropdownItem<String>.simple(
                value: 'main',
                label: 'main',
                icon: PhosphorIconsRegular.gitBranch,
              ),
              BaseDropdownItem<String>.simple(
                value: 'develop',
                label: 'develop',
                icon: PhosphorIconsRegular.gitBranch,
              ),
            ],
          ),
        ),
      ),
    ),
    GoldenScene(
      name: 'base_date_field',
      build: (BuildContext context) => _matrix(
        context,
        columnHeaders: const <String>['closed'],
        rowHeaders: const <String>['empty', 'with value'],
        cell: (int row, int column) => _field(
          BaseDateField(
            label: 'Since',
            // A fixed date, never DateTime.now(): a baseline that encodes the
            // day it was generated fails on the next one.
            value: row == 0 ? null : DateTime.utc(2026, 3, 14),
            onChanged: (DateTime? value) {},
          ),
        ),
      ),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Container components
// ---------------------------------------------------------------------------

List<GoldenScene> _containerScenes() {
  return <GoldenScene>[
    GoldenScene(
      name: 'base_card_states',
      width: 900,
      build: (BuildContext context) => _row(<Widget>[
        for (final (String label, BaseCard card) in <(String, BaseCard)>[
          ('default', BaseCard(content: _cardBody('default'), onTap: _noop)),
          (
            'selected',
            BaseCard(
              content: _cardBody('selected'),
              isSelected: true,
              onTap: _noop,
            ),
          ),
          (
            'multi-selected',
            BaseCard(
              content: _cardBody('multi'),
              isMultiSelected: true,
              onTap: _noop,
            ),
          ),
          (
            // A selected row in a panel that does not own focus must read as
            // quieter than the same row in the focused panel; without both in
            // one image that difference is unreviewable.
            'selected, unfocused container',
            BaseCard(
              content: _cardBody('unfocused'),
              isSelected: true,
              containerHasFocus: false,
              onTap: _noop,
            ),
          ),
        ])
          _captioned(context, label, SizedBox(width: 190, child: card)),
      ]),
    ),
    GoldenScene(
      name: 'base_panel_states',
      build: (BuildContext context) => _row(<Widget>[
        _captioned(
          context,
          'plain',
          SizedBox(
            width: 260,
            child: BasePanel(
              title: const TitleSmallLabel('Staged changes'),
              content: _panelBody(),
            ),
          ),
        ),
        _captioned(
          context,
          'actions + border',
          SizedBox(
            width: 280,
            child: BasePanel(
              title: const TitleSmallLabel('Staged changes'),
              hasBorder: true,
              actions: <Widget>[
                BaseIconButton(
                  onPressed: _noop,
                  icon: IconRole.arrowsClockwise,
                  tooltip: 'Refresh',
                  size: ButtonSize.small,
                ),
                BaseIconButton(
                  onPressed: _noop,
                  icon: IconRole.funnel,
                  tooltip: 'Filter',
                  size: ButtonSize.small,
                ),
              ],
              content: _panelBody(),
            ),
          ),
        ),
        _captioned(
          context,
          'collapsible, expanded',
          SizedBox(
            width: 240,
            child: BasePanel(
              title: const TitleSmallLabel('History'),
              isCollapsible: true,
              content: _panelBody(),
            ),
          ),
        ),
        _captioned(
          context,
          'collapsible, collapsed',
          SizedBox(
            width: 240,
            child: BasePanel(
              title: const TitleSmallLabel('History'),
              isCollapsible: true,
              initiallyExpanded: false,
              content: _panelBody(),
            ),
          ),
        ),
      ]),
    ),
    GoldenScene(
      name: 'base_list_item_states',
      width: 760,
      build: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (String caption, BaseListItem item)
              in <(String, BaseListItem)>[
                ('default', BaseListItem(content: _listBody('lib/main.dart'))),
                (
                  'selected',
                  BaseListItem(
                    content: _listBody('lib/app.dart'),
                    isSelected: true,
                  ),
                ),
                (
                  'multi-selected',
                  BaseListItem(
                    content: _listBody('lib/router.dart'),
                    isMultiSelected: true,
                  ),
                ),
                (
                  'selected, unfocused container',
                  BaseListItem(
                    content: _listBody('lib/theme.dart'),
                    isSelected: true,
                    containerHasFocus: false,
                  ),
                ),
                (
                  'leading, trailing and badge',
                  BaseListItem(
                    content: _listBody('README.md'),
                    leading: const Icon(
                      PhosphorIconsRegular.folder,
                      size: AppTheme.iconS,
                    ),
                    badge: const BaseBadge(
                      label: 'M',
                      variant: BadgeVariant.warning,
                      size: BadgeSize.small,
                    ),
                    trailing: BaseIconButton(
                      onPressed: _noop,
                      icon: IconRole.x,
                      tooltip: 'Unstage',
                      size: ButtonSize.small,
                    ),
                  ),
                ),
              ])
            _captioned(context, caption, item, stretch: true),
        ],
      ),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Display components
// ---------------------------------------------------------------------------

List<GoldenScene> _displayScenes() {
  const List<BadgeVariant> badgeVariants = BadgeVariant.values;
  const List<BadgeSize> badgeSizes = BadgeSize.values;
  return <GoldenScene>[
    GoldenScene(
      name: 'base_chips',
      width: 900,
      build: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.paddingM,
        children: <Widget>[
          _captioned(
            context,
            'filter chip',
            _row(<Widget>[
              BaseFilterChip(
                label: 'Modified',
                selected: false,
                onSelected: (bool _) {},
              ),
              BaseFilterChip(
                label: 'Modified',
                selected: true,
                onSelected: (bool _) {},
              ),
              BaseFilterChip(
                label: 'Staged',
                selected: true,
                icon: PhosphorIconsRegular.check,
                count: 12,
                showCount: true,
                onSelected: (bool _) {},
              ),
            ]),
          ),
          // The single-choice component is a group, so the scene shows a group
          // rather than three loose chips in states that could never coexist:
          // only one option of a group is ever chosen, and the baseline has to
          // show what the app can actually render.
          _captioned(
            context,
            'choice group',
            BaseChoiceGroup<String>(
              options: const <ChoiceOption<String>>[
                ChoiceOption<String>(value: 'feature', label: 'feature'),
                ChoiceOption<String>(value: 'release', label: 'release'),
                ChoiceOption<String>(
                  value: 'hotfix',
                  label: 'hotfix',
                  icon: PhosphorIconsRegular.warning,
                ),
              ],
              selected: 'release',
              onSelected: (String _) {},
            ),
          ),
          _captioned(
            context,
            'action chip',
            _row(<Widget>[
              BaseActionChip(label: 'Fetch', onPressed: _noop),
              BaseActionChip(
                label: 'Pull',
                icon: PhosphorIconsRegular.arrowsClockwise,
                onPressed: _noop,
              ),
            ]),
          ),
        ],
      ),
    ),
    GoldenScene(
      name: 'base_badges',
      build: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.paddingL,
        children: <Widget>[
          _matrix(
            context,
            columnHeaders: badgeSizes.map((BadgeSize s) => s.name).toList(),
            rowHeaders: badgeVariants.map((BadgeVariant v) => v.name).toList(),
            cell: (int row, int column) => BaseBadge(
              label: 'status',
              variant: badgeVariants[row],
              size: badgeSizes[column],
            ),
          ),
          _captioned(
            context,
            'icon, square and deletable',
            _row(<Widget>[
              const BaseBadge(
                label: 'ahead 3',
                variant: BadgeVariant.success,
                icon: PhosphorIconsRegular.arrowRight,
              ),
              const BaseBadge(
                label: 'squared',
                variant: BadgeVariant.info,
                isPill: false,
              ),
              BaseBadge(
                label: 'deletable',
                variant: BadgeVariant.neutral,
                onDeleted: _noop,
              ),
            ]),
          ),
          _captioned(
            context,
            'numeric, icon and dot',
            _row(<Widget>[
              const BaseNumericBadge(count: 7),
              const BaseNumericBadge(count: 143),
              const BaseIconBadge(
                count: 4,
                child: Icon(PhosphorIconsRegular.gitBranch),
              ),
              const BaseDotBadge(),
            ]),
          ),
        ],
      ),
    ),
    // The type scale is the app's most load-bearing token set and the one the
    // issue found collapsed from fifteen sizes to five. Rendering every role
    // with the same sample string turns "the hierarchy does not exist at
    // runtime" into something visible at a glance.
    GoldenScene(
      name: 'base_labels_type_scale',
      width: 760,
      build: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (String role, Widget label) in <(String, Widget)>[
            ('displayLarge', const DisplayLargeLabel('Commit')),
            ('displayMedium', const DisplayMediumLabel('Commit')),
            ('displaySmall', const DisplaySmallLabel('Commit')),
            ('headlineLarge', const HeadlineLargeLabel('Commit')),
            ('headlineMedium', const HeadlineMediumLabel('Commit')),
            ('headlineSmall', const HeadlineSmallLabel('Commit')),
            ('titleLarge', const TitleLargeLabel('Commit')),
            ('titleMedium', const TitleMediumLabel('Commit')),
            ('titleSmall', const TitleSmallLabel('Commit')),
            ('bodyLarge', const BodyLargeLabel('Commit')),
            ('bodyMedium', const BodyMediumLabel('Commit')),
            ('bodySmall', const BodySmallLabel('Commit')),
            ('labelLarge', const LabelLargeLabel('Commit')),
            ('labelMedium', const LabelMediumLabel('Commit')),
            ('labelSmall', const LabelSmallLabel('Commit')),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: AppTheme.paddingM,
                children: <Widget>[
                  SizedBox(width: 140, child: _caption(context, role)),
                  label,
                ],
              ),
            ),
        ],
      ),
    ),
    GoldenScene(
      name: 'base_misc_controls',
      width: 900,
      build: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.paddingL,
        children: <Widget>[
          _captioned(
            context,
            'switcher',
            _row(<Widget>[
              BaseSwitcher(
                icon: PhosphorIconsRegular.folder,
                label: 'flutter-gitui',
                tooltip: 'Repository',
                onTap: _noop,
              ),
              BaseSwitcher(
                icon: PhosphorIconsRegular.gitBranch,
                label: 'master',
                tooltip: 'Branch',
                showDropdown: true,
                onTap: _noop,
              ),
              // The registered minimum width: a switcher squeezed to it must
              // ellipsize rather than overflow, which is only observable in a
              // baseline that actually applies the constraint.
              const SizedBox(
                width: BaseSwitcher.minShrunkWidth,
                child: BaseSwitcher(
                  icon: PhosphorIconsRegular.gitBranch,
                  label: 'feature/a-very-long-branch-name',
                  tooltip: 'Branch',
                  showDropdown: true,
                ),
              ),
            ]),
          ),
          _captioned(
            context,
            'select all',
            _row(<Widget>[
              const BaseSelectAllButton(isAllSelected: false, onPressed: _noop),
              const BaseSelectAllButton(isAllSelected: true, onPressed: _noop),
              const BaseSelectAllIconButton(
                isAllSelected: false,
                onPressed: _noop,
              ),
              const BaseSelectAllIconButton(
                isAllSelected: true,
                onPressed: _noop,
              ),
              const BaseSelectionCountBadge(count: 12),
            ]),
          ),
          _captioned(
            context,
            'speed dial (collapsed, expanded)',
            // BaseSpeedDial builds a `Positioned`, so it only lays out inside
            // a Stack — it is designed to float in the corner of a screen and
            // positions itself from the bottom-right edge. The scene therefore
            // gives each one its own Stack of a fixed size, which is also what
            // makes the dial's own 16 dp edge margin visible in the baseline.
            _row(<Widget>[
              for (final bool expanded in <bool>[false, true])
                SizedBox(
                  width: 260,
                  height: 240,
                  child: Stack(
                    children: <Widget>[
                      BaseSpeedDial(
                        actions: _speedDialActions,
                        isExpanded: expanded,
                        onToggle: _noop,
                        onCollapse: _noop,
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        ],
      ),
    ),
  ];
}

final List<SpeedDialAction> _speedDialActions = <SpeedDialAction>[
  SpeedDialAction(
    icon: PhosphorIconsRegular.plus,
    label: 'New branch',
    onPressed: _noop,
  ),
  SpeedDialAction(
    icon: PhosphorIconsRegular.copy,
    label: 'Clone',
    onPressed: _noop,
  ),
];

// ---------------------------------------------------------------------------
// Driven states
// ---------------------------------------------------------------------------

/// The three states that exist only while something is being done to the
/// control, and therefore need a driver and a scene of their own. Disabled and
/// selected are construction-time states and live in the grids instead.
enum _DrivenState {
  hovered,
  focused,
  pressed;

  SceneDriver get driver => switch (this) {
    _DrivenState.hovered => (WidgetTester tester) async {
      await hoverOver(tester, find.byKey(kDrivenControlKey));
    },
    // Tab reaches the first focusable widget in the scene, which every driven
    // scene deliberately places first.
    _DrivenState.focused => focusFirstWithTab,
    _DrivenState.pressed => (WidgetTester tester) async {
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byKey(kDrivenControlKey),
      );
      // The gesture is released at teardown rather than here: lifting the
      // finger starts the splash's fade-out, and the frame that is captured
      // must still show the pressed state.
      addTearDown(() async {
        await gesture.up();
      });
    },
  };
}

/// One representative variant per Material button family. The family, not the
/// variant, decides which role the state layer derives from.
enum _DrivenFamily {
  filled(ButtonVariant.primary),
  outlined(ButtonVariant.secondary),
  text(ButtonVariant.tertiary);

  const _DrivenFamily(this.variant);

  final ButtonVariant variant;
}

const List<_DrivenFamily> _drivenFamilies = _DrivenFamily.values;

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

/// A labelled grid: one row per [rowHeaders] entry, one column per
/// [columnHeaders] entry, each cell built by [cell].
///
/// The headers are part of the image on purpose. A reviewer looking at a diff
/// months from now has only the PNG, and an unlabelled grid of twenty-one
/// buttons does not say which row is `dangerSecondary`.
Widget _matrix(
  BuildContext context, {
  required List<String> columnHeaders,
  required List<String> rowHeaders,
  required Widget Function(int row, int column) cell,
}) {
  return Table(
    defaultColumnWidth: const IntrinsicColumnWidth(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: <TableRow>[
      TableRow(
        children: <Widget>[
          const SizedBox.shrink(),
          for (final String header in columnHeaders)
            _cellPadding(_caption(context, header)),
        ],
      ),
      for (int row = 0; row < rowHeaders.length; row++)
        TableRow(
          children: <Widget>[
            _cellPadding(_caption(context, rowHeaders[row])),
            for (int column = 0; column < columnHeaders.length; column++)
              _cellPadding(
                Align(
                  alignment: Alignment.centerLeft,
                  child: cell(row, column),
                ),
              ),
          ],
        ),
    ],
  );
}

Widget _cellPadding(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: AppTheme.paddingS,
    vertical: AppTheme.paddingXS,
  ),
  child: child,
);

/// The caption style used for grid headers and scene labels. It is
/// deliberately taken from the theme rather than hard-coded, so a caption can
/// never accidentally become the most stable text in an image whose whole
/// point is to detect typography changes.
Widget _caption(BuildContext context, String text) {
  final ThemeData theme = Theme.of(context);
  return Text(
    text,
    style: theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

/// A component under a caption naming what is being shown.
Widget _captioned(
  BuildContext context,
  String caption,
  Widget child, {
  bool stretch = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.paddingS),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      spacing: AppTheme.paddingXS,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: _caption(context, caption),
        ),
        child,
      ],
    ),
  );
}

Widget _row(
  List<Widget> children, {
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: crossAxisAlignment,
    spacing: AppTheme.paddingM,
    children: children,
  );
}

Widget _cardBody(String label) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: AppTheme.paddingXS,
  children: <Widget>[
    TitleSmallLabel(label),
    const BodySmallLabel('12 commits ahead'),
  ],
);

Widget _panelBody() => const Padding(
  padding: EdgeInsets.symmetric(vertical: AppTheme.paddingS),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      BodySmallLabel('lib/main.dart'),
      BodySmallLabel('lib/app.dart'),
    ],
  ),
);

Widget _listBody(String path) => Row(
  spacing: AppTheme.paddingS,
  children: <Widget>[
    Expanded(child: BodyMediumLabel(path, overflow: TextOverflow.ellipsis)),
    const BodySmallLabel('+12 -3'),
  ],
);

/// A callback that does nothing. Scenes need enabled controls, and an enabled
/// control needs a non-null callback; nothing in a golden ever fires it.
void _noop() {}
