// Writes assets/changelog.json and the release-notes markdown for the
// version being built. The release workflow runs this from the repository
// root before `flutter build`, so the notes ship inside the asset bundle and
// the GitHub release body comes from the same generation — "View Release
// History" and the release page cannot drift apart.
//
// Everything is read from the LOCAL git history (tags and commit ranges); the
// bullets are the commit subjects. Nothing is fetched from the network or from
// the GitHub release, so the generator needs no token and works the same on a
// fork, offline, or a private repository.

import 'dart:convert';
import 'dart:io';

import 'changelog_builder.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);

  final tagPattern = RegExp(r'^v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$');
  final tags =
      const LineSplitter()
          .convert(await _git(['tag', '--list', 'v*']))
          .where(tagPattern.hasMatch)
          .toList()
        ..sort(compareVersions);

  final specs = _planEntries(tags, options.version);

  // Entries the retired local pipeline wrote by hand predate the issue
  // workflow this generator reads from; keeping them beats regenerating a
  // thinner version of the same history. The entry for the version being
  // built is always regenerated, so the shipped notes match the release.
  final seed = _readSeed(options.assetOut);
  final releases = <Map<String, dynamic>>[];
  for (final spec in specs) {
    final seeded = seed[spec.version];
    if (spec.version != options.version && seeded != null) {
      releases.add(seeded);
    } else {
      releases.add(await _buildEntry(spec));
    }
  }

  const encoder = JsonEncoder.withIndent('  ');
  final assetFile = File(options.assetOut);
  assetFile.parent.createSync(recursive: true);
  assetFile.writeAsStringSync('${encoder.convert({'releases': releases})}\n');

  final notesFile = File(options.notesOut);
  notesFile.parent.createSync(recursive: true);
  notesFile.writeAsStringSync('${releases.first['changelog'] as String}\n');

  stdout.writeln(
    'wrote ${options.assetOut} with ${releases.length} release(s)',
  );
  stdout.writeln('wrote ${options.notesOut} for ${options.version}');
}

class _Options {
  const _Options({
    required this.version,
    required this.assetOut,
    required this.notesOut,
  });

  factory _Options.parse(List<String> arguments) {
    String? version;
    var assetOut = 'assets/changelog.json';
    var notesOut = 'dist/release-notes.md';
    for (var i = 0; i < arguments.length; i += 2) {
      final flag = arguments[i];
      if (i + 1 >= arguments.length) {
        _fail('missing value after $flag');
      }
      final value = arguments[i + 1];
      switch (flag) {
        case '--version':
          version = value;
        case '--asset-out':
          assetOut = value;
        case '--notes-out':
          notesOut = value;
        default:
          _fail('unknown argument: $flag');
      }
    }
    if (version == null || version.isEmpty) {
      _fail('--version is required (the version being built, without the v)');
    }
    return _Options(version: version, assetOut: assetOut, notesOut: notesOut);
  }

  /// The version being built, without the leading `v` (e.g. `0.5.5-alpha`).
  final String version;
  final String assetOut;
  final String notesOut;
}

/// One release entry to generate: its version label, the revision whose date
/// and hash it carries, and the commit range it summarises.
class _EntrySpec {
  const _EntrySpec({
    required this.version,
    required this.rev,
    required this.range,
  });

  final String version;
  final String rev;
  final String range;
}

/// Plans one entry per tag up to the version being built, newest first, so
/// the shipped history covers every release and index 0 is the build itself.
List<_EntrySpec> _planEntries(List<String> ascendingTags, String version) {
  final currentTag = 'v$version';
  final hasTag = ascendingTags.contains(currentTag);
  // A rebuild of an old tag must not describe releases that came after it.
  final relevant = hasTag
      ? ascendingTags
            .where((tag) => compareVersions(tag, currentTag) <= 0)
            .toList()
      : ascendingTags;
  final specs = <_EntrySpec>[];
  for (var i = 0; i < relevant.length; i++) {
    specs.add(
      _EntrySpec(
        version: relevant[i].substring(1),
        rev: relevant[i],
        range: i == 0 ? relevant[i] : '${relevant[i - 1]}..${relevant[i]}',
      ),
    );
  }
  if (!hasTag) {
    // A workflow_dispatch build can run before the tag exists; its release
    // is then everything since the newest tag.
    specs.add(
      _EntrySpec(
        version: version,
        rev: 'HEAD',
        range: ascendingTags.isEmpty ? 'HEAD' : '${ascendingTags.last}..HEAD',
      ),
    );
  }
  return specs.reversed.toList();
}

Future<Map<String, Object>> _buildEntry(_EntrySpec spec) async {
  final rawLog = await _git([
    'log',
    '--no-merges',
    '--format=%B%x02',
    spec.range,
  ]);
  final commits = rawLog
      .split('\x02')
      .map((message) => message.trim())
      .where((message) => message.isNotEmpty)
      .toList()
      // git log lists newest first; the notes read as a narrative, oldest
      // first, and dedupe must credit the commit that introduced a change.
      .reversed
      .map(parseCommitMessage)
      .toList();
  // The issue-title map stays empty: the bullets are the commit subjects, so
  // nothing needs the network. buildReleaseNotes keeps the parameter for the
  // rare empty-subject fallback.
  final markdown = buildReleaseNotes(commits, const {}).toMarkdown();
  // ^{commit} because an annotated tag resolves to the tag object, whose
  // hash names no commit a reader could look up.
  final commitHash = (await _git(['rev-parse', '${spec.rev}^{commit}'])).trim();
  final timestamp = int.parse(
    (await _git(['log', '-1', '--format=%ct', spec.rev])).trim(),
  );
  return releaseEntryJson(
    version: spec.version,
    date: formatUtcTimestamp(timestamp),
    // Fixed width instead of --short, which lengthens on ambiguity and would
    // make the two platform builds disagree about the same release.
    commit: commitHash.substring(0, 7),
    changelog: markdown,
  );
}

Map<String, Map<String, dynamic>> _readSeed(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  try {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final entries = (decoded['releases'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return {for (final entry in entries) entry['version'] as String: entry};
  } on Object catch (error) {
    stderr.writeln('warning: ignoring unreadable seed $path: $error');
    return {};
  }
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    _fail('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

Never _fail(String message) {
  stderr.writeln('error: $message');
  exit(1);
}
