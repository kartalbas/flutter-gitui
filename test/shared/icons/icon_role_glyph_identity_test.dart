/// Pins the glyph identity the icon-vocabulary conversion (#249, P3a) must
/// preserve: for every mark the converted directories draw today, the Material
/// skin's answer to the corresponding [IconRole] is the very same `IconData`
/// the application's own Phosphor constants hold.
///
/// This is the acceptance test of the sub-phase in checkable form. "No glyph
/// may change" is only enforceable if something compares the two sides of the
/// seam value by value: a call site that today writes
/// `PhosphorIconsRegular.tag` will write `IconRole.tag` after conversion, and
/// the skin resolves that role through `MaterialGlyphs`. If a single table
/// entry pointed at the wrong codepoint - or at the right codepoint in the
/// wrong font family, which is how Phosphor encodes WEIGHT - the application
/// would render a different mark with every suite still green, because no
/// golden covers most of these sites and a wrong-but-plausible glyph reads
/// fine to a test that only checks presence. `IconData` implements equality
/// over codepoint, font family, font package and direction handling, so one
/// `expect` per pair closes exactly that hole.
///
/// The three tables below are MEASURED, not curated: they are the 132 distinct
/// (weight, glyph) pairs an AST scan found across the 432 icon references in
/// `lib/features/{tags,stashes,repositories,workspaces,settings,changelog,about}`,
/// `lib/core` and `lib/main.dart` - the directories assigned to the first
/// conversion wave. 94 pairs are Phosphor Regular, 25 Bold and 13 Fill. The
/// weight split matters because [IconRole] deliberately carries no weight
/// (SKIN-CONTRACT.md, conflict C3): the heavier and solid strokes are
/// re-decided on the skin's side by `MaterialGlyphs.boldOf` and
/// `MaterialGlyphs.filledOf`, so each measured weight must round-trip through
/// its own lookup, not just through `of`.
///
/// When the census changes - a screen is deleted, a new mark is drawn - the
/// tables are regenerated the same way they were produced: parse the listed
/// directories, collect every `PhosphorIcons<Weight>.<name>` reference, and
/// emit one entry per distinct (weight, name) pair. Hand-editing a single
/// entry is the failure mode this file exists to catch, so do not.
///
/// **This file measures the TABLE, never a call site.** It proves that
/// `boldOf` and `filledOf` hold the right marks; it cannot say whether any
/// site still asks for them, which is a different question and a different
/// failure. That one is measured over the whole of `lib/` by
/// `test/shared/icons/icon_weight_census_test.dart`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;
import 'package:gitui_skin_material/gitui_skin_material.dart';

