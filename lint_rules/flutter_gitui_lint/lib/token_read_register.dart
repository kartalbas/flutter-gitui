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

/// The register itself: 77 reads as of the 2026-08-09 census — 64 waiting
/// for a named P5 member, 6 blocked on a missing word, 7 kept by a named
/// permanent carve-out (#433). The gate test pins the total (shrink-only —
/// lower it when converting, never raise it) and the per-cause counts, so a
/// read cannot change its story without passing through that pin.
const List<TokenReadRegisterEntry> tokenReadRegister = [
  // ── chrome.screen — ScreenSpec.primaryActions (15 reads) ────────────────
  // The entire hand-built draggable speed dial. SKIN-CONTRACT-MEMBERS.md:1357
  // states the member's shape exists precisely for Material's FAB; the skin
  // draws the FAB, mini-FABs, label pills, elevations and gaps, and decides
  // placement, so the drag machinery and its edge margins die with the
  // construction.
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'AppTheme.paddingM,',
    reads: 6,
    waitsFor: 'chrome.screen (ScreenSpec.primaryActions)',
    reason:
        'Default resting offset from the bottom-right corner and the '
        'bare halves of the drag-clamp arithmetic that keep the dial inside '
        'its edge margin. Placement is the skin\'s once primaryActions '
        'exists, so the whole drag machinery goes with the construction.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'viewport.width - dialSize.width - AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'chrome.screen (ScreenSpec.primaryActions)',
    reason: 'Horizontal drag clamp keeping the dial\'s edge margin.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'viewport.height - dialSize.height - AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'chrome.screen (ScreenSpec.primaryActions)',
    reason: 'Vertical drag clamp keeping the dial\'s edge margin.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'bottom: AppTheme.paddingS + AppTheme.paddingXS,',
    reads: 2,
    waitsFor: 'chrome.screen (ScreenSpec.primaryActions)',
    reason:
        'Row pitch between the dial\'s action rows; the skin owns the '
        'column once it draws the mini-FABs.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'elevation: AppTheme.elevationLevel2,',
    reads: 1,
    waitsFor: 'chrome.screen (ScreenSpec.primaryActions)',
    reason: 'Label pill elevation; the skin draws the label pills.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'AppTheme.paddingS + AppTheme.paddingXS,',
    reads: 2,
    waitsFor: 'chrome.screen (ScreenSpec.primaryActions)',
    reason: 'Label pill horizontal padding.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_speed_dial.dart',
    site: 'width: AppTheme.paddingS + AppTheme.paddingXS,',
    reads: 2,
    waitsFor: 'chrome.screen (ScreenSpec.primaryActions)',
    reason: 'Gap between a label pill and its mini-FAB.',
  ),

  // ── surfaces.codeLine (11 reads) ────────────────────────────────────────
  // The hand-painted diff/full-file line. CodeLineSpec carries oldNumber and
  // newNumber, so the gutter column width and its gap are the skin's numbers.
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_diff_viewer.dart',
    site: 'width: AppTheme.iconXL + AppTheme.paddingM + AppTheme.paddingXS,',
    reads: 9,
    waitsFor: 'surfaces.codeLine',
    reason:
        'The line-number gutter column width, three reads per gutter '
        '(old number, new number, full-file view). CodeLineSpec carries the '
        'numbers as data, so the column is the skin\'s to size.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_diff_viewer.dart',
    site: 'const SizedBox(width: AppTheme.paddingS + AppTheme.paddingXS),',
    reads: 2,
    waitsFor: 'surfaces.codeLine',
    reason: 'The gutter-to-content gap of the same hand-painted line.',
  ),

  // ── surfaces.badge (8 reads) ────────────────────────────────────────────
  // The hand-painted pill. BadgeSpec maps size to ControlScale and variant to
  // Tone; the per-size geometry below is what the member replaces. A Material
  // floor already exists (material_surfaces.dart:670).
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'horizontalPadding = AppTheme.paddingS;',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Per-size (small) horizontal padding of the hand-painted pill.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'horizontalPadding = AppTheme.paddingM;',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Per-size (medium) horizontal padding of the hand-painted pill.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'horizontalPadding = AppTheme.paddingL;',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Per-size (large) horizontal padding of the hand-painted pill.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'verticalPadding = AppTheme.paddingS;',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Per-size (large) vertical padding of the hand-painted pill.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'borderRadius = isPill ? 12 : AppTheme.radiusS;',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Per-size (small) corner of the hand-painted pill.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'borderRadius = isPill ? 16 : AppTheme.radiusS;',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Per-size (medium) corner of the hand-painted pill.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'borderRadius = isPill ? 20 : AppTheme.radiusM;',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Per-size (large) corner of the hand-painted pill.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'SizedBox(width: AppTheme.paddingS / 2),',
    reads: 1,
    waitsFor: 'surfaces.badge',
    reason: 'Icon-to-label gap inside the pill.',
  ),

  // ── surfaces.tag (2 reads) ──────────────────────────────────────────────
  // The deletable form of the pill; TagSpec (onRemoved, removeTooltip) owns
  // the delete affordance geometry.
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'AppTheme.paddingS / 2,',
    reads: 1,
    waitsFor: 'surfaces.tag',
    reason:
        'The delete-gap half-step inside the math.max that spaces the '
        'label from the delete affordance.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_badge.dart',
    site: 'radius: glyphSize / 2 + AppTheme.paddingXS,',
    reads: 1,
    waitsFor: 'surfaces.tag',
    reason:
        'The delete affordance\'s state-layer radius; the skin owns the '
        'delete geometry.',
  ),

  // ── layout.grid — GridSpec with onColumnsChanged (6 reads) ──────────────
  // GridSpec's own doc (layout_specs.dart:8-14) names this exact
  // construction: the screen re-implements the delegate's own formula.
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/repositories_screen.dart',
    site: '(_cardMaxCrossAxisExtent + AppTheme.paddingM))',
    reads: 1,
    waitsFor: 'layout.grid (GridSpec.onColumnsChanged)',
    reason:
        'The column-count formula the delegate already owns; GridSpec '
        'reports the count back instead of the screen re-deriving it.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/repositories_screen.dart',
    site: 'crossAxisSpacing: AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'layout.grid (GridSpec)',
    reason: 'Grid gutter; the grid member owns its gutters.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/repositories_screen.dart',
    site: 'mainAxisSpacing: AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'layout.grid (GridSpec)',
    reason: 'Grid gutter; the grid member owns its gutters.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/workspaces/workspaces_screen.dart',
    site: '(_cardMaxCrossAxisExtent + AppTheme.paddingL))',
    reads: 1,
    waitsFor: 'layout.grid (GridSpec.onColumnsChanged)',
    reason:
        'Same column-count formula as the repositories screen, with the '
        'wider gutter.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/workspaces/workspaces_screen.dart',
    site: 'crossAxisSpacing: AppTheme.paddingL,',
    reads: 1,
    waitsFor: 'layout.grid (GridSpec)',
    reason: 'Grid gutter; the grid member owns its gutters.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/workspaces/workspaces_screen.dart',
    site: 'mainAxisSpacing: AppTheme.paddingL,',
    reads: 1,
    waitsFor: 'layout.grid (GridSpec)',
    reason: 'Grid gutter; the grid member owns its gutters.',
  ),
  // ── surfaces.tree (5 reads) ─────────────────────────────────────────────
  // The tree owns per-depth indent, row height and (via TreeNodeSpec.menu)
  // its own row-action anchor.
  TokenReadRegisterEntry(
    file: 'lib/features/history/widgets/file_tree_panel.dart',
    site: 'left: depth * AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'surfaces.tree',
    reason: 'Per-depth indent; the tree member owns the rung.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/history/widgets/file_tree_panel.dart',
    site: 'minWidth: AppTheme.paddingL,',
    reads: 1,
    waitsFor: 'surfaces.tree',
    reason:
        'Shrunk row-action PopupMenuButton constraint; TreeNodeSpec.menu '
        'replaces the hand-built anchor.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/history/widgets/file_tree_panel.dart',
    site: 'minHeight: AppTheme.paddingL,',
    reads: 1,
    waitsFor: 'surfaces.tree',
    reason:
        'Shrunk row-action PopupMenuButton constraint; TreeNodeSpec.menu '
        'replaces the hand-built anchor.',
  ),
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

  // ── controls.suggestField (3 reads) ─────────────────────────────────────
  // Both hand-built searchable dropdowns; "a different canonical widget
  // class in every language" (skin_controls.dart:40-48).
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_dropdown.dart',
    site: 'elevation: AppTheme.elevationLevel2,',
    reads: 1,
    waitsFor: 'controls.suggestField',
    reason:
        'Overlay elevation of the hand-built searchable dropdown '
        '(SearchableBaseDropdown).',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_dropdown.dart',
    site: 'vertical: AppTheme.paddingS + 4,',
    reads: 1,
    waitsFor: 'controls.suggestField',
    reason:
        'Field box vertical padding of the hand-built searchable '
        'dropdown.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/shared/widgets/searchable_dropdown.dart',
    site: 'elevation: AppTheme.elevationLevel2,',
    reads: 1,
    waitsFor: 'controls.suggestField',
    reason: 'Overlay elevation of the second hand-built searchable dropdown.',
  ),

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

  // ── surfaces.commitGraphRow (2 reads) ───────────────────────────────────
  // The contract names these constants as moving into the skin verbatim
  // (SKIN-CONTRACT.md §5.4).
  TokenReadRegisterEntry(
    file: 'lib/features/history/widgets/commit_graph_painter.dart',
    site: 'static const double _dividerStrip = AppTheme.paddingS + 1.0;',
    reads: 1,
    waitsFor: 'surfaces.commitGraphRow',
    reason:
        'The divider strip constant the contract moves into the skin '
        'verbatim.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/history/widgets/commit_graph_painter.dart',
    site: 'AppTheme.paddingL +',
    reads: 1,
    waitsFor: 'surfaces.commitGraphRow',
    reason:
        'The lane x-origin (paddingL + laneWidth * lane) the contract '
        'moves into the skin verbatim.',
  ),

  // ── controls.seriesPicker (2 reads) ─────────────────────────────────────
  // The workspace-colour swatch grid; after Tone.series the application
  // cannot even enumerate the palette (control_specs.dart:534-541).
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/dialogs/project_dialog.dart',
    site: 'width: AppTheme.iconXL * 2,',
    reads: 1,
    waitsFor: 'controls.seriesPicker',
    reason: 'Swatch square width; the picker owns swatch geometry.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/repositories/dialogs/project_dialog.dart',
    site: 'height: AppTheme.iconXL * 2,',
    reads: 1,
    waitsFor: 'controls.seriesPicker',
    reason: 'Swatch square height; the picker owns swatch geometry.',
  ),

  // ── surfaces.disclosure (2 reads) ───────────────────────────────────────
  // The command-log entry is a named floor of this member
  // (SKIN-CONTRACT-MEMBERS.md:396,418); the outcome mark becomes
  // DisclosureSpec.leading, so the hanging-indent measurement dies.
  TokenReadRegisterEntry(
    file: 'lib/shared/widgets/command_log_panel.dart',
    site: 'left: AppTheme.paddingM + AppTheme.paddingS,',
    reads: 2,
    waitsFor: 'surfaces.disclosure',
    reason:
        'Meta-row hanging indent aligning under the headline past the '
        'outcome mark; DisclosureSpec.leading absorbs the mark and the '
        'measurement with it.',
  ),

  // ── surfaces.dataGrid (2 reads) ─────────────────────────────────────────
  TokenReadRegisterEntry(
    file: 'lib/features/browse/widgets/viewers/csv_viewer_dialog.dart',
    site: 'columnSpacing: AppTheme.paddingL,',
    reads: 1,
    waitsFor: 'surfaces.dataGrid',
    reason:
        'The CSV viewer\'s DataTable column spacing; the grid member '
        'owns table metrics.',
  ),
  TokenReadRegisterEntry(
    file: 'lib/features/browse/widgets/viewers/csv_viewer_dialog.dart',
    site: 'horizontalMargin: AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'surfaces.dataGrid',
    reason:
        'The CSV viewer\'s DataTable horizontal margin; the grid member '
        'owns table metrics.',
  ),

  // ── controls.progress — ProgressExtent.block (1 read) ───────────────────
  TokenReadRegisterEntry(
    file:
        'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart',
    site: 'minHeight: AppTheme.paddingS,',
    reads: 1,
    waitsFor: 'controls.progress (ProgressExtent.block)',
    reason:
        'Bar thickness; the member takes fraction + extent and the '
        'thickness is the skin\'s.',
  ),

  // ── overlays.presentMenu (1 read) ───────────────────────────────────────
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_animated_widgets.dart',
    site: 'iconSize: iconSize ?? AppTheme.iconM,',
    reads: 1,
    waitsFor: 'overlays.presentMenu',
    reason:
        'The anchor glyph\'s fallback size in BasePopupMenuButton; the '
        'skin builds its own menu anchor from MenuEntry data, so the '
        'fallback goes with the construction. Not mechanical: deleting the '
        'fallback would change 20 to Material\'s 24.',
  ),

  // ── surfaces.listRow (1 read) ───────────────────────────────────────────
  TokenReadRegisterEntry(
    file: 'lib/shared/components/base_list_item.dart',
    site: 'start: AppTheme.paddingM,',
    reads: 1,
    waitsFor: 'surfaces.listRow',
    reason: 'Inset divider start; the tile is the P2 extraction floor.',
  ),

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
