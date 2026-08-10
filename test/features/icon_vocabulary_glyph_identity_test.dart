/// The acceptance test for the icon half of the vocabulary conversion, over
/// the five densest feature areas: `branches`, `history`, `changes`, `browse`
/// and `merge` (#249 P3a).
///
/// **The bar the conversion has to clear is that no glyph changes.** A site
/// that draws a git-branch mark today has to draw the same mark once it names
/// `IconRole.gitBranch` instead of `PhosphorIconsRegular.gitBranch`, because
/// the Material skin maps the role back to the same Phosphor codepoint. That
/// is checkable rather than arguable, and it has to be checked mechanically:
/// a role pointed at the wrong glyph swaps one plausible mark for another,
/// nothing throws, no golden covers most of these screens, and the first
/// person to notice is a user.
///
/// The proof is in two halves, because the conversion can go wrong in two
/// independent ways.
///
/// **Half one — the site still names the same mark.** [_kMarkCensus] is the
/// measured inventory of every glyph these forty files named before the
/// conversion started: 246 references over 77 distinct marks, counted per file
/// and per mark. The first test re-counts the same files, folding
/// `PhosphorIcons*.x` and `IconRole.x` into one tally because a converted site
/// and an unconverted one name the same *mark* under two vocabularies, and
/// requires the tally to be identical. A site that quietly moves from
/// `pencil` to `pencilSimple`, loses a mark, or grows one therefore fails
/// here, whether it has been converted yet or not — which is what lets the
/// census guard a conversion that lands file by file.
///
/// **Half two — the skin maps the mark back to the identical glyph.** The
/// second and third tests resolve every one of those 77 marks through
/// `MaterialGlyphs` and compare the resulting `IconData` field for field
/// against this application's own generated Phosphor constants in
/// `lib/shared/icons/`. Identity means the codepoint, the font family, the
/// font package and `matchTextDirection` all agree; a table that answered with
/// a different font family would render a different-weight mark at the same
/// codepoint and pass a codepoint-only check.
///
/// **Why the weight axis gets its own test.** `IconRole` deliberately carries
/// no weight — Phosphor's Regular/Bold/Fill, a Fluent filled variant and an SF
/// Symbol weight are not the same three things, so the weight is re-decided
/// inside the skin. Nine of the references in these five areas are drawn at
/// Phosphor Bold today, and collapsing them onto a role that only knows the
/// ordinary stroke would change the mark just as surely as picking the wrong
/// name. [_kDrawnAtBold] names them, and the third test proves two things at
/// once: that `MaterialGlyphs.boldOf` holds the identical Bold codepoint for
/// each, and that its answer genuinely differs from `of` — so the heavier mark
/// is available to the facet that knows which slot it is filling, rather than
/// silently absent.
///
/// **What this file deliberately cannot see, and who does.** Half one folds
/// `PhosphorIcons<Weight>.x` and `IconRole.x` into ONE tally — that fold is
/// what lets the census guard a conversion landing file by file, and its exact
/// cost is that a site changing from `PhosphorIconsBold.magnifyingGlass` to
/// `IconRole.magnifyingGlass` is invisible here. Half two proves the heavier
/// mark EXISTS in the table, which is a property of the table and not of any
/// call site. Neither half can therefore report that a site gave up its
/// weight. That measurement lives in
/// `test/shared/icons/icon_weight_census_test.dart`, which counts the Bold and
/// Fill references of the whole of `lib/` against a before-and-after ledger
/// and requires every difference to be named. Do not duplicate it here: the
/// fold is this file's tool, not its oversight.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;
import 'package:gitui_skin_material/gitui_skin_material.dart';

