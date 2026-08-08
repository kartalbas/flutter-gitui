// The app shell's keyboard frame (#290): the navigation rail, the toolbar,
// the content area and the command log panel are one Tab cycle in that order;
// F6 / Shift+F6 move between them as panes; the shell's anchor is never a Tab
// stop; and the app-level Ctrl shortcuts keep firing exactly as before.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/navigation/app_shell.dart';
import 'package:flutter_gitui/core/navigation/command_palette.dart';
import 'package:flutter_gitui/core/navigation/navigation_item.dart';
import 'package:flutter_gitui/features/history/history_screen.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import '../../skin/pump_under_skin.dart';

const _railRegion = 'AppShell.railRegion';
const _toolbarRegion = 'AppShell.toolbarRegion';
const _contentRegion = 'AppShell.contentRegion';
const _commandLogRegion = 'AppShell.commandLogRegion';
const _regionLabels = {
  _railRegion,
  _toolbarRegion,
  _contentRegion,
  _commandLogRegion,
};

/// The shell region owning [node], resolved through the region marker nodes
/// on the focus path. Null when focus sits outside every region.
String? _regionOf(FocusNode? node) {
  if (node == null) return null;
  for (final ancestor in node.ancestors) {
    final label = ancestor.debugLabel;
    if (label != null && _regionLabels.contains(label)) return label;
  }
  return null;
}

Future<void> _pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // A pre-validated default config: no config file is read or written,
        // and the empty defaults run no tool detection.
        configProvider.overrideWith(
          (ref) => ConfigNotifier.withConfig(ref, AppConfig.defaults),
        ),
        // The "What's New" dialog reads real version state; mark it checked.
        whatsNewDialogCheckedProvider.overrideWith((ref) => true),
        // The command log panel must be visible for its region to take part
        // in the cycle.
        commandLogPanelVisibleProvider.overrideWithValue(true),
        // Start on settings, which is also where the shell auto-navigates
        // with an unconfigured default config, so the destination is stable
        // for the whole test.
        navigationDestinationProvider.overrideWith(
          (ref) => AppDestination.settings,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // This suite builds its own root on purpose - it inserts nothing
        // between the navigator and the shell - but from the moment the
        // shell's components render through the contract it still has to
        // install the skin, exactly as pump_under_skin.dart documents: a
        // migrated component below reaches its design language through
        // SkinScope and fails loudly without one.
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),
        home: const AppShell(),
      ),
    ),
  );

  // Let the deferred config validation finish, then give the shell anchor
  // its decision frame: it claims focus only after the autofocus pipeline
  // settled with nothing focused.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  await tester.pump();
}

Future<void> _f6(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.f6);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'one Tab cycle walks rail, toolbar, content and command log in order, '
    'and the anchor is never a Tab stop',
    (tester) async {
      await _pumpShell(tester);

      // Startup: no screen claims focus today, so the anchor holds it as the
      // focus of last resort — yet every Tab press below must land inside a
      // region, never back on the anchor.
      expect(primaryFocus?.debugLabel, 'AppShell.anchor');

      final collapsed = <String>[];
      for (var i = 0; i < 150 && collapsed.length < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final region = _regionOf(primaryFocus);
        expect(
          region,
          isNotNull,
          reason:
              'Tab stop "${primaryFocus?.debugLabel}" lies outside every '
              'shell region',
        );
        if (collapsed.isEmpty || collapsed.last != region) {
          collapsed.add(region!);
        }
      }

      expect(collapsed, [
        _railRegion,
        _toolbarRegion,
        _contentRegion,
        _commandLogRegion,
        _railRegion,
      ]);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('F6 cycles the shell panes and Shift+F6 cycles back', (
    tester,
  ) async {
    await _pumpShell(tester);

    // From the anchor, F6 enters the first pane: the rail.
    await _f6(tester);
    expect(_regionOf(primaryFocus), _railRegion);

    // F6 moves from the rail into the toolbar; Shift+F6 goes back.
    await _f6(tester);
    expect(_regionOf(primaryFocus), _toolbarRegion);
    await _f6(tester, shift: true);
    expect(_regionOf(primaryFocus), _railRegion);

    // The full forward cycle: toolbar, content, command log, rail again.
    await _f6(tester);
    expect(_regionOf(primaryFocus), _toolbarRegion);
    await _f6(tester);
    expect(_regionOf(primaryFocus), _contentRegion);
    await _f6(tester);
    expect(_regionOf(primaryFocus), _commandLogRegion);
    await _f6(tester);
    expect(_regionOf(primaryFocus), _railRegion);
    await tester.pumpAndSettle();
  });

  testWidgets('the existing Ctrl shortcuts still fire', (tester) async {
    await _pumpShell(tester);

    // Ctrl+K opens the command palette. The palette lays out fine with real
    // fonts, but the test font's uniformly wide glyphs overflow one of its
    // rows, so RenderFlex overflow reports are tolerated around this step —
    // the assertion is that the shortcut opened the palette at all.
    final defaultOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      defaultOnError?.call(details);
    };
    await _ctrl(tester, LogicalKeyboardKey.keyK);
    expect(find.byType(CommandPalette), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsNothing);
    FlutterError.onError = defaultOnError;

    // Ctrl+4 navigates to the history screen.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    await _ctrl(tester, LogicalKeyboardKey.digit4);
    expect(
      container.read(navigationDestinationProvider),
      AppDestination.history,
    );
    expect(find.byType(HistoryScreen), findsOneWidget);

    // Ctrl+comma navigates back to settings.
    await _ctrl(tester, LogicalKeyboardKey.comma);
    expect(
      container.read(navigationDestinationProvider),
      AppDestination.settings,
    );
  });
}
