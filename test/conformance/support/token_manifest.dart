/// Checked-in manifest of every design token the conformance suite measures.
///
/// `expectConformant` refuses to assert on a token that is not listed here,
/// so the set of measured tokens is itself reviewable: adding a measurement
/// requires a diff in this file, and a register entry whose token is missing
/// from this manifest is flagged as dead by deviation_register_test.dart.
///
/// A token id is `<component>.<property>`, exactly as those two fields appear
/// in docs/deviation_register.yaml — e.g. the entry with
/// `component: TextTheme.bodyLarge` and `property: fontSize` is looked up
/// under the token `TextTheme.bodyLarge.fontSize`. Conforming tokens are
/// listed too: the manifest names what is measured, the register names only
/// what is allowed to diverge.
library;

const Set<String> conformanceTokenManifest = <String>{
  // The app's TextTheme vs the Material 3 type-scale oracle
  // (Typography.englishLike2021, flutter/lib/src/material/typography.dart).
  // Values in comments are the M3 sizes at the default (medium) setting;
  // deviating roles carry their register entry id.
  'TextTheme.displayLarge.fontSize', // M3: 57.0 — registered TYPE-001
  'TextTheme.displayMedium.fontSize', // M3: 45.0 — registered TYPE-002
  'TextTheme.displaySmall.fontSize', // M3: 36.0 — registered TYPE-003
  'TextTheme.headlineLarge.fontSize', // M3: 32.0 — registered TYPE-004
  'TextTheme.headlineMedium.fontSize', // M3: 28.0 — registered TYPE-005
  'TextTheme.headlineSmall.fontSize', // M3: 24.0 — registered TYPE-006
  'TextTheme.titleLarge.fontSize', // M3: 22.0 — registered TYPE-007
  'TextTheme.titleMedium.fontSize', // M3: 16.0 — conforms
  'TextTheme.titleSmall.fontSize', // M3: 14.0 — conforms
  'TextTheme.bodyLarge.fontSize', // M3: 16.0 — registered TYPE-008
  'TextTheme.bodyMedium.fontSize', // M3: 14.0 — registered TYPE-009
  'TextTheme.bodySmall.fontSize', // M3: 12.0 — conforms
  'TextTheme.labelLarge.fontSize', // M3: 14.0 — conforms
  'TextTheme.labelMedium.fontSize', // M3: 12.0 — conforms
  'TextTheme.labelSmall.fontSize', // M3: 11.0 — conforms
  // BaseButton vs the Material 3 button oracles (FilledButton /
  // OutlinedButton / TextButton `defaultStyleOf`, Flutter 3.44.4). Geometry
  // is measured on the Material box (the visual container), color roles via
  // `colorRoleName`, typography by mapping the rendered style onto the
  // three M3 label roles.
  'BaseButton.shape', // M3: stadium, 20.0 at the 40 dp container — BTN-001
  'BaseButton.small.containerHeight', // M3: 40.0 — registered BTN-002
  'BaseButton.small.labelTextStyle', // M3: labelLarge — registered BTN-003
  'BaseButton.small.iconSize', // M3: 18.0 — registered BTN-004
  'BaseButton.medium.containerHeight', // M3: 40.0 — conforms
  'BaseButton.medium.minimumWidth', // M3: 64.0 — conforms
  'BaseButton.medium.labelTextStyle', // M3: labelLarge — conforms
  'BaseButton.medium.iconSize', // M3: 18.0 — conforms
  'BaseButton.large.containerHeight', // M3: 40.0 — registered BTN-005
  'BaseButton.large.labelTextStyle', // M3: labelLarge — conforms
  'BaseButton.large.iconSize', // M3: 18.0 — conforms
  'BaseButton.tertiary.foregroundRole', // M3: primary — conforms
  'BaseButton.ghost.foregroundRole', // M3: primary — registered BTN-006
  'BaseButton.disabled.containerColor', // M3: onSurface @ 12% — conforms
  'BaseButton.disabled.foregroundColor', // M3: onSurface @ 38% — conforms
  'BaseButton.overlay.pressed', // M3: onPrimary @ 10% — conforms
  'BaseButton.overlay.hovered', // M3: onPrimary @ 8% — conforms
  'BaseButton.overlay.focused', // M3: onPrimary @ 10% — conforms
  // BaseIconButton vs the Material 3 icon button oracle. IconButton exposes
  // no public `defaultStyleOf` seam (harness note, conformance_harness.dart),
  // so the oracle values are constants pinned from the generated
  // _IconButtonDefaultsM3 (Flutter 3.44.4 icon_button.dart) with source
  // citations in the suite.
  'BaseIconButton.shape', // M3: stadium, 20.0 at the 40 dp container — ICO-001
  'BaseIconButton.small.containerSize', // M3: 40.0 — registered ICO-002
  'BaseIconButton.small.iconSize', // M3: 24.0 — registered ICO-003
  'BaseIconButton.medium.containerSize', // M3: 40.0 — conforms
  'BaseIconButton.medium.iconSize', // M3: 24.0 — registered ICO-004
  'BaseIconButton.large.containerSize', // M3: 40.0 — registered ICO-005
  'BaseIconButton.large.iconSize', // M3: 24.0 — conforms
  'BaseIconButton.standard.foregroundRole', // M3: onSurfaceVariant — conforms
  'BaseIconButton.disabled.containerColor', // M3: onSurface @ 12% — conforms
  'BaseIconButton.disabled.foregroundColor', // M3: onSurface @ 38% — conforms
  'BaseIconButton.overlay.pressed', // M3: onSurfaceVariant @ 10% — conforms
  'BaseIconButton.overlay.hovered', // M3: onSurfaceVariant @ 8% — conforms
  'BaseIconButton.overlay.focused', // M3: onSurfaceVariant @ 10% — conforms
  // BaseCard vs the Material 3 outlined-card oracle (`Card.outlined`,
  // Flutter 3.44.4 card.dart:371-396). Both sides are pumped in the same
  // harness and read with the same probes, so fonts, density and pixel ratio
  // cancel out; state layers are diffed out of the ink paint stream.
  'BaseCard.shape', // M3: 12.0 — conforms
  'BaseCard.elevation', // M3: 0.0 — conforms
  'BaseCard.containerColor', // M3: surface — registered CARD-001
  'BaseCard.borderColor', // M3: outlineVariant — conforms
  'BaseCard.borderWidth', // M3: 1.0 — conforms
  'BaseCard.margin', // M3: 4.0 — registered CARD-002
  'BaseCard.contentTextStyle', // M3: bodyMedium — conforms
  'BaseCard.overlay.hovered', // M3: hoverColor ink — conforms
  'BaseCard.overlay.pressed', // M3: splash + highlight ink — conforms
  'BaseCard.overlay.focused', // M3: focusColor ink — registered CARD-003
  // BaseListItem vs the Material 3 list-item oracle (`ListTile`,
  // Flutter 3.44.4 list_tile.dart:1818-1860).
  'BaseListItem.minTileHeight', // M3: 56.0 — conforms
  'BaseListItem.contentPadding.start', // M3: 16.0 — conforms
  'BaseListItem.contentPadding.end', // M3: 24.0 — conforms
  'BaseListItem.contentPadding.vertical', // M3: 8.0 — registered LIST-001
  'BaseListItem.leadingGap', // M3: 16.0 — conforms
  'BaseListItem.shape', // M3: 0.0 — conforms
  'BaseListItem.tileColor', // M3: transparent — conforms
  'BaseListItem.titleTextStyle', // M3: bodyLarge — conforms
  'BaseListItem.iconColor', // M3: onSurfaceVariant — conforms
  'BaseListItem.overlay.hovered', // M3: hoverColor ink — conforms
  'BaseListItem.overlay.pressed', // M3: splash + highlight ink — conforms
  'BaseListItem.overlay.focused', // M3: focusColor ink — registered LIST-002
  // BasePanel vs two Material 3 oracles: the elevated card for the container
  // (`Card`, card.dart:301-323) and the expansion-tile header for the header
  // row (`ExpansionTile`, expansion_tile.dart:907-925, whose header is a
  // ListTile).
  'BasePanel.elevation', // M3: 1.0 — conforms
  'BasePanel.shape', // M3: 12.0 — conforms
  'BasePanel.containerColor', // M3: surfaceContainerLow — conforms
  'BasePanel.borderColor', // M3: outlineVariant — conforms
  'BasePanel.margin', // M3: 4.0 — registered PANEL-002
  'BasePanel.contentTextStyle', // M3: bodyMedium — conforms
  'BasePanel.header.minTileHeight', // M3: 56.0 — conforms
  'BasePanel.header.contentPadding.start', // M3: 16.0 — registered PANEL-001
  'BasePanel.header.contentPadding.end', // M3: 24.0 — conforms
  'BasePanel.header.titleTextStyle', // M3: bodyLarge — conforms
  'BasePanel.collapsedIconColor', // M3: onSurfaceVariant — conforms
  'BasePanel.expandedIconColor', // M3: primary — conforms
  'BasePanel.header.overlay.hovered', // M3: hoverColor ink — conforms
  'BasePanel.header.overlay.pressed', // M3: splash + highlight — conforms
  'BasePanel.header.overlay.focused', // M3: focusColor ink — conforms
  // BaseTextField vs the Material 3 text-field oracle: a real `TextField`
  // carrying an `OutlineInputBorder`, pumped through the same harness. There
  // is no defaults seam for InputDecorator either — the border for the current
  // state is resolved inside the private `_InputDecoratorState` — so the
  // container, its outline and its corners are read out of the paint stream.
  'BaseTextField.shape', // M3: 4.0 — conforms
  'BaseTextField.containerHeight', // M3: 55.0 (>= 48 dp) — conforms
  'BaseTextField.contentPadding.start', // M3: 16.0 — conforms
  'BaseTextField.contentPadding.top', // M3: 16.0 — conforms
  'BaseTextField.enabled.border', // M3: outline 1 dp — conforms
  'BaseTextField.hovered.border', // M3: onSurface 1 dp — conforms
  'BaseTextField.focused.border', // M3: primary 2 dp — conforms
  'BaseTextField.error.border', // M3: error 1 dp — conforms
  'BaseTextField.disabled.border', // M3: onSurface @ 12% 1 dp — conforms
  'BaseTextField.inputTextStyle', // M3: bodyLarge — conforms
  'BaseTextField.labelTextStyle', // M3: theme label style — conforms
  'BaseTextField.hintTextStyle', // M3: theme hint style — conforms
  'BaseTextField.hintColor', // M3: theme hint color — conforms
  'BaseTextField.helperTextStyle', // M3: bodySmall — conforms
  'BaseTextField.errorTextStyle', // M3: bodySmall on error — conforms
  'BaseTextField.prefixIcon.size', // M3: 24.0 — registered FIELD-001
  'BaseTextField.filled.fillColor', // M3: surfaceContainerHighest — conforms
  'BaseTextField.filled.bottomCornerRadius', // M3: 0.0 — registered FIELD-002
  'BaseTextField.filled.activeIndicator', // M3: onSurfaceVariant — FIELD-003
  // BaseDropdown vs `DropdownButtonFormField` with an `OutlineInputBorder`,
  // the same M3 component it is built on, pumped through the same harness.
  'BaseDropdown.shape', // M3: 4.0 — conforms
  'BaseDropdown.containerHeight', // M3: 56.0 — conforms
  'BaseDropdown.contentPadding.start', // M3: 16.0 — conforms
  'BaseDropdown.enabled.border', // M3: outline 1 dp — conforms
  'BaseDropdown.focused.border', // M3: primary 2 dp — conforms
  'BaseDropdown.labelTextStyle', // M3: theme label style — conforms
  'BaseDropdown.valueTextStyle', // M3: titleMedium — conforms
  'BaseDropdown.prefixIcon.size', // M3: 24.0 — registered DROP-001
  // BaseDateField vs the same text-field oracle as BaseTextField: a picked
  // date is a text field's value, and the component is an `InputDecorator`
  // around it.
  'BaseDateField.shape', // M3: 4.0 — conforms
  'BaseDateField.containerHeight', // M3: 55.0 — conforms
  'BaseDateField.contentPadding.start', // M3: 16.0 — conforms
  'BaseDateField.enabled.border', // M3: outline 1 dp — conforms
  'BaseDateField.hovered.border', // M3: onSurface 1 dp — conforms
  'BaseDateField.focused.border', // M3: primary 2 dp — conforms
  'BaseDateField.valueTextStyle', // M3: bodyLarge — conforms
  'BaseDateField.labelTextStyle', // M3: theme label style — conforms
  'BaseDateField.suffixIcon.size', // M3: 24.0 — registered DATE-001
  // BaseFilterChip / BaseChoiceChip / BaseActionChip vs `FilterChip`,
  // `ChoiceChip` and `ActionChip`, each pumped through the same harness.
  'BaseFilterChip.shape', // M3: 8.0 — conforms
  'BaseFilterChip.containerHeight', // M3: 48.0 — conforms
  'BaseFilterChip.labelTextStyle', // M3: labelLarge — conforms
  'BaseFilterChip.unselected.labelColor', // M3: onSurfaceVariant — conforms
  'BaseFilterChip.selected.labelColor', // M3: the chip's own role — conforms
  'BaseFilterChip.labelInset', // M3: 17.0 — conforms
  'BaseFilterChip.avatar.size', // M3: 18.0 — conforms
  'BaseFilterChip.avatarGap', // M3: 9.0 — conforms
  'BaseFilterChip.unselected.border', // M3: outlineVariant 1 dp — conforms
  'BaseFilterChip.selected.border', // M3: transparent — registered CHIP-001
  'BaseFilterChip.unselected.containerColor', // M3: transparent — conforms
  'BaseFilterChip.selected.containerColor', // M3: secondaryContainer — conforms
  'BaseFilterChip.selected.widthDelta', // M3: +20.0 (checkmark) — CHIP-002
  'BaseFilterChip.overlay.hovered', // M3: hoverColor ink — conforms
  'BaseFilterChip.overlay.pressed', // M3: splash + highlight ink — conforms
  'BaseFilterChip.overlay.focused', // M3: focusColor ink — conforms
  'BaseChoiceChip.shape', // M3: 8.0 — conforms
  'BaseChoiceChip.containerHeight', // M3: 48.0 — conforms
  'BaseChoiceChip.labelTextStyle', // M3: labelLarge — conforms
  'BaseChoiceChip.selected.border', // M3: transparent — registered CHIP-003
  'BaseActionChip.shape', // M3: 8.0 — conforms
  'BaseActionChip.containerHeight', // M3: 48.0 — conforms
  'BaseActionChip.labelTextStyle', // M3: labelLarge — conforms
  'BaseActionChip.labelColor', // M3: onSurface — conforms
  // BaseDialog vs a real `AlertDialog`, both pushed with `showDialog` through
  // the same harness, because a dialog's surface, width and barrier only exist
  // inside a route. Three tokens are pinned from the generated
  // `_DialogDefaultsM3` instead of read off the oracle, because this app's own
  // `dialogTheme` overrides them and a pumped AlertDialog would report the
  // override — see the suite's library comment.
  'BaseDialog.shape', // M3: 28.0 — registered DLG-001
  'BaseDialog.elevation', // M3: 6.0 — conforms
  'BaseDialog.containerColor', // M3: surfaceContainerHigh — conforms
  'BaseDialog.surfaceTintColor', // M3: transparent — conforms
  'BaseDialog.barrierColor', // M3: black at 54% — conforms
  'BaseDialog.titleTextStyle', // M3: headlineSmall (pinned) — conforms
  'BaseDialog.contentTextStyle', // M3: bodyMedium (pinned) — conforms
  'BaseDialog.titlePadding.top', // M3: 24.0 — conforms
  'BaseDialog.contentPadding.start', // M3: 24.0 — conforms
  'BaseDialog.titleToContentGap', // M3: 16.0 — conforms
  'BaseDialog.contentToActionsGap', // M3: 24.0 — conforms
  'BaseDialog.actionsPadding.end', // M3: 24.0 — conforms
  'BaseDialog.actionsPadding.bottom', // M3: 24.0 — conforms
  'BaseDialog.actionsSpacing', // M3: 8.0 — conforms
  'BaseDialog.actionsAlignment', // M3: end — conforms
  'BaseDialog.icon.size', // M3: 24.0 — conforms
  'BaseDialog.icon.color', // M3: secondary (pinned) — registered DLG-002
  'BaseDialog.minWidth', // M3: 280.0 — registered DLG-003
  'BaseDialog.maxWidth', // M3: 1200.0 at the harness surface — DLG-004
  // BaseViewerDialog vs the same `AlertDialog` oracle: the viewer is a
  // `Dialog` too, and measuring both dialog components against one ruler is
  // what shows which differences they share and which are the viewer's own.
  'BaseViewerDialog.shape', // M3: 28.0 — registered VIEW-001
  'BaseViewerDialog.elevation', // M3: 6.0 — conforms
  'BaseViewerDialog.containerColor', // M3: surfaceContainerHigh — conforms
  'BaseViewerDialog.surfaceTintColor', // M3: transparent — conforms
  'BaseViewerDialog.barrierColor', // M3: black at 54% — conforms
  'BaseViewerDialog.titleTextStyle', // M3: headlineSmall — VIEW-002
  'BaseViewerDialog.contentTextStyle', // M3: bodyMedium (pinned) — conforms
  'BaseViewerDialog.headerPadding.start', // M3: 24.0 — registered VIEW-003
  'BaseViewerDialog.contentPadding.start', // M3: 24.0 — registered VIEW-004
  'BaseViewerDialog.actionsPadding.end', // M3: 24.0 — registered VIEW-005
  'BaseViewerDialog.actionsPadding.bottom', // M3: 24.0 — VIEW-006
  'BaseViewerDialog.actionsSpacing', // M3: 8.0 — conforms
  'BaseViewerDialog.actionsAlignment', // M3: end — conforms
  'BaseViewerDialog.minWidth', // M3: 280.0 — registered VIEW-007
  'BaseViewerDialog.maxWidth', // M3: 1200.0 — registered VIEW-008
  // The menu family, against two oracles: a real `PopupMenuButton` holding
  // `PopupMenuItem`s for the surface and the item (BaseMenuItem is a
  // PopupMenuItem subclass), and `MenuItemButton` — M3's own menu item, the
  // only one with a leading-icon slot — for the glyph and the gap after it.
  // Note that `titleSmall` and `labelLarge` share a metric triple in the M3
  // type scale, so `describeTextRole` names the SDK's labelLarge `titleSmall`;
  // both sides go through the same descriptor.
  'BasePopupMenuButton.menu.shape', // M3: 4.0 — conforms
  'BasePopupMenuButton.menu.containerColor', // M3: surfaceContainer — conforms
  'BasePopupMenuButton.menu.elevation', // M3: 3.0 — conforms
  'BasePopupMenuButton.menu.padding.vertical', // M3: 8.0 — conforms
  'BasePopupMenuButton.iconSize', // M3: 24.0 — registered MENU-004
  'BaseMenuItem.minHeight', // M3: 48.0 — conforms
  'BaseMenuItem.contentPadding.start', // M3: 12.0 — conforms
  'BaseMenuItem.labelTextStyle', // M3: labelLarge — conforms
  'BaseMenuItem.labelColor', // M3: onSurface — conforms
  'BaseMenuItem.disabled.labelColor', // M3: onSurface @ 38% — conforms
  'BaseMenuItem.overlay.hovered', // M3: hoverColor ink — conforms
  'BaseMenuItem.overlay.pressed', // M3: splash + highlight ink — conforms
  'BaseMenuItem.overlay.focused', // M3: focusColor ink — conforms
  'MenuItemContent.labelTextStyle', // M3: labelLarge — registered MENU-001
  'MenuItemContent.disabled.labelColor', // M3: onSurface @ 38% — conforms
  'MenuItemContent.iconSize', // M3: 24.0 — registered MENU-002
  'MenuItemContent.leadingGap', // M3: 12.0 — registered MENU-003
  // The badge family vs a real `Badge`, pumped through the same harness.
  // Material 3 has one badge and this app has four, which is what the register
  // entries below describe. `colorRoleName` reports M3's `onError` as
  // `onPrimary` here, because the two roles are the same white in this app's
  // scheme; both sides go through the same descriptor.
  'BaseBadge.containerHeight', // M3: 16.0 (largeSize) — BADGE-001
  'BaseBadge.shape', // M3: stadium — conforms
  'BaseBadge.padding.horizontal', // M3: 4.0 — registered BADGE-002
  'BaseBadge.labelFontSize', // M3: 11.0 (labelSmall) — BADGE-003
  'BaseBadge.danger.containerColor', // M3: error — registered BADGE-004
  'BaseBadge.danger.labelColor', // M3: onError — registered BADGE-005
  'BaseNumericBadge.containerHeight', // M3: 16.0 — registered BADGE-006
  'BaseNumericBadge.shape', // M3: stadium — conforms
  'BaseNumericBadge.danger.containerColor', // M3: error — conforms
  'BaseNumericBadge.danger.labelColor', // M3: onError — conforms
  'BaseNumericBadge.labelTextStyle', // M3: labelSmall — BADGE-007
  'BaseIconBadge.alignment', // M3: topEnd — conforms
  'BaseIconBadge.offset', // M3: Offset(4, 4) from the child — conforms
  'BaseIconBadge.labelTextStyle', // M3: labelSmall — registered BADGE-008
  'BaseDotBadge.size', // M3: 6.0 (smallSize) — registered BADGE-009
  'BaseDotBadge.shape', // M3: circle — conforms
  // BaseSwitch vs the generated `_SwitchDefaultsM3` / `_SwitchConfigM3`
  // (Flutter 3.44.4 switch.dart:2168 onwards). The oracle is pinned rather
  // than pumped because the app installs a `switchTheme`, so a stock `Switch`
  // under this theme would report the app's own values as the specification —
  // see the suite's library comment. Geometry and colour are read out of the
  // paint stream, because a switch is one CustomPaint rather than a tree of
  // styled boxes.
  'BaseSwitch.trackWidth', // M3: 52.0 — conforms
  'BaseSwitch.trackHeight', // M3: 32.0 — conforms
  'BaseSwitch.trackShape', // M3: stadium, 16.0 at the 32 dp track — conforms
  'BaseSwitch.tapTargetSize', // M3: 48.0 — conforms
  'BaseSwitch.unselected.thumbDiameter', // M3: 16.0 — conforms
  'BaseSwitch.selected.thumbDiameter', // M3: 24.0 — conforms
  'BaseSwitch.pressed.thumbDiameter', // M3: 28.0 — conforms
  'BaseSwitch.unselected.trackColor', // M3: surfaceContainerHighest — conforms
  'BaseSwitch.unselected.thumbColor', // M3: outline — conforms
  'BaseSwitch.unselected.trackOutline', // M3: outline 2 dp — conforms
  'BaseSwitch.selected.trackColor', // M3: primary — conforms
  'BaseSwitch.selected.thumbColor', // M3: onPrimary — conforms
  'BaseSwitch.selected.trackOutline', // M3: transparent — conforms
  'BaseSwitch.disabled.unselected.trackColor', // M3: the role @ 12% — conforms
  'BaseSwitch.disabled.unselected.thumbColor', // M3: onSurface @ 38% — conforms
  'BaseSwitch.disabled.selected.trackColor', // M3: onSurface @ 12% — conforms
  'BaseSwitch.disabled.selected.thumbColor', // M3: surface — conforms
  'BaseSwitch.overlay.hovered', // M3: onSurface @ 8% — conforms
  'BaseSwitch.overlay.focused', // M3: onSurface @ 10% — registered SWITCH-001
  'BaseSwitch.overlay.pressed', // M3: onSurface @ 10% — registered SWITCH-002
  'BaseSwitch.selected.overlay.focused', // M3: primary @ 10% — SWITCH-003
  // BaseSpeedDial (lib/shared/components/base_speed_dial.dart) vs the
  // generated `_FABDefaultsM3` (Flutter 3.44.4 floating_action_button.dart:775
  // onwards), pinned for the same reason as the switch: the app configures
  // `fabUseShape` and `fabRadius`, so a stock FAB under this theme would
  // report the app's corner back as the specification.
  'BaseSpeedDial.fab.containerSize', // M3: 56.0 — conforms
  'BaseSpeedDial.fab.shape', // M3: 16.0 — conforms
  'BaseSpeedDial.fab.elevation', // M3: 6.0 — conforms
  'BaseSpeedDial.fab.hoveredElevation', // M3: 8.0 — conforms
  'BaseSpeedDial.fab.containerColor', // M3: primaryContainer — conforms
  'BaseSpeedDial.fab.foregroundColor', // M3: onPrimaryContainer — conforms
  'BaseSpeedDial.fab.iconSize', // M3: 24.0 — conforms
  'BaseSpeedDial.fab.overlay.hovered', // M3: onPrimaryContainer @ 8% — conforms
  'BaseSpeedDial.miniFab.containerSize', // M3: 40.0 — conforms
  'BaseSpeedDial.miniFab.shape', // M3: 12.0 — registered FAB-001
  'BaseSpeedDial.miniFab.iconSize', // M3: 24.0 — conforms
  'BaseSpeedDial.miniFab.containerColor', // M3: primaryContainer — conforms
  'BaseSpeedDial.miniFab.tapTargetSize', // M3: 48.0 — conforms
  'BaseSpeedDial.edgeMargin', // M3: 16.0 — conforms
  // The accessibility matrix sweep (test/conformance/a11y). These are not
  // Material 3 component tokens but WCAG/platform minimums measured on the
  // same component matrix the goldens render, so the register can hold them
  // in the same executable both-directions form as everything above.
  'BaseSwitcher.tapTargetHeight', // 48.0 minimum — registered A11Y-001
};
