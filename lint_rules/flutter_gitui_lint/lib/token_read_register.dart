/// The token-read register: the executable list of every `AppTheme.*` read
/// the armed `token_read_is_mechanical` rule is allowed to find in the
/// application's `lib/`, each entry naming the contract member the read is
/// waiting for — or, for the handful the vocabulary genuinely cannot say yet,
/// the missing word itself — or, for the sites the contract cannot reach or
/// does not govern by construction, the named permanent carve-out.
///
/// This is the same pattern as `packages/gitui_skin_material/docs/
/// deviation_register.yaml`: a register that is normative and executable, and
/// that **fails in both directions**. An `AppTheme.*` read the classifier
/// reports that has no entry here is an error. An entry here whose site the
/// classifier no longer reports is *also* an error — a stale entry — so the
/// register can only shrink, and it must shrink deliberately: converting a
/// read and deleting its entry is one change, reviewed together. That is what
/// stops the register rotting into an excuse list.
///
/// Three kinds of entry, told apart by which field they carry, because they
/// have different causes and go away for different reasons:
///
/// * [TokenReadRegisterEntry.waitsFor] — the read sits inside a construction
///   that a named P5 contract member replaces wholesale. Converting the token
///   half alone would half-migrate a construction the member deletes, so the
///   read waits for the member and dies with the construction.
/// * [TokenReadRegisterEntry.vocabularyGap] — the read expresses a meaning
///   the contract vocabulary has no word for. There is no member to wait for;
///   filing it under one would misstate the cause. Each gap names the missing
///   word so the vocabulary decision it needs can be made on its own terms.
/// * [TokenReadRegisterEntry.carveOut] — the read sits in code the contract
///   cannot reach (it runs where no skin scope exists) or does not govern
///   (a file outside the shipping application). No member and no word would
///   ever free it; the read dies with its code — deleted or redesigned — and
///   this two-way register forces the entry out in that same change. The
///   category exists so the gap list cannot quietly become the place where
///   the unsayable and the merely unreachable are counted as one cause
///   (#433).
///
/// The `reason` lives here, not in a comment at the call site, so this file
/// is the single place the remainder is counted and argued.
///
/// **How a site is identified.** By `file` (repo-relative, forward slashes)
/// plus `site`, the exact trimmed text of the source line the read sits on,
/// plus `reads`, the number of reads the classifier reports across all lines
/// in the file with that exact text. Line numbers would go stale on every
/// unrelated edit above the site; the line's own text moves with the code. If
/// the site line itself is edited, the register goes red in both directions
/// at once (the new text is unregistered, the old entry is stale), which is
/// the honest outcome: an edited design-bearing line is a design decision and
/// must pass through this file.
///
/// **Deliberately import-free.** The lint rule reads this data inside the
/// analyzer plugin isolate, and `test/token_read_register_gate_test.dart`
/// reads it inside the application's `flutter test` run (the lint cannot see
/// a *deleted* file, so the gate test is what catches an entry whose whole
/// file is gone). One import with zero dependencies serves both.
library;

/// One register entry: `reads` allowed classifier reports at `site` in
/// `file`, waiting for `waitsFor` (a P5 contract member), blocked on
/// `vocabularyGap` (a word the contract vocabulary does not have), or kept
/// by `carveOut` (a named permanent exception the contract cannot absorb).
class TokenReadRegisterEntry {
  const TokenReadRegisterEntry({
    required this.file,
    required this.site,
    required this.reads,
    this.waitsFor,
    this.vocabularyGap,
    this.carveOut,
    required this.reason,
  });

  /// Repo-relative path with forward slashes, e.g. `lib/main.dart`.
  final String file;

  /// The exact trimmed text of the source line the read sits on.
  final String site;

  /// How many reads the classifier reports across all lines in [file] whose
  /// trimmed text equals [site]. One line can carry several reads (each
  /// `AppTheme.*` token in `a + b + c` is one), and several identical lines
  /// sum into one entry.
  final int reads;

  /// The P5 contract member whose arrival deletes the construction this read
  /// is part of. Exactly one of [waitsFor], [vocabularyGap] and [carveOut]
  /// is set.
  final String? waitsFor;

