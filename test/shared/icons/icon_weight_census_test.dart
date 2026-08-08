/// The WEIGHT half of the icon conversion's acceptance test (#249, P3a).
///
/// The three glyph-identity suites that already exist ask "does the site still
/// name the same mark?" and "does the skin map that mark back to the identical
/// `IconData`?". Both fold `PhosphorIcons<Weight>.x` and `IconRole.x` into one
/// tally on purpose, because that is what lets them guard a conversion landing
/// file by file — a converted site and an unconverted one name the same MARK.
/// The cost of that fold is precise and was measured rather than argued: they
/// cannot see the WEIGHT. Change `PhosphorIconsFill.downloadSimple` to
/// `IconRole.downloadSimple` and every one of them still passes, while the
/// shell toolbar quietly stops drawing a solid mark.
///
/// That is the hole this file closes, and it closes it over the WHOLE of
/// `lib/` rather than over one wave's directories.
///
/// **How.** Phosphor's Regular, Bold and Fill are three fonts at one set of
/// codepoints, so a weight only exists in application source while the site
/// still names a Phosphor constant. [_kWeightLedger] therefore records, per
/// file, how many Bold and Fill references stood there before the conversion
/// began and how many stand there now. Every difference is a site that gave up
/// a weight at the seam, and every one of them is enumerated in
/// [_kWeightsGivenUp] with what happened to it. A conversion that drops a
/// thirteenth weight without saying so fails here with the file named; so does
/// one that quietly puts a weight back.
///
/// **What the ledger cannot say, and who says it instead.** Once a site names
/// a role, the weight it renders is the skin's answer and no source scan can
/// see it. The two mechanisms that carry a weight across the seam are asserted
/// against the real widget tree instead:
///
///  * a control STATE, re-decided by the skin —
///    `packages/gitui_skin_material/test/conformance/components/`
///    `base_icon_button_conformance_test.dart`, group "the selected mark, on
///    every platform", which proves a selected toggle draws the solid mark;
///  * a distinct MEANING, answered by the table —
///    `packages/gitui_skin_material/test/conformance/`
///    `glyph_table_totality_test.dart`, which pins `IconRole.updateAvailable`
///    to the solid download arrow the shell toolbar has always drawn.
///
/// The last group below checks the application half of that second mechanism:
/// that the shell still NAMES the split role, since a table entry nobody asks
/// for restores nothing.
library;

import 'dart:io';

import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;
import 'package:gitui_skin_material/gitui_skin_material.dart';

/// How many marks one file draws at Phosphor's two heavier weights, before the
/// conversion and now.
class _Weights {
  const _Weights(this.boldBefore, this.fillBefore, this.boldNow, this.fillNow);

  /// References to `PhosphorIconsBold.*` at the commit the conversion started
  /// from.
  final int boldBefore;

  /// References to `PhosphorIconsFill.*` at that same commit.
  final int fillBefore;

  /// What the file must hold today.
  final int boldNow;

  /// What the file must hold today.
  final int fillNow;
}

