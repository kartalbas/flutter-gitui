import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The glyph table: this skin's answer to "which mark stands for this idea?".
///
/// The contract carries [IconRole] and never an `IconData`, because `IconData`
/// is type-neutral but not identity-neutral - keeping it would have meant the
/// Fluent skin could never use `FluentIcons` and the macOS skin could never
/// use SF Symbols, and every skin would render Phosphor glyphs forever
/// (`docs/SKIN-CONTRACT.md` conflict C3). Material's answer is Phosphor,
/// because that is the set this application has always rendered, and the
/// answer lives here.
///
/// **The entries are `const` and cannot be assembled at runtime.** Flutter's
/// icon tree-shaker only accepts constant `IconData` arguments, and building
/// one from a codepoint variable is a warning in the blocking analysis step
/// even though it would run - so the table is written out rather than folded
/// into a codepoint map plus a factory. That is also why [selectedOf] does not
/// carry a second full table: switching weight means switching FONT FAMILY at
/// the same codepoint, which cannot be expressed over a const table without
/// duplicating all 151 entries, so the skin's own selected marks are named
/// individually and a full bold table is generated when a member needs one.
///
/// **Not imported from the application.** The application ships the same
/// codepoints in `lib/shared/icons/phosphor_icons_regular.dart`, but a skin
/// package reaching back into `lib/` would invert the one dependency edge the
/// whole contract is built on, and the workspace-isolation gate makes that a
/// hard error. The table is therefore this package's own, generated from the
/// same measurement that produced the 151 members of [IconRole].
///
/// Phosphor's Dart code is never imported for a measured reason recorded in
/// the application's own generated file: `phosphor_flutter` declares
/// `class PhosphorIconData extends IconData`, and `IconData` is a final class
/// in current Flutter, so importing the package fails to compile on every
/// platform. The dependency stays so the font assets are bundled; the
/// constants are plain [IconData].
abstract final class MaterialGlyphs {
  /// The font this skin draws its marks from, at its ordinary weight.
  static const String _regularFamily = 'PhosphorRegular';

  /// The same font at the weight this skin marks a chosen thing with. The
  /// codepoints are identical across Phosphor's three weights - only the
  /// family changes - which is what makes a per-mark bold constant a one-line
  /// affair rather than a second table.
  static const String _boldFamily = 'PhosphorBold';

  /// The package the font travels in. Named rather than bundled here, so the
  /// glyphs resolve wherever this skin is used.
  static const String _package = 'phosphor_flutter';

  /// The mark this skin draws for [role].
  ///
  /// Total over the enum by construction: [_glyphs] has one entry per member,
  /// and the lookup asserts rather than falling back, because a fallback would
  /// hide a missing role behind a plausible-looking glyph.
  static IconData of(IconRole role) => _glyphs[role]!;

  /// The check mark at the weight that says "this one is chosen".
  ///
  /// Used by `controls.seriesPicker`, which is the one place this skin marks a
  /// selection with a glyph rather than with a container. Glyph WEIGHT is a
  /// skin decision - which is why no [IconRole] carries one - and this is
  /// where this skin makes it.
  static const IconData selectedCheck = IconData(
    0xe182,
    fontFamily: _boldFamily,
    fontPackage: _package,
    matchTextDirection: true,
  );