/// Every glyph the converted directories draw at Phosphor's ordinary weight,
/// keyed by the role the conversion will hand the skin instead.
const Map<IconRole, IconData> _regularPairs = <IconRole, IconData>{
  IconRole.arrowBendDownLeft: PhosphorIconsRegular.arrowBendDownLeft,
  IconRole.arrowBendDownRight: PhosphorIconsRegular.arrowBendDownRight,
  IconRole.arrowBendUpLeft: PhosphorIconsRegular.arrowBendUpLeft,
  IconRole.arrowClockwise: PhosphorIconsRegular.arrowClockwise,
  IconRole.arrowCounterClockwise: PhosphorIconsRegular.arrowCounterClockwise,
  IconRole.arrowDown: PhosphorIconsRegular.arrowDown,
  IconRole.arrowUUpLeft: PhosphorIconsRegular.arrowUUpLeft,
  IconRole.arrowUp: PhosphorIconsRegular.arrowUp,
  IconRole.arrowsClockwise: PhosphorIconsRegular.arrowsClockwise,
  IconRole.arrowsCounterClockwise: PhosphorIconsRegular.arrowsCounterClockwise,
  IconRole.arrowsLeftRight: PhosphorIconsRegular.arrowsLeftRight,
  IconRole.at: PhosphorIconsRegular.at,
  IconRole.bookmark: PhosphorIconsRegular.bookmark,
  IconRole.broom: PhosphorIconsRegular.broom,
  IconRole.calendar: PhosphorIconsRegular.calendar,
  IconRole.caretDown: PhosphorIconsRegular.caretDown,
  IconRole.caretLeft: PhosphorIconsRegular.caretLeft,
  IconRole.caretRight: PhosphorIconsRegular.caretRight,
  IconRole.chartLine: PhosphorIconsRegular.chartLine,
  IconRole.check: PhosphorIconsRegular.check,
  IconRole.checkCircle: PhosphorIconsRegular.checkCircle,
  IconRole.checkSquare: PhosphorIconsRegular.checkSquare,
  IconRole.checkSquareOffset: PhosphorIconsRegular.checkSquareOffset,
  IconRole.circle: PhosphorIconsRegular.circle,
  IconRole.circleDashed: PhosphorIconsRegular.circleDashed,
  IconRole.clock: PhosphorIconsRegular.clock,
  IconRole.clockCountdown: PhosphorIconsRegular.clockCountdown,
  IconRole.clockCounterClockwise: PhosphorIconsRegular.clockCounterClockwise,
  IconRole.cloud: PhosphorIconsRegular.cloud,
  IconRole.cloudArrowDown: PhosphorIconsRegular.cloudArrowDown,
  IconRole.cloudSlash: PhosphorIconsRegular.cloudSlash,
  IconRole.code: PhosphorIconsRegular.code,
  IconRole.codeSimple: PhosphorIconsRegular.codeSimple,
  IconRole.copy: PhosphorIconsRegular.copy,
  IconRole.dot: PhosphorIconsRegular.dot,
  IconRole.dotsThreeVertical: PhosphorIconsRegular.dotsThreeVertical,
  IconRole.downloadSimple: PhosphorIconsRegular.downloadSimple,
  IconRole.fileCode: PhosphorIconsRegular.fileCode,
  IconRole.fileText: PhosphorIconsRegular.fileText,
  IconRole.filmStrip: PhosphorIconsRegular.filmStrip,
  IconRole.floppyDisk: PhosphorIconsRegular.floppyDisk,
  IconRole.folder: PhosphorIconsRegular.folder,
  IconRole.folderOpen: PhosphorIconsRegular.folderOpen,
  IconRole.folderPlus: PhosphorIconsRegular.folderPlus,
  IconRole.folderSimple: PhosphorIconsRegular.folderSimple,
  IconRole.funnel: PhosphorIconsRegular.funnel,
  IconRole.gear: PhosphorIconsRegular.gear,
  IconRole.gitBranch: PhosphorIconsRegular.gitBranch,
  IconRole.gitCommit: PhosphorIconsRegular.gitCommit,
  IconRole.gitDiff: PhosphorIconsRegular.gitDiff,
  IconRole.gitMerge: PhosphorIconsRegular.gitMerge,
  IconRole.gitPullRequest: PhosphorIconsRegular.gitPullRequest,
  IconRole.globe: PhosphorIconsRegular.globe,
  IconRole.graph: PhosphorIconsRegular.graph,
  IconRole.gridFour: PhosphorIconsRegular.gridFour,
  IconRole.house: PhosphorIconsRegular.house,
  IconRole.info: PhosphorIconsRegular.info,
  IconRole.link: PhosphorIconsRegular.link,
  IconRole.listBullets: PhosphorIconsRegular.listBullets,
  IconRole.listNumbers: PhosphorIconsRegular.listNumbers,
  IconRole.magnifyingGlass: PhosphorIconsRegular.magnifyingGlass,
  IconRole.package: PhosphorIconsRegular.package,
  IconRole.palette: PhosphorIconsRegular.palette,
  IconRole.pencil: PhosphorIconsRegular.pencil,
  IconRole.pencilSimple: PhosphorIconsRegular.pencilSimple,
  IconRole.plus: PhosphorIconsRegular.plus,
  IconRole.record: PhosphorIconsRegular.record,
  IconRole.rows: PhosphorIconsRegular.rows,
  IconRole.seal: PhosphorIconsRegular.seal,
  IconRole.selection: PhosphorIconsRegular.selection,
  IconRole.signIn: PhosphorIconsRegular.signIn,
  IconRole.sliders: PhosphorIconsRegular.sliders,
  IconRole.sortAscending: PhosphorIconsRegular.sortAscending,
  IconRole.sortDescending: PhosphorIconsRegular.sortDescending,
  IconRole.spinner: PhosphorIconsRegular.spinner,
  IconRole.square: PhosphorIconsRegular.square,
  IconRole.stamp: PhosphorIconsRegular.stamp,
  IconRole.star: PhosphorIconsRegular.star,
  IconRole.storefront: PhosphorIconsRegular.storefront,
  IconRole.tag: PhosphorIconsRegular.tag,
  IconRole.target: PhosphorIconsRegular.target,
  IconRole.terminal: PhosphorIconsRegular.terminal,
  IconRole.textAa: PhosphorIconsRegular.textAa,
  IconRole.textAlignLeft: PhosphorIconsRegular.textAlignLeft,
  IconRole.textT: PhosphorIconsRegular.textT,
  IconRole.timer: PhosphorIconsRegular.timer,
  IconRole.trash: PhosphorIconsRegular.trash,
  IconRole.upload: PhosphorIconsRegular.upload,
  IconRole.user: PhosphorIconsRegular.user,
  IconRole.warning: PhosphorIconsRegular.warning,
  IconRole.warningCircle: PhosphorIconsRegular.warningCircle,
  IconRole.warningDiamond: PhosphorIconsRegular.warningDiamond,
  IconRole.x: PhosphorIconsRegular.x,
  IconRole.xCircle: PhosphorIconsRegular.xCircle,
};

