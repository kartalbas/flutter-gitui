/// The shell the application actually ships, measured — and until now the
/// only one of the three that had no behaviour suite at all.
///
/// That gap is the reason this file exists before the adoption rather than
/// after it. `chrome.shell` is written and implemented in every skin and has
/// ZERO callers in `lib/`: the application still composes its own window in
/// `app_shell.dart`, the single riskiest file in the programme (#413). The
/// swap deletes 600 lines of arrangement and trusts this member to reproduce
/// them. What it has to reproduce is what is pinned here, so the swap becomes
/// a deletion whose safety was established beforehand rather than discovered
/// afterwards.
///
/// The application's own contract with the shell is the F6 pane cycle over
/// four regions in a fixed order (#290). That contract survives ANY skin's
/// arrangement for exactly one reason: every pane a skin draws is routed
/// through `ShellSpec.paneHost`. So the first group below is the one that
/// matters most, and it asserts the routing member by member rather than
/// asserting that the window looks right.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../support/conformance_harness.dart';

/// A 1x1 transparent PNG: `AppIdentity` requires a raster mark, and no test
/// here measures it.
final Uint8List _pixel = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

ShellDestination _destination(String label, {int? badgeCount}) =>
    ShellDestination(
      label: label,
      icon: IconRole.gitBranch,
      selectedIcon: IconRole.gitBranch,
      badgeCount: badgeCount,
      body: () => ContentPort(Text('body-of-$label')),
    );

ShellSpec _shell({
  int selectedIndex = 0,
  ValueChanged<int>? onSelect,
  List<ShellDestination>? destinations,
  List<ToolbarGroup> toolbar = const <ToolbarGroup>[],
  ShellPaneHost? paneHost,
  NavigationDensity? density,
  ValueChanged<NavigationDensity>? onDensityChanged,
  ShellAside? aside,
  BannerSpec? banner,
  ShellStatus? status,
  ActivitySpec? activity,
  BlockingProgressSpec? blocking,
}) => ShellSpec(
  identity: AppIdentity(
    name: 'GitUI',
    icon: IconRole.gitBranch,
    appIcon: MemoryImage(_pixel),
  ),
  destinations:
      destinations ??
      <ShellDestination>[
        _destination('Repositories'),
        _destination('History'),
        _destination('Settings'),
      ],
  selectedIndex: selectedIndex,
  onSelect: onSelect ?? (int _) {},
  toolbar: toolbar,
  paneHost: paneHost,
  density: density,
  onDensityChanged: onDensityChanged,
  aside: aside,
  banner: banner,
  status: status,
  activity: activity,
  blocking: blocking,
);

Future<void> _pumpShell(WidgetTester tester, ShellSpec spec) => pumpConformance(
  tester,
  Builder(
    builder: (BuildContext context) =>
        const MaterialSkin().chrome.shell(context, spec),
  ),
);

/// Marks the pane it wraps, so a test can prove the skin routed it.
Widget _marked(ShellPane pane, Widget contents) =>
    KeyedSubtree(key: ValueKey<String>('pane-${pane.name}'), child: contents);

Finder _pane(ShellPane pane) =>
    find.byKey(ValueKey<String>('pane-${pane.name}'));