/// Every file in `lib/` that has ever named a heavier Phosphor weight, with
/// the before-and-after count.
///
/// Measured, not curated: `PhosphorIcons(Bold|Fill)\.\w+` counted over
/// `git show HEAD:` each file and over the working tree, with whole-line
/// comments dropped so that a comment recording what a site USED to draw is
/// not counted as a live reference. 110 Bold and 14 Fill references before;
/// 98 and 10 now, and the two "before" totals are the ones the mapping phase's
/// own census reported.
const Map<String, _Weights> _kWeightLedger = <String, _Weights>{
  'lib/core/navigation/app_shell.dart': _Weights(2, 1, 2, 0),
  'lib/core/navigation/navigation_item.dart': _Weights(0, 9, 0, 9),
  'lib/features/branches/widgets/branch_list_tile.dart': _Weights(1, 0, 1, 0),
  'lib/features/changes/widgets/git_status_tree_view.dart': _Weights(
    4,
    0,
    4,
    0,
  ),
  'lib/features/history/dialogs/advanced_search_dialog.dart': _Weights(
    4,
    0,
    3,
    0,
  ),
  'lib/features/history/widgets/file_tree_panel.dart': _Weights(2, 0, 2, 0),
  'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart':
      _Weights(4, 0, 4, 0),
  'lib/features/repositories/dialogs/create_pull_request_dialog.dart': _Weights(
    2,
    0,
    0,
    0,
  ),
  'lib/features/repositories/dialogs/project_dialog.dart': _Weights(4, 0, 1, 0),
  'lib/features/repositories/repositories_screen.dart': _Weights(1, 0, 1, 0),
  'lib/features/repositories/screens/icon_comparison_screen.dart': _Weights(
    10,
    0,
    10,
    0,
  ),
  'lib/features/repositories/widgets/batch_operations_toolbar.dart': _Weights(
    1,
    0,
    1,
    0,
  ),
  'lib/features/repositories/widgets/global_branch_switcher.dart': _Weights(
    4,
    0,
    4,
    0,
  ),
  'lib/features/repositories/widgets/project_section.dart': _Weights(
    2,
    0,
    2,
    0,
  ),
  'lib/features/repositories/widgets/repositories_empty_state.dart': _Weights(
    1,
    0,
    1,
    0,
  ),
  'lib/features/repositories/widgets/repository_card.dart': _Weights(
    2,
    1,
    0,
    0,
  ),
  'lib/features/repositories/widgets/repository_list_item.dart': _Weights(
    2,
    1,
    2,
    0,
  ),
  'lib/features/tags/tags_screen.dart': _Weights(12, 2, 12, 1),
  'lib/features/tags/widgets/tag_list_tile.dart': _Weights(2, 0, 2, 0),
  'lib/features/workspaces/widgets/workspace_card.dart': _Weights(2, 0, 2, 0),
  'lib/features/workspaces/widgets/workspace_list_item.dart': _Weights(
    2,
    0,
    2,
    0,
  ),
  'lib/features/workspaces/widgets/workspaces_empty_state.dart': _Weights(
    1,
    0,
    1,
    0,
  ),
  'lib/main.dart': _Weights(1, 0, 1, 0),
  'lib/shared/dialogs/batch_result_dialog.dart': _Weights(2, 0, 0, 0),
  'lib/shared/dialogs/branch_switcher_dialog.dart': _Weights(3, 0, 2, 0),
  'lib/shared/dialogs/create_tag_dialog.dart': _Weights(1, 0, 1, 0),
  'lib/shared/dialogs/repository_switcher_dialog.dart': _Weights(4, 0, 3, 0),
  'lib/shared/utils/file_icon_utils.dart': _Weights(21, 0, 21, 0),
  'lib/shared/widgets/base_tree_item.dart': _Weights(3, 0, 3, 0),
  'lib/shared/widgets/branch_switcher.dart': _Weights(3, 0, 3, 0),
  'lib/shared/widgets/language_selector.dart': _Weights(1, 0, 1, 0),
  'lib/shared/widgets/repository_switcher.dart': _Weights(2, 0, 2, 0),
  'lib/shared/widgets/workspace_switcher.dart': _Weights(4, 0, 4, 0),
};

/// What happened to a weight that left the source.
enum _Fate {
  /// The mark still renders at that weight, because the skin re-decides it
  /// from something the application still says.
  restored,

  /// The mark now renders at the ordinary stroke. A deliberate, measured
  /// decision, recorded at the call site and repeated here.
  normalised,
}

/// One site that gave up a Phosphor weight, and what became of it.
class _GivenUp {
  const _GivenUp(this.file, this.mark, this.weight, this.fate, this.because);

  final String file;
  final String mark;
  final String weight;
  final _Fate fate;
  final String because;
}