/// Every glyph the converted directories draw at Phosphor's heavier stroke -
/// dense surfaces, chosen menu rows, batch outcome marks - which must survive
/// conversion through `MaterialGlyphs.boldOf`, not `of`.
const Map<IconRole, IconData> _boldPairs = <IconRole, IconData>{
  IconRole.bookmark: PhosphorIconsBold.bookmark,
  IconRole.check: PhosphorIconsBold.check,
  IconRole.checkCircle: PhosphorIconsBold.checkCircle,
  IconRole.checkSquare: PhosphorIconsBold.checkSquare,
  IconRole.circle: PhosphorIconsBold.circle,
  IconRole.circleDashed: PhosphorIconsBold.circleDashed,
  IconRole.dot: PhosphorIconsBold.dot,
  IconRole.floppyDisk: PhosphorIconsBold.floppyDisk,
  IconRole.folder: PhosphorIconsBold.folder,
  IconRole.folderOpen: PhosphorIconsBold.folderOpen,
  IconRole.gitBranch: PhosphorIconsBold.gitBranch,
  IconRole.gitCommit: PhosphorIconsBold.gitCommit,
  IconRole.gitPullRequest: PhosphorIconsBold.gitPullRequest,
  IconRole.house: PhosphorIconsBold.house,
  IconRole.package: PhosphorIconsBold.package,
  IconRole.plus: PhosphorIconsBold.plus,
  IconRole.record: PhosphorIconsBold.record,
  IconRole.seal: PhosphorIconsBold.seal,
  IconRole.selection: PhosphorIconsBold.selection,
  IconRole.stamp: PhosphorIconsBold.stamp,
  IconRole.tag: PhosphorIconsBold.tag,
  IconRole.target: PhosphorIconsBold.target,
  IconRole.warning: PhosphorIconsBold.warning,
  IconRole.warningCircle: PhosphorIconsBold.warningCircle,
  IconRole.xCircle: PhosphorIconsBold.xCircle,
};

/// Every glyph the converted directories draw solid - the selected rail
/// destination, a favourited repository, an engaged filter, an active
/// grouping, the standing update signal - which must survive conversion
/// through `MaterialGlyphs.filledOf`.
const Map<IconRole, IconData> _fillPairs = <IconRole, IconData>{
  IconRole.chartLine: PhosphorIconsFill.chartLine,
  IconRole.downloadSimple: PhosphorIconsFill.downloadSimple,
  IconRole.folderOpen: PhosphorIconsFill.folderOpen,
  IconRole.funnel: PhosphorIconsFill.funnel,
  IconRole.gear: PhosphorIconsFill.gear,
  IconRole.gitBranch: PhosphorIconsFill.gitBranch,
  IconRole.gitCommit: PhosphorIconsFill.gitCommit,
  IconRole.house: PhosphorIconsFill.house,
  IconRole.package: PhosphorIconsFill.package,
  IconRole.pencilSimple: PhosphorIconsFill.pencilSimple,
  IconRole.rows: PhosphorIconsFill.rows,
  IconRole.star: PhosphorIconsFill.star,
  IconRole.tag: PhosphorIconsFill.tag,
};

/// Describes [icon] precisely enough that a failure names the actual
/// divergence - a codepoint is a different MARK, a family is a different
/// WEIGHT - instead of printing two opaque `IconData` instances.
String _describe(IconData icon) =>
    'U+${icon.codePoint.toRadixString(16).toUpperCase()} '
    'in ${icon.fontFamily} (${icon.fontPackage})';

void main() {
  test('every Regular mark the converted directories draw survives the role '
      'round-trip identically', () {
    for (final MapEntry<IconRole, IconData> pair in _regularPairs.entries) {
      final IconData resolved = MaterialGlyphs.of(pair.key);
      expect(
        resolved,
        pair.value,
        reason:
            'IconRole.${pair.key.name} resolves to ${_describe(resolved)} '
            'but the application draws ${_describe(pair.value)} today. A '
            'converted call site would silently change its mark, which is '
            'exactly what this sub-phase promises cannot happen.',
      );
    }
  });

  test('every Bold mark the converted directories draw survives the role '
      'round-trip through boldOf identically', () {
    for (final MapEntry<IconRole, IconData> pair in _boldPairs.entries) {
      final IconData resolved = MaterialGlyphs.boldOf(pair.key);
      expect(
        resolved,
        pair.value,
        reason:
            'IconRole.${pair.key.name} resolves through boldOf to '
            '${_describe(resolved)} but the application draws '
            '${_describe(pair.value)} today. Either the bold table lost its '
            'entry - the fallback to the ordinary weight is silent by '
            'design - or the entry points at the wrong glyph.',
      );
    }
  });

  test('every Fill mark the converted directories draw survives the role '
      'round-trip through filledOf identically', () {
    for (final MapEntry<IconRole, IconData> pair in _fillPairs.entries) {
      final IconData resolved = MaterialGlyphs.filledOf(pair.key);
      expect(
        resolved,
        pair.value,
        reason:
            'IconRole.${pair.key.name} resolves through filledOf to '
            '${_describe(resolved)} but the application draws '
            '${_describe(pair.value)} today. A solid mark is how this '
            'application says "this one is on", so losing it does not just '
            'restyle an icon - it silences a state.',
      );
    }
  });
}