void main() {
  test('every site in the five dense areas still names the same mark', () {
    final Map<String, Map<String, int>> found = <String, Map<String, int>>{};
    for (final String path in _kMarkCensus.keys) {
      final File file = File(_fromPackageRoot(path));
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '$path is in the icon census but no longer exists. If the file '
            'was renamed or deleted, move its marks in _kMarkCensus with it '
            'rather than dropping them: the census is what proves the '
            'conversion changed no glyph.',
      );
      found[path] = _marksIn(file.readAsStringSync());
    }

    expect(
      found,
      _kMarkCensus,
      reason:
          'The set of marks named in the five dense feature areas has moved. '
          'Both vocabularies are counted together, so this is not a report '
          'that a file has been converted - it is a report that a site now '
          'asks for a DIFFERENT mark than it did before. Either a role was '
          'chosen that does not correspond to the glyph the site used to '
          'draw, or an icon was added or removed. Neither is part of a '
          'vocabulary conversion; if the change is deliberate, update the '
          'census in the same commit and say why.',
    );
  });

  test('the census still accounts for all 247 references', () {
    // A cheap arithmetic backstop for the map comparison above. If somebody
    // edits the census to make a failure go away, the two numbers stop
    // agreeing and this says so in one line instead of a 247-entry diff.
    // 247 = the 246 the conversion measured, plus the diff viewer's `file`
    // and `gitDiff` that moved into git_status_tree_view.dart with the
    // view-mode toggle (recorded at that entry), minus the three marks the
    // tree conversion moved across the seam (the disclosure caret pair and
    // the row-menu trigger are `surfaces.tree`'s own affordances now,
    // recorded at the file_tree_panel.dart entry); plus the two the branches
    // screen names since it adopted `chrome.screen` (#442) - the refresh
    // arrow and the overflow dots, which `StandardAppBar` used to name from
    // outside this census and the screen states on `ScreenSpec.toolbar` now,
    // recorded at that entry. Every mark involved was and stays in the
    // distinct set, so the 77 below is unchanged.
    final int total = _kMarkCensus.values
        .expand((Map<String, int> marks) => marks.values)
        .fold(0, (int sum, int count) => sum + count);
    expect(total, 247);
    expect(
      _kMarkCensus.values
          .expand((Map<String, int> marks) => marks.keys)
          .toSet()
          .length,
      77,
    );
  });

  test('the Material skin maps every one of those marks to the same glyph', () {
    final Map<String, _Glyph> phosphorRegular = _generatedGlyphs(
      'lib/shared/icons/phosphor_icons_regular.dart',
    );

    for (final String mark in _marksInCensus()) {
      final IconRole role = _roleNamed(mark);
      final _Glyph? drawnToday = phosphorRegular[mark];
      expect(
        drawnToday,
        isNotNull,
        reason:
            'The application draws $mark today, but there is no '
            'PhosphorIconsRegular.$mark in the generated constants. The '
            'census and lib/shared/icons/ have drifted apart.',
      );
      expect(
        _Glyph.of(MaterialGlyphs.of(role)),
        drawnToday,
        reason:
            'MaterialGlyphs.of(IconRole.$mark) is not the glyph '
            'PhosphorIconsRegular.$mark draws. Every converted site in the '
            'five dense areas reaches its mark through this table, so a '
            'disagreement here is a silent icon change at every one of them.',
      );
    }
  });

  test('the heavier stroke the nine bold sites draw is still reachable', () {
    final Map<String, _Glyph> phosphorBold = _generatedGlyphs(
      'lib/shared/icons/phosphor_icons_bold.dart',
    );

    for (final String mark in _kDrawnAtBold.keys) {
      final IconRole role = _roleNamed(mark);
      expect(
        _Glyph.of(MaterialGlyphs.boldOf(role)),
        phosphorBold[mark],
        reason:
            'MaterialGlyphs.boldOf(IconRole.$mark) is not the glyph '
            'PhosphorIconsBold.$mark draws, and ${_kDrawnAtBold[mark]} draws '
            'it. A role carries no weight by design, so the heavier stroke '
            'can only come back from this table; if it is wrong the mark '
            'changes and nothing else notices.',
      );
      expect(
        MaterialGlyphs.boldOf(role),
        isNot(MaterialGlyphs.of(role)),
        reason:
            'MaterialGlyphs has no separate bold entry for IconRole.$mark, so '
            'boldOf has fallen back to the ordinary stroke. '
            '${_kDrawnAtBold[mark]} draws this mark bold today, so the '
            'fallback would flatten it. The entry has to exist before that '
            'site is converted.',
      );
    }
  });
}

/// One glyph's identity, compared field for field.
///
/// The codepoint alone is not identity: Phosphor's three weights share every
/// codepoint and differ only in the font family, so a table that answered
/// `PhosphorRegular` where the application draws `PhosphorBold` would pass a
/// codepoint check while rendering a visibly different mark.
class _Glyph {
  const _Glyph(
    this.codePoint,
    this.fontFamily,
    this.fontPackage,
    this.matchTextDirection,
  );

  factory _Glyph.of(IconData icon) => _Glyph(
    icon.codePoint,
    icon.fontFamily,
    icon.fontPackage,
    icon.matchTextDirection,
  );

  final int codePoint;
  final String? fontFamily;
  final String? fontPackage;
  final bool matchTextDirection;

