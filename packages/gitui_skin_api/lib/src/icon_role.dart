/// A glyph named by MEANING.
///
/// The question the application asks is "which idea does this mark stand for",
/// never "which glyph is it". `IconData` deliberately does not cross this
/// line: it is type-neutral but not identity-neutral, so keeping it would mean
/// the Fluent skin can never use `FluentIcons` and the macOS skin can never
/// use `CupertinoIcons`, and every skin would render Phosphor glyphs forever.
/// That is the hand-painted-lookalike failure displaced from geometry onto
/// iconography (`docs/SKIN-CONTRACT.md` conflict C3).
///
/// The GLYPH WEIGHT is a skin decision too - Phosphor Regular/Bold/Fill, a
/// Fluent filled variant, an SF Symbol weight - which is why no role carries
/// one and why selected-state weight switching moves inside the skin.
///
/// **Generated, not written.** 151 of the 156 members are one per glyph the
/// application uses today, produced by
/// `grep -rhoE 'PhosphorIcons[A-Za-z]*\.[a-zA-Z0-9_]+' lib | sed 's/.*\.//' | sort -u`
/// over `lib/` at 917 references. The names are therefore Phosphor's, and that
/// is a deliberate cost taken once: renaming 151 glyphs into a house
/// vocabulary would make the mechanical substitution at P3a a judgement pass
/// over 917 sites, and the enum's job is to be an identity the skins map from,
/// not a thesaurus. A skin that has no counterpart for a role answers with its
/// nearest neighbour and registers the substitution.
///
/// Regenerate with the command above; the count is asserted by the migration's
/// own progress bar rather than by this comment.
///
/// The other five members were added during the conversion, each with its own
/// reason recorded at the member: [archive] and [bell], drawn by the shell
/// toolbar fixture the census did not read; [caretLineLeft] and
/// [caretLineRight], because the changelog pager draws four marks and only two
/// had a role; and [updateAvailable], because one site's mark carried a
/// meaning the glyph name could not.
///
/// **Where the generated names are known to be wrong, and why they stay.**
/// Two costs of naming the members after Phosphor's glyphs are measured rather
/// than suspected, and both are recorded here so the thesaurus phase inherits
/// the measurement instead of re-taking it:
///
///  * **One role, several meanings.** [downloadSimple] is named by nine sites
///    that mean four different things - clone a repository
///    (`git_commands.dart:298`, `clone_repository_dialog.dart`,
///    `app_shell.dart` "Clone repository"), fetch from a remote
///    (`git_commands.dart:583`), synchronise tags (`tag_sync_banner.dart:83`)
///    and download a released build (`updates_section.dart`,
///    `update_available_dialog.dart`). No skin can draw them apart, because
///    the application no longer says which is which. The ONE member of that
///    group whose mark was visibly different - the shell's standing
///    update-ready signal, drawn solid where every other download mark was an
///    outline - is [updateAvailable], split out because collapsing it lost
///    something a user could see. The rest are drawn identically today, so
///    splitting them would be a rename with no visible consequence and is
///    deliberately left to the phase that renames all 151.
///  * **Several roles, one meaning.** [pencil] and [pencilSimple] both mean
///    "edit" - and the split runs THROUGH one flow: the branch switcher's
///    rename button names [pencilSimple] (`branch_switcher.dart:123`) while
///    the dialog it opens names [pencil] (`rename_branch_dialog.dart:54`).
///    `git_commands.dart` uses [pencilSimple] for "amend last commit" and
///    `git_config_section.dart` uses [pencil] for "edit git config", so the
///    split provably encodes nothing. The same holds for [copy]/[copySimple],
///    [code]/[codeSimple], [download]/[downloadSimple] and
///    [folder]/[folderSimple]. Merging any pair changes which mark a site
///    draws, which the icon conversion is not allowed to do, so each merge is
///    a design decision for the thesaurus phase and not a mechanical edit.
enum IconRole {
  arrowBendDownLeft,
  arrowBendDownRight,
  arrowBendUpLeft,
  arrowClockwise,
  arrowCounterClockwise,
  arrowDown,
  arrowLeft,
  arrowRight,
  arrowSquareOut,
  arrowUUpLeft,
  arrowUp,
  arrowsClockwise,
  arrowsCounterClockwise,
  arrowsInLineVertical,
  arrowsLeftRight,
  asterisk,
  // Drawn by the shell toolbar fixture rather than by a screen, which is
  // why the 915-reference census did not see them. Recorded as roles so
  // that a toolbar entry can name its meaning like every other one.
  archive,
  at,
  bell,
  bookOpen,
  bookmark,
  broom,
  calendar,
  caretDoubleDown,
  caretDown,
  caretLeft,
  // Added after the census, as the mapping phase resolved: the changelog
  // pager draws FOUR marks and only two of them had a role. "Back one" is
  // caretLeft and "back to the start" is this, and collapsing the two onto
  // one role would draw half the pager identically.
  caretLineLeft,
  caretLineRight,
  caretRight,
  caretUp,
  chartLine,
  chatText,
  check,
  checkCircle,
  checkSquare,
  checkSquareOffset,
  circle,
  circleDashed,
  circleNotch,
  clipboard,
  clock,
  clockCountdown,
  clockCounterClockwise,
  cloud,
  cloudArrowDown,
  cloudSlash,
  code,
  codeSimple,
  copy,
  copySimple,
  cursorClick,
  desktop,
  dot,
  dotsThreeVertical,
  download,
  downloadSimple,
  eye,
  eyeSlash,
  faders,
  file,
  fileAudio,
  fileCode,
  fileCss,
  fileHtml,
  fileImage,
  fileMinus,
  filePdf,
  filePlus,
  fileText,
  fileVideo,
  fileX,
  fileZip,
  files,
  filmStrip,
  flagCheckered,
  floppyDisk,
  folder,
  folderOpen,
  folderPlus,
  folderSimple,
  funnel,
  gear,
  gitBranch,
  gitCommit,
  gitDiff,
  gitMerge,
  gitPullRequest,
  globe,
  graph,
  gridFour,
  hardDrives,
  hash,
  house,
  image,
  info,
  lightbulb,
  link,
  list,
  listBullets,
  listMagnifyingGlass,
  listNumbers,
  lock,
  magnifyingGlass,
  minus,
  minusCircle,
  minusSquare,
  moon,
  mouseSimple,
  package,
  palette,
  path,
  pencil,
  pencilSimple,
  plus,
  plusCircle,
  pulse,
  question,
  record,
  rows,
  seal,
  selection,
  signIn,
  skipForward,
  sliders,
  sortAscending,
  sortDescending,
  spinner,
  square,
  stamp,
  star,
  storefront,
  sun,
  table,
  tag,
  target,
  terminal,
  textAa,
  textAlignLeft,
  textIndent,
  textOutdent,
  textT,
  textbox,
  timer,
  trash,
  tree,

  /// **A new version is ready to install.** A standing signal, not a command.
  ///
  /// Added after the census, and it is the one place the census's own rule -
  /// "one member per glyph" - had to give way, because at this site the glyph
  /// alone carried the meaning. `app_shell.dart` drew the shell toolbar's
  /// update signal at Phosphor FILL while the twelve download *actions*
  /// beside it - clone, fetch, download a build - drew the same mark as an
  /// outline. One of those actions, "Clone repository", sits in the same
  /// toolbar row at the same moment. Collapsed onto [downloadSimple] the two
  /// became one mark, and the only thing left separating a standing signal
  /// from a command was the button's own emphasis, which the mapping phase
  /// measured as half the signal.
  ///
  /// A skin answers this with whatever it uses for "an update is waiting":
  /// Material with the solid download arrow the application always drew here,
  /// Fluent with its own update idiom, macOS with `arrow.down.circle.fill`.
  /// The weight is NOT what crosses the seam - the meaning is, and this skin's
  /// answer to that meaning happens to be a solid mark.
  updateAvailable,
  upload,
  user,
  userCircle,
  userList,
  users,
  warning,
  warningCircle,
  warningDiamond,
  x,
  xCircle,
}
