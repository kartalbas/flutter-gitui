import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ContentPort, IconRole, Proximity, Skin, SkinScope, TextRole;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../shared/components/base_badge.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/components/base_label.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/services/version_service.dart';
import '../../core/services/build_info.dart';
import '../../shared/components/base_layout.dart';

class AppAboutDialog extends HookConsumerWidget {
  const AppAboutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionService = ref.watch(versionServiceProvider);
    final version = useState<String>('...');

    useEffect(() {
      versionService.getCurrentVersion().then((v) {
        // The dialog can be closed before the version resolves; the hook
        // notifier is disposed with it and must not be written afterwards
        if (context.mounted) version.value = v;
      });
      return null;
    }, []);

    return BaseDialog(
      title: 'About Flutter GitUI',
      icon: IconRole.info,
      variant: DialogVariant.normal,
      onSubmit: () => Navigator.of(context).pop(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App icon and name
            Center(
              child: Column(
                children: [
                  // The plate is NOT converted, and the corner stays with it —
                  // reported rather than rounded. `surfaces.avatar` is the
                  // member this shape would otherwise be ("which person or
                  // thing is this, as a single compact mark", a fill, a shape
                  // and one glyph), and it cannot take this one: its only size
                  // vocabulary is `ControlScale`, whose three rungs are
                  // CONTROL sizes — Material draws them at 24, 40 and 40 dp —
                  // and this is an 80 dp hero holding a 48 dp mark. Naming
                  // `prominent` would halve the whole plate, which is the
                  // rounding rule this repository refuses. The skin already
                  // meets the same problem inside `surfaces.emptyState` and
                  // answers it privately, by deriving that member's 64 dp hero
                  // from twice its largest icon rung rather than exposing a
                  // fourth rung nobody could promise.
                  //
                  // Worth measuring when it does move: the mark is `primary`
                  // painted on `primaryContainer`, which is not the pairing
                  // the scheme names for that fill (`onPrimaryContainer` is).
                  // The member resolves both halves from one tone, so the
                  // pairing is settled by the conversion rather than by a
                  // colour changed here by hand.
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    ),
                    // The application's own mark, and it stays a raw `Icon`
                    // with its colour on it. The meaning is `Tone.accent`, but
                    // a tone only reaches a mark through `BaseIcon`, and
                    // `BaseIcon` draws at one of three `ControlScale` rungs
                    // whose largest is 24 - naming the nearest one would halve
                    // this 48 px hero, which is rounding a meaning onto the
                    // nearest available word. `BaseIcon` would also swap
                    // Material's glyph for this skin's Phosphor one. The size
                    // and the colour are one decision and leave together, with
                    // the branded hero, when a member owns it.
                    child: Icon(
                      Icons.commit,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const BaseGap(Proximity.grouped),
                  BaseLabel('Flutter GitUI', role: TextRole.pageTitle),
                  const BaseGap(Proximity.hairline),
                  BaseLabel('Version ${version.value}', role: TextRole.detail),
                  const BaseGap(Proximity.hairline),
                  BaseLabel(
                    'Build: ${BuildInfo.displayCommit}',
                    role: TextRole.detail,
                    align: TextAlign.center,
                  ),
                  if (BuildInfo.displayDate.isNotEmpty) ...[
                    const BaseGap(Proximity.hairline),
                    BaseLabel(
                      BuildInfo.displayDate,
                      role: TextRole.detail,
                      align: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const BaseGap(Proximity.separate),

            // Description
            Center(
              child: BaseLabel(
                'A cross-platform Git UI built with Flutter.',
                role: TextRole.body,
                align: TextAlign.center,
              ),
            ),

            const BaseGap(Proximity.separate),

            const BaseSeparator(),
            const BaseGap(Proximity.grouped),

            // Technology stack
            Center(child: BaseLabel('Built with', role: TextRole.sectionTitle)),
            const BaseGap(Proximity.related),
            Center(
              // The four chips are one run of equals that breaks onto a second
              // line in a narrow dialog, which is what `layout.row(wrap: true)`
              // states; the distance between two chips and the distance between
              // two lines of them are one rung the skin answers, not the two 8s
              // written here. The chips are all one height, so the run's cross
              // alignment is not visible; `start` is what the bare `Wrap` did.
              child: SkinScope.render(context, (Skin skin, BuildContext inner) {
                return skin.layout.row(
                  inner,
                  const [
                    // The four chips carried a leading glyph each - a Flutter
                    // dash, `Icons.code`, `Icons.architecture`,
                    // `Icons.palette` - and they are gone rather than
                    // converted. What each mark stood for is a PRODUCT, not a
                    // meaning: "the Flutter framework", "the Dart language",
                    // "Riverpod", "Material 3". `IconRole` is a vocabulary of
                    // meanings and has no product identities in it, so every
                    // candidate here (code for Dart, palette for Material 3)
                    // would be the site's original adjacency guess re-stated
                    // as a contract claim. The badge's mark crosses the seam
                    // now, so a guess made here would be handed to every skin.
                    // Reported as a contract finding in the P5 surfaces.badge
                    // report; the chips say the product's name in words, which
                    // is what they were always read by.
                    ContentPort(_TechChip(label: 'Flutter')),
                    ContentPort(_TechChip(label: 'Dart')),
                    ContentPort(_TechChip(label: 'Riverpod')),
                    ContentPort(_TechChip(label: 'Material 3')),
                  ],
                  gap: Proximity.related,
                  cross: CrossAxisAlignment.start,
                  wrap: true,
                );
              }),
            ),
            const BaseGap(Proximity.grouped),

            const BaseSeparator(),
            const BaseGap(Proximity.grouped),
          ],
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;

  const _TechChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return BaseBadge(
      label: label,
      variant: BadgeVariant.primary,
      size: BadgeSize.medium,
    );
  }
}