void main() {
  group('the panes the application owns', () {
    testWidgets('every region the skin draws is routed through the '
        'application\'s pane host, which is what keeps the F6 cycle the '
        'application\'s under any arrangement', (WidgetTester tester) async {
      final List<ShellPane> routed = <ShellPane>[];
      await _pumpShell(
        tester,
        _shell(
          toolbar: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              ToolbarActionEntry(
                label: 'Fetch',
                tooltip: 'Fetch',
                icon: IconRole.download,
                onPressed: () {},
              ),
            ], priority: ToolbarPriority.pinned),
          ],
          aside: ShellAside(
            title: 'Command log',
            visible: true,
            content: const ContentPort(Text('the log')),
          ),
          paneHost: (ShellPane pane, Widget contents) {
            routed.add(pane);
            return _marked(pane, contents);
          },
        ),
      );

      expect(
        routed.toSet(),
        <ShellPane>{
          ShellPane.rail,
          ShellPane.toolbar,
          ShellPane.content,
          ShellPane.log,
        },
        reason:
            'a pane the skin draws but does not route is a pane the F6 '
            'cycle cannot reach',
      );
      for (final ShellPane pane in routed) {
        expect(_pane(pane), findsOneWidget);
      }
    });

    testWidgets('a shell with no pane host renders every pane bare rather '
        'than dropping it', (WidgetTester tester) async {
      await _pumpShell(
        tester,
        _shell(
          aside: ShellAside(
            title: 'Command log',
            visible: true,
            content: const ContentPort(Text('the log')),
          ),
        ),
      );
      expect(find.text('body-of-Repositories'), findsOneWidget);
      expect(find.text('the log'), findsOneWidget);
    });

    testWidgets('the banner belongs to the CONTENT pane, not to the toolbar '
        '- it is part of what the user is working on', (
      WidgetTester tester,
    ) async {
      await _pumpShell(
        tester,
        _shell(
          banner: const BannerSpec(
            tone: Tone.warning,
            title: 'Git executable is not configured',
          ),
          paneHost: _marked,
        ),
      );
      expect(
        find.descendant(
          of: _pane(ShellPane.content),
          matching: find.text('Git executable is not configured'),
        ),
        findsOneWidget,
        reason:
            'F6 must not make the user leave the content to read the '
            'warning about it',
      );
    });
  });

  group('the destinations', () {
    testWidgets('the selected destination is the one whose body is mounted, '
        'and no other body is built', (WidgetTester tester) async {
      await _pumpShell(tester, _shell(selectedIndex: 1));
      expect(find.text('body-of-History'), findsOneWidget);
      expect(find.text('body-of-Repositories'), findsNothing);
      expect(find.text('body-of-Settings'), findsNothing);
    });

    testWidgets('choosing a destination is REPORTED, never kept: the shell '
        'holds no selection of its own', (WidgetTester tester) async {
      final List<int> chosen = <int>[];
      await _pumpShell(tester, _shell(selectedIndex: 0, onSelect: chosen.add));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(chosen, <int>[2]);
      // Still on the first destination: the application decides what the
      // choice means, and the shell never anticipates it.
      expect(find.text('body-of-Repositories'), findsOneWidget);
    });

    testWidgets('a destination with things waiting carries its count, and '
        'one with nothing to report carries no badge', (
      WidgetTester tester,
    ) async {
      await _pumpShell(
        tester,
        _shell(
          destinations: <ShellDestination>[
            _destination('Repositories', badgeCount: 7),
            _destination('History'),
          ],
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
    });
  });

  group('the display mode', () {
    testWidgets('at the application-stated hidden density the rail is gone '
        'and the content keeps the whole window', (WidgetTester tester) async {
      await _pumpShell(
        tester,
        _shell(density: NavigationDensity.hidden, paneHost: _marked),
      );
      expect(_pane(ShellPane.rail), findsNothing);
      expect(find.text('body-of-Repositories'), findsOneWidget);
    });

    testWidgets('a shell with no destinations draws no rail at all', (
      WidgetTester tester,
    ) async {
      await _pumpShell(
        tester,
        _shell(destinations: <ShellDestination>[], paneHost: _marked),
      );
      expect(_pane(ShellPane.rail), findsNothing);
    });
  });

  group('the aside', () {
    testWidgets('an aside that is not visible is not drawn, and its pane is '
        'not routed', (WidgetTester tester) async {
      final List<ShellPane> routed = <ShellPane>[];
      await _pumpShell(
        tester,
        _shell(
          aside: ShellAside(
            title: 'Command log',
            visible: false,
            content: const ContentPort(Text('the log')),
          ),
          paneHost: (ShellPane pane, Widget contents) {
            routed.add(pane);
            return _marked(pane, contents);
          },
        ),
      );
      expect(find.text('the log'), findsNothing);
      expect(routed, isNot(contains(ShellPane.log)));
    });
  });

  group('what is running', () {
    testWidgets('a blocking operation covers the window; the content is '
        'still there behind it but cannot be reached', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pumpShell(
        tester,
        _shell(
          destinations: <ShellDestination>[
            ShellDestination(
              label: 'Repositories',
              icon: IconRole.gitBranch,
              selectedIcon: IconRole.gitBranch,
              body: () => ContentPort(
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
          blocking: const BlockingProgressSpec(operation: 'Cloning'),
        ),
      );
      expect(find.text('Cloning'), findsOneWidget);

      await tester.tapAt(const Offset(700, 400));
      await tester.pump();
      expect(
        taps,
        0,
        reason: 'a blocking operation the user must wait for takes input away',
      );
    });

    testWidgets('a non-blocking activity is reported without taking input', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pumpShell(
        tester,
        _shell(
          destinations: <ShellDestination>[
            ShellDestination(
              label: 'Repositories',
              icon: IconRole.gitBranch,
              selectedIcon: IconRole.gitBranch,
              body: () => ContentPort(
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
          activity: const ActivitySpec(operation: 'Fetching'),
        ),
      );
      // The caption carries the language's own ellipsis, so the operation is
      // matched rather than the whole string.
      expect(find.textContaining('Fetching'), findsOneWidget);

      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(
        taps,
        1,
        reason: 'a background operation never steals the user\'s click',
      );
    });
  });

  group('the toolbar, whose arithmetic was reported broken four times', () {
    ToolbarActionEntry action(String name) => ToolbarActionEntry(
      label: name,
      tooltip: name,
      icon: IconRole.download,
      onPressed: () {},
    );

    ShellSpec withUtilities(int count) => _shell(
      density: NavigationDensity.hidden,
      toolbar: <ToolbarGroup>[
        ToolbarGroup(<ToolbarEntry>[
          const ToolbarPickerEntry(
            label: 'Repository',
            value: 'flutter-gitui',
            icon: IconRole.gitBranch,
            entries: <MenuEntry>[],
          ),
        ], priority: ToolbarPriority.pinned),
        ToolbarGroup(<ToolbarEntry>[
          for (int i = 0; i < count; i++) action('Utility $i'),
        ], priority: ToolbarPriority.sheddable),
      ],
    );

    /// Which utility actions reached the bar itself, by index.
    List<int> onBar(int count) => <int>[
      for (int i = 0; i < count; i++)
        if (find.byTooltip('Utility $i').evaluate().isNotEmpty) i,
    ];

    testWidgets('a sheddable group is CAPPED, so it collapses into its own '
        'overflow instead of pushing the picker off the bar (#359)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 800);
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpShell(tester, withUtilities(10));

      // The measured invariant, and the one a naive bar gets wrong: the
      // sheddable cluster does NOT grow into the room a wide window offers.
      // It claims three item widths at most, which is two actions and its own
      // overflow button, and everything else goes into that menu.
      expect(onBar(10), <int>[0, 1]);
      expect(find.text('flutter-gitui'), findsOneWidget);

      tester.view.physicalSize = const Size(700, 800);
      await tester.pumpAndSettle();
      expect(
        onBar(10),
        <int>[0, 1],
        reason:
            'the cap is what makes the narrow window behave like the wide '
            'one - the subject every other control acts on never gives way to '
            'the utilities',
      );
      expect(find.text('flutter-gitui'), findsOneWidget);
    });

    testWidgets('a group that fits keeps every action on the bar', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, withUtilities(2));
      expect(onBar(2), <int>[0, 1]);
    });

    testWidgets('a picker names its subject and offers the rest - the shape '
        'the four switchers become', (WidgetTester tester) async {
      final List<String> chosen = <String>[];
      await _pumpShell(
        tester,
        _shell(
          toolbar: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              ToolbarPickerEntry(
                label: 'Repository',
                value: 'flutter-gitui',
                icon: IconRole.gitBranch,
                entries: <MenuEntry>[
                  MenuAction(
                    label: 'other-repo',
                    onPressed: () => chosen.add('other-repo'),
                  ),
                ],
              ),
            ], priority: ToolbarPriority.pinned),
          ],
        ),
      );
      expect(find.text('flutter-gitui'), findsOneWidget);

      await tester.tap(find.text('flutter-gitui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('other-repo'));
      await tester.pumpAndSettle();
      expect(chosen, <String>['other-repo']);
    });

    testWidgets('a picker with nothing to choose from says so and does not '
        'open', (WidgetTester tester) async {
      await _pumpShell(
        tester,
        _shell(
          toolbar: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              const ToolbarPickerEntry(
                label: 'Repository',
                value: '',
                emptyLabel: 'No repository',
                icon: IconRole.gitBranch,
                entries: <MenuEntry>[],
              ),
            ], priority: ToolbarPriority.pinned),
          ],
        ),
      );
      expect(find.text('No repository'), findsOneWidget);

      await tester.tap(find.text('No repository'));
      await tester.pumpAndSettle();
      // A picker over an empty set is a statement, not a control: nothing
      // opened, and the words are still the only thing on screen.
      expect(find.text('No repository'), findsOneWidget);
    });

    testWidgets('a standing menu is a popup of its own and is never folded '
        'into an overflow', (WidgetTester tester) async {
      await _pumpShell(
        tester,
        _shell(
          toolbar: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              ToolbarMenuEntry(
                icon: IconRole.gear,
                tooltip: 'Quick settings',
                entries: <MenuEntry>[
                  MenuAction(label: 'Dark mode', onPressed: () {}),
                ],
              ),
            ], priority: ToolbarPriority.pinned),
          ],
        ),
      );

      await tester.tap(find.byTooltip('Quick settings'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode'), findsOneWidget);
    });
  });
}
