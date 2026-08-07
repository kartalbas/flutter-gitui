/// Material 3 conformance suite for BaseSpeedDial
/// (lib/shared/components/base_speed_dial.dart).
///
/// ## What is measured, and what Material 3 does not specify
///
/// Material 3 has no speed dial. What it does specify is the two components
/// the dial is built out of: a regular floating action button for the dial's
/// own button and a *small* one for each action. Those are what this suite
/// measures — size, corner, elevation (resting and hovered), colour roles,
/// glyph size, state layer and tap target — plus the one placement rule the
/// SDK states for a floating button, its 16 dp margin from the screen edge
/// (`kFloatingActionButtonMargin`, floating_action_button_location.dart:25).
///
/// The dial's own inventions — the labelled chip beside each action, the gap
/// between the rows, the rotation of the glyph — have no oracle at all, so
/// nothing is asserted about them here rather than inventing token values that
/// no specification could falsify. The golden `base_misc_controls` freezes
/// their appearance instead, which is the right instrument for a composition.
///
/// ## Why the oracle is pinned rather than pumped
///
/// Same reason as the switch suite: the app configures `fabUseShape` and
/// `fabRadius` in `FlexSubThemesData` (app_theme.dart), so a stock
/// `FloatingActionButton` pumped under the app's theme carries the app's
/// corner and would report it back as if it were the specification. The ruler
/// is therefore the generated `_FABDefaultsM3` block itself
/// (Flutter 3.44.4 floating_action_button.dart:775-833), cited per value.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/components/base_speed_dial.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

// ---------------------------------------------------------------------------
// The Material 3 oracle, pinned from the generated token block.
// ---------------------------------------------------------------------------

/// floating_action_button.dart:783-786 (`_FABDefaultsM3.sizeConstraints`).
const double _m3FabSize = 56.0;

/// floating_action_button.dart:787-790 (`_FABDefaultsM3.smallSizeConstraints`).
const double _m3MiniFabSize = 40.0;

/// floating_action_button.dart:817 (`_FABDefaultsM3.shape`, regular).
const double _m3FabCornerRadius = 16.0;

/// floating_action_button.dart:818 (`_FABDefaultsM3.shape`, small).
const double _m3MiniFabCornerRadius = 12.0;

/// floating_action_button.dart:778 (`_FABDefaultsM3` elevation).
const double _m3FabElevation = 6.0;

/// floating_action_button.dart:780 (`_FABDefaultsM3` hoverElevation).
const double _m3FabHoverElevation = 8.0;

/// floating_action_button.dart:825-826 (`_FABDefaultsM3.iconSize`, regular and
/// small alike).
const double _m3FabIconSize = 24.0;

/// floating_action_button_location.dart:25 (`kFloatingActionButtonMargin`).
const double _m3FabEdgeMargin = 16.0;

/// constants.dart:27 (`kMinInteractiveDimension`) — the target a FAB reaches
/// through `MaterialTapTargetSize.padded` even when its painted container is
/// smaller.
const double _m3MinTapTarget = 48.0;

// ---------------------------------------------------------------------------
// The dial under measurement
// ---------------------------------------------------------------------------

/// The size of the `Stack` the dial is placed in. The dial positions itself
/// from the bottom-right corner of its stack, so the edge margin is only
/// measurable against a stack of a known size.
const double _stageSide = 400.0;

/// Identifies that stack. A `Scaffold` builds stacks of its own, so the stage
/// has to be named rather than picked out of `find.byType(Stack)` by position.
const Key _stageKey = ValueKey<String>('speed-dial-stage');

final List<SpeedDialAction> _actions = <SpeedDialAction>[
  SpeedDialAction(
    icon: PhosphorIconsRegular.plus,
    label: 'New branch',
    onPressed: () {},
  ),
  SpeedDialAction(
    icon: PhosphorIconsRegular.copy,
    label: 'Clone',
    onPressed: () {},
  ),
];

