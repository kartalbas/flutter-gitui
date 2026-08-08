/// The closed types the contract speaks in.
///
/// A vocabulary member names a MEANING and never a value. That is the whole
/// reason these types exist: `Proximity.related` says "these two things belong
/// together", which three design languages answer with three different
/// distances and all three are right, whereas `8.0` is Material's answer
/// chosen once for every language. `docs/SKIN-CONTRACT.md` §1 calls that the
/// Substitution Test, and everything in this file passes it.
///
/// The file is in two parts. The first fifteen types are the vocabularies the
/// census settled (`docs/SKIN-CONTRACT-MEMBERS.md` §1: "grows the closed
/// vocabularies from 9 enums to 15"); [IconRole] is the fifteenth and lives in
/// its own library because its 151 members are generated from a measurement
/// rather than written. The second part holds the enums that are carried by a
/// single spec and are not counted as vocabularies - they describe a piece of
/// application structure (which pane, which priority, which row state) rather
/// than a unit of visual meaning.
library;

// -----------------------------------------------------------------------
// Part one - the fifteen vocabularies
// -----------------------------------------------------------------------

/// How closely two neighbours belong together.
///
/// The application declares the RELATIONSHIP; the skin decides the DISTANCE.
/// There is deliberately no "how many pixels" here, and that absence is the
/// entire point of the type: a token bag would move where the number comes
/// from without moving who decided that a gap exists, where it goes and which
/// rung it takes.
///
/// Five rungs because `AppTheme.paddingXS/S/M/L/XL` are the five steps the
/// application actually uses, at 1,340 measured reads. That lineage is
/// recorded honestly in `docs/SKIN-CONTRACT-MEMBERS.md` §10.4: five rungs is
/// Material's 4dp grid counted out, and Fluent and macOS will not land on
/// five. They are not required to - a skin may collapse rungs, and a skin that
/// does registers the collapse as a deviation.
enum Proximity {
  /// Touching. Two halves of one thing: a glyph and the count beside it.
  hairline,

  /// Two parts of one statement: a label and the value it names.
  related,

  /// Members of one group: the rows of a form, the actions of a toolbar.
  grouped,

  /// Two groups inside one region.
  separate,

  /// Two regions of a screen that are about different subjects.
  sectioned,
}

/// How far a container's content sits from its own edge.
///
/// The question is "how much breathing room does this container owe its
/// content", not "how many pixels of padding". A container at [Inset.none]
/// still lays out, which is what makes this appearance rather than structure.
enum Inset {
  /// The content reaches the edge. A list row that draws its own separator,
  /// an image that must bleed.
  none,

  /// Barely set in. A dense row, a chip, a badge.
  tight,

  /// The ordinary reading distance of this design language.
  normal,

  /// Deliberately generous: a card, a dialog body, an empty state.
  roomy,
}

/// What a piece of text is FOR, in this application's words.
///
/// Nine roles, not Material's fifteen. A screen that names `bodyMedium` has
/// picked Material's type ramp for Fluent and AppKit too, which is exactly the
/// substitution failure the contract exists to prevent - so the roles here are
/// the jobs this application's text actually does, and each skin maps them
/// onto its own ramp. `docs/SKIN-CONTRACT.md` decision D3 records that the
/// collapse from fifteen to nine changes rendered sizes once, deliberately.
enum TextRole {
  /// The loudest line in a region: what this screen, dialog or panel is
  /// about. At most one per region.
  ///
  /// Deliberately "region" and not "surface", because the application reaches
  /// for this in two places and calling it a page title made a skin read only
  /// one of them. It names a screen or a dialog - and it is also the headline
  /// of the empty or the error state that stands IN PLACE OF a region's
  /// content ("No repositories yet", "Could not read this file"), which is
  /// where roughly four of every five uses are. A bisect dialog therefore
  /// renders it twice at once: its own name at the top, and the headline of
  /// the empty state filling its body.
  ///
  /// **So a skin must not answer this with window or title-bar chrome.** It
  /// appears in the middle of a panel, and a macOS skin stamping its
  /// sheet-title treatment on every empty state would be wrong four times out
  /// of five - the substitution failure `docs/SKIN-CONTRACT-MEMBERS.md` §10
  /// names, arriving through a role's DOC rather than through its name. A
  /// dialog's own title is chrome, and it stops coming through this role the
  /// moment `BaseDialog` renders through `overlays.dialog`: the title is a
  /// slot on `DialogSpec`, and a skin gets to draw THAT in its title idiom.
  /// `lib/shared/components/base_dialog.dart` is the one site still spending
  /// this role on chrome, and it is spending it there because its component
  /// has not migrated yet.
  pageTitle,