  @override
  bool operator ==(Object other) =>
      other is _Glyph &&
      other.codePoint == codePoint &&
      other.fontFamily == fontFamily &&
      other.fontPackage == fontPackage &&
      other.matchTextDirection == matchTextDirection;

  @override
  int get hashCode =>
      Object.hash(codePoint, fontFamily, fontPackage, matchTextDirection);

  @override
  String toString() =>
      'U+${codePoint.toRadixString(16)} in $fontFamily/$fontPackage'
      '${matchTextDirection ? ' (mirrored)' : ''}';
}

/// Every mark the census names, once each.
Iterable<String> _marksInCensus() =>
    _kMarkCensus.values.expand((Map<String, int> marks) => marks.keys).toSet();

/// The role that stands for [mark], with a failure that names the mark rather
/// than throwing a bare `ArgumentError` out of `byName`.
IconRole _roleNamed(String mark) {
  final IconRole? role = IconRole.values
      .where((IconRole candidate) => candidate.name == mark)
      .firstOrNull;
  expect(
    role,
    isNotNull,
    reason:
        'The five dense areas draw $mark and IconRole has no member for it. '
        'The mapping phase settled that all 151 marks the application uses '
        'have a role, so a gap here means either the census or the enum has '
        'moved and the conversion must stop until it is decided once.',
  );
  return role!;
}

/// Counts the marks a Dart source names, under either vocabulary.
///
/// Comment lines are dropped first. The measured census contains no reference
/// inside a comment, so nothing is lost, and it keeps a comment that records
/// what a site used to draw - the kind a conversion commit wants to leave
/// behind - from being counted as a second live reference.
Map<String, int> _marksIn(String source) {
  final Map<String, int> counts = <String, int>{};
  for (final String line in _withoutComments(source).split('\n')) {
    for (final RegExpMatch match in _kMarkReference.allMatches(line)) {
      final String mark = match.group(2)!;
      counts[mark] = (counts[mark] ?? 0) + 1;
    }
  }
  return counts;
}

/// A reference to a mark, in either vocabulary: the Phosphor constant the
/// application named before the conversion, or the role it names after.
final RegExp _kMarkReference = RegExp(
  r'(PhosphorIcons(?:Regular|Bold|Fill)|IconRole)\.([a-zA-Z0-9_]+)',
);

/// Drops block comments and whole-line comments.
///
/// Deliberately not a parser: a `//` inside a string literal is left alone by
/// only dropping lines that BEGIN with a comment marker, which is the shape
/// every comment in these forty files takes.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((String line) {
      final String trimmed = line.trimLeft();
      return !trimmed.startsWith('//') && !trimmed.startsWith('*');
    })
    .join('\n');

/// Reads this application's generated Phosphor constants out of their source.
///
/// A source scan rather than a lookup table, for the reason the generated file
/// itself records: `phosphor_flutter` declares
/// `class PhosphorIconData extends IconData` and `IconData` is a final class,
/// so the package's Dart code cannot be imported at all, and the constants are
/// static fields that no Dart program can enumerate by name. Reading them back
/// out of the file the generator wrote is therefore the only way to compare
/// all 77 mechanically instead of typing 77 expectations by hand.
Map<String, _Glyph> _generatedGlyphs(String path) {
  final String source = File(_fromPackageRoot(path)).readAsStringSync();
  final Map<String, _Glyph> glyphs = <String, _Glyph>{};
  for (final RegExpMatch match in _kGeneratedConstant.allMatches(source)) {
    glyphs[match.group(1)!] = _Glyph(
      int.parse(match.group(2)!, radix: 16),
      match.group(3),
      match.group(4),
      match.group(5) == 'true',
    );
  }
  expect(
    glyphs,
    isNotEmpty,
    reason:
        'No constants were read out of $path. The generated file has changed '
        'shape and this test is no longer measuring anything.',
  );
  return glyphs;
}

/// One entry of `lib/shared/icons/phosphor_icons_*.dart`, which is generated
/// and therefore uniform enough to read with a pattern.
final RegExp _kGeneratedConstant = RegExp(
  r'static const IconData ([a-zA-Z0-9_]+) = IconData\(\s*'
  r'0x([0-9a-fA-F]+),\s*'
  r"fontFamily: '([^']+)',\s*"
  r"fontPackage: '([^']+)',\s*"
  r'matchTextDirection: (true|false),',
);

