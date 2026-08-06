/// The single conformance assertion.
///
/// `expectConformant` fails in BOTH directions:
///
///   * an unregistered mismatch fails with measured-vs-expected values
///     (M3 CONFORMANCE FAILURE),
///   * a registered deviation whose measured value now conforms fails as
///     stale (STALE DEVIATION), so docs/deviation_register.yaml cannot rot,
///   * a registered deviation whose documented spec_value no longer matches
///     the oracle fails (REGISTER SPEC MISMATCH), catching SDK default moves,
///   * and a registered deviation whose measured value drifted to a third
///     value fails too (DEVIATION DRIFT).
///
/// It also refuses tokens that are not listed in the checked-in token
/// manifest, so nobody measures an unlisted token.
library;

import 'package:flutter_test/flutter_test.dart';

import 'deviation_register.dart';
import 'token_manifest.dart';

DeviationRegister? _registerCache;

/// Test-only seam: overrides the register used by [expectConformant] so the
/// harness itself can be exercised against synthetic registers. Pass null to
/// fall back to loading docs/deviation_register.yaml again.
void debugOverrideDeviationRegister(DeviationRegister? register) {
  _registerCache = register;
}

DeviationRegister _register() => _registerCache ??= DeviationRegister.load();

/// Asserts that [measured] conforms to [expected] for [token], honouring the
/// deviation register in both directions (see library docs).
///
/// Numbers are compared with [tolerance]; every other type is compared via
/// `toString()` equality. [unit] is only used in failure messages.
void expectConformant({
  required String token,
  required String component,
  required Object measured,
  required Object expected,
  String unit = 'dp',
  double tolerance = 0.01,
}) {
  if (!conformanceTokenManifest.contains(token)) {
    fail(
      'UNLISTED TOKEN\n'
      "  '$token' is not in conformanceTokenManifest\n"
      '  (test/conformance/support/token_manifest.dart).\n'
      '  Add the token to the manifest first so the set of measured tokens\n'
      '  stays reviewable, then measure it.',
    );
  }

  final DeviationEntry? deviation = _register().forToken(token);
  final bool conforms = _valuesMatch(measured, expected, tolerance);

  if (conforms) {
    if (deviation != null) {
      fail(
        'STALE DEVIATION ${deviation.id}\n'
        '  component: $component\n'
        '  token:     $token\n'
        '  The register documents app_value=${deviation.appValue}, but the\n'
        '  measured value ${_describe(measured, unit)} now conforms to the\n'
        '  M3 oracle ${_describe(expected, unit)}.\n'
        '  Delete the entry from docs/deviation_register.yaml so the\n'
        '  register cannot rot.',
      );
    }
    return;
  }

  if (deviation == null) {
    fail(
      'M3 CONFORMANCE FAILURE\n'
      '  component: $component\n'
      '  token:     $token\n'
      '  expected:  ${_describe(expected, unit)} (M3 oracle)\n'
      '  measured:  ${_describe(measured, unit)}\n'
      '  No deviation for this token is registered in\n'
      '  docs/deviation_register.yaml. Either make the component conform\n'
      '  to the Material 3 default, or register the approved deviation\n'
      '  with id, component, property, spec_value, app_value, spec_source,\n'
      '  rationale and registered.',
    );
  } else if (!_matchesRegisteredValue(
    expected,
    deviation.specValue,
    tolerance,
  )) {
    fail(
      'REGISTER SPEC MISMATCH ${deviation.id}\n'
      '  component: $component\n'
      '  token:     $token\n'
      '  The register documents spec_value=${deviation.specValue}, but the\n'
      '  M3 oracle now measures ${_describe(expected, unit)}. The SDK\n'
      "  default moved out from under the entry; re-read the entry's\n"
      '  spec_source, re-evaluate the deviation and update\n'
      '  docs/deviation_register.yaml.',
    );
  } else if (!_matchesRegisteredValue(
    measured,
    deviation.appValue,
    tolerance,
  )) {
    fail(
      'DEVIATION DRIFT ${deviation.id}\n'
      '  component: $component\n'
      '  token:     $token\n'
      '  The register documents app_value=${deviation.appValue}, but the\n'
      '  measured value is ${_describe(measured, unit)} (M3 oracle:\n'
      '  ${_describe(expected, unit)}). The entry no longer describes\n'
      '  reality; update or delete it in docs/deviation_register.yaml.',
    );
  }
  // Otherwise: approved deviation, measured matches the registered app_value.
}

bool _valuesMatch(Object measured, Object expected, double tolerance) {
  if (measured is num && expected is num) {
    return (measured - expected).abs() <= tolerance;
  }
  return measured.toString() == expected.toString();
}

bool _matchesRegisteredValue(
  Object value,
  String registeredValue,
  double tolerance,
) {
  if (value is num) {
    final num? parsed = num.tryParse(registeredValue);
    if (parsed != null) {
      return (value - parsed).abs() <= tolerance;
    }
  }
  return value.toString().trim() == registeredValue.trim();
}

String _describe(Object value, String unit) {
  return unit.isEmpty ? '$value' : '$value $unit';
}
