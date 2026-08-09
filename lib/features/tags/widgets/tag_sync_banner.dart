import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show BannerSpec, IconRole, Inset, NoticeAction, Skin, SkinScope, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_layout.dart';

/// Banner widget showing tag sync status with local/remote repositories
class TagSyncBanner extends StatelessWidget {
  final int localOnlyCount;
  final int remoteOnlyCount;
  final VoidCallback onPushAll;
  final VoidCallback onFetchAll;

  const TagSyncBanner({
    super.key,
    required this.localOnlyCount,
    required this.remoteOnlyCount,
    required this.onPushAll,
    required this.onFetchAll,
  });

  @override
  Widget build(BuildContext context) {
    if (localOnlyCount == 0 && remoteOnlyCount == 0) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

    // **Something about this whole surface needs saying** - which is the
    // member this widget's own name has been claiming since it was written,
    // and it was drawing the claim by hand: a `primaryContainer` fill, an 8 dp
    // corner, an accent stroke washed to 30%, and a `DefaultTextStyle.merge`
    // spelling out the paired foreground its own fill demanded. All four are
    // the SURFACE, and all four are the skin's now. `Tone.info` - "this is
    // worth knowing and nothing is wrong", which is exactly what an unsynced
    // tag count is - resolves under Material to the same
    // `primaryContainer`/`onPrimaryContainer` pair this file spelled out, so
    // the pairing survives the move without the application naming either
    // half.
    //
    // The two counts become the banner's `body`, one per line, because they
    // are the longer form of the statement in its `title` rather than two
    // independent sentences.
    final List<String> lines = <String>[
      if (localOnlyCount > 0) l10n.tagsNotPushed(localOnlyCount),
      if (remoteOnlyCount > 0) l10n.tagsAvailableToFetch(remoteOnlyCount),
    ];

    // The banner's margin is the distance between the banner and the screen
    // around it - an inset owed by what CONTAINS the banner, not by the banner
    // itself - so it is stated as an inset around the whole surface rather
    // than as a fourth number inside it.
    return BaseInset(
      all: Inset.normal,
      child: SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.surfaces.banner(
          inner,
          BannerSpec(
            tone: Tone.info,
            title: l10n.syncStatus,
            body: lines.join('\n'),
            icon: IconRole.gitDiff,
            actions: <NoticeAction>[
              if (localOnlyCount > 0)
                NoticeAction(
                  label: l10n.pushAll,
                  tooltip: l10n.pushAll,
                  icon: IconRole.upload,
                  onPressed: onPushAll,
                ),
              if (remoteOnlyCount > 0)
                NoticeAction(
                  label: l10n.fetchAll,
                  tooltip: l10n.fetchAll,
                  icon: IconRole.downloadSimple,
                  onPressed: onFetchAll,
                ),
            ],
          ),
        );
      }),
    );
  }
}
