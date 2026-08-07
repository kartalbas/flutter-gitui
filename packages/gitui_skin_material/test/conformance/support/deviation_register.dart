/// Loader for docs/deviation_register.yaml, the single source of truth for
/// approved divergences from Material 3 defaults.
///
/// The loader is strict on purpose: a register that cannot be parsed, that
/// misses a field, or that registers the same token twice is a broken
/// contract and must fail loudly, not be silently tolerated.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

/// One approved divergence from a Material 3 default.
///
/// The fields mirror the register's schema exactly (id, component, property,
/// spec_value, app_value, spec_source, rationale, registered).
class DeviationEntry {
  const DeviationEntry({
    required this.id,
    required this.component,
    required this.property,
    required this.specValue,
    required this.appValue,
    required this.specSource,
    required this.rationale,
    required this.registered,
  });

  /// Stable unique id, e.g. `TYPE-001` (never reuse an id).
  final String id;

  /// What deviates, e.g. `TextTheme.displayLarge`.
  final String component;

  /// The deviating property of that component, e.g. `fontSize`.
  final String property;

  /// The Material 3 value; the suite fails when the oracle stops matching it.
  final String specValue;

  /// The value the app really renders; the suite fails when it drifts.
  final String appValue;

  /// URL or SDK file:line the spec value was read from.
  final String specSource;

  /// Why the deviation is intentional.
  final String rationale;

  /// ISO date the entry was registered.
  final DateTime registered;

  /// The token id this entry is looked up under, `<component>.<property>`;
  /// must exist in the token manifest.
  String get token => '$component.$property';
}

/// Parsed register with token lookup.
class DeviationRegister {
  DeviationRegister._(this.version, this.entries, this._byToken);

  /// The one schema version this loader understands.
  static const int supportedVersion = 1;

  /// Register location, relative to the package root.
  static const String defaultRelativePath = 'docs/deviation_register.yaml';

  /// Value of the `version` key in the file.
  final int version;

  /// All entries in file order.
  final List<DeviationEntry> entries;

  final Map<String, DeviationEntry> _byToken;

  /// Returns the registered deviation for [token], or null when the
  /// component is expected to conform for that token.
  DeviationEntry? forToken(String token) => _byToken[token];

  /// Loads and validates the register.
  ///
  /// [path] overrides the file location (used by harness self-tests); by
  /// default the file is resolved against the package root, found by
  /// walking up from the current directory to the nearest pubspec.yaml.
  static DeviationRegister load({String? path}) {
    final File file = File(path ?? _resolveDefaultPath());
    if (!file.existsSync()) {
      throw StateError(
        'Deviation register not found at ${file.path}. The conformance '
        'suite requires $defaultRelativePath to exist (it may contain an '
        'empty `deviations: []` list).',
      );
    }
    final Object? doc = loadYaml(file.readAsStringSync(), sourceUrl: file.uri);
    if (doc is! YamlMap) {
      throw FormatException(
        'Deviation register root must be a map, got ${doc.runtimeType}.',
      );
    }
    final Object? version = doc['version'];
    if (version is! int || version != supportedVersion) {
      throw FormatException(
        'Unsupported deviation register version: $version '
        '(this loader supports $supportedVersion).',
      );
    }
    final Object? rawList = doc['deviations'];
    final List<DeviationEntry> entries = <DeviationEntry>[];
    if (rawList != null) {
      if (rawList is! YamlList) {
        throw FormatException(
          "'deviations' must be a list, got ${rawList.runtimeType}.",
        );
      }
      for (int i = 0; i < rawList.length; i++) {
        entries.add(_parseEntry(rawList[i], i));
      }
    }
    final Map<String, DeviationEntry> byToken = <String, DeviationEntry>{};
    for (final DeviationEntry entry in entries) {
      final DeviationEntry? existing = byToken[entry.token];
      if (existing != null) {
        throw FormatException(
          'Deviations ${existing.id} and ${entry.id} both register token '
          '${entry.token}; token lookup must be unambiguous.',
        );
      }
      byToken[entry.token] = entry;
    }
    return DeviationRegister._(
      version,
      List<DeviationEntry>.unmodifiable(entries),
      byToken,
    );
  }

  static String _resolveDefaultPath() {
    Directory dir = Directory.current;
    for (int i = 0; i < 10; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        return '${dir.path}/$defaultRelativePath';
      }
      final Directory parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }
    throw StateError(
      'Could not locate the package root (pubspec.yaml) walking up from '
      '${Directory.current.path}.',
    );
  }

  static DeviationEntry _parseEntry(Object? node, int index) {
    if (node is! YamlMap) {
      throw FormatException(
        'deviations[$index] must be a map, got ${node.runtimeType}.',
      );
    }
    final Object? idValue = node['id'];
    final String label = idValue == null
        ? 'deviations[$index]'
        : 'deviations[$index] ($idValue)';
    String req(String key) {
      final Object? value = node[key];
      if (value == null || value.toString().trim().isEmpty) {
        throw FormatException("$label: missing required field '$key'.");
      }
      return value.toString().trim();
    }

    DateTime reqDate(String key) {
      final String raw = req(key);
      final DateTime? parsed = DateTime.tryParse(raw);
      if (parsed == null) {
        throw FormatException(
          "$label: field '$key' is not an ISO date: '$raw'.",
        );
      }
      return parsed;
    }

    return DeviationEntry(
      id: req('id'),
      component: req('component'),
      property: req('property'),
      specValue: req('spec_value'),
      appValue: req('app_value'),
      specSource: req('spec_source'),
      rationale: req('rationale'),
      registered: reqDate('registered'),
    );
  }
}