Widget _dial({required bool expanded}) {
  return SizedBox(
    width: _stageSide,
    height: _stageSide,
    child: Stack(
      key: _stageKey,
      children: <Widget>[
        BaseSpeedDial(
          actions: _actions,
          isExpanded: expanded,
          onToggle: () {},
          onCollapse: () {},
        ),
      ],
    ),
  );
}

Future<void> _pumpDial(WidgetTester tester, {required bool expanded}) async {
  await pumpConformance(tester, _dial(expanded: expanded));
  await tester.pumpAndSettle();
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

/// The dial's own button. It is built last, so it is the last FAB in the tree.
Finder _mainFab() => find.byType(FloatingActionButton).last;

/// The first action's mini FAB.
Finder _miniFab() => find.byType(FloatingActionButton).first;

/// The `Material` that paints a FAB's container — the box whose size, corner,
/// elevation and colour Material 3 specifies. It is smaller than the widget's
/// own layout box whenever the padded tap target adds room around it.
Finder _fabContainer(Finder fab) =>
    find.descendant(of: fab, matching: find.byType(Material));

Material _container(WidgetTester tester, Finder fab) =>
    tester.widget<Material>(_fabContainer(fab));

double _cornerRadius(ShapeBorder? shape) {
  if (shape is RoundedRectangleBorder) {
    final BorderRadiusGeometry radius = shape.borderRadius;
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  fail('Expected a rounded FAB shape, got $shape.');
}

String _role(WidgetTester tester, Color color) =>
    colorRoleName(_theme(tester).colorScheme, color);

void main() {
  group("the dial's own floating action button", () {
    testWidgets('container size', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: false);
      final Size size = tester.getSize(_fabContainer(_mainFab()));

      expect(size.width, size.height, reason: 'a regular FAB is square');
      expectConformant(
        token: 'BaseSpeedDial.fab.containerSize',
        component: 'BaseSpeedDial',
        measured: size.height,
        expected: _m3FabSize,
      );
    });

    testWidgets('corner radius', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: false);

      expectConformant(
        token: 'BaseSpeedDial.fab.shape',
        component: 'BaseSpeedDial',
        measured: _cornerRadius(_container(tester, _mainFab()).shape),
        expected: _m3FabCornerRadius,
      );
    });

    testWidgets('resting and hovered elevation', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: false);

      expectConformant(
        token: 'BaseSpeedDial.fab.elevation',
        component: 'BaseSpeedDial',
        measured: _container(tester, _mainFab()).elevation,
        expected: _m3FabElevation,
        unit: '',
      );

      final double hovered = await whileHovering(
        tester,
        _mainFab(),
        () => _container(tester, _mainFab()).elevation,
      );
      expectConformant(
        token: 'BaseSpeedDial.fab.hoveredElevation',
        component: 'BaseSpeedDial',
        measured: hovered,
        expected: _m3FabHoverElevation,
        unit: '',
      );
    });

    testWidgets('container and foreground roles', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: false);
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseSpeedDial.fab.containerColor',
        component: 'BaseSpeedDial',
        measured: _role(tester, _container(tester, _mainFab()).color!),
        // floating_action_button.dart:810 (`backgroundColor`).
        expected: colorRoleName(scheme, scheme.primaryContainer),
        unit: '',
      );

      final Finder glyph = find.descendant(
        of: _mainFab(),
        matching: find.byType(Icon),
      );
      expectConformant(
        token: 'BaseSpeedDial.fab.foregroundColor',
        component: 'BaseSpeedDial',
        measured: _role(tester, IconTheme.of(tester.element(glyph)).color!),
        // floating_action_button.dart:809 (`foregroundColor`).
        expected: colorRoleName(scheme, scheme.onPrimaryContainer),
        unit: '',
      );
      expectConformant(
        token: 'BaseSpeedDial.fab.iconSize',
        component: 'BaseSpeedDial',
        measured: effectiveIconSize(tester, glyph),
        expected: _m3FabIconSize,
      );
    });

    testWidgets('hover paints the M3 state layer', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: false);
      final ColorScheme scheme = _theme(tester).colorScheme;
      // The dial has its own ink layer; without `within` the probe would read
      // the Scaffold's, where nothing is happening.
      final String measured = describeStateLayer(
        tester,
        await hoverStateLayer(
          tester,
          _mainFab(),
          within: find.byType(BaseSpeedDial),
        ),
      );

      expectConformant(
        token: 'BaseSpeedDial.fab.overlay.hovered',
        component: 'BaseSpeedDial',
        measured: measured,
        // floating_action_button.dart:813 (`hoverColor`).
        expected: colorRoleName(
          scheme,
          scheme.onPrimaryContainer.withValues(alpha: 0.08),
        ),
        unit: '',
      );
    });
  });

  group("an action's mini floating action button", () {
    testWidgets('container size', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: true);
      final Size size = tester.getSize(_fabContainer(_miniFab()));

      expect(size.width, size.height, reason: 'a small FAB is square');
      expectConformant(
        token: 'BaseSpeedDial.miniFab.containerSize',
        component: 'BaseSpeedDial',
        measured: size.height,
        expected: _m3MiniFabSize,
      );
    });

    testWidgets('corner radius (FAB-001)', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: true);

      expectConformant(
        token: 'BaseSpeedDial.miniFab.shape',
        component: 'BaseSpeedDial',
        measured: _cornerRadius(_container(tester, _miniFab()).shape),
        expected: _m3MiniFabCornerRadius,
      );
    });

    testWidgets('container role and glyph size', (WidgetTester tester) async {
      await _pumpDial(tester, expanded: true);
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseSpeedDial.miniFab.containerColor',
        component: 'BaseSpeedDial',
        measured: _role(tester, _container(tester, _miniFab()).color!),
        expected: colorRoleName(scheme, scheme.primaryContainer),
        unit: '',
      );
      expectConformant(
        token: 'BaseSpeedDial.miniFab.iconSize',
        component: 'BaseSpeedDial',
        measured: effectiveIconSize(
          tester,
          find.descendant(of: _miniFab(), matching: find.byType(Icon)),
        ),
        expected: _m3FabIconSize,
      );
    });

    testWidgets('the 40 dp container still carries a 48 dp tap target', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpDial(tester, expanded: true);

      expectConformant(
        token: 'BaseSpeedDial.miniFab.tapTargetSize',
        component: 'BaseSpeedDial',
        measured: tester.getSize(_miniFab()).height,
        expected: _m3MinTapTarget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('placement', () {
    testWidgets('the dial keeps the M3 edge margin', (
      WidgetTester tester,
    ) async {
      await _pumpDial(tester, expanded: false);
      final Rect stage = tester.getRect(find.byKey(_stageKey));
      final Rect fab = tester.getRect(_fabContainer(_mainFab()));

      expect(
        stage.right - fab.right,
        stage.bottom - fab.bottom,
        reason: 'the dial sits the same distance from both edges',
      );
      expectConformant(
        token: 'BaseSpeedDial.edgeMargin',
        component: 'BaseSpeedDial',
        measured: stage.right - fab.right,
        expected: _m3FabEdgeMargin,
      );
    });
  });

  group('accessible names', () {
    testWidgets('every button in the dial names itself', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpDial(tester, expanded: true);

      // The dial's own button names the *next* press rather than the current
      // glyph, so an expanded dial offers to collapse.
      expect(
        tester.widget<FloatingActionButton>(_mainFab()).tooltip,
        'Collapse',
      );
      for (final SpeedDialAction action in _actions) {
        expect(
          find.byTooltip(action.label),
          findsOneWidget,
          reason: '${action.label} has no accessible name',
        );
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