  /// The meaning the contract vocabulary cannot express yet. Exactly one of
  /// [waitsFor], [vocabularyGap] and [carveOut] is set.
  final String? vocabularyGap;

  /// The named permanent exception that keeps this read: the site is outside
  /// the contract's reach (code that runs where no skin scope exists, so no
  /// word could be resolved even if it existed) or outside its scope (a file
  /// that is not part of the shipping application). Deliberately hard to
  /// enter: a carve-out claims a conversion is impossible by construction,
  /// never that it is merely unpleasant, and the claim is argued in the
  /// entry's [reason]. Exactly one of [waitsFor], [vocabularyGap] and
  /// [carveOut] is set.
  final String? carveOut;

  /// Why this read cannot convert before its member (or word) exists — or,
  /// for a carve-out, why no member and no word ever frees it.
  final String reason;
}

/// A register entry the classifier could not fully account for: fewer than
/// [TokenReadRegisterEntry.reads] reads remain at its site.
class StaleTokenRead {
  const StaleTokenRead({required this.entry, required this.found});

  /// The entry that is (partly) stale.
  final TokenReadRegisterEntry entry;

  /// How many reads the classifier actually found at the entry's site.
  final int found;
}

/// The outcome of reconciling one file's classifier reads against the
/// register: which reads to report as unregistered, and which entries are
/// stale.
class TokenReadReconciliation {
  const TokenReadReconciliation({
    required this.unregistered,
    required this.stale,
  });

  /// Indexes into the `readLineTexts` given to [reconcileTokenReads] whose
  /// reads have no remaining register budget and must be reported.
  final List<int> unregistered;

  /// Register entries for the file whose budget was not used up — their
  /// sites are (partly) clean, so the entries must shrink or go.
  final List<StaleTokenRead> stale;
}

/// Reconciles the classifier's findings for one [file] against [register].
///
/// [readLineTexts] carries, in source order, the trimmed text of the line
/// each reported read sits on — one element per read. The function is pure
/// and total so that the gate test can prove **both** directions on synthetic
/// registers: a read without an entry lands in
/// [TokenReadReconciliation.unregistered], and an entry without its reads
/// lands in [TokenReadReconciliation.stale]. A register in which either
/// direction had quietly been removed fails those tests, which is the
/// difference between a two-way register and a one-way one that looks
/// identical until it rots.
TokenReadReconciliation reconcileTokenReads({
  required String file,
  required List<String> readLineTexts,
  List<TokenReadRegisterEntry> register = tokenReadRegister,
}) {
  final entries = [
    for (final entry in register)
      if (entry.file == file) entry,
  ];
  // (file, site) pairs are unique — the gate test pins that — so a plain map
  // cannot silently merge two entries' budgets.
  final remaining = <String, int>{
    for (final entry in entries) entry.site: entry.reads,
  };

  final unregistered = <int>[];
  for (var i = 0; i < readLineTexts.length; i++) {
    final budget = remaining[readLineTexts[i]];
    if (budget != null && budget > 0) {
      remaining[readLineTexts[i]] = budget - 1;
    } else {
      unregistered.add(i);
    }
  }

  final stale = <StaleTokenRead>[
    for (final entry in entries)
      if (remaining[entry.site]! > 0)
        StaleTokenRead(
          entry: entry,
          found: entry.reads - remaining[entry.site]!,
        ),
  ];

  return TokenReadReconciliation(unregistered: unregistered, stale: stale);
}