  /// The name of a region inside a screen: a panel header, a settings section.
  sectionTitle,

  /// The name of one object: a repository, a branch, a tag, a commit.
  itemTitle,

  /// Ordinary prose, and the values the user reads.
  body,

  /// Prose that must stand out from the prose beside it.
  ///
  /// Its opposite is [Tone.muted], which says "present, but secondary to what
  /// it sits beside" - so the two cannot be said about the same line, and
  /// `BaseLabel` asserts that they are not. An empty state's explanation is
  /// NOT this: the headline above it is what stands out, and the explanation
  /// is [body]. That pairing is how the contradiction got in.
  emphasis,

  /// Supporting detail: a path, an author, a date, a byte count.
  detail,

  /// Badge counts, chip labels, status pills - text that is nearly a symbol.
  micro,

  /// Button labels, field labels, menu entries: text the user operates.
  control,

  /// Diffs, hashes, paths, command output. Monospaced by definition, because
  /// alignment is meaning here rather than style.
  code,
}

/// How loudly a control asks to be used.
///
/// This is one half of what a seven-value `ButtonVariant` used to say. The
/// other half is [Tone]. Splitting them is what turns `dangerSecondary` - a
/// Material compound - into "quiet, and destructive", which three languages
/// can each answer their own way.
enum Emphasis {
  /// The thing this surface is for. At most one per surface.
  primary,

  /// A real action, weighted below the primary one.
  secondary,

  /// Present but not competing: an auxiliary action, a toolbar glyph.
  quiet,

  /// Navigation to somewhere else, in the language's link idiom.
  link,
}

/// How much room a control is entitled to.
///
/// Three coarse steps and never a pixel size, because the spike measured
/// `size` as the ONLY lossy parameter on `BaseButton` under Fluent: Fluent 2
/// has exactly one control height. Three values is the most all three
/// languages can honour, and macOS deliberately loses `ControlSize.mini`
/// rather than the contract growing a fourth rung nobody else has.
enum ControlScale {
  /// Dense: a toolbar glyph, a row-level action, a chip.
  compact,

  /// The default weight of this design language.
  normal,

  /// Deliberately large: an empty state's call to action, a primary
  /// confirmation.
  prominent,
}

/// How far a surface stands off the one behind it.
///
/// Named honestly in `docs/SKIN-CONTRACT-MEMBERS.md` §10.1 as Material's
/// elevation-plus-surface-tint ramp wearing a neutral label: Fluent expresses
/// depth as acrylic plus a 1px stroke and macOS as flat surfaces plus
/// hairlines, so both will map several rungs onto one appearance. The question
/// the application is asking is still a real one - "is this thing part of the
/// page, sitting on it, or floating above it" - which is why the type stays.
enum Elevation {
  /// Part of the page. No separation of any kind.
  flush,

  /// A surface the page can tell apart from its background.
  resting,

  /// Deliberately lifted: a selected card, a hovered row.
  raised,

  /// On top of everything: a menu, a popover, a dialog.
  overlay,
}

/// What a change of state MEANS in time.
///
/// The application never reads a `Duration`; it says which kind of change this
/// is and the skin decides how long that takes - including zero, which is what
/// the blueprint answers and what makes the zero-and-extremes sweep able to
/// see a motion dependence at all.
enum MotionRole {
  /// No perceived transition. State that must be true before the user's eye
  /// arrives.
  instant,

  /// Acknowledging a gesture: a press, a toggle, a hover.
  feedback,

  /// One thing becoming another: a pane opening, a row expanding.
  transition,

  /// A change the user must not miss. Named honestly in
  /// `docs/SKIN-CONTRACT-MEMBERS.md` §10.3 as Material's `Easing.emphasized*`
  /// family; Fluent has no emphasis tier and macOS has no motion tokens at all.
  emphasis,
}

