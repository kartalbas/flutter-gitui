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
};
