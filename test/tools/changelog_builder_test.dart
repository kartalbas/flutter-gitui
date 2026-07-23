// The release workflow can only be proven end to end on a real tag, so the
// rules that decide what a generated release note says are pinned here:
// trailer parsing, section mapping, issue-title preference, dedupe, section
// order, version ordering and the exact JSON shape the app parses.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/models/changelog_release.dart';

import '../../tools/changelog/changelog_builder.dart';

void main() {
  group('parseCommitMessage', () {
    test('extracts the subject and a Fixes trailer', () {
      final commit = parseCommitMessage(
        'fix(update): verify the archive digest\n\nLong explanation.\n\nFixes #301\n',
      );
      expect(commit.subject, 'fix(update): verify the archive digest');
      expect(commit.issues, [301]);
    });

    test('collects several issues from one trailer line', () {
      final commit = parseCommitMessage('feat: x\n\nFixes #1, #2\n');
      expect(commit.issues, [1, 2]);
    });

    test('collects issues across Fixes and Refs lines without duplicates', () {
      final commit = parseCommitMessage(
        'feat: x\n\nRefs #5\nFixes #7\nRefs #5\n',
      );
      expect(commit.issues, [5, 7]);
    });

    test('matches trailers case-insensitively', () {
      expect(parseCommitMessage('fix: x\n\nfixes #12\n').issues, [12]);
      expect(parseCommitMessage('fix: x\n\nREFS #12\n').issues, [12]);
    });

    test('ignores issue mentions inside prose', () {
      final commit = parseCommitMessage(
        'fix: x\n\nThis reverts the fix for #263 because it was too broad.\n'
        'See Fixes #264 for the follow-up.\n',
      );
      expect(commit.issues, isEmpty);
    });

    test('does not read a reference out of the subject line', () {
      expect(parseCommitMessage('Fixes #3').issues, isEmpty);
    });
  });

  group('sectionFor', () {
    test('maps user-facing types to their sections', () {
      expect(sectionFor('feat: add a thing'), ReleaseSection.features);
      expect(sectionFor('feat(toolbar): add a thing'), ReleaseSection.features);
      expect(sectionFor('feat(api)!: breaking thing'), ReleaseSection.features);
      expect(sectionFor('fix: repair a thing'), ReleaseSection.bugFixes);
      expect(sectionFor('perf: speed up a thing'), ReleaseSection.improvements);
      expect(
        sectionFor('refactor: split the service'),
        ReleaseSection.improvements,
      );
      expect(sectionFor('style: format'), ReleaseSection.improvements);
      expect(
        sectionFor('docs: describe the setup'),
        ReleaseSection.documentation,
      );
    });

    test('drops types a user cannot observe', () {
      for (final subject in [
        'chore(release): set the version to 0.5.4-alpha',
        'ci: retry release API calls',
        'build: bump a dependency',
        'test: cover the parser',
        'revert: undo the change',
      ]) {
        expect(sectionFor(subject), isNull, reason: subject);
      }
    });

    test('drops subjects without a conventional prefix', () {
      expect(sectionFor('Initial commit'), isNull);
      expect(sectionFor('Add force delete button'), isNull);
    });
  });

  group('buildReleaseNotes', () {
    test('uses the cleaned commit subject, not the problem-phrased title', () {
      final notes = buildReleaseNotes(
        [
          const ParsedCommit(
            subject: 'fix(history): guard the provider',
            issues: [45],
          ),
        ],
        {45: '[high] leaving the screen aborts a running batch operation'},
      );
      // The subject describes what the release did; the issue title describes
      // the problem and would read wrong under "Bug Fixes".
      expect(notes.items[ReleaseSection.bugFixes], ['Guard the provider']);
    });

    test('strips the conventional-commit prefix from the subject', () {
      final notes = buildReleaseNotes([
        const ParsedCommit(
          subject: 'feat(toolbar): add a fetch button',
          issues: [9],
        ),
      ], const {});
      expect(notes.items[ReleaseSection.features], ['Add a fetch button']);
    });

    test('folds follow-up commits for the same issue into one item', () {
      final notes = buildReleaseNotes([
        const ParsedCommit(subject: 'fix: first attempt', issues: [247]),
        const ParsedCommit(subject: 'fix: second attempt', issues: [247]),
        const ParsedCommit(subject: 'feat: follow-up', issues: [247]),
      ], const {});
      // The first commit that references the issue supplies the item; the
      // later ones for the same issue add nothing.
      expect(notes.items[ReleaseSection.bugFixes], ['First attempt']);
      expect(notes.items[ReleaseSection.features], isEmpty);
    });

    test('folds every issue a commit closes into one item', () {
      final notes = buildReleaseNotes([
        const ParsedCommit(subject: 'fix: both at once', issues: [1, 2]),
      ], const {});
      expect(notes.items[ReleaseSection.bugFixes], ['Both at once']);
    });

    test('leaves commits without issues uncited and deduplicates them', () {
      final notes = buildReleaseNotes([
        const ParsedCommit(subject: 'fix: a plain repair'),
        const ParsedCommit(subject: 'fix: a plain repair'),
      ], const {});
      expect(notes.items[ReleaseSection.bugFixes], ['A plain repair']);
    });

    test('reports a release with nothing user-facing as exactly that', () {
      final notes = buildReleaseNotes([
        const ParsedCommit(subject: 'chore: housekeeping'),
        const ParsedCommit(subject: 'ci: pipeline work'),
        const ParsedCommit(subject: 'Initial commit'),
      ], const {});
      expect(notes.isEmpty, isTrue);
      expect(notes.toMarkdown(), noUserFacingChanges);
    });

    test('renders the sections in a fixed order with the exact headings', () {
      final notes = buildReleaseNotes([
        const ParsedCommit(subject: 'docs: describe setup'),
        const ParsedCommit(subject: 'perf: faster status refresh'),
        const ParsedCommit(subject: 'fix: broken tooltip', issues: [3]),
        const ParsedCommit(subject: 'feat: stash support', issues: [4]),
      ], const {});
      expect(
        notes.toMarkdown(),
        '### ✨ Features\n\n'
        '- Stash support\n\n'
        '### 🐛 Bug Fixes\n\n'
        '- Broken tooltip\n\n'
        '### 🔧 Improvements\n\n'
        '- Faster status refresh\n\n'
        '### 📝 Documentation\n\n'
        '- Describe setup',
      );
    });
  });

  group('compareVersions', () {
    test('orders releases numerically with pre-releases first', () {
      final tags = [
        'v0.10.0',
        'v0.5.4',
        'v0.5.4-alpha',
        'v0.9.0',
        'v0.5.0-alpha',
      ]..sort(compareVersions);
      expect(tags, [
        'v0.5.0-alpha',
        'v0.5.4-alpha',
        'v0.5.4',
        'v0.9.0',
        'v0.10.0',
      ]);
    });

    test('orders pre-release identifiers per semver', () {
      expect(compareVersions('0.5.4-alpha', '0.5.4-alpha.2'), lessThan(0));
      expect(compareVersions('1.0.0-2', '1.0.0-alpha'), lessThan(0));
      expect(compareVersions('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
      expect(compareVersions('0.5.4-alpha', '0.5.4-alpha'), 0);
    });
  });

  group('formatUtcTimestamp', () {
    test('renders the shape the bundled changelog has always used', () {
      final seconds =
          DateTime.utc(2025, 12, 5, 14, 6, 5).millisecondsSinceEpoch ~/ 1000;
      expect(formatUtcTimestamp(seconds), '2025-12-05T14:06:05Z');
      expect(formatUtcTimestamp(0), '1970-01-01T00:00:00Z');
    });
  });

  group('releaseEntryJson', () {
    test('round-trips through the model the app parses the asset with', () {
      final entry = releaseEntryJson(
        version: '0.5.5-alpha',
        date: '2026-07-23T00:00:00Z',
        commit: 'abcdef0',
        changelog: '### Added\n\n- Something (#1)',
      );
      final release = ChangelogRelease.fromJson(entry);
      expect(release.version, '0.5.5-alpha');
      expect(release.date, '2026-07-23T00:00:00Z');
      expect(release.commit, 'abcdef0');
      expect(release.changelog, '### Added\n\n- Something (#1)');

      final data = ChangelogData.fromJson({
        'releases': [entry],
      });
      expect(data.releases.single.version, '0.5.5-alpha');
    });
  });
}