/// How much of the surface a progress indicator occupies.
///
/// The one vocabulary in the whole contract whose neutral name matches all
/// three canons exactly: it maps 1:1 onto `LinearProgressIndicator` /
/// `CircularProgressIndicator`, `ProgressBar` / `ProgressRing` and
/// `ProgressBar` / `ProgressCircle` (`docs/SKIN-CONTRACT-MEMBERS.md` §10).
enum ProgressExtent {
  /// Inside a line of content: beside a label, inside a button, along an edge.
  inline,

  /// Occupying its own region, with nothing else competing for the space.
  block,
}

/// Which of the two toggle idioms a labelled row is asking for.
///
/// Measured: 26 `CheckboxListTile(` and 10 `SwitchListTile(` sites. The
/// distinction is not decoration - a checkbox states a fact that is committed
/// later, a switch commits immediately - and every language draws both.
enum ToggleKind {
  /// "This is selected." Part of a set the user confirms afterwards.
  check,

  /// "This is on." Takes effect the moment it changes.
  switching,
}

/// How much of an instant the user is being asked to name.
///
/// It exists so that a time field extends this member instead of adding one:
/// `dateField` answers both, and each language reaches for its own picker.
enum DatePrecision {
  /// A calendar day.
  date,

  /// A calendar day and a time of day.
  dateTime,
}

/// What kind of text entry this is.
///
/// It carries ONLY the values for which a language reaches for a DIFFERENT
/// canonical widget, which is why there are three and not six: `search` maps
/// onto three distinct widgets (`SearchBar`, `AutoSuggestBox`'s host,
/// `MacosSearchField`), `password` onto Fluent's distinct `PasswordBox`, and
/// `text` is the default. `multiline` and `path` were rejected because
/// `FieldSpec.maxLines` and the in-field suffix already say them, and a
/// purpose value that duplicates an existing parameter is a second name for
/// one thing (`docs/SKIN-CONTRACT-MEMBERS.md` §6.3).
enum FieldPurpose {
  /// Ordinary text the user types.
  text,

  /// A query that narrows something else on the screen.
  search,

  /// A secret. The language decides whether and how it can be revealed.
  password,
}

/// How tightly a collection of equal things is packed.
///
/// Shared by `layout.grid` and `surfaces.dataGrid` because they ask the same
/// question - "how much of this does the user want to see at once" - and
/// answering it with two enums would be two names for one thing.
enum GridDensity {
  /// As many as will fit: the user is scanning.
  compact,

  /// The design language's ordinary rhythm.
  normal,

  /// Few and large: the user is choosing, not scanning.
  roomy,
}

/// Which of a split pane's two halves the user can resize.
///
/// Carried because macOS's `ResizablePane` requires it (`resizable_pane.dart`
/// takes a `resizableSide`), and because the answer is a fact about the
/// application's layout rather than a look: a file tree beside a viewer is
/// resized from the tree's trailing edge, and no design language changes that.
enum PaneSide {
  /// The pane that comes first in reading order owns the handle.
  leading,

  /// The pane that comes second owns the handle.
  trailing,
}

/// How long a transient notice is meant to stay.
///
/// Not speculation about a future notification centre: `notification_service`
/// already sets a 365-day duration on an error notice today, which is
/// [persistent] spelled as a number. Without this value that behaviour is lost
/// the moment the contract lands.
enum NoticeLifetime {
  /// It says something the user may miss without harm. The skin dismisses it.
  brief,

  /// It says something that must be read. Only the user or the application
  /// dismisses it.
  persistent,
}

/// What a thing MEANS. Never how it looks.
///
/// A final class rather than an enum, for exactly one reason: [Tone.series]
/// has to exist. Commit-graph lanes, branch colours and workspace colours are
/// a generated set whose PALETTE and LENGTH both belong to the skin, and the
/// application indexes into it without knowing either. That is what deletes
/// the 12-colour palette duplicated across `project.dart`, `workspace.dart`
/// and `quick_settings_menu.dart`, and it is why `controls.seriesPicker`
/// exists: once the skin owns the length, the application cannot enumerate the
/// swatches itself.
///
/// Seventeen named tones plus the series. The eight git tones are here because
/// no design language has a slot for "this file is staged" - each skin answers
/// them from its own palette, which is also the fix for the fixed hex values
/// that are identical in light and dark and fail WCAG AA in light mode (#341).
final class Tone {
  const Tone._(this.name) : seriesIndex = null;