/// Every weight the conversion removed from `lib/`, with its disposition.
///
/// Sixteen entries against a ledger difference of 12 Bold plus 4 Fill, so the
/// two measurements have to agree; the first test makes them.
const List<_GivenUp> _kWeightsGivenUp = <_GivenUp>[
  // ---- Fill: four sites, all four still drawn solid -----------------------
  _GivenUp(
    'lib/core/navigation/app_shell.dart',
    'downloadSimple',
    'Fill',
    _Fate.restored,
    'The shell toolbar\'s update signal. The one solid mark in the census '
        'that was not a control state: nothing said "this means an update is '
        'ready", and the Clone action in the same toolbar row names the same '
        'download mark. Restored by splitting the MEANING out as '
        'IconRole.updateAvailable, whose Material answer is the solid arrow.',
  ),
  _GivenUp(
    'lib/features/repositories/widgets/repository_card.dart',
    'star',
    'Fill',
    _Fate.restored,
    'The favourite star. `isSelected: repository.isFavorite` already crosses '
        'the seam beside the role, and MaterialControls.iconButton answers it '
        'with MaterialGlyphs.filledOf.',
  ),
  _GivenUp(
    'lib/features/repositories/widgets/repository_list_item.dart',
    'star',
    'Fill',
    _Fate.restored,
    'The same favourite star in the list presentation, by the same mechanism.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'funnel',
    'Fill',
    _Fate.restored,
    'The engaged filter. `isSelected: _hasActiveFilters()` carries the state '
        'and the skin re-decides the solid mark from it.',
  ),
  // ---- Bold: twelve marks, all twelve now at the ordinary stroke ----------
  _GivenUp(
    'lib/features/history/dialogs/advanced_search_dialog.dart',
    'magnifyingGlass',
    'Bold',
    _Fate.normalised,
    'Dialog title mark. 6 of the 72 BaseDialog.icon sites were bold; this '
        'dialog draws the same magnifying glass at the ordinary stroke twice '
        'more, on its query field and on its own Search button.',
  ),
  _GivenUp(
    'lib/features/repositories/dialogs/create_pull_request_dialog.dart',
    'gitPullRequest',
    'Bold',
    _Fate.normalised,
    'Dialog title mark, same slot and same measurement.',
  ),
  _GivenUp(
    'lib/features/repositories/dialogs/create_pull_request_dialog.dart',
    'gitPullRequest',
    'Bold',
    _Fate.normalised,
    'The affirmative action\'s leading mark. 2 of the 16 DialogAction.icon '
        'sites were bold.',
  ),
  _GivenUp(
    'lib/features/repositories/dialogs/project_dialog.dart',
    'folder',
    'Bold',
    _Fate.normalised,
    'Dialog title mark. The folder mark is drawn at the ordinary stroke 14 '
        'times elsewhere.',
  ),
  _GivenUp(
    'lib/features/repositories/dialogs/project_dialog.dart',
    'floppyDisk',
    'Bold',
    _Fate.normalised,
    'The affirmative action\'s leading mark while editing.',
  ),
  _GivenUp(
    'lib/features/repositories/dialogs/project_dialog.dart',
    'plus',
    'Bold',
    _Fate.normalised,
    'The same action while creating. `plus` is drawn at the ordinary stroke '
        'at 16 other sites.',
  ),
  _GivenUp(
    'lib/features/repositories/widgets/repository_card.dart',
    'checkCircle',
    'Bold',
    _Fate.normalised,
    'The batch outcome mark. The application draws this same "how did the '
        'operation end" mark at BOTH weights already — bold in '
        'batch_result_dialog.dart and batch_operation_progress_dialog.dart:254, '
        'ordinary in git_output_dialog.dart and the same progress dialog at '
        ':392 — so the heavier stroke was carrying nothing.',
  ),
  _GivenUp(
    'lib/features/repositories/widgets/repository_card.dart',
    'warningCircle',
    'Bold',
    _Fate.normalised,
    'The failure branch of the same mark, at the same weight on both sides of '
        'the ternary, so no state distinction existed to lose.',
  ),
  _GivenUp(
    'lib/shared/dialogs/batch_result_dialog.dart',
    'checkCircle',
    'Bold',
    _Fate.normalised,
    'The same outcome mark as a dialog title. Its sibling dialogs reporting '
        'the same fact never drew it bold.',
  ),
  _GivenUp(
    'lib/shared/dialogs/batch_result_dialog.dart',
    'warningCircle',
    'Bold',
    _Fate.normalised,
    'The failure branch of that same dialog title mark, drawn at the same '
        'weight as the success branch, so nothing distinguished the two.',
  ),
  _GivenUp(
    'lib/shared/dialogs/branch_switcher_dialog.dart',
    'gitBranch',
    'Bold',
    _Fate.normalised,
    'Dialog title mark. The branch mark is drawn at the ordinary stroke 53 '
        'times, including on this dialog\'s own search field.',
  ),
  _GivenUp(
    'lib/shared/dialogs/repository_switcher_dialog.dart',
    'gitCommit',
    'Bold',
    _Fate.normalised,
    'Dialog title mark, drawn at the ordinary stroke at 21 other sites.',
  ),
];

