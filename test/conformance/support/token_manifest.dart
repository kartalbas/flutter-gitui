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
};