  /// Every role, at its Phosphor Regular codepoint.
  ///
  /// Ordered as [IconRole] is ordered, so the two files can be compared line
  /// by line when the enum grows.
  static const Map<IconRole, IconData> _glyphs = <IconRole, IconData>{
    IconRole.arrowBendDownLeft: IconData(
      0xe018,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowBendDownRight: IconData(
      0xe01a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowBendUpLeft: IconData(
      0xe024,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowClockwise: IconData(
      0xe036,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowCounterClockwise: IconData(
      0xe038,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowDown: IconData(
      0xe03e,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowLeft: IconData(
      0xe058,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowRight: IconData(
      0xe06c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowSquareOut: IconData(
      0xe5de,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowUUpLeft: IconData(
      0xe08a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowUp: IconData(
      0xe08e,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowsClockwise: IconData(
      0xe094,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowsCounterClockwise: IconData(
      0xe096,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowsInLineVertical: IconData(
      0xe532,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.arrowsLeftRight: IconData(
      0xe0a0,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.asterisk: IconData(
      0xe0aa,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.at: IconData(
      0xe0ac,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.bookOpen: IconData(
      0xe0e6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.bookmark: IconData(
      0xe0e8,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.broom: IconData(
      0xec54,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.calendar: IconData(
      0xe108,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.caretDoubleDown: IconData(
      0xe126,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.caretDown: IconData(
      0xe136,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.caretLeft: IconData(
      0xe138,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.caretRight: IconData(
      0xe13a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.caretUp: IconData(
      0xe13c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.chartLine: IconData(
      0xe154,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.chatText: IconData(
      0xe17a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.check: IconData(
      0xe182,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.checkCircle: IconData(
      0xe184,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.checkSquare: IconData(
      0xe186,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.checkSquareOffset: IconData(
      0xe188,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.circle: IconData(
      0xe18a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.circleDashed: IconData(
      0xe602,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.circleNotch: IconData(
      0xeb44,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.clipboard: IconData(
      0xe196,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.clock: IconData(
      0xe19a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.clockCountdown: IconData(
      0xed2c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.clockCounterClockwise: IconData(
      0xe1a0,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.cloud: IconData(
      0xe1aa,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.cloudArrowDown: IconData(
      0xe1ac,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.cloudSlash: IconData(
      0xe1b6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.code: IconData(
      0xe1bc,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.codeSimple: IconData(
      0xe1be,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.copy: IconData(
      0xe1ca,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.copySimple: IconData(
      0xe1cc,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.cursorClick: IconData(
      0xe7c8,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.desktop: IconData(
      0xe560,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.dot: IconData(
      0xecde,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.dotsThreeVertical: IconData(
      0xe208,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.download: IconData(
      0xe20a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.downloadSimple: IconData(
      0xe20c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.eye: IconData(
      0xe220,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.eyeSlash: IconData(
      0xe224,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.faders: IconData(
      0xe228,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.file: IconData(
      0xe230,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileAudio: IconData(
      0xea20,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileCode: IconData(
      0xe914,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileCss: IconData(
      0xeb34,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileHtml: IconData(
      0xeb38,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileImage: IconData(
      0xea24,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileMinus: IconData(
      0xe234,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.filePdf: IconData(
      0xe702,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.filePlus: IconData(
      0xe236,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileText: IconData(
      0xe23a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileVideo: IconData(
      0xea22,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileX: IconData(
      0xe23c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.fileZip: IconData(
      0xe958,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.files: IconData(
      0xe710,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.filmStrip: IconData(
      0xe792,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.flagCheckered: IconData(
      0xea38,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.floppyDisk: IconData(
      0xe248,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.folder: IconData(
      0xe24a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.folderOpen: IconData(
      0xe256,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.folderPlus: IconData(
      0xe258,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.folderSimple: IconData(
      0xe25a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.funnel: IconData(
      0xe266,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.gear: IconData(
      0xe270,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.gitBranch: IconData(
      0xe278,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.gitCommit: IconData(
      0xe27a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.gitDiff: IconData(
      0xe27c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.gitMerge: IconData(
      0xe280,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.gitPullRequest: IconData(
      0xe282,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.globe: IconData(
      0xe288,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.graph: IconData(
      0xeb58,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.gridFour: IconData(
      0xe296,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.hardDrives: IconData(
      0xe2a0,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.hash: IconData(
      0xe2a2,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.house: IconData(
      0xe2c2,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.image: IconData(
      0xe2ca,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.info: IconData(
      0xe2ce,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.lightbulb: IconData(
      0xe2dc,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.link: IconData(
      0xe2e2,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.list: IconData(
      0xe2f0,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.listBullets: IconData(
      0xe2f2,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.listMagnifyingGlass: IconData(
      0xebe0,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.listNumbers: IconData(
      0xe2f6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.lock: IconData(
      0xe2fa,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.magnifyingGlass: IconData(
      0xe30c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.minus: IconData(
      0xe32a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.minusCircle: IconData(
      0xe32c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.minusSquare: IconData(
      0xed4c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.moon: IconData(
      0xe330,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.mouseSimple: IconData(
      0xe644,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.package: IconData(
      0xe390,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.palette: IconData(
      0xe6c8,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.path: IconData(
      0xe39c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.pencil: IconData(
      0xe3ae,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.pencilSimple: IconData(
      0xe3b4,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.plus: IconData(
      0xe3d4,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.plusCircle: IconData(
      0xe3d6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.pulse: IconData(
      0xe000,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.question: IconData(
      0xe3e8,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.record: IconData(
      0xe3ee,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.rows: IconData(
      0xe5a2,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.seal: IconData(
      0xe604,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.selection: IconData(
      0xe69a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.signIn: IconData(
      0xe428,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.skipForward: IconData(
      0xe5a6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.sliders: IconData(
      0xe432,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.sortAscending: IconData(
      0xe444,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.sortDescending: IconData(
      0xe446,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.spinner: IconData(
      0xe66a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.square: IconData(
      0xe45e,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.stamp: IconData(
      0xea48,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.star: IconData(
      0xe46a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.storefront: IconData(
      0xe470,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.sun: IconData(
      0xe472,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.table: IconData(
      0xe476,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.tag: IconData(
      0xe478,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.target: IconData(
      0xe47c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.terminal: IconData(
      0xe47e,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.textAa: IconData(
      0xe6ee,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.textAlignLeft: IconData(
      0xe484,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.textIndent: IconData(
      0xea1e,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.textOutdent: IconData(
      0xea1c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.textT: IconData(
      0xe48a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.textbox: IconData(
      0xeb0a,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.timer: IconData(
      0xe492,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.trash: IconData(
      0xe4a6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.tree: IconData(
      0xe6da,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.upload: IconData(
      0xe4be,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.user: IconData(
      0xe4c2,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.userCircle: IconData(
      0xe4c4,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.userList: IconData(
      0xe73c,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.users: IconData(
      0xe4d6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.warning: IconData(
      0xe4e0,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.warningCircle: IconData(
      0xe4e2,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.warningDiamond: IconData(
      0xe7fc,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.x: IconData(
      0xe4f6,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
    IconRole.xCircle: IconData(
      0xe4f8,
      fontFamily: _regularFamily,
      fontPackage: _package,
      matchTextDirection: true,
    ),
  };
}
