/// The T3 partition, demonstrated rather than asserted.
///
/// Three properties have to hold before the attribution walk means anything,
/// and until this file existed none of them was checked:
///
///  1. **Everything a skin's root treatment installs is on the skin's side.**
///     `SkinContentHost.build` used to plant the fence INSIDE
///     `chrome.wrapRoot`'s child, so every widget the root treatment wrapped
///     around that child - a `Theme`, an `AnimatedTheme`, a `Material`, a
///     `DecoratedBox`, and in the blueprint a `DefaultTextStyle` and an
///     `IconTheme` - sat in the half of the partition the walk attributes to
///     the application. On the first T3 run over any dialog route, the Material
///     skin's own widgets would have been reported as application leaks,
///     attributed by their creator chain to the skin package's own file.
///  2. **Everything the application hands a skin comes back attributable.**
///     `layout.column`, `layout.row` and `layout.inset` took raw widgets, and
///     a widget that never passes through a `ContentPort` has no boundary
///     above it - so it lands inside the pruned region and neither T3 nor T4
///     (blind inside a package) can ever see a leak in it. Those are the three
///     most-called members in the contract.
///  3. **The report names something a developer can act on.** A walk that says
///     "there is a leak" and cannot say where is a worse instrument than no
///     walk at all.
///
/// Each test below builds the smallest tree that can tell the answer apart,
/// which is why they build their own roots rather than going through
/// `pumpUnderSkin`: the subject here is the composition itself.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart';

import 'attribution_walk.dart';

void main() {
  testWidgets('the skin root treatment is attributed to the skin', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_install(const SizedBox.shrink()));

    final List<AttributedWidget> leaks = attributionWalk(
      tester.element(find.byKey(_root)),
    );

    expect(
      leaks.map((AttributedWidget leak) => leak.name),
      isNot(contains('DefaultTextStyle')),
      reason:
          "The blueprint's wrapRoot installs a DefaultTextStyle and an "
          'IconTheme. With the fence inside wrapRoot\'s child they were above '
          'it, in the region the walk attributes to the application - so the '
          'first T3 run over a dialog would have reported the skin to itself.',
    );
    expect(
      leaks.map((AttributedWidget leak) => leak.name),
      isNot(contains('IconTheme')),
    );
  });

  testWidgets('a leak in the application content is found and named', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _install(
        const Column(children: <Widget>[ColoredBox(color: Color(0xFFFFC107))]),
      ),
    );

    final List<AttributedWidget> leaks = attributionWalk(
      tester.element(find.byKey(_root)),
    );

    expect(
      leaks.map((AttributedWidget leak) => leak.name),
      contains('ColoredBox'),
      reason:
          'The application content is mounted through a ContentPort, so the '
          'walk resumes inside it. A ColoredBox is on no allow-list: it is '
          'the widget the original deny-list omitted, and it paints the one '
          'colour an achromatic invariant permits.',
    );
    expect(
      leaks.map((AttributedWidget leak) => leak.name),
      isNot(contains('Column')),
      reason: 'Flex topology is structure and stays in application code.',
    );

    final AttributedWidget leak = leaks.firstWhere(
      (AttributedWidget candidate) => candidate.name == 'ColoredBox',
    );
    expect(
      leak.creatorChain,
      contains('ColoredBox'),
      reason:
          'The report has to name something a developer can act on. The '
          'creator chain is what carries the file and the line under '
          '--track-widget-creation, which flutter test turns on in debug.',
    );
    expect(
      leak.element.renderObject?.debugCreator,
      isA<DebugCreator>(),
      reason:
          'This is the object the framework itself reads to print "The '
          'relevant error-causing widget was: ...", so the attribution T3 '
          'promises is genuinely available and not merely hoped for.',
    );
  });

  testWidgets(
    'a leak inside a layout member is attributable through its port',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _install(
          Builder(
            builder: (BuildContext context) =>
                const BlueprintSkin().layout.column(context, <ContentPort>[
                  ContentPort(const ColoredBox(color: Color(0xFFFFC107))),
                ]),
          ),
        ),
      );

      final List<AttributedWidget> leaks = attributionWalk(
        tester.element(find.byKey(_root)),
      );

      expect(
        leaks.map((AttributedWidget leak) => leak.name),
        contains('ColoredBox'),
        reason:
            'This is finding 2, executed. With List<Widget> children the child '
            'was placed inside the skin-painted region with no boundary above '
            'it, so the walk pruned before reaching it and every leak inside '
            'the most-called member in the contract was invisible - '
            'permanently, because T4 is blind inside a package too.',
      );
    },
  );

  testWidgets('what a skin builds inside a member is never reported', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _install(
        Builder(
          builder: (BuildContext context) => SkinScope.render(
            context,
            (Skin skin, BuildContext inner) => skin.controls.button(
              inner,
              const ButtonSpec(label: 'Delete', onPressed: _nothing),
            ),
          ),
        ),
      ),
    );

    final List<AttributedWidget> leaks = attributionWalk(
      tester.element(find.byKey(_root)),
    );

    expect(
      leaks,
      isEmpty,
      reason:
          'A member rendered through SkinScope.render is fenced in exactly '
          'one place, so nothing the skin drew - the outline, the marks, the '
          'CustomPaint - is the application\'s. If this ever reports, the '
          'fence moved and every skin in the repository became a leak.',
    );
  });
}

void _nothing() {}

/// Where each walk starts: one level ABOVE the fence the root planted, so that
/// a fence in the wrong place shows up as the skin's own widgets being
/// reported rather than as a walk that never looked at them.
const Key _root = Key('attribution-walk-root');

/// The application root, composed the way `SkinScope.install` composes it.
Widget _install(Widget app) => Directionality(
  key: _root,
  textDirection: TextDirection.ltr,
  child: SkinScope.install(
    skin: const BlueprintSkin(),
    request: const SkinRequest(
      brightness: Brightness.light,
      accentSeed: 0,
      textScale: 1,
      codeScale: 1,
      animationScale: 0,
      monoFamily: 'monospace',
      uiFamily: 'sans-serif',
    ),
    dialogKeyboardHost:
        (BuildContext context, DialogSpec spec, Widget surface) => surface,
    app: ContentPort(app),
  ),
);
