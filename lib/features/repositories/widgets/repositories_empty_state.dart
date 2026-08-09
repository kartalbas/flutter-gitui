import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ContentPort, Proximity, Skin, SkinScope, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty state for repositories screen
class RepositoriesEmptyState extends StatelessWidget {
  final VoidCallback onOpenRepository;
  final VoidCallback onCloneRepository;
  final VoidCallback onInitRepository;

  const RepositoriesEmptyState({
    super.key,
    required this.onOpenRepository,
    required this.onCloneRepository,
    required this.onInitRepository,
  });

  @override
  Widget build(BuildContext context) {
    // The hand-rolled Column of {64 px glyph, headline, explanation, ways
    // out} is gone (#430). `EmptyStateSpec` takes icon/title/message and NO
    // size, so a glyph size written here would be a leak by construction -
    // the member that accepts no size is the one that owns it. The gaps this
    // Column spelled out are the same rungs the facade already uses at those
    // two boundaries (`separate` around the mark and around the actions,
    // `related` between headline and explanation), so nothing about the
    // rhythm is being re-decided here; it is being stopped from being said
    // twice. The mark's colour goes with its size: this state painted its
    // glyph in Material's accent role, and the member draws every empty
    // state's mark in the supporting foreground instead.
    //
    // The three ways out travel through the legacy `action` slot rather than
    // `EmptyStateAction`, and that is deliberate: `EmptyStateAction` is a
    // BUTTON - a label, a mark and a callback stacked vertically - while
    // these are three cards that also carry a sentence of explanation each
    // and lay out across. Folding them into buttons would throw the
    // descriptions away, which is a redesign and not a conversion. They stay
    // whole here until `surfaces.emptyState` grows a way to say "several
    // described choices".
    return EmptyStateWidget(
      icon: PhosphorIconsBold.gitBranch,
      title: AppLocalizations.of(context)!.noRepositoriesYet,
      message: AppLocalizations.of(context)!.addRepositoryToGetStarted,
      // The three choices are one run of equals that breaks onto a second line
      // when the state is narrower than they are, which is exactly what
      // `layout.row(wrap: true)` says. The two 16s that stood here said it as
      // Material's number twice - between two cards and between two lines of
      // them - and the member answers both with the one rung. Stated `start`
      // because that is what the bare `Wrap` did: three cards of unequal height
      // hang from the top of their line, and centring them would move them.
      action: SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.layout.row(
          inner,
          [
            ContentPort(
              _ActionCard(
                icon: PhosphorIconsRegular.folderOpen,
                title: AppLocalizations.of(context)!.openRepository,
                description: AppLocalizations.of(
                  context,
                )!.browseExistingRepository,
                onTap: onOpenRepository,
              ),
            ),
            ContentPort(
              _ActionCard(
                icon: PhosphorIconsRegular.downloadSimple,
                title: AppLocalizations.of(context)!.cloneRepository,
                description: AppLocalizations.of(context)!.cloneFromRemoteUrl,
                onTap: onCloneRepository,
              ),
            ),
            ContentPort(
              _ActionCard(
                icon: PhosphorIconsRegular.plus,
                title: AppLocalizations.of(context)!.initializeRepository,
                description: AppLocalizations.of(
                  context,
                )!.createNewGitRepository,
                onTap: onInitRepository,
              ),
            ),
          ],
          gap: Proximity.grouped,
          cross: CrossAxisAlignment.start,
          wrap: true,
        );
      }),
    );
  }
}

/// Action card for quick actions
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: BaseCard(
        onTap: onTap,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Deliberately NOT converted, and the size is the reason. This is
            // a 48 px hero inside a quick-action card, and `ControlScale`'s
            // three rungs are 16 / 20 / 24: naming `prominent` here would
            // halve the mark, which is a different card and not a different
            // spelling of this one. It is not the empty state's own mark
            // either - `EmptyStateWidget` above draws exactly one of those,
            // and these are the three choices UNDER it - so the member that
            // owns a size has no slot for this. Because the size cannot move,
            // the accent cannot either: a `Tone` needs a `BaseIcon` to be
            // said through, and a `BaseIcon` cannot be told 48. Both leave
            // together when the card becomes a surface member.
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const BaseGap(Proximity.grouped),
            BaseLabel(title, role: TextRole.pageTitle, align: TextAlign.center),
            const BaseGap(Proximity.related),
            BaseLabel(
              description,
              role: TextRole.detail,
              align: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
