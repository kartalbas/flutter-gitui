// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';

/// Script to check for missing translation keys across all language files
/// Compares all language files against the English (master) file
void main() async {
  final l10nDir = Directory('lib/l10n');
  final englishFile = File('${l10nDir.path}/app_en.arb');

  if (!await englishFile.exists()) {
    print('Error: English translation file not found at ${englishFile.path}');
    exit(1);
  }

  // Load English translations (master file)
  final englishContent = await englishFile.readAsString();
  final englishJson = jsonDecode(englishContent) as Map<String, dynamic>;

  // Get all keys from English (excluding metadata keys starting with @)
  final englishKeys = englishJson.keys
      .where((key) => !key.startsWith('@'))
      .toSet();

  print('📋 Translation Coverage Report');
  print('=' * 80);
  print('Master file: app_en.arb');
  print('Total keys in English: ${englishKeys.length}');
  print('=' * 80);
  print('');

  // Check each language file
  final languageFiles = await l10nDir
      .list()
      .where((entity) => entity is File && entity.path.endsWith('.arb') && !entity.path.endsWith('app_en.arb'))
      .cast<File>()
      .toList();

  final Map<String, MissingKeysInfo> results = {};

  for (final langFile in languageFiles) {
    final langName = langFile.path.split(Platform.pathSeparator).last
        .replaceAll('app_', '')
        .replaceAll('.arb', '');

    final langContent = await langFile.readAsString();
    final langJson = jsonDecode(langContent) as Map<String, dynamic>;

    // Get all keys from this language (excluding metadata keys)
    final langKeys = langJson.keys
        .where((key) => !key.startsWith('@'))
        .toSet();

    // Find missing keys
    final missingKeys = englishKeys.difference(langKeys);
    final extraKeys = langKeys.difference(englishKeys);
    final coverage = ((langKeys.length / englishKeys.length) * 100).toStringAsFixed(1);

    results[langName] = MissingKeysInfo(
      languageCode: langName,
      totalKeys: langKeys.length,
      missingKeys: missingKeys.toList()..sort(),
      extraKeys: extraKeys.toList()..sort(),
      coverage: coverage,
    );
  }

  // Sort by coverage (ascending - worst first)
  final sortedResults = results.entries.toList()
    ..sort((a, b) => a.value.totalKeys.compareTo(b.value.totalKeys));

  // Print summary
  print('📊 Summary:');
  print('');
  for (final entry in sortedResults) {
    final info = entry.value;
    final emoji = info.missingKeys.isEmpty ? '✅' : '⚠️';
    print('$emoji ${info.languageCode.toUpperCase().padRight(4)} | '
        'Coverage: ${info.coverage.padLeft(5)}% | '
        'Keys: ${info.totalKeys.toString().padLeft(4)}/${englishKeys.length} | '
        'Missing: ${info.missingKeys.length}');
  }

  print('');
  print('=' * 80);
  print('');

  // Print detailed report for each language
  for (final entry in sortedResults) {
    final info = entry.value;

    if (info.missingKeys.isEmpty && info.extraKeys.isEmpty) {
      print('✅ ${info.languageCode.toUpperCase()} - Complete (100% coverage)');
      print('');
      continue;
    }

    print('📝 ${info.languageCode.toUpperCase()} - Detailed Report');
    print('-' * 80);
    print('Coverage: ${info.coverage}%');
    print('Total keys: ${info.totalKeys}/${englishKeys.length}');

    if (info.missingKeys.isNotEmpty) {
      print('Missing keys: ${info.missingKeys.length}');
      print('');
      print('Missing translations:');
      for (var i = 0; i < info.missingKeys.length; i++) {
        final key = info.missingKeys[i];
        final englishValue = englishJson[key];
        print('  ${(i + 1).toString().padLeft(4)}. $key');
        if (englishValue is String && englishValue.length < 80) {
          print('       EN: "$englishValue"');
        }
      }
    }

    if (info.extraKeys.isNotEmpty) {
      print('');
      print('⚠️ Extra keys (not in English): ${info.extraKeys.length}');
      for (final key in info.extraKeys) {
        print('     - $key');
      }
    }

    print('');
    print('=' * 80);
    print('');
  }

  // Generate missing keys files for each language
  print('💾 Generating missing keys files...');
  print('');

  final outputDir = Directory('scripts/translation_reports');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
  }

  for (final entry in results.entries) {
    final info = entry.value;
    if (info.missingKeys.isEmpty) continue;

    final outputFile = File('${outputDir.path}/missing_keys_${info.languageCode}.txt');
    final buffer = StringBuffer();

    buffer.writeln('Missing translations for ${info.languageCode.toUpperCase()}');
    buffer.writeln('Coverage: ${info.coverage}%');
    buffer.writeln('Missing: ${info.missingKeys.length} keys');
    buffer.writeln('=' * 80);
    buffer.writeln('');

    for (final key in info.missingKeys) {
      final englishValue = englishJson[key];
      buffer.writeln('Key: $key');
      buffer.writeln('EN:  $englishValue');
      buffer.writeln('${info.languageCode.toUpperCase()}:  [MISSING - NEEDS TRANSLATION]');
      buffer.writeln('');
    }

    await outputFile.writeAsString(buffer.toString());
    print('  ✓ ${outputFile.path}');
  }

  print('');
  print('✨ Done! Check scripts/translation_reports/ for detailed missing keys.');
}

class MissingKeysInfo {
  final String languageCode;
  final int totalKeys;
  final List<String> missingKeys;
  final List<String> extraKeys;
  final String coverage;

  MissingKeysInfo({
    required this.languageCode,
    required this.totalKeys,
    required this.missingKeys,
    required this.extraKeys,
    required this.coverage,
  });
}
