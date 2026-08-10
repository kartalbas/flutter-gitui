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
/// 71 and 9 now, and the two "before" totals are the ones the mapping phase's
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
  'lib/features/history/widgets/file_tree_panel.dart': _Weights(2, 0, 0, 0),
  'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart':
      _Weights(4, 0, 0, 0),
  'lib/features/repositories/dialogs/create_pull_request_dialog.dart': _Weights(
    2,
    0,
    0,
    0,
  ),
  'lib/features/repositories/dialogs/project_dialog.dart': _Weights(4, 0, 0, 0),
  'lib/features/repositories/repositories_screen.dart': _Weights(1, 0, 0, 0),
  // icon_comparison_screen.dart held 10 bold marks before and 10 now - a
  // specimen sheet whose whole subject was the raw weight difference - and
  // the file is deleted outright now, the same disposition
  // batch_operations_toolbar.dart got. Its ledger row left with it. Neither
  // pin below moves: the row's before and now were equal, so it contributed
  // nothing to boldRemoved, and it named no site in _kWeightsGivenUp.
  'lib/features/repositories/widgets/global_branch_switcher.dart': _Weights(
    4,
    0,
    3,
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
    0,
    0,
  ),
  'lib/features/tags/tags_screen.dart': _Weights(12, 2, 1, 0),
  'lib/features/tags/widgets/tag_list_tile.dart': _Weights(2, 0, 2, 0),
  'lib/features/workspaces/widgets/workspace_card.dart': _Weights(2, 0, 0, 0),
  'lib/features/workspaces/widgets/workspace_list_item.dart': _Weights(
    2,
    0,
    0,
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
  'lib/shared/widgets/repository_switcher.dart': _Weights(2, 0, 1, 0),
  'lib/shared/widgets/workspace_switcher.dart': _Weights(4, 0, 2, 0),
};

/// What happened to a weight that left the source.
enum _Fate {
  /// The mark still renders at that weight, because the skin re-decides it
  /// from something the application still says.
  restored,

  /// The mark now renders at the ordinary stroke. A deliberate, measured
  /// decision, recorded at the call site and repeated here.
  normalised,

