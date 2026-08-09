import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_badge.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/copyable_text.dart';
import '../../../core/git/models/commit.dart';

/// Panel showing detailed information about a commit
class CommitDetailsPanel extends StatefulWidget {
  final GitCommit commit;

  const CommitDetailsPanel({super.key, required this.commit});

  @override
  State<CommitDetailsPanel> createState() => _CommitDetailsPanelState();
}

class _CommitDetailsPanelState extends State<CommitDetailsPanel> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BasePanel(
      title: Row(
        children: [
          // A panel header's mark: dense, and carrying the application's own
          // colour rather than Material's `primary` slot.
          const BaseIcon(
            IconRole.info,
            scale: ControlScale.compact,
            tone: Tone.accent,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(l10n.commitDetails, role: TextRole.sectionTitle),
        ],
      ),
      actions: const [],
      content: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commit message (prominent).
              //
              // **Here is one self-contained object** - the commit's own
              // message, which is what this panel exists to show. The fill and
              // the corner were that card drawn by hand; `roomy` was already
              // stated here and is the rung the member defaults to, so the
              // breathing room does not move. What the member adds is the edge
              // this card never had: a card in this language carries a resting
              // outline, and the hand-painted copy had only a fill.
              SizedBox(
                width: double.infinity,
                child: BaseCard(
                  isSelectable: false,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const BaseIcon(
                            IconRole.chatText,
                            scale: ControlScale.compact,
                            tone: Tone.accent,
                          ),
                          const BaseGap(Proximity.related),
                          // The brand tint this header spelled out said
                          // nothing the header was not already saying by being a
                          // section title, so it goes rather than being renamed.
                          BaseLabel(
                            l10n.commitMessage,
                            role: TextRole.sectionTitle,
                          ),
                        ],
                      ),
                      const BaseGap(Proximity.grouped),
                      // The commit message is set one step ABOVE ordinary
                      // prose on purpose - it is what this panel is for - and
                      // no `TextRole` reaches that step: `body` lands on
                      // `bodyMedium` and there is no rung between it and
                      // `pageTitle`. Saying `body` here would shrink the
                      // panel's own subject by two points, which is the trade
                      // #426 was a fix commit for, so the ramp step stays until
                      // the role exists.
                      //
                      // The colour that sat beside it is gone, and no pixel
                      // moved (#432): `AppTheme._brightnessCorrectedTextTheme`
                      // applies the scheme's `onSurface` to every step of the
                      // scale, so naming it here restated what `bodyLarge`
                      // already carries. It never needed a `Tone` either -
                      // `Tone.neutral` IS "whatever this surface's ordinary
                      // foreground is", and saying nothing is how a style says
                      // that.
                      SelectableText(
                        widget.commit.message,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),

              const BaseGap(Proximity.grouped),

              // Expandable details section.
              //
              // **This is `surfaces.disclosure` and it cannot go yet**, and
              // the blocker is in the member's Material implementation rather
              // than in `DisclosureSpec`, which says everything this site
              // needs. `MaterialSurfaces.disclosure` reveals with an
              // `AnimatedCrossFade`, and that widget keeps the collapsed body
              // MOUNTED - it only stops PAINTING it. For a settings section,
              // whose body is a handful of rows, nobody noticed. For this
              // panel the body is the whole details card, and mounting it
              // while closed costs two things that are not this screen's to
              // absorb: thirty-two widgets built on every rebuild of a
              // collapsed section, and a count the scene sweep can no longer
              // state in one number, because the blueprint skin mounts its
              // body only while expanded (`if (spec.expanded)`) and Material
              // does not - 119 against 87 for the same screen at the same
              // distance, which `kContractRenderedUnderBlueprint` can only
              // express for a STRETCHED run.
              //
              // M3's own canonical widget already does the right thing:
              // `ExpansionTile` drops its children when closed
              // (`shouldRemoveChildren`, expansion_tile.dart). The member
              // should follow the canon it already claims to follow, and when
              // it does this construction becomes one call with no corner in
              // it - the header box, its stroke, the caret the screen swaps by
              // hand and the Show/Hide word beside it (two affordances for one
              // job, which this repository's own rules forbid) all leave
              // together. Reported rather than converted, because converting
              // it first would leave a shared register with no number that
              // makes both skins agree.
              //
              // The FOCUS of a collapsed body was never part of the defect:
              // `AnimatedCrossFade` excludes the hidden child's focus by
              // default (`excludeBottomFocus` defaults to true), so a closed
              // section's buttons were never Tab-reachable. Only the
              // mounted-widgets cost above stands.
              InkWell(
                onTap: () {
                  setState(() {
                    _showDetails = !_showDetails;
                  });
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: BaseInset(
                    child: Row(
                      children: [
                        // The disclosure mark is a row-level one, and secondary
                        // to the words beside it.
                        BaseIcon(
                          _showDetails
                              ? IconRole.caretDown
                              : IconRole.caretRight,
                          scale: ControlScale.compact,
                          tone: Tone.muted,
                        ),
                        const BaseGap(Proximity.related),
                        BaseLabel(l10n.additionalDetails, role: TextRole.body),
                        const Spacer(),
                        BaseLabel(
                          _showDetails ? l10n.hide : l10n.show,
                          role: TextRole.detail,
                          tone: Tone.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Details content (expandable)
              if (_showDetails) ...[
                const BaseGap(Proximity.grouped),
                // **Here is one self-contained object** again: everything git
                // records about this commit besides its message. The same
                // hand-painted card as the message above it, down to the fill
                // and the corner, so it becomes the same member and the two
                // cannot round differently again.
                SizedBox(
                  width: double.infinity,
                  child: BaseCard(
                    isSelectable: false,
                    inset: Inset.normal,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author info
                        _buildSection(
                          context,
                          l10n.authorLabel,
                          IconRole.user,
                          child: Column(
                            children: [
                              _buildInfoRow(l10n.name, widget.commit.author),
                              _buildInfoRow(
                                l10n.email,
                                widget.commit.authorEmail,
                              ),
                              _buildInfoRow(
                                l10n.date,
                                widget.commit.authorDateDisplay(
                                  Localizations.localeOf(context).languageCode,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const BaseGap(Proximity.grouped),

                        // Committer info (if different from author)
                        if (widget.commit.committer != widget.commit.author ||
                            widget.commit.committerEmail !=
                                widget.commit.authorEmail) ...[
                          _buildSection(
                            context,
                            l10n.committerLabel,
                            IconRole.userCircle,
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  l10n.name,
                                  widget.commit.committer,
                                ),
                                _buildInfoRow(
                                  l10n.email,
                                  widget.commit.committerEmail,
                                ),
                                _buildInfoRow(
                                  l10n.date,
                                  widget.commit.committerDateDisplay(
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const BaseGap(Proximity.grouped),
                        ],

                        // Commit hash
                        _buildSection(
                          context,
                          l10n.hash,
                          IconRole.hash,
                          child: CopyableText(
                            text: widget.commit.hash,
                            icon: IconRole.gitCommit,
                          ),
                        ),

                        // Parents
                        if (widget.commit.parents.isNotEmpty) ...[
                          const BaseGap(Proximity.grouped),
                          _buildSection(
                            context,
                            widget.commit.parents.length > 1
                                ? l10n.parents
                                : l10n.parent,
                            widget.commit.isMergeCommit
                                ? IconRole.gitMerge
                                : IconRole.gitCommit,
                            child: Column(
                              children: widget.commit.parents.map((parent) {
                                return Padding(
                                  // Left as a literal on purpose. The space
                                  // belongs BELOW each parent, the last one
                                  // included, so it is a trailing margin a
                                  // child owns rather than a gap between two
                                  // named neighbours - and the composition the
                                  // vocabulary prescribes for a per-side
                                  // padding drops the trailing one. Reported
                                  // rather than rounded onto a rung.
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: CopyableText(
                                    text: parent,
                                    icon: IconRole.gitCommit,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        // Refs (branches, tags)
                        if (widget.commit.refs.isNotEmpty) ...[
                          const BaseGap(Proximity.grouped),
                          _buildSection(
                            context,
                            l10n.references,
                            IconRole.gitBranch,
                            // Which branches and tags point at this commit.
                            // Each is a named mark riding on the card - the
                            // badge member's own question - and the commit LIST
                            // one screen over already asks it exactly this way
                            // (`commit_list_item.dart`, the same
                            // `ref.contains('tag:')` split into the same two
                            // roles at the same small scale). One fact was
                            // being drawn in two treatments: the list's
                            // member-drawn neutral chip, and this
                            // hand-painted `secondaryContainer` /
                            // `tertiaryContainer` box with a 30 % hairline, a
                            // 12 dp corner, an 8/4 inset, an explicit 12 px
                            // glyph and the on-container foreground spelled out
                            // twice. Nothing here could ever see the mismatch,
                            // because a drawn copy has no way to ask what the
                            // member rounds at.
                            //
                            // **Tag-versus-branch survives as the GLYPH, and
                            // loses the tint.** The pill said that one fact
                            // twice - a tag mark AND a tertiary wash - and only
                            // the wash is unsayable: no `Tone` means "this ref
                            // is a tag", because a container role is Material's
                            // containment model rather than a meaning three
                            // languages carry. The mark says it in all three,
                            // which is how the commit list has always said it.
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: widget.commit.refs
                                  .map(
                                    (ref) => BaseBadge(
                                      label: ref,
                                      icon: ref.contains('tag:')
                                          ? IconRole.tag
                                          : IconRole.gitBranch,
                                      size: BadgeSize.small,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconRole icon, {
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // A section's mark, at the one scale a dense header mark takes.
            // It was 14 here and 16 in the header above it, for the same job.
            BaseIcon(icon, scale: ControlScale.compact, tone: Tone.accent),
            const BaseGap(Proximity.related),
            BaseLabel(
              title,
              role: TextRole.sectionTitle,
              // "This is the configured, resolved value" - the meaning the
              // brand colour was standing in for beside its red-when-unset
              // siblings.
              tone: Tone.accent,
            ),
          ],
        ),
        const BaseGap(Proximity.related),
        child,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      // The same trailing margin as the parent list above, and left for the
      // same reason: the row owns the space under itself, which no rung of
      // either distance vocabulary can be owned by one child.
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: BaseLabel(label, role: TextRole.detail, tone: Tone.muted),
          ),
          const BaseGap(Proximity.grouped),
          Expanded(
            // The value beside its label: supporting detail the user copies
            // out, which is `detail` said selectably rather than a ramp step
            // plus a colour. The colour it spelled out was this surface's own
            // ordinary foreground, which is what `Tone.neutral` means and what
            // the label inherits by saying nothing.
            child: BaseLabel(value, role: TextRole.detail, selectable: true),
          ),
        ],
      ),
    );
  }
}
