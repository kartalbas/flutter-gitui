/// chrome.shell, measured: the NavigationView - the pane that absorbs what
/// Material calls an app bar, its selection pill, its subtle ladder, its
/// hamburger, and the layers the window is built from.
///
/// Every pinned literal restates its source beside it, independently of
/// the constants in lib/: pane widths from fluent_ui@4.16.1
/// navigation_view/pane.dart:4,7; the tile anatomy from
/// pane_items.dart:370-395 and view.dart:12; the tile states from
/// navigation_view/theme.dart:4-21 and pane_items.dart:381-390; the pill
/// from indicators.dart:186-208, :375-379 and styles/theme.dart:483; the
/// content layer from styles/theme.dart:456 and body.dart:82-83; the
/// smoke from color_resources.dart (SmokeFillColorDefault, 30% black).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_icon_button.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_pressable.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_chrome.dart';

import 'support/fluent_behavior_harness.dart';
import 'support/fluent_chrome_harness.dart';

// The subtle ladder, light theme: SubtleFillColorSecondary (hover) and
// Tertiary (pressed), color_resources.dart:298-299.
const Color _subtleHoverLight = Color(0x09000000);
const Color _subtlePressedLight = Color(0x06000000);

// The Windows default accent's resting brush on light grounds
// (fluent_ui color.dart:171, :347-352) - the selection pill's ink.
const Color _accentRestLight = Color(0xff0066b4);

// LayerOnAcrylicFillColorDefault, light (color_resources.dart:334) - the
// content layer the reference installs as scaffoldBackgroundColor.
const Color _contentLayerLight = Color(0x40ffffff);

// SmokeFillColorDefault (color_resources.dart, both dictionaries).
const Color _smoke = Color(0x4d000000);

// SystemFillColorCritical, light (color_resources.dart:350).
const Color _criticalLight = Color(0xFFc42b1c);

ShellDestination _destination(String label) => ShellDestination(
  label: label,
  icon: IconRole.x,
  selectedIcon: IconRole.x,
  body: () => ContentPort(Text('body-of-$label')),
);

ShellSpec _shellSpec({
  int selectedIndex = 0,
  ValueChanged<int>? onSelect,
  NavigationDensity? density,
  ValueChanged<NavigationDensity>? onDensityChanged,
  List<ToolbarGroup> toolbar = const <ToolbarGroup>[],
  ShellPaneHost? paneHost,
  ShellAside? aside,
  ShellStatus? status,
  ActivitySpec? activity,
  BlockingProgressSpec? blocking,
  List<ShellDestination>? destinations,
}) => ShellSpec(
  identity: AppIdentity(
    name: 'GitUI',
    icon: IconRole.x,
    appIcon: MemoryImage(kTransparentPngBytes),
  ),
  destinations:
      destinations ??
      <ShellDestination>[
        _destination('Repositories'),
        _destination('History'),
        _destination('Settings'),
      ],
  selectedIndex: selectedIndex,
  onSelect: onSelect ?? (_) {},
  toolbar: toolbar,
  paneHost: paneHost,
  density: density,
  onDensityChanged: onDensityChanged,
  aside: aside,
  status: status,
  activity: activity,
  blocking: blocking,
);

Future<void> _pumpShell(WidgetTester tester, ShellSpec spec) =>
    pumpFluentChrome(
      tester,
      (BuildContext context) => const FluentChrome().shell(context, spec),
    );

/// The pressable tile a destination's visible label lives in.
Finder _tile(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(FluentPressable));

