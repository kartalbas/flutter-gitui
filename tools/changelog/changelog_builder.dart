// Pure rules for turning a release's commits into its release notes. Nothing
// here touches git, the network or the filesystem: the release workflow can
// only be proven end to end on a real tag, so every decision about what a
// note says lives in these functions, where
// test/tools/changelog_builder_test.dart can pin it down.
// generate_changelog.dart wires them to git and gh.

/// Sections a release-note item can land in, in the order they are rendered.
///
/// The headings are fixed by the format the app has always rendered (the
/// bundled 0.1.0 entry): the emoji and wording are exactly these, so a
/// generated entry looks the same as the curated one. Only user-facing types
/// map to a section; chore/ci/build/test and the per-release version bump are
/// left out so the notes read for a user, not for a developer.
enum ReleaseSection {
  features('✨ Features'),
  bugFixes('🐛 Bug Fixes'),
  improvements('🔧 Improvements'),
  documentation('📝 Documentation');

  const ReleaseSection(this.heading);

  final String heading;
}

/// Shown when a release contains no commit of a user-visible type, so the
/// entry says so instead of rendering empty.
const String noUserFacingChanges = 'No user-facing changes in this release.';

/// A commit reduced to what the notes are built from: its subject line and
/// the issues its `Fixes #n` / `Refs #n` trailer lines point at.
class ParsedCommit {
  const ParsedCommit({required this.subject, this.issues = const []});

  final String subject;
  final List<int> issues;
}

// Trailer lines only: a passing mention like "the fix for #263" mid-sentence
// is prose about an issue, not a claim that this commit belongs to it.
final RegExp _trailerPattern = RegExp(
  r'^\s*(?:fixes|refs)\s+((?:#\d+[\s,]*)+)$',
  caseSensitive: false,
);
final RegExp _issueNumberPattern = RegExp(r'#(\d+)');
final RegExp _conventionalPattern = RegExp(r'^(\w+)(?:\([^)]*\))?!?:\s*(.*)$');
// Issue titles carry a local priority tag ("[high] ...") that means nothing
// to a release reader.
final RegExp _priorityTagPattern = RegExp(r'^\[[^\]]+\]\s*');

/// Extracts the subject and the referenced issues from a full commit message.
ParsedCommit parseCommitMessage(String message) {
  final lines = message.split('\n');
  final subject = lines.isEmpty ? '' : lines.first.trim();
  final issues = <int>[];
  // The subject is skipped: an issue reference only counts as a trailer.
  for (final line in lines.skip(1)) {
    final match = _trailerPattern.firstMatch(line);
    if (match == null) continue;
    for (final numberMatch in _issueNumberPattern.allMatches(match.group(1)!)) {
      final number = int.parse(numberMatch.group(1)!);
      if (!issues.contains(number)) issues.add(number);
    }
  }
  return ParsedCommit(subject: subject, issues: issues);
}

/// Maps a commit subject to the section it belongs in, or null when the
/// change belongs in no section (test, revert, a subject with no type).
ReleaseSection? sectionFor(String subject) {
  final match = _conventionalPattern.firstMatch(subject);
  if (match == null) return null;
  switch (match.group(1)!.toLowerCase()) {
    case 'feat':
      return ReleaseSection.features;
    case 'fix':
      return ReleaseSection.bugFixes;
    case 'perf':
    case 'refactor':
    case 'style':
      return ReleaseSection.improvements;
    case 'docs':
      return ReleaseSection.documentation;
  }
  return null;
}

/// Grouped, rendered items of one release.
class ReleaseNotes {
  const ReleaseNotes(this.items);

  final Map<ReleaseSection, List<String>> items;

  bool get isEmpty => items.values.every((section) => section.isEmpty);

  String toMarkdown() {
    if (isEmpty) return noUserFacingChanges;
    final parts = <String>[];
    for (final section in ReleaseSection.values) {
      final lines = items[section];
      if (lines == null || lines.isEmpty) continue;
      final bullets = lines.map((line) => '- $line').join('\n');
      parts.add('### ${section.heading}\n\n$bullets');
    }
    return parts.join('\n\n');
  }
}