  /// The mark left the source together with the hand-painted construction
  /// that drew it; the member that replaced the construction states the same
  /// fact in its own idiom, so no site renders this mark at any weight.
  superseded,
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
/// Forty-four entries against a ledger difference of 39 Bold plus 5 Fill,
/// so the two measurements have to agree; the third test makes them.
const List<_GivenUp> _kWeightsGivenUp = <_GivenUp>[
  // ---- Bold: the switcher menus that became MenuChoice data ---------------
  _GivenUp(
    'lib/shared/widgets/workspace_switcher.dart',
    'house',
    'Bold',
    _Fate.superseded,
    'The mark on a default-workspace row of the workspace menu, which this '
        'file drew by hand as a PopupMenuItem. The rows are MenuChoice data '
        'now and the menu belongs to the skin (#412), so the mark is stated '
        'as a role and its weight is the language answer.',
  ),
  _GivenUp(
    'lib/shared/widgets/workspace_switcher.dart',
    'folder',
    'Bold',
    _Fate.superseded,
    'The same, on an ordinary workspace row of the same menu.',
  ),
  _GivenUp(
    'lib/shared/widgets/repository_switcher.dart',
    'gitCommit',
    'Bold',
    _Fate.superseded,
    'The same, on the rows of the repository menu. The trigger of each '
        'switcher keeps its own Bold glyph until the shell carries these four '
        'as ToolbarPickerEntry (#413).',
  ),
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
  // ---- Bold: eighteen marks, all eighteen now at the ordinary stroke ------
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
  // ---- The tone conversion's six, adjudicated by its review ---------------
  _GivenUp(
    'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart',
    'checkCircle',
    'Bold',
    _Fate.normalised,
    'The per-repository outcome mark in the progress list. The same dialog '
        'already drew the same outcome at the ordinary stroke through its '
        'status helper, so one dialog was stating one fact at two weights; '
        'the row now matches its converted twin.',
  ),
  _GivenUp(
    'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart',
    'xCircle',
    'Bold',
    _Fate.normalised,
    'The failure branch of that same row mark, at the same weight on both '
        'branches of the ternary, so no state distinction existed to lose.',
  ),
  _GivenUp(
    'lib/features/repositories/widgets/global_branch_switcher.dart',
    'gitBranch',
    'Bold',
    _Fate.normalised,
    'Unconditional on every row of the switcher menu, so it separated no row '
        'from another, and the application draws the same mark at the '
        'ordinary stroke for the same meaning across its branch lists. Where '
        'the weight IS the meaning - branch_list_tile.dart, Bold for the '
        'current branch - it is a state and stays.',
  ),
  _GivenUp(
    'lib/features/repositories/widgets/repository_list_item.dart',
    'checkCircle',
    'Bold',
    _Fate.normalised,
    'The batch outcome mark in the list presentation - the twin of '
        'repository_card.dart\'s, recorded above, by the same measurement: '
        'the weight was identical on both branches of the ternary and never '
        'told success from failure.',
  ),
  _GivenUp(
    'lib/features/repositories/widgets/repository_list_item.dart',
    'warningCircle',
    'Bold',
    _Fate.normalised,
    'The failure branch of that same list mark, drawn at the same weight as '
        'the success branch, so nothing distinguished the two.',
  ),
  // ---- P5's one: the weight crossed the seam with its member --------------
  _GivenUp(
    'lib/features/repositories/dialogs/project_dialog.dart',
    'check',
    'Bold',
    _Fate.restored,
    'The selected-swatch tick in the colour picker. The whole picker moved '
        'across the seam as controls.seriesPicker, and the member keeps the '
        'weight: MaterialControls.seriesPicker draws the tick with '
        'MaterialGlyphs.boldOf(IconRole.check), because a mark sitting on a '
        'saturated swatch has to survive the contrast - the skin deciding a '
        'WEIGHT, which is exactly the decision IconRole refuses to carry.',
  ),
  // ---- The #438 closing wave: two constructions crossed the seam ----------
  _GivenUp(
    'lib/features/history/widgets/file_tree_panel.dart',
    'folder',
    'Bold',
    _Fate.normalised,
    'The details tree crossed the seam as surfaces.tree, and the member '
        'draws every node mark at the ordinary stroke today. The loss is '
        'recorded on the member\'s own Icon (material_surfaces.dart, "A '
        'KNOWN weight loss"): the boldOf swap is one line, held back only '
        'because the tree goldens cannot be regenerated on Windows.',
  ),
  _GivenUp(
    'lib/features/history/widgets/file_tree_panel.dart',
    'folderOpen',
    'Bold',
    _Fate.normalised,
    'The open twin of the entry above, by the same seam-crossing and with '
        'the same recorded one-line restoration waiting on Linux goldens.',
  ),
  // The tags screen's sort and group menus stopped hand-painting their own
  // selection radios (a Bold checkCircle against a Regular circle, 16 px,
  // eleven rows across the two menus) when both menus became the contract's
  // anchored menu. The selection signal is the SKIN's now - Material's
  // MenuChoice answer is the emphasised label with a trailing check - so the
  // eleven marks left with the construction rather than surviving anywhere
  // at any weight. One entry per reference, as the ledger requires.
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Sort menu, name A-Z row: the hand-drawn selection radio died with the '
        'menu construction; MenuChoice.selected carries the fact instead.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Sort menu, name Z-A row, by the same conversion to MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Sort menu, date-newest row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Sort menu, date-oldest row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Sort menu, version-ascending row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Sort menu, version-descending row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Group menu, no-grouping row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Group menu, by-prefix row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Group menu, by-version row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Group menu, by-author row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'checkCircle',
    'Bold',
    _Fate.superseded,
    'Group menu, by-date row, by the same conversion to '
        'MenuChoice.selected.',
  ),
  _GivenUp(
    'lib/features/tags/tags_screen.dart',
    'rows',
    'Fill',
    _Fate.restored,
    'The engaged group anchor. "A grouping is applied" crosses as '
        'MenuAnchorSpec.selected; Material\'s anchor is its own icon-button '
        'member, whose selected mark is MaterialGlyphs.filledOf, and the '
        'filled table holds rows - so the solid mark is re-decided on the '
        'skin\'s side of the seam, exactly like the star and the funnel.',
  ),
  // ---- The banner/badge/avatar wave: seven Bold marks, each leaving with
  // the hand-painted construction that drew it ------------------------------
  _GivenUp(
    'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart',
    'checkCircle',
    'Bold',
    _Fate.normalised,
    'The clean-run branch of the completion callout, which is '
        'surfaces.banner now. Both branches drew Bold, so the weight '
        'distinguished nothing between them; BannerSpec.icon names the same '
        'mark and the skin draws it at the ordinary stroke, where it already '
        'stands in git_output_dialog.dart and eight lines further down this '
        'same file.',
  ),
  _GivenUp(
    'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart',
    'warningCircle',
    'Bold',
    _Fate.normalised,
    'The with-failures branch of the same callout, by the same conversion '
        'to surfaces.banner and the same measurement.',
  ),
  _GivenUp(
    'lib/features/repositories/repositories_screen.dart',
    'folderOpen',
    'Bold',
    _Fate.normalised,
    'The drag-and-drop overlay\'s 64 dp hero mark, drawn by hand together '
        'with the wash, the border and the corner around it, until the whole '
        'overlay became surfaces.dropTarget. DropTargetSpec.icon still names '
        'the mark; Material answers it from its regular table at its own '
        'hero size.',
  ),
  _GivenUp(
    'lib/features/workspaces/widgets/workspace_card.dart',
    'house',
    'Bold',
    _Fate.normalised,
    'The default workspace\'s identity tile, an avatar the card painted by '
        'hand until it became surfaces.avatar. The weight was unconditional '
        '- both branches of the ternary drew Bold - so it distinguished '
        'nothing, and AvatarSpec.glyph hands the stroke to the skin.',
  ),
  _GivenUp(
    'lib/features/workspaces/widgets/workspace_card.dart',
    'folder',
    'Bold',
    _Fate.normalised,
    'The ordinary workspace\'s branch of the same identity tile, by the '
        'same conversion to surfaces.avatar.',
  ),
  _GivenUp(
    'lib/features/workspaces/widgets/workspace_list_item.dart',
    'house',
    'Bold',
    _Fate.normalised,
    'The list presentation\'s twin of the workspace card\'s identity tile, '
        'converted to surfaces.avatar with it and by the same measurement.',
  ),
  _GivenUp(
    'lib/features/workspaces/widgets/workspace_list_item.dart',
    'folder',
    'Bold',
    _Fate.normalised,
    'The ordinary workspace\'s branch of the same row tile, by the same '
        'conversion to surfaces.avatar.',
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
            '_kWeightsGivenUp and at the call site, exactly as those '
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
      // 39 held one normalisation in batch_operations_toolbar.dart. That file
      // is deleted outright now - it had lost its callers, so there is no
      // destination to move its entry to - and its ledger entry and its
      // disposition note left with it, one bold on each side, so the pin
      // follows without the two lists drifting apart. 41 adds the three the
      // switcher menus gave up when their rows became MenuChoice data: two in
      // the workspace menu (house and folder) and one in the repository menu.
      expect(boldRemoved, 41);
      expect(fillRemoved, 5);
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

  group('the twenty normalised marks are the ordinary stroke everywhere', () {
    test('each one is a mark the application already draws unheavied', () {
      // The specific way this could still have gone wrong: ten roles in the
      // census are drawn ONLY at Bold, so routing one of them through a bare
      // `type.icon` would render a mark that appears nowhere in the shipping
      // application. None of the twenty is such a role — each is drawn at
      // the ordinary stroke at other sites (xCircle at
      // command_log_panel.dart:172, checkSquare at
      // base_select_all_button.dart:127) — and this pins that.
      const List<IconRole> normalised = <IconRole>[
        IconRole.magnifyingGlass,
        IconRole.gitPullRequest,
        IconRole.folder,
        IconRole.folderOpen,
        IconRole.floppyDisk,
        IconRole.plus,
        IconRole.checkCircle,
        IconRole.warningCircle,
        IconRole.gitBranch,
        IconRole.gitCommit,
        IconRole.xCircle,
        IconRole.checkSquare,
      ];
      for (final IconRole role in normalised) {
        expect(
          MaterialGlyphs.of(role).fontFamily,
          'PhosphorRegular',
          reason:
              'IconRole.${role.name} no longer answers with the ordinary '
              'stroke, so the recorded normalisations no longer say '
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