void main() {
  group('the pane and its hamburger', () {
    testWidgets('rests OPEN at the published 320, and the skin\'s own '
        'toggle collapses it to the compact 50', (WidgetTester tester) async {
      await _pumpShell(tester, _shellSpec());
      expect(
        tester.getSize(find.byKey(FluentShell.paneKey)).width,
        320,
        reason: 'kOpenNavigationPaneWidth (pane.dart:7)',
      );
      expect(find.text('History'), findsOneWidget);

      await tester.tap(find.byKey(FluentShell.paneToggleKey));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(FluentShell.paneKey)).width,
        50,
        reason: 'kCompactNavigationPaneWidth (pane.dart:4)',
      );
      expect(
        find.text('History'),
        findsNothing,
        reason: 'compact reduces destinations to their marks',
      );

      await tester.tap(find.byKey(FluentShell.paneToggleKey));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(FluentShell.paneKey)).width, 320);
    });

    testWidgets('an application-stated density is honoured and changes are '
        'REPORTED, never kept', (WidgetTester tester) async {
      final List<NavigationDensity> reported = <NavigationDensity>[];
      await _pumpShell(
        tester,
        _shellSpec(
          density: NavigationDensity.condensed,
          onDensityChanged: reported.add,
        ),
      );
      expect(tester.getSize(find.byKey(FluentShell.paneKey)).width, 50);
      await tester.tap(find.byKey(FluentShell.paneToggleKey));
      await tester.pumpAndSettle();
      expect(reported, <NavigationDensity>[NavigationDensity.full]);
      expect(
        tester.getSize(find.byKey(FluentShell.paneKey)).width,
        50,
        reason:
            'the fact belongs to the application: until it rebuilds the '
            'spec, the pane must not move',
      );
    });

    testWidgets('at the application-stated hidden density only the '
        'hamburger survives, because a toggle that vanished with the thing '
        'it restores could never bring it back', (WidgetTester tester) async {
      final List<NavigationDensity> reported = <NavigationDensity>[];
      await _pumpShell(
        tester,
        _shellSpec(
          density: NavigationDensity.hidden,
          onDensityChanged: reported.add,
        ),
      );
      expect(find.text('Repositories'), findsNothing);
      expect(find.byKey(FluentShell.paneToggleKey), findsOneWidget);
      await tester.tap(find.byKey(FluentShell.paneToggleKey));
      await tester.pumpAndSettle();
      expect(reported, <NavigationDensity>[NavigationDensity.full]);
    });
  });

  group('the destinations: the pill and the ladder', () {
    testWidgets('the selected destination carries the 3-epx accent pill; '
        'its neighbours carry none', (WidgetTester tester) async {
      await _pumpShell(tester, _shellSpec());
      final List<RRect> selectedRects = paintedRRects(
        tester,
        _tile('Repositories'),
      );
      expect(
        selectedRects.where((RRect r) => r.width == 3),
        isNotEmpty,
        reason:
            'the WinUI selection indicator is 3 epx wide '
            '(indicators.dart:205-208, "to match WinUI3 NavigationView '
            'standard")',
      );
      expect(
        paintedFillColors(
          tester,
          _tile('Repositories'),
        ).map((Color c) => c.toARGB32()),
        contains(_accentRestLight.toARGB32()),
        reason:
            'the pill fills with the highlight - the accent brush '
            '(styles/theme.dart:483)',
      );
      expect(
        paintedFillColors(
          tester,
          _tile('History'),
        ).map((Color c) => c.toARGB32()),
        isNot(contains(_accentRestLight.toARGB32())),
      );
    });

    testWidgets('a destination hovers on the subtle ladder and the press '
        'RECEDES below the hover - Fluent\'s direction, not Material\'s '
        'overlay', (WidgetTester tester) async {
      await _pumpShell(tester, _shellSpec());
      final TestGesture pointer = await hoverOver(tester, find.text('History'));
      expect(
        paintedFillColors(
          tester,
          _tile('History'),
        ).map((Color c) => c.toARGB32()),
        contains(_subtleHoverLight.toARGB32()),
        reason: 'SubtleFillColorSecondary on hover (theme.dart:4-21)',
      );
      await hoverAway(tester, pointer);

      final TestGesture gesture = await pressAndHold(
        tester,
        find.text('History'),
      );
      // Inside the pane's scrollable the tap only wins the gesture arena
      // after the press deadline, and the fill animates for 83 ms after
      // that - pump past both before reading the paint.
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        paintedFillColors(
          tester,
          _tile('History'),
        ).map((Color c) => c.toARGB32()),
        contains(_subtlePressedLight.toARGB32()),
        reason:
            'SubtleFillColorTertiary on press: 0x06 alpha UNDER the '
            'hover\'s 0x09 - a Fluent subtle control recedes as it is '
            'pressed, where Material lays a stronger overlay on',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('choosing a destination is reported, never kept', (
      WidgetTester tester,
    ) async {
      final List<int> selected = <int>[];
      await _pumpShell(tester, _shellSpec(onSelect: selected.add));
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(selected, <int>[1]);
      expect(
        find.text('body-of-Repositories'),
        findsOneWidget,
        reason:
            'selectedIndex is the application\'s fact; the shell must '
            'not navigate by itself',
      );
    });

    testWidgets('the selected destination\'s body is the one mounted', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, _shellSpec(selectedIndex: 2));
      expect(find.text('body-of-Settings'), findsOneWidget);
      expect(find.text('body-of-Repositories'), findsNothing);
    });
  });

  group('the layers', () {
    testWidgets('the content stands on the layer fill, one step off the '
        'window ground, with no rule drawn between pane and content', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, _shellSpec());
      final ColoredBox layer = tester.widget<ColoredBox>(
        find.byKey(FluentShell.contentKey),
      );
      expect(
        layer.color.toARGB32(),
        _contentLayerLight.toARGB32(),
        reason:
            'the reference paints its NavigationView body with '
            'scaffoldBackgroundColor := LayerOnAcrylicFillColorDefault '
            '(styles/theme.dart:456, body.dart:82-83) - depth as a layer, '
            'not a divider',
      );
    });

    testWidgets('a blocking operation smokes the window and takes input '
        'away', (WidgetTester tester) async {
      final List<int> selected = <int>[];
      await _pumpShell(
        tester,
        _shellSpec(
          onSelect: selected.add,
          blocking: const BlockingProgressSpec(
            operation: 'Cloning repository',
            fraction: 0.4,
            currentStep: 2,
            totalSteps: 5,
            detail: 'Receiving objects',
          ),
        ),
      );
      final ModalBarrier barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier),
      );
      expect(
        barrier.color!.toARGB32(),
        _smoke.toARGB32(),
        reason: 'SmokeFillColorDefault: 30% black on either brightness',
      );
      expect(find.text('Cloning repository'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('Receiving objects'), findsOneWidget);
      await tester.tap(find.text('History'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selected, isEmpty, reason: 'the smoke absorbs the press');
    });

    testWidgets('a non-blocking activity reports along the content\'s top '
        'edge without stealing the press underneath', (
      WidgetTester tester,
    ) async {
      final List<int> selected = <int>[];
      int detailOpened = 0;
      await _pumpShell(
        tester,
        _shellSpec(
          onSelect: selected.add,
          activity: ActivitySpec(
            operation: 'Fetching origin',
            currentStep: 2,
            totalSteps: 5,
            indeterminate: false,
            onShowDetail: () => detailOpened++,
          ),
        ),
      );
      expect(find.text('Fetching origin (2/5)'), findsOneWidget);
      await tester.tap(find.text('Fetching origin (2/5)'));
      await tester.pumpAndSettle();
      expect(detailOpened, 1);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(selected, <int>[1], reason: 'the shell stays operable');
    });
  });

  group('the regions around the content', () {
    testWidgets('every pane the skin draws is routed through the '
        'application\'s own pane host, whatever the arrangement', (
      WidgetTester tester,
    ) async {
      final Set<ShellPane> hosted = <ShellPane>{};
      await _pumpShell(
        tester,
        _shellSpec(
          paneHost: (ShellPane pane, Widget contents) {
            hosted.add(pane);
            return contents;
          },
          toolbar: <ToolbarGroup>[
            ToolbarGroup(<ToolbarEntry>[
              ToolbarActionEntry(
                icon: IconRole.x,
                label: 'Fetch',
                tooltip: 'Fetch from origin',
                onPressed: () {},
              ),
            ]),
          ],
          aside: const ShellAside(
            title: 'Command log',
            content: ContentPort(Text('log-content')),
            visible: true,
          ),
        ),
      );
      expect(hosted, <ShellPane>{
        ShellPane.rail,
        ShellPane.toolbar,
        ShellPane.content,
        ShellPane.log,
      });
    });

    testWidgets('the aside shows its name in the pane\'s section-header '
        'treatment and its hide affordance reports', (
      WidgetTester tester,
    ) async {
      final List<bool> visibility = <bool>[];
      await _pumpShell(
        tester,
        _shellSpec(
          aside: ShellAside(
            title: 'Command log',
            content: const ContentPort(Text('log-content')),
            visible: true,
            onVisibilityChanged: visibility.add,
          ),
        ),
      );
      expect(find.text('Command log'), findsOneWidget);
      expect(find.text('log-content'), findsOneWidget);
      await tester.tap(find.byType(FluentIconButton));
      await tester.pumpAndSettle();
      expect(visibility, <bool>[false]);
    });

    testWidgets('the status line says what the shell is saying, in the '
        'tone\'s own ink', (WidgetTester tester) async {
      int tapped = 0;
      await _pumpShell(
        tester,
        _shellSpec(
          status: ShellStatus(
            label: 'merge conflict',
            detail: 'feature/login',
            tone: Tone.danger,
            onTap: () => tapped++,
          ),
        ),
      );
      expect(
        renderedLabelColor(tester, 'merge conflict').toARGB32(),
        _criticalLight.toARGB32(),
        reason:
            'Tone.danger is SystemFillColorCritical '
            '(color_resources.dart:350)',
      );
      expect(find.text('feature/login'), findsOneWidget);
      await tester.tap(find.text('merge conflict'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });
  });
}
