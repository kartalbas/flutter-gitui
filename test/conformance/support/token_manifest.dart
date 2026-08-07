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
};