  /// The nth member of the skin's generated series.
  ///
  /// The application knows only the index. How many colours exist, and which
  /// they are, is the skin's answer - which is why `controls.seriesPicker` is
  /// the only way to let a user choose one.
  const Tone.series(int index) : name = 'series', seriesIndex = index;

  /// The tone's stable identity, for switching and for diagnostics. Never a
  /// value a skin is obliged to render literally.
  final String name;

  /// Set only on [Tone.series]; null on every named tone.
  final int? seriesIndex;

  /// The default. Whatever this surface's ordinary foreground is.
  static const Tone neutral = Tone._('neutral');

  /// Present, but secondary to what it sits beside.
  static const Tone muted = Tone._('muted');

  /// The application's own colour: the selection, the brand mark, the thing
  /// being emphasised.
  static const Tone accent = Tone._('accent');

  /// Foreground for something already painted in [accent]. Named honestly in
  /// `docs/SKIN-CONTRACT-MEMBERS.md` §10.2 as Material's on-colour pairing
  /// model - neither other language has a paired on-colour concept, and both
  /// derive foreground contrast per surface instead.
  static const Tone onAccent = Tone._('onAccent');

  /// This destroys something the user cannot get back by repeating the
  /// gesture.
  static const Tone danger = Tone._('danger');

  /// This may not be what the user intended.
  static const Tone warning = Tone._('warning');

  /// The value here is missing or rejected, and the user must fix it before
  /// continuing.
  ///
  /// Not [danger]: an unset git executable destroys nothing, and danger's
  /// whole definition is "this destroys something the user cannot get back by
  /// repeating the gesture". Not [warning] either, which is "this may not be
  /// what you intended" - an empty required field is not a doubt, it is a
  /// fact to be corrected. Material happens to answer both this and [danger]
  /// with `colorScheme.error`; Fluent answers it with a field validation
  /// style rather than `InfoBarSeverity.error`, which is the proof this is a
  /// meaning and not a colour.
  static const Tone invalid = Tone._('invalid');

  /// This finished, and it finished well.
  static const Tone success = Tone._('success');

  /// This is worth knowing and nothing is wrong.
  static const Tone info = Tone._('info');

  /// A file git has never seen before, now staged for its first commit.
  static const Tone gitAdded = Tone._('gitAdded');

  /// A tracked file whose content differs from the index.
  static const Tone gitModified = Tone._('gitModified');

  /// A tracked file that is gone.
  static const Tone gitDeleted = Tone._('gitDeleted');

  /// A tracked file that moved.
  static const Tone gitRenamed = Tone._('gitRenamed');

  /// A file in the working tree that git is not tracking.
  static const Tone gitUntracked = Tone._('gitUntracked');

  /// A file a merge could not resolve. The user must decide.
  static const Tone gitConflicted = Tone._('gitConflicted');

  /// A file `.gitignore` excludes.
  static const Tone gitIgnored = Tone._('gitIgnored');

  /// A change that is in the index and will be part of the next commit.
  static const Tone gitStaged = Tone._('gitStaged');

  @override
  bool operator ==(Object other) =>
      other is Tone && other.name == name && other.seriesIndex == seriesIndex;

  @override
  int get hashCode => Object.hash(name, seriesIndex);

  @override
  String toString() =>
      seriesIndex == null ? 'Tone.$name' : 'Tone.series($seriesIndex)';
}

// -----------------------------------------------------------------------
// Part two - the structural enums the specs carry
// -----------------------------------------------------------------------
//
// These are not counted among the fifteen vocabularies because they do not
// name a unit of visual meaning. Each states a fact about the application's
// own structure that a skin needs in order to place something, and each is
// carried by exactly one spec.

/// How much of the navigation the user has asked to see.
///
/// Nullable wherever it appears, and that nullability is the decision: a skin
/// whose canonical navigation ships its own display-mode control - Fluent's
/// `NavigationPane`, macOS's `MacosWindowScope.toggleSidebar()` - leaves the
/// value null and binds its own affordance to `onDensityChanged`. Two
/// affordances for one job is a defect by this repository's own rules, so the
/// skin decides whether a toggle is drawn at all.
enum NavigationDensity {
  /// Every destination shows its name.
  full,

  /// Destinations are reduced to their glyphs.
  condensed,

  /// The navigation is not on screen.
  hidden,
}

