import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import '../../shared/components/base_badge.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_viewer_dialog.dart';
import '../../shared/utils/keyboard_guards.dart';
import '../../core/models/changelog_release.dart';
import '../../core/services/changelog_service.dart';
import '../../core/services/version_service.dart';
import '../../core/services/logger_service.dart';
import '../../shared/components/base_layout.dart';
import '../../shared/widgets/empty_state.dart';

class ChangelogDialog extends HookConsumerWidget {
  final int initialIndex;

  const ChangelogDialog({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changelogAsync = ref.watch(changelogDataProvider);
    final currentIndex = useState(initialIndex);
    final dontShowAgain = useState(false);
    final touched = useState(false); // User toggled the checkbox themselves
    final versionService = ref.watch(versionServiceProvider);

    // Initialize the checkbox from the persisted setting. The load is async,
    // so adopt the stored value only while the user has not touched the
    // checkbox yet, and never after the dialog was dismissed.
    useEffect(() {
      versionService.isWhatsNewDialogDisabled().then((isDisabled) {
        if (!context.mounted) return;
        if (!touched.value) dontShowAgain.value = isDisabled;
      });
      return null;
    }, []);

    // Persisting on toggle (instead of on close) makes every close path -
    // Esc, Enter, the X, the barrier and the Close button - equally safe:
    // there is no pending state a dismissal could lose.
    Future<void> setDontShowAgain(bool value) async {
      touched.value = true;
      dontShowAgain.value = value;
      if (value) {
        await versionService.disableWhatsNewDialog();
      } else {
        await versionService.enableWhatsNewDialog();
      }
    }

    final releases =
        changelogAsync.value?.releases ?? const <ChangelogRelease>[];
    final index = releases.isEmpty
        ? 0
        : currentIndex.value.clamp(0, releases.length - 1);
    final hasOlder = index < releases.length - 1;
    final hasNewer = index > 0;

    // The version pager is this dialog's list; the arrow keys drive it. A
    // raw CallbackShortcuts used to sit here and fired unconditionally, so
    // paging shadowed the selection caret of the selectable release body -
    // exactly the drift avoid_raw_shortcuts now bans (#382). The handler
    // follows the shared keyboard contract instead: it yields every key a
    // focused editable interprets (focusedEditableOwnsKey - the selectable
    // markdown is an editable in the guard's sense), leaves modified chords
    // to the shell, and only then pages.
    KeyEventResult handlePagerKey(FocusNode node, KeyEvent event) {
      if (event is KeyUpEvent) return KeyEventResult.ignored;
      if (focusedEditableOwnsKey(event)) return KeyEventResult.ignored;
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed ||
          keyboard.isAltPressed ||
          keyboard.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (hasOlder) currentIndex.value = index + 1;
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (hasNewer) currentIndex.value = index - 1;
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Mirrors what CallbackShortcuts builds internally: a non-focusable,
    // traversal-invisible node that only observes keys bubbling up from the
    // dialog - never a Tab stop, never a focus claim.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: handlePagerKey,
      child: BaseViewerDialog(
        icon: IconRole.clockCounterClockwise,
        title: 'Release History',
        widthFactor: 0.75,
        heightFactor: 0.85,
        // Reading is this dialog's only job, so closing is its primary
        // action: Enter, Esc and the X all do the same thing.
        onSubmit: () => Navigator.of(context).pop(),
        content: changelogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // The twin of the "no release history" pane below, and no longer the
          // one shape the facade could not take. This pane was hand-rolled for
          // a single reason - its hero is RED and `EmptyStateWidget` painted
          // every hero in the supporting foreground - and the hero carries a
          // tone now (#431), so `Tone.danger` says the whole difference
          // between "there is nothing here" and "this could not be read" as a
          // meaning rather than as a colour this dialog picked. The glyph and
          // its 64 px survive the move unchanged: the member draws the
          // `IconData` it is handed at the one hero size it owns (#430). The
          // gaps and the sentence's treatment become the member's, exactly as
          // in `ReflogDialog._buildError` - a member that owns a composition
          // owns its rhythm too.
          error: (error, stack) => EmptyStateWidget(
            icon: Icons.error_outline,
            title: 'Failed to load changelog',
            message: error.toString(),
            tone: Tone.danger,
          ),
          data: (changelogData) {
            if (changelogData.releases.isEmpty) {
              // The facade, not a copy of it (#430): a mark, a headline and
              // no size written here. Its hero already drew the muted mark
              // this pane drew, so adopting `surfaces.emptyState`'s stand-in
              // costs nothing and takes the 64 px with it - a member that
              // accepts no size owns the size. There is no sentence under the
              // headline, which `ErrorState` in the same file already spells
              // as an empty message.
              return const EmptyStateWidget(
                icon: Icons.history,
                title: 'No release history available',
                message: '',
              );
            }

            final release = changelogData.releases[index];

            return Column(
              children: [
                // Version header
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                  child: BaseInset(
                    all: Inset.normal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Stays a raw `Icon`, and the colour stays with
                            // it. The mark MEANS `Tone.accent` and 20 px is
                            // exactly `ControlScale.normal`, but a tone only
                            // reaches a mark through `BaseIcon`, and `BaseIcon`
                            // takes an `IconRole` - which would swap Material's
                            // `new_releases` badge for this skin's Phosphor
                            // glyph. No role means "this is release N" either:
                            // `IconRole.updateAvailable` means "a new version
                            // is waiting to be installed", which is a different
                            // sentence and a solid download arrow. Changing the
                            // mark is the one thing this phase promises cannot
                            // happen, so the meaning is reported rather than
                            // rounded onto the nearest available word.
                            Icon(
                              Icons.new_releases,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const BaseGap(Proximity.related),
                            BaseLabel(
                              'Version ${release.version}',
                              role: TextRole.pageTitle,
                            ),
                            // **A named thing riding on the heading beside
                            // it**, which is the badge member, and this site
                            // already said the migration would take it: the
                            // solid accent was a FILL the application picked,
                            // and `Tone.onAccent` was the other half of that
                            // pairing, kept only because the screen had
                            // painted the first half. Both leave together with
                            // the 12 dp corner, and what remains is the one
                            // fact the application owns - this release is the
                            // newest one.
                            if (index == 0) ...[
                              const BaseGap(Proximity.related),
                              const BaseBadge(
                                label: 'LATEST',
                                variant: BadgeVariant.primary,
                                size: BadgeSize.small,
                              ),
                            ],
                          ],
                        ),
                        const BaseGap(Proximity.related),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Both marks in this row stay raw, and their
                            // colour stays with them. They mean `Tone.muted`,
                            // but 14 px is not a rung: `ControlScale`'s
                            // densest is 16, and taking it would grow every
                            // mark in this header by two pixels - the exact
                            // shape of the rounding that cost #426. The glyphs
                            // are Material's rather than this skin's too, so
                            // `BaseIcon` would change the mark as well as its
                            // measure.
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const BaseGap(Proximity.hairline),
                            BaseLabel(
                              _formatDate(release.date),
                              role: TextRole.detail,
                              tone: Tone.muted,
                            ),
                            const BaseGap(Proximity.grouped),
                            Icon(
                              Icons.commit,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const BaseGap(Proximity.hairline),
                            BaseLabel(
                              release.commit,
                              role: TextRole.detail,
                              tone: Tone.muted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Changelog content
                Expanded(
                  // A scroll view's padding is the inset its content owes
                  // the viewport's edge and scrolls with it, so it is stated
                  // as an inset around the content.
                  child: SingleChildScrollView(
                    child: BaseInset(
                      all: Inset.roomy,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: MarkdownBody(
                          data: release.changelog,
                          selectable: true,
                          // `MarkdownStyleSheet` takes `TextStyle`s, so a role
                          // and a tone cannot be handed to it; the ramp steps
                          // stay written out until a member owns rendered
                          // markdown. What is gone is the colour: each of these
                          // three steps used to re-state `onSurface` on top of
                          // the step it was copying, and every step of this
                          // scale already carries the scheme's `onSurface`
                          // (`AppTheme._brightnessCorrectedTextTheme`). Saying
                          // nothing is what `Tone.neutral` means and is how the
                          // skin itself says it - `MaterialType.text` leaves
                          // the colour OUT of a neutral style rather than
                          // stamping it back in.
                          styleSheet: MarkdownStyleSheet(
                            h3: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 2,
                                ),
                            p: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.6),
                            listBullet: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        footer: releases.isEmpty
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: BaseInset(
                  all: Inset.normal,
                  child: Row(
                    children: [
                      // "Don't show again" checkbox (left side)
                      Expanded(
                        child: Row(
                          children: [
                            Checkbox(
                              value: dontShowAgain.value,
                              onChanged: (value) =>
                                  setDontShowAgain(value ?? false),
                            ),
                            const BaseGap(Proximity.related),
                            Flexible(
                              child: BaseLabel(
                                "Don't show on startup",
                                role: TextRole.detail,
                                tone: Tone.muted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Navigation controls (center)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BaseIconButton(
                            onPressed: hasOlder
                                ? () => currentIndex.value = releases.length - 1
                                : null,
                            icon: IconRole.caretLineLeft,
                            tooltip: 'Oldest version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.related),
                          BaseIconButton(
                            onPressed: hasOlder
                                ? () => currentIndex.value = index + 1
                                : null,
                            icon: IconRole.caretLeft,
                            tooltip: 'Older version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.grouped),
                          // **How many, riding on something else** — which is
                          // exactly `surfaces.badge`, and the same façade the
                          // "LATEST" mark in this dialog's own header has been
                          // going through all along. Two pills in one dialog,
                          // one drawn by the member and one hand-painted at a
                          // different measure, is the disagreement the last
                          // pass found three times over; this is the fourth.
                          //
                          // The fill and the foreground leave together, and
                          // that pairing is the reason: a solid
                          // `primaryContainer` forced the site to name
                          // `onPrimaryContainer` beside it, so the pill was
                          // stating both halves of a Material pairing the
                          // application has no business knowing. `accent` is
                          // the whole of what it means.
                          //
                          // The pill moves, and by more than the fill: solid
                          // `primaryContainer` becomes the badge's 15 % wash
                          // of `primary`, the `body` words in
                          // `onPrimaryContainer` become the badge's 12 sp
                          // `w600` in `primary`, the vertical inset falls
                          // 6 -> 4 so the pill sits ~4 dp shorter, and the
                          // 16 dp corner becomes the pill's own half-height.
                          // Every one of those numbers is the measure the
                          // "LATEST" badge above has worn all along - two
                          // pills of one kind in one dialog at two measures
                          // was the drift, and the member's measure is the
                          // one the human-verified baseline already shows.
                          BaseBadge(
                            label: '${index + 1} of ${releases.length}',
                            variant: BadgeVariant.primary,
                          ),
                          const BaseGap(Proximity.grouped),
                          BaseIconButton(
                            onPressed: hasNewer
                                ? () => currentIndex.value = index - 1
                                : null,
                            icon: IconRole.caretRight,
                            tooltip: 'Newer version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.related),
                          BaseIconButton(
                            onPressed: hasNewer
                                ? () => currentIndex.value = 0
                                : null,
                            icon: IconRole.caretLineRight,
                            tooltip: 'Latest version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.separate),
                          BaseButton(
                            label: 'Close',
                            variant: ButtonVariant.primary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMMM d, yyyy').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  /// Show the changelog dialog
  static Future<void> show(BuildContext context, {int initialIndex = 0}) async {
    // Dismissable from every path: the checkbox persists on toggle, so a
    // barrier click or Esc cannot lose anything.
    await showDialog(
      context: context,
      builder: (_) => ChangelogDialog(initialIndex: initialIndex),
    );
  }

  /// Show the "What's New" dialog if needed (version upgrade)
  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final versionService = ref.read(versionServiceProvider);

    // Get current state for logging
    final currentVersion = await versionService.getCurrentVersion();
    final lastSeenVersion = await versionService.getLastSeenVersion();
    final isDisabled = await versionService.isWhatsNewDialogDisabled();

    Logger.info('[ChangelogDialog] showIfNeeded called');
    Logger.info('[ChangelogDialog] Current version: $currentVersion');
    Logger.info('[ChangelogDialog] Last seen version: $lastSeenVersion');
    Logger.info('[ChangelogDialog] Dialog disabled: $isDisabled');

    final shouldShow = await versionService.shouldShowWhatsNew();
    Logger.info('[ChangelogDialog] shouldShowWhatsNew result: $shouldShow');

    if (!shouldShow || !context.mounted) {
      Logger.info(
        '[ChangelogDialog] Not showing - shouldShow: $shouldShow, mounted: ${context.mounted}',
      );
      return;
    }

    final changelogData = await ref.read(changelogDataProvider.future);
    final latestRelease = changelogData.releases.firstOrNull;

    Logger.info('[ChangelogDialog] Latest release: ${latestRelease?.version}');

    if (latestRelease == null || !context.mounted) {
      Logger.info('[ChangelogDialog] Not showing - no release or not mounted');
      return;
    }

    // Release builds regenerate assets/changelog.json in CI before packing
    // (tools/changelog/generate_changelog.dart), so on an installed release
    // both versions match and the dialog shows. A source build still runs
    // against the checked-in seed asset, and announcing its entry as LATEST
    // would describe a release this build is not - the guard stays for that.
    if (latestRelease.version != currentVersion.split('+').first) {
      Logger.info(
        '[ChangelogDialog] Not showing - changelog latest ${latestRelease.version} does not match app $currentVersion',
      );
      return;
    }

    // Compare without the build number so this matches shouldShowWhatsNew, which
    // treats "0.1.0+1" and "0.1.0+2" as the same version.
    final isVersionUpgrade =
        lastSeenVersion == null ||
        lastSeenVersion.split('+').first != currentVersion.split('+').first;
    Logger.info('[ChangelogDialog] Is version upgrade: $isVersionUpgrade');

    // Show dialog with latest release
    Logger.info('[ChangelogDialog] Showing dialog now');
    await showDialog(
      context: context,
      builder: (_) => const ChangelogDialog(initialIndex: 0),
    );

    // Only mark version as seen after version upgrades (first run or update)
    // For normal runs, we DON'T mark it as seen so it shows every time
    // (unless user disables it via "Don't show again")
    if (isVersionUpgrade) {
      Logger.info(
        '[ChangelogDialog] Version upgrade detected - marking version as seen',
      );
      // Record the app's own version, not the changelog entry's: the bundled
      // changelog can lag behind the app, and disableWhatsNewDialog() stores
      // currentVersion - writing anything else here would revert that preference.
      await versionService.markVersionAsSeen(currentVersion);
      Logger.info('[ChangelogDialog] Version marked as seen: $currentVersion');
    } else {
      Logger.info('[ChangelogDialog] Normal run - NOT marking version as seen');
    }

    Logger.info('[ChangelogDialog] showIfNeeded completed');
  }
}