/// Builds the notes for one release from its commits, oldest first.
///
/// The bullet text is the commit subject stripped of its conventional-commit
/// prefix ("Add a fetch button"), which is what the app's existing entries
/// read like and describes what the release did. Issue titles are phrased as
/// the problem ("X is broken") and read wrong under a section heading, so
/// they are only a fallback when a subject has no text of its own.
/// Follow-up commits to an issue already covered add nothing: one issue is
/// one item. Bullets carry no "(#n)" citation, matching the format the app
/// already renders.
ReleaseNotes buildReleaseNotes(
  List<ParsedCommit> commits,
  Map<int, String> issueTitles,
) {
  final items = {
    for (final section in ReleaseSection.values) section: <String>[],
  };
  final coveredIssues = <int>{};
  for (final commit in commits) {
    final section = sectionFor(commit.subject);
    if (section == null) continue;
    final newIssues = commit.issues.where(
      (issue) => !coveredIssues.contains(issue),
    );
    if (commit.issues.isNotEmpty && newIssues.isEmpty) continue;
    coveredIssues.addAll(commit.issues);
    final line = _itemLine(commit, issueTitles);
    // Two issue-less commits can share a subject (a change re-applied after
    // a revert); repeating the line would say nothing new.
    if (!items[section]!.contains(line)) {
      items[section]!.add(line);
    }
  }
  return ReleaseNotes(items);
}

String _itemLine(ParsedCommit commit, Map<int, String> issueTitles) {
  final match = _conventionalPattern.firstMatch(commit.subject);
  final subject = _capitalize((match?.group(2) ?? commit.subject).trim());
  if (subject.isNotEmpty) return subject;
  // Only when the commit has no subject text of its own does the issue title
  // stand in, priority tag stripped.
  for (final issue in commit.issues) {
    final title = issueTitles[issue];
    if (title != null) {
      return _capitalize(title.replaceFirst(_priorityTagPattern, ''));
    }
  }
  return subject;
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Orders semantic versions, tolerating a leading `v` and a pre-release
/// suffix. Needed because git's own version sort does not know that
/// `0.5.4-alpha` precedes `0.5.4`.
int compareVersions(String a, String b) =>
    _SemVer.parse(a).compareTo(_SemVer.parse(b));

class _SemVer implements Comparable<_SemVer> {
  const _SemVer(this.numbers, this.preRelease);

  factory _SemVer.parse(String input) {
    var text = input.startsWith('v') ? input.substring(1) : input;
    String? preRelease;
    final dash = text.indexOf('-');
    if (dash >= 0) {
      preRelease = text.substring(dash + 1);
      text = text.substring(0, dash);
    }
    final numbers = text
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return _SemVer(numbers, preRelease);
  }

  final List<int> numbers;
  final String? preRelease;

  @override
  int compareTo(_SemVer other) {
    for (var i = 0; i < 3; i++) {
      final delta = numbers[i].compareTo(other.numbers[i]);
      if (delta != 0) return delta;
    }
    // A pre-release precedes its release: 0.5.4-alpha < 0.5.4.
    if (preRelease == null) return other.preRelease == null ? 0 : 1;
    if (other.preRelease == null) return -1;
    return _comparePreRelease(preRelease!, other.preRelease!);
  }

  static int _comparePreRelease(String a, String b) {
    final partsA = a.split('.');
    final partsB = b.split('.');
    final shared = partsA.length < partsB.length
        ? partsA.length
        : partsB.length;
    for (var i = 0; i < shared; i++) {
      final numA = int.tryParse(partsA[i]);
      final numB = int.tryParse(partsB[i]);
      // Numeric identifiers sort below alphanumeric ones, per semver.
      if (numA != null && numB != null) {
        final delta = numA.compareTo(numB);
        if (delta != 0) return delta;
      } else if (numA != null) {
        return -1;
      } else if (numB != null) {
        return 1;
      } else {
        final delta = partsA[i].compareTo(partsB[i]);
        if (delta != 0) return delta;
      }
    }
    return partsA.length.compareTo(partsB.length);
  }
}

/// Formats a unix timestamp as the `yyyy-MM-ddTHH:mm:ssZ` shape the bundled
/// changelog has always used, so seed and generated entries parse alike.
String formatUtcTimestamp(int secondsSinceEpoch) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch * 1000,
    isUtc: true,
  );
  String pad(int value) => value.toString().padLeft(2, '0');
  final day =
      '${date.year.toString().padLeft(4, '0')}'
      '-${pad(date.month)}-${pad(date.day)}';
  return '${day}T${pad(date.hour)}:${pad(date.minute)}:${pad(date.second)}Z';
}

/// The exact key set `ChangelogRelease.fromJson` expects. The shipped file is
/// parsed by the app, so the shape is pinned here and round-tripped through
/// the model in the tests.
Map<String, Object> releaseEntryJson({
  required String version,
  required String date,
  required String commit,
  required String changelog,
}) => {
  'version': version,
  'date': date,
  'changelog': changelog,
  'commit': commit,
};