/// Resolves [relativePath] against the package root, walking up from the
/// current directory to the first pubspec.yaml, so the test runs the same from
/// the repository root and from a subdirectory.
String _fromPackageRoot(String relativePath) {
  Directory directory = Directory.current;
  while (true) {
    if (File('${directory.path}/pubspec.yaml').existsSync()) {
      return '${directory.path}/$relativePath';
    }
    final Directory parent = directory.parent;
    if (parent.path == directory.path) return relativePath;
    directory = parent;
  }
}

/// The nine references in these five areas that are drawn at Phosphor Bold,
/// with what each one is saying by being heavier.
///
/// They are listed because the conversion loses the weight at the seam by
/// design: the role names the mark and the SLOT decides the stroke, so each of
/// these needs the facet filling its slot to ask `MaterialGlyphs.boldOf`. The
/// value is the reason, so that a later reader can tell a deliberate weight
/// from an accident.
const Map<String, String> _kDrawnAtBold = <String, String>{
  'gitBranch':
      'branch_list_tile.dart draws the CURRENT branch heavier than the rest',
  'checkSquare':
      'git_status_tree_view.dart draws a fully staged file heavier, in a '
      'dense tree',
  'minusSquare':
      'git_status_tree_view.dart draws a partly staged file heavier, in the '
      'same tree',
  'asterisk':
      'advanced_search_dialog.dart draws the regex filter heavier while it is '
      'engaged',
  'target':
      'advanced_search_dialog.dart draws the fuzzy filter heavier while it is '
      'engaged',
  'textAa':
      'advanced_search_dialog.dart draws the case filter heavier while it is '
      'engaged',
  // The one entry here whose site has already moved, kept rather than deleted
  // because it is the only place in these five areas where the conversion
  // changed what is drawn. `advanced_search_dialog.dart` drew its own dialog
  // mark at the heavier stroke and now names the role, which `BaseDialog`
  // resolves at the ordinary one: same glyph, thinner. It is recorded as a
  // deliberate decision at the call site, and the entry stays so that the day
  // `DialogSpec` can carry the fact, the table is already proven to hold the
  // heavier mark.
  'magnifyingGlass':
      'advanced_search_dialog.dart drew its own dialog mark heavier until the '
      'conversion; the weight had no slot to survive in',
  // These two sites have also moved, by the same precedent: the details tree
  // crossed the seam as `surfaces.tree` in the #438 closing wave, and the
  // member draws every node mark at the ordinary stroke today while its own
  // source records the one-line `boldOf` restoration waiting on Linux golden
  // regeneration. The entries stay so the heavier mark is already proven to
  // be in the table the day that line lands.
  'folder':
      'file_tree_panel.dart drew every mark in the file tree heavier until '
      'the tree crossed the seam; the member records the loss and the '
      'waiting one-line restoration',
  'folderOpen':
      'file_tree_panel.dart drew every mark in the file tree heavier until '
      'the tree crossed the seam; the member records the loss and the '
      'waiting one-line restoration',
};