void main() {
  group('the weight ledger', () {
    test('every file holds exactly the heavier marks it is meant to', () {
      final Map<String, String> wrong = <String, String>{};
      for (final MapEntry<String, _Weights> entry in _kWeightLedger.entries) {
        final File file = File(_fromPackageRoot(entry.key));
        expect(
          file.existsSync(),
          isTrue,
          reason:
              '${entry.key} is in the weight ledger but no longer exists. Move '
              'its entry with the file rather than dropping it.',
        );
        final String source = _withoutComments(file.readAsStringSync());
        final int bold = _kBold.allMatches(source).length;
        final int fill = _kFill.allMatches(source).length;
        if (bold != entry.value.boldNow || fill != entry.value.fillNow) {
          wrong[entry.key] =
              'expected ${entry.value.boldNow} bold / '
              '${entry.value.fillNow} fill, found $bold / $fill';
        }
      }
      expect(
        wrong,
        isEmpty,
        reason:
            'A file gained or lost a Phosphor weight without the ledger being '
            'updated. Losing one is a site that will now render at the '
            'ordinary stroke — write down which site and why in '
            '_kWeightsGivenUp and at the call site, exactly as the twelve '
            'already recorded there did, or find the member that carries the '
            'weight across the seam and use it instead.',
      );
    });

    test('no file outside the ledger draws a heavier mark', () {
      final List<String> strays = <String>[];
      for (final FileSystemEntity entity in Directory(
        _fromPackageRoot('lib'),
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String relative = entity.path
            .replaceAll(r'\', '/')
            .split('/lib/')
            .last;
        final String path = 'lib/$relative';
        if (_kWeightLedger.containsKey(path)) continue;
        final String source = _withoutComments(entity.readAsStringSync());
        if (_kBold.hasMatch(source) || _kFill.hasMatch(source)) {
          strays.add(path);
        }
      }
      expect(
        strays,
        isEmpty,
        reason:
            'A file started drawing at a heavier Phosphor weight without being '
            'in the ledger. New weights in application code are how the '
            'conversion goes backwards: the weight belongs to the skin, which '
            're-decides it from the slot or from a state the spec carries.',
      );
    });

    test('the ledger and the disposition list describe the same removals', () {
      int boldRemoved = 0;
      int fillRemoved = 0;
      for (final _Weights weights in _kWeightLedger.values) {
        boldRemoved += weights.boldBefore - weights.boldNow;
        fillRemoved += weights.fillBefore - weights.fillNow;
      }
      expect(
        boldRemoved,
        _kWeightsGivenUp.where((_GivenUp g) => g.weight == 'Bold').length,
        reason:
            'The ledger says a different number of bold marks left the source '
            'than _kWeightsGivenUp accounts for. Every one has to be named, '
            'because a weight that leaves without a note is exactly the silent '
            'change this file exists to prevent.',
      );
      expect(
        fillRemoved,
        _kWeightsGivenUp.where((_GivenUp g) => g.weight == 'Fill').length,
      );
      expect(boldRemoved, 12);
      expect(fillRemoved, 4);
    });

    test('every removal names the file it happened in', () {
      for (final _GivenUp given in _kWeightsGivenUp) {
        expect(
          _kWeightLedger.containsKey(given.file),
          isTrue,
          reason: '${given.file} is not in the ledger.',
        );
        expect(
          given.because.length,
          greaterThan(40),
          reason:
              '${given.file}/${given.mark} has no reason recorded. "It '
              'compiled" is not one.',
        );
      }
    });
  });

  group('the four solid marks still render solid', () {
    test('the shell names the split role rather than the download action', () {
      final String shell = _withoutComments(
        File(
          _fromPackageRoot('lib/core/navigation/app_shell.dart'),
        ).readAsStringSync(),
      );
      expect(
        shell.contains('IconRole.updateAvailable'),
        isTrue,
        reason:
            'The update signal is back to naming a plain download mark. It '
            'shares that mark with the Clone action in the same toolbar row, '
            'so the two become one picture and the only thing left telling '
            'them apart is the button emphasis.',
      );
    });

    test('the update signal resolves to the solid arrow the shell drew', () {
      expect(
        MaterialGlyphs.of(IconRole.updateAvailable),
        PhosphorIconsFill.downloadSimple,
        reason:
            'Field for field — codepoint, font family, package and direction. '
            'A family-only slip would draw the outline at the right codepoint '
            'and pass a codepoint check.',
      );
    });

    test('the favourite star and the engaged funnel keep a solid variant', () {
      expect(MaterialGlyphs.filledOf(IconRole.star), PhosphorIconsFill.star);
      expect(
        MaterialGlyphs.filledOf(IconRole.funnel),
        PhosphorIconsFill.funnel,
      );
      expect(
        MaterialGlyphs.filledOf(IconRole.star),
        isNot(MaterialGlyphs.of(IconRole.star)),
        reason:
            'If these collapse, a favourited repository looks exactly like an '
            'unfavourited one apart from a tint.',
      );
    });
  });

  group('the twelve normalised marks are the ordinary stroke everywhere', () {
    test('each one is a mark the application already draws unheavied', () {
      // The specific way this could still have gone wrong: ten roles in the
      // census are drawn ONLY at Bold, so routing one of them through a bare
      // `type.icon` would render a mark that appears nowhere in the shipping
      // application. None of the twelve is such a role — each is drawn at the
      // ordinary stroke at other sites — and this pins that.
      const List<IconRole> normalised = <IconRole>[
        IconRole.magnifyingGlass,
        IconRole.gitPullRequest,
        IconRole.folder,
        IconRole.floppyDisk,
        IconRole.plus,
        IconRole.checkCircle,
        IconRole.warningCircle,
        IconRole.gitBranch,
        IconRole.gitCommit,
      ];
      for (final IconRole role in normalised) {
        expect(
          MaterialGlyphs.of(role).fontFamily,
          'PhosphorRegular',
          reason:
              'IconRole.${role.name} no longer answers with the ordinary '
              'stroke, so the twelve recorded normalisations no longer say '
              'what happened.',
        );
        expect(
          MaterialGlyphs.boldOf(role),
          isNot(MaterialGlyphs.of(role)),
          reason:
              'IconRole.${role.name} has lost its heavier variant, so the '
              'surfaces still waiting to be answered with boldOf — the file '
              'and status trees, the four toolbar switchers, the picker menu '
              'rows — would silently thin when they migrate.',
        );
      }
    });
  });
}

/// A reference to a mark at one of the two heavier Phosphor weights.
final RegExp _kBold = RegExp(r'PhosphorIconsBold\.[a-zA-Z0-9_]+');
final RegExp _kFill = RegExp(r'PhosphorIconsFill\.[a-zA-Z0-9_]+');

/// Drops block comments and whole-line comments.
///
/// The same shape the sibling glyph-identity suites use, and for the same
/// reason: a comment recording what a site USED to draw must not be counted as
/// a live reference, and every comment in these files begins its own line.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((String line) {
      final String trimmed = line.trimLeft();
      return !trimmed.startsWith('//') && !trimmed.startsWith('*');
    })
    .join('\n');

/// Resolves a repository-relative path however the suite was started.
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