/// The regions of the shell the F6 / Shift+F6 cycle walks, in order.
///
/// This is WHAT THE USER CAN DO, so it is structure and no skin may reorder
/// it. `BaseFocusRegion` stays in application code and wraps AROUND whatever
/// `chrome.shell` returns.
enum ShellPane {
  /// The navigation rail, pane or sidebar.
  rail,

  /// The shell's own action bar.
  toolbar,

  /// The selected destination's body.
  content,

  /// The command-log panel.
  log,
}

/// What the application knows about overflow that the skin does not: which
/// group to shed first.
///
/// Everything else about overflow - whether it happens, where the menu goes,
/// what it looks like - is the skin's, because two of the three languages
/// already own overflow at the bar (`CommandBar.primaryItems`,
/// `ToolBar.actions` with its own `ToolbarOverflowButton`).
enum ToolbarPriority {
  /// Never leaves the bar. Losing it would leave the bar meaningless.
  pinned,

  /// Sheds after everything sheddable has already gone.
  normal,

  /// The first to move into the overflow menu.
  sheddable,
}

/// What the window frame itself is expected to be.
///
/// One of the three declared exceptions on `SkinRootClaims`: window chrome is
/// a skin decision that today lives as a one-time `window_manager` call in
/// `main.dart`, which is theming outside every skin. An enum rather than a
/// value, so nothing measurable crosses the seam.
enum WindowChrome {
  /// Whatever the operating system draws by default.
  hostDefault,

  /// The skin draws the title bar itself.
  skinDrawn,

  /// The host's frame, tinted from the system accent.
  systemAccented,
}

/// What kind of thing a dialog contains.
///
/// It replaces `BaseDialog.maxWidth`, and it is not a width bucket wearing a
/// different name: a width would be unreachable anyway, because macOS pins its
/// alert to 260px and Cupertino to 270. What the skin genuinely needs to know
/// is what the dialog holds, because that is what decides `MacosAlertDialog`
/// versus `MacosSheet` - and it is the same information fifteen call sites are
/// approximating with a number today.
enum DialogExtent {
  /// A sentence and up to two answers.
  alert,

  /// Fields the user fills in.
  form,

  /// Something to look through: a file tree, a list, a diff.
  browser,
}

/// What an action at the bottom of a dialog MEANS.
///
/// The role, not a button variant, is what a dialog declares, because the
/// languages disagree about how emphasis is expressed and even about where the
/// actions go: Material and AppKit put the affirmative last, Fluent puts it
/// FIRST and stretches every action to equal width. A call site that handed
/// over a ready-made button would have made all of those decisions for every
/// language at once.
enum DialogActionRole {
  /// Completes the dialog by doing the thing it asked about. A dialog has at
  /// most one - it is the one a language may single out as its default, and
  /// "the default" is not a set.
  affirmative,

  /// Completes the dialog by destroying something. Separate from
  /// [affirmative] rather than a flag on it, because a dialog may offer two
  /// destructive actions while it may only ever have one default.
  destructive,

  /// Leaves the dialog without doing what it asked. The action Escape is the
  /// keyboard equivalent of.
  dismissive,

  /// Any other way forward, or an auxiliary action that does not close the
  /// dialog at all.
  neutral,
}

/// What an action inside a menu MEANS.
///
/// The same argument as [DialogActionRole], one surface down: Material tints a
/// destructive entry with `error`, Fluent gives it its own critical style, and
/// macOS's pulldown menus carry no destructive styling at all - a registered
/// loss rather than a hand-painted lookalike.
enum MenuActionRole {
  /// An ordinary entry: open, rename, copy, check out, push.
  normal,

  /// An entry that destroys something the user cannot get back by repeating
  /// the gesture.
  destructive,
}

/// What a row's selection state means.
///
/// Two of these three values are what `colorScheme.secondaryContainer` and
/// `tertiaryContainer` actually mean at `base_list_item.dart` today. Only a
/// human knows that, which is why translating those reads is judgement work
/// rather than a codemod.
///
/// It is deliberately not the whole story: a roving-highlight list has TWO
/// independent facts, and the second one is carried beside this as
/// `containerFocused`. See `ListRowSpec.containerFocused`.
enum RowSelection {
  /// Not selected.
  none,

  /// The one row the user is acting on.
  primary,

  /// One of several rows the user has gathered for a batch action.
  multi,
}