/// Every mark named in the five dense feature areas, per file, measured before
/// the conversion began: 246 references over 77 distinct marks in 40 files.
///
/// The counts are per MARK and not per weight, because that is the axis the
/// conversion must not move: a role names the mark and the skin re-decides the
/// stroke. The nine references that are drawn bold are named separately in
/// [_kDrawnAtBold] and asserted there.
const Map<String, Map<String, int>> _kMarkCensus = <String, Map<String, int>>{
  // `arrowsClockwise` and `dotsThreeVertical` are the #442 adoption, and they
  // are not two new marks on this screen: the refresh arrow and the overflow
  // dots have always been drawn at the top of the branches screen, named by
  // `StandardAppBar` - a file this census does not cover. The screen states
  // its own bar as `ScreenSpec.toolbar` now, so the two names moved from the
  // shared bar into the screen that asks for them. What the user sees is
  // unchanged; what this file counts is the naming, and the naming moved.
  'lib/features/branches/branches_screen.dart': <String, int>{
    'arrowsClockwise': 1,
    'cloud': 1,
    'dotsThreeVertical': 1,
    'folder': 1,
    'plus': 1,
  },
  'lib/features/branches/dialogs/delete_branch_dialog.dart': <String, int>{
    'lock': 1,
    'warning': 1,
  },
  'lib/features/branches/dialogs/merge_branch_dialog.dart': <String, int>{
    'gitMerge': 1,
  },
  'lib/features/branches/dialogs/rename_branch_dialog.dart': <String, int>{
    'lock': 1,
    'pencil': 2,
  },
  'lib/features/branches/dialogs/search_branches_dialog.dart': <String, int>{
    'magnifyingGlass': 2,
  },
  'lib/features/branches/widgets/branch_list_tile.dart': <String, int>{
    'arrowRight': 3,
    'arrowsLeftRight': 1,
    'gitBranch': 2,
    'gitMerge': 1,
    'lock': 1,
    'pencil': 1,
    'trash': 1,
    'warning': 1,
  },
  'lib/features/branches/widgets/branches_empty_state.dart': <String, int>{
    'cloud': 1,
    'folder': 1,
  },
  'lib/features/branches/widgets/branches_error_state.dart': <String, int>{
    'warningCircle': 1,
  },
  'lib/features/browse/browse_screen.dart': <String, int>{
    'clockCounterClockwise': 1,
    'dotsThreeVertical': 1,
    'eye': 1,
    'magnifyingGlass': 1,
    'users': 1,
  },
  'lib/features/browse/widgets/browse_no_file_selected_state.dart':
      <String, int>{'file': 1},
  'lib/features/browse/widgets/browse_no_repository_state.dart': <String, int>{
    'folderOpen': 1,
  },
  'lib/features/browse/widgets/file_blame_panel.dart': <String, int>{
    'arrowClockwise': 1,
    'clock': 1,
    'file': 1,
    'gitCommit': 1,
    'info': 1,
    'warningCircle': 1,
  },
  'lib/features/browse/widgets/file_history_panel.dart': <String, int>{
    'arrowClockwise': 1,
    'clockCounterClockwise': 1,
    'gitCommit': 1,
    'warningCircle': 1,
  },
  'lib/features/browse/widgets/file_preview_panel.dart': <String, int>{
    'arrowClockwise': 1,
    'eye': 1,
    'fileCode': 1,
    'warningCircle': 1,
  },
  'lib/features/browse/widgets/file_tree_view.dart': <String, int>{
    'clipboard': 1,
    'copy': 1,
    'copySimple': 1,
    'folderOpen': 1,
    'path': 1,
    'pencil': 1,
    'pencilSimple': 1,
    'textbox': 1,
    'trash': 1,
    'warning': 1,
  },
  'lib/features/browse/widgets/viewers/csv_viewer_dialog.dart': <String, int>{
    'table': 1,
    'warningCircle': 1,
  },
  'lib/features/browse/widgets/viewers/image_viewer_dialog.dart': <String, int>{
    'image': 1,
    'mouseSimple': 1,
  },
  'lib/features/browse/widgets/viewers/markdown_viewer_dialog.dart':
      <String, int>{'fileText': 1, 'warningCircle': 1},
  'lib/features/changes/changes_screen.dart': <String, int>{
    'arrowCounterClockwise': 1,
    'arrowsClockwise': 1,
    'check': 2,
    'checkCircle': 1,
    'folderOpen': 2,
    'globe': 1,
    'minus': 2,
    'plus': 2,
    'trash': 3,
    'warningCircle': 2,
  },
  'lib/features/changes/widgets/changes_clean_state.dart': <String, int>{
    'checkCircle': 1,
  },
  'lib/features/changes/widgets/changes_error_state.dart': <String, int>{
    'warningCircle': 1,
  },
  'lib/features/changes/widgets/commit_dialog.dart': <String, int>{
    'caretDown': 1,
    'caretUp': 1,
    'check': 1,
    'checkSquare': 1,
    'gitCommit': 1,
    'lightbulb': 1,
    'warningCircle': 1,
  },
  'lib/features/changes/widgets/file_list_item.dart': <String, int>{
    'arrowsLeftRight': 1,
    'copy': 1,
    'file': 1,
    'filePlus': 1,
    'gitDiff': 1,
    'minus': 2,
    'pencilSimple': 1,
    'plus': 2,
    'trash': 1,
  },
  // `file` and the second `gitDiff` arrived from base_diff_viewer.dart with
  // the view-mode toggle: #438 resolved the floating speed dial as the site
  // asking the wrong member - a region's action set belongs to the region's
  // panel header, not to `ScreenSpec.primaryActions` - so the toggle is a
  // header action of the diff panel now, naming the same two marks as roles.
  'lib/features/changes/widgets/git_status_tree_view.dart': <String, int>{
    'arrowCounterClockwise': 1,
    'arrowSquareOut': 1,
    'checkSquare': 2,
    'copy': 1,
    'file': 1,
    'gitDiff': 2,
    'minus': 1,
    'minusSquare': 2,
    'plus': 1,
    'square': 2,
    'trash': 1,
    'tree': 1,
    'userList': 1,
    'warningCircle': 1,
  },
  'lib/features/history/dialogs/advanced_search_dialog.dart': <String, int>{
    'asterisk': 2,
    'calendar': 4,
    'file': 1,
    'hash': 1,
    'magnifyingGlass': 3,
    'target': 2,
    'textAa': 2,
    'user': 3,
  },
  'lib/features/history/dialogs/branch_switch_error_dialog.dart': <String, int>{
    'xCircle': 1,
  },
  'lib/features/history/dialogs/compare_commits_dialog.dart': <String, int>{
    'gitCommit': 1,
    'gitDiff': 1,
    'user': 1,
  },
  'lib/features/history/dialogs/create_branch_from_commit_dialog.dart':
      <String, int>{'gitBranch': 3, 'gitCommit': 1},
  'lib/features/history/dialogs/reset_mode_dialog.dart': <String, int>{
    'arrowCounterClockwise': 1,
    'gitCommit': 1,
  },
  'lib/features/history/dialogs/squash_commits_dialog.dart': <String, int>{
    'arrowsInLineVertical': 1,
    'gitCommit': 1,
    'info': 1,
    'warningCircle': 1,
  },
  'lib/features/history/dialogs/uncommitted_changes_dialog.dart': <String, int>{
    'warning': 1,
  },
  'lib/features/history/history_screen.dart': <String, int>{
    'arrowBendDownRight': 2,
    'arrowCounterClockwise': 4,
    'arrowsInLineVertical': 2,
    'calendar': 1,
    'chatText': 1,
    'copy': 1,
    'faders': 1,
    'funnel': 1,
    'gitBranch': 1,
    'gitDiff': 1,
    'listBullets': 1,
    'listMagnifyingGlass': 1,
    'magnifyingGlass': 1,
    'tag': 2,
    'warningCircle': 1,
    'x': 1,
  },
  'lib/features/history/widgets/commit_details_panel.dart': <String, int>{
    'caretDown': 1,
    'caretRight': 1,
    'chatText': 1,
    'gitBranch': 2,
    'gitCommit': 3,
    'gitMerge': 1,
    'hash': 1,
    'info': 1,
    'tag': 1,
    'user': 1,
    'userCircle': 1,
  },
  'lib/features/history/widgets/commit_diff_panel.dart': <String, int>{
    'arrowSquareOut': 1,
    'files': 1,
    'gitDiff': 1,
    'warningCircle': 2,
  },
  'lib/features/history/widgets/commit_list_item.dart': <String, int>{
    'clock': 1,
    'gitBranch': 2,
    'tag': 1,
    'user': 1,
  },
  'lib/features/history/widgets/deep_search_states.dart': <String, int>{
    'listMagnifyingGlass': 1,
    'magnifyingGlass': 2,
    'warningCircle': 1,
    'x': 3,
  },
  // The #438 closing wave took three marks OUT of this file without any site
  // changing what it says: the details tree crossed the seam as
  // `surfaces.tree`, and the disclosure caret pair and the per-row menu
  // trigger are the member's own affordances now — Material's `_TreeCaret`
  // and `_TreeMenuAnchor` draw the same three marks on the skin's side of
  // the seam. All three survive elsewhere in the census, so the distinct-77
  // set is unchanged.
  'lib/features/history/widgets/file_tree_panel.dart': <String, int>{
    'download': 1,
    'files': 1,
    'folder': 1,
    'folderOpen': 2,
    'gitDiff': 1,
    'minusCircle': 1,
    'pencilSimple': 1,
    'plusCircle': 1,
    'textbox': 1,
    'tree': 1,
    'warningCircle': 1,
  },
  'lib/features/history/widgets/history_empty_states.dart': <String, int>{
    'cursorClick': 1,
    'gitCommit': 1,
    'listMagnifyingGlass': 1,
    'magnifyingGlass': 1,
    'warningCircle': 1,
    'x': 1,
  },
  'lib/features/history/widgets/history_list_footer.dart': <String, int>{
    'caretDoubleDown': 1,
    'flagCheckered': 1,
    'listMagnifyingGlass': 1,
  },
  'lib/features/merge/conflict_resolution_screen.dart': <String, int>{
    'arrowLeft': 1,
    'arrowRight': 2,
    'arrowsLeftRight': 1,
    'check': 3,
    'checkCircle': 5,
    'fileText': 2,
    'gitMerge': 1,
    'info': 1,
    'warning': 2,
    'warningCircle': 1,
    'xCircle': 2,
  },
};