/// The register itself: 77 reads at the 2026-08-09 census, 33 standing after
/// the #438 conversions and the menu family's move behind the contract — 20
/// waiting for a named P5 member, 6 blocked on a missing word, 7 kept by a
/// named permanent carve-out (#433). Of the 20, the speed dial's 15 were
/// REFILED off `chrome.screen (ScreenSpec.primaryActions)` and onto
/// `surfaces.tree (TreeNodeSpec.menu)`: the cause is unchanged — they still
/// wait for a member — but the member they named was one no conversion here
/// would ever reach, and the group comment argues the measurement. The
/// gate test
/// pins the total (shrink-only — lower it when converting, never raise it)
/// and the per-cause counts, so a read cannot change its story without
/// passing through that pin.
const List<TokenReadRegisterEntry> tokenReadRegister = [
  // ── surfaces.tree — TreeNodeSpec.menu (15 reads) ─────────────────────────
  // The entire hand-built draggable speed dial: its resting offset, both drag
  // clamps, the row pitch of its action column, and the label pills'
  // elevation, padding and gap.
  //
  // REFILED. These 15 reads stood under `chrome.screen (ScreenSpec
  // .primaryActions)`, and that filing named a member no conversion here will
  // ever reach - the same defect #433 fixed for the icon-comparison grid.
  // The codebase had already recorded why, for the third dial: #438 moved the
  // Changes screen's diff-column dial into `PanelSpec.actions` because "up to
  // seven entries are not 'the one or two things a user came here to do'"
  // (git_status_tree_view.dart, `_headerActions`). The two dials that remain
  // measure the same way, and neither lands on `primaryActions`:
  //
  //  * BROWSE (browse_screen.dart, built by `FileTreeViewState.fabActions`) -
  //    up to seven entries, every one gated on a selected FILE node: open in
  //    editor, rename, copy, paste, delete, copy path, reveal. That is a file
  //    tree row's own menu, and the contract already has the slot:
  //    `TreeNodeSpec.menu`, the one the commit-details tree converted under.
  //    It is also the browse tree's ONLY affordance for those seven actions -
  //    that tree has no context menu - so this half CONVERTS.
  //  * HISTORY (history_screen.dart) - five entries whose gating and
  //    callbacks are a strict SUBSET of the commit context menu built in the
  //    same file: squash (>= 2), cherry-pick (> 0), revert, reset and create
  //    tag (== 1) dispatch to the same five methods the menu's entries do.
  //    The menu carries four more entries, is reachable by right-click AND
  //    from the keyboard (Shift+F10 and the ContextMenu key), and marks
  //    squash, revert and reset `MenuActionRole.destructive` while the dial
  //    marks nothing. Two affordances for one job, the weaker one without the
  //    destructive treatment: that half is DELETED, not converted, and no
  //    member and no word frees it.
  //
  // So the file dies when the browse tree becomes `surfaces.tree` and states
  // its row actions as `TreeNodeSpec.menu` - the one member a conversion here
  // actually reaches - with the history dial going in the same change for its
  // own reason.
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'AppTheme.paddingM,',
    reads: 6,
    waitsFor: 'surfaces.tree (TreeNodeSpec.menu)',
    reason:
        'Default resting offset from the bottom-right corner and the '
        'bare halves of the drag-clamp arithmetic that keep the dial inside '
        'its edge margin. A row menu has no resting place to drag, so the '
        'whole drag machinery dies with the construction.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'viewport.width - dialSize.width - AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'surfaces.tree (TreeNodeSpec.menu)',
    reason: 'Horizontal drag clamp keeping the dial\'s edge margin.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'viewport.height - dialSize.height - AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'surfaces.tree (TreeNodeSpec.menu)',
    reason: 'Vertical drag clamp keeping the dial\'s edge margin.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'bottom: AppTheme.paddingS + AppTheme.paddingXS,',
    reads: 2,
    waitsFor: 'surfaces.tree (TreeNodeSpec.menu)',
    reason:
        'Row pitch between the dial\'s action rows; a menu\'s rows are '
        'the skin\'s once the entries travel as `MenuEntry` data.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'elevation: AppTheme.elevationLevel2,',
    reads: 1,
    waitsFor: 'surfaces.tree (TreeNodeSpec.menu)',
    reason:
        'Label pill elevation. A menu entry carries its label inline, so '
        'the pill it is painted on has no successor to inherit the number.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'AppTheme.paddingS + AppTheme.paddingXS,',
    reads: 2,
    waitsFor: 'surfaces.tree (TreeNodeSpec.menu)',
    reason: 'Label pill horizontal padding.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'width: AppTheme.paddingS + AppTheme.paddingXS,',
    reads: 2,
    waitsFor: 'surfaces.tree (TreeNodeSpec.menu)',
    reason: 'Gap between a label pill and its mini-FAB.',
  ),

  // ── surfaces.codeLine — CONVERTED (was 11 reads) ────────────────────────
  // base_diff_viewer.dart calls surfaces.codeLine for every diff and
  // full-file line, so the gutter column width and its gaps moved into the
  // skin. The two facts that blocked the conversion each got their door:
  // the user's code font size crosses as SkinRequest.codeScale (beside the
  // monoFamily it always belonged with), and the full-file view's one-sided
  // gutter is CodeLineSpec.paired = false.

  // ── layout.grid — GridSpec with onColumnsChanged (0 reads) ──────────────
  // Both card grids CONVERTED. The repositories grid went first: it states
  // GridDensity.roomy through KeyboardNavigableGridView and the member
  // answers with the tile extent, the aspect ratio, both gutters and -
  // through onColumnsChanged - the column count the screen used to re-derive
  // from the delegate's own formula; its numbers were the member's exactly
  // (400, 1.2, 16, 16), so not a pixel moved. The workspaces grid was held
  // by a measured blocker - GridSpec had no word for how TALL a tile has to
  // be, and the member's fixed proportion shortened the workspace card by
  // 7.1 pixels at the shell's 870-pixel measurement - until #438 built the
  // word: GridSpec.tileHeight, whose TileHeight.content rung lays each tile
  // at the height its content asks for. The grid now states density plus
  // content ownership through the contract, and its 3 reads (the column
  // formula and both paddingL gutters) died with the hand-built delegate.

  // ── surfaces.tree (2 reads here; 15 more in the dial group above) ───────
  // The tree owns per-depth indent, row height and (via TreeNodeSpec.menu)
  // its own row-action anchor. The commit-details tree
  // (file_tree_panel.dart) CONVERTED and took its 3 reads with it - the
  // per-depth indent, and the two shrunk PopupMenuButton constraints
  // TreeNodeSpec.menu replaced. The two reads below belong to the two
  // keyboard trees, whose conversion the contract no longer blocks
  // (TreeSpec.revealed and TreeNodeSpec.leadingTone exist now) but whose
  // keyboard stack still owns the ListView the member replaces.
  TokenReadRegisterEntry(
    file: 'lib/shared/widgets/base_tree_item.dart',
    site: 'left: depth * indentPerLevel + AppTheme.paddingS,',
    reads: 1,
    waitsFor: 'surfaces.tree',
    reason: 'Per-depth indent plus base inset; the tree member owns both.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/changes/widgets/git_status_tree_view.dart',
    site: 'indentPerLevel: AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'surfaces.tree',
    reason:
        'The site\'s own comment says the rung cannot be stated until '
        'the component\'s indent parameter becomes one.',
  ),

  // ── controls.suggestField — CONVERTED, no entries left ──────────────────
  // Both hand-built searchable dropdowns are gone. `SearchableBaseDropdown`
  // is a façade over `controls.suggestField` (through `Fields.suggest`), so
  // the overlay elevation and the closed box's vertical padding are the
  // skin's numbers now; `searchable_dropdown.dart` had no call site anywhere
  // in lib/ and a second façade over one member would be two ways to ask for
  // one thing, so it was deleted rather than converted.

  // ── chrome.shell — ShellSpec.toolbar (2 reads) ──────────────────────────
  // The skin owns what fits and what overflows (SKIN-CONTRACT.md §4.1);
  // OverflowActionBar and visibleActionCount() move with it at P5 (§5.6).
  TokenReadRegisterEntry(
    file: 'lib/core/navigation/app_shell.dart',
    site: 'AppTheme.paddingM -',
    reads: 1,
    waitsFor: 'chrome.shell (ShellSpec.toolbar)',
    reason:
        'Switcher-group width budget (inner.maxWidth - paddingM - '
        'menuExtent); the fitting arithmetic moves into the skin with the '
        'toolbar.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/widgets/overflow_action_bar.dart',
    site: 'static const double spacing = AppTheme.paddingS;',
    reads: 1,
    waitsFor: 'chrome.shell (ShellSpec.toolbar)',
    reason:
        'Deliberately one statement with the fitting arithmetic; the '
        'file\'s own comment says the arithmetic moves into the skin with '
        'the bar.',
  ),

  // ── surfaces.commitGraphRow — CONVERTED (was 2 reads) ───────────────────
  // commit_list_item.dart calls surfaces.commitGraphRow and
  // commit_graph_painter.dart is deleted, so the divider strip and the lane
  // x-origin moved into the skin verbatim, exactly as SKIN-CONTRACT.md §5.4
  // said they would. lib/ now contains no `extends CustomPainter`.

  // controls.seriesPicker: CONVERTED, 2 reads gone. The swatch grid in
  // project_dialog.dart is the member now, so the swatch geometry - and the
  // length of the palette the application could still enumerate - is the
  // skin's. What the dialog still owns is which member of the series is on.

  // ── surfaces.disclosure — CONVERTED (was 2 reads) ───────────────────────
  // command_log_panel.dart's log entry calls surfaces.disclosure. The
  // hanging indent died with the construction rather than moving: the
  // outcome mark leads the header row and the command and its meta line
  // share the column beside it, so the meta line is aligned by the layout.
  // The mark stayed in the header port and did NOT become
  // DisclosureSpec.leading, because that slot is an IconRole with no Tone
  // and cannot say "this run failed" - reported as a contract finding.

  // ── surfaces.dataGrid — CONVERTED (was 2 reads) ─────────────────────────
  // csv_viewer_dialog.dart calls surfaces.dataGrid; the column spacing and
  // the horizontal margin are the member's arithmetic now.

  // ── controls.progress — CONVERTED, no entries left ──────────────────────
  // The batch dialog's bar calls `controls.progress` and the thickness is the
  // skin's. The entry that stood here named the wrong rung: it said
  // `ProgressExtent.block`, but `block` is the rung for "its own region, with
  // nothing else competing for the space" - Material draws it as a centred
  // ring and the blueprint skin as a bare "(45%)". The batch bar shares its
  // row with the "3 / 10" count, which is `ProgressExtent.inline` by the
  // vocabulary's own words, and that is the rung it converted under.

  // ── overlays.menuAnchor — CONVERTED (was 1 read) ────────────────────────
  // The fallback sized the anchor glyph of `BasePopupMenuButton`, and every
  // caller that let it decide now states its trigger as a `MenuAnchorSpec`
  // instead: the app bar's overflow, the repository card and list row, the
  // workspace-section header, the stash and tag tiles. The skin builds the
  // trigger and opens the menu against it, so the fallback died with the
  // construction exactly as this entry predicted. The two menus that keep
  // the widget form (#438: per-row swatch and flag artwork) hand in their
  // own already-sized `BaseIcon`, so nothing was left for it to size.

  // ── surfaces.listRow — CONVERTED (was 1 read) ───────────────────────────
  // base_list_item.dart is a façade over surfaces.listRow, so the inset rule
  // between two rows - and the leading edge it starts at - is the skin's.

  // ── surfaces.panel (1 read) ─────────────────────────────────────────────
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_panel.dart',
    site: 'this.elevation = AppTheme.elevationLevel1,',
    reads: 1,
    waitsFor: 'surfaces.panel',
    reason:
        'The raw-double elevation parameter default is exactly what '
        'PanelSpec deletes.',
  ),

  // ── Vocabulary gaps (6 reads) ───────────────────────────────────────────
  // No member to wait for; each entry names the missing word instead, so the
  // vocabulary decision it needs can be made on its own terms rather than
  // being buried under a fake member name. #433 audited this list and moved
  // the reads that were not actually waiting for a word - the pre-scope boot
  // splash and the unreachable specimen sheet - into the named carve-outs
  // below, so what remains here is exactly the set a vocabulary decision
  // would free.
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/dialogs/create_pull_request_dialog.dart',
    site: 'height: AppTheme.paddingL + AppTheme.paddingS,',
    reads: 4,
    vocabularyGap:
        'form-row field alignment ("start where the adjacent '
        'labelled field\'s box starts")',
    reason:
        'The 32px is the neighbouring dropdown\'s label-region height, '
        'hand-copied so the Local/Remote toggle aligns with the field\'s '
        'input box. controls.choiceGroup replaces the toggle but does not '
        'absorb a metric of the other control.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_diff_viewer.dart',
    site: 'const Icon(Icons.description_outlined, size: AppTheme.iconXL * 2),',
    reads: 1,
    vocabularyGap:
        'an empty state without a message '
        '(EmptyStateSpec.message is required)',
    reason:
        'surfaces.emptyState exists, but passing an empty message '
        'painted a blank line and moved two distances; until the spec can '
        'say "no message", no rung reaches this state\'s artwork size.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/history/history_screen.dart',
    site: 'Offset(AppTheme.paddingXL, rowBox.size.height / 2),',
    reads: 1,
    vocabularyGap:
        'an element-anchored presentMenu ("open on this row") as '
        'opposed to a point-anchored one',
    reason:
        'Where a keyboard-opened context menu anchors on the selected '
        'commit row. overlays.presentMenu requires an application-supplied '
        'at: Offset, so this length survives the overlay funnel.',
  ),

  // ── Named carve-outs (7 reads, decided in #433) ─────────────────────────
  // Not waiting for anything. Each of these sites is outside the contract's
  // reach or scope by construction, so no P5 member and no new vocabulary
  // word would ever free it; the read dies with its code - deleted or
  // redesigned - never with a vocabulary decision.
  TokenReadRegisterEntry(
    file: 'lib/main.dart',
    site: 'size: AppTheme.iconXL * 3 + AppTheme.paddingS,',
    reads: 2,
    carveOut: 'pre-scope boot splash: renders before any skin scope exists',
    reason:
        'The boot splash (_NativeLoadingScreen) is returned from build() '
        'BEFORE the MaterialApp whose builder installs SkinScope, so at '
        'that moment in the app\'s life there is no skin to answer ANY '
        'word - inventing "a brand mark at display scale" would free '
        'nothing, which is what made the old vocabulary-gap filing false: '
        'the missing thing is the scope, not a word. Same shape as the '
        'three declared exceptions on SkinRootClaims - root plumbing in '
        'main.dart that the contract names instead of absorbing. The brand '
        'mark\'s 104px ends only if the boot sequence is redesigned to '
        'install a scope of its own, a programme decision rather than a '
        'vocabulary one.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/main.dart',
    site: 'const SizedBox(height: AppTheme.iconXL * 2),',
    reads: 1,
    carveOut: 'pre-scope boot splash: renders before any skin scope exists',
    reason:
        'The same pre-scope boot splash: the separation under the brand '
        'mark, kept for the same structural reason.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/screens/icon_comparison_screen.dart',
    site: 'size: AppTheme.iconXL * 2,',
    reads: 2,
    carveOut:
        'developer-only specimen sheet: unreachable in the shipping '
        'application and recorded for deletion',
    reason:
        'The screen\'s subject IS the raw weight difference between two '
        'Phosphor fonts, so rendering its specimens through the contract '
        'would measure the skin instead of the fonts: IconRole lets the '
        'skin re-decide the weight, which deletes the comparison (#249 '
        'conflict C3). No vocabulary is grown for it - a specimen is not a '
        'control, and ControlScale\'s own doc caps the contract at the '
        'three rungs every language honours - because the contract\'s scope '
        'is the shipping application and this screen is not in it: zero '
        'references anywhere in lib/, and the screen-population census '
        '(test/skin/screen_population.dart, kScreensNoSceneCovers) already '
        'records that it is to be DELETED rather than covered. These reads '
        'die with the file, and this two-way register forces their entries '
        'out in that same change.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/screens/icon_comparison_screen.dart',
    site: 'crossAxisSpacing: AppTheme.paddingM,',
    reads: 1,
    carveOut:
        'developer-only specimen sheet: unreachable in the shipping '
        'application and recorded for deletion',
    reason:
        'Formerly filed under layout.grid (GridSpec), which claimed a P5 '
        'conversion would visit this gutter. It will not: the screen is '
        'unreachable and recorded for deletion (see the entry above), and '
        'a dead screen is deleted, not converted. Refiled in #433 so the '
        'GridSpec remainder counts only reads a conversion will actually '
        'reach.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/screens/icon_comparison_screen.dart',
    site: 'mainAxisSpacing: AppTheme.paddingM,',
    reads: 1,
    carveOut:
        'developer-only specimen sheet: unreachable in the shipping '
        'application and recorded for deletion',
    reason: 'The other gutter of the same dead grid; see the entries above.',
  ),
];
