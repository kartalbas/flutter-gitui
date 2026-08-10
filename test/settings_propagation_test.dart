// The four appearance settings reach the pixels by ordinary propagation
// (#425). `main.dart` used to carry
//
//   key: ValueKey('$fontSize-$fontFamily-$colorScheme-$animationSpeed')
//
// on the one MaterialApp, which tore the whole application down - navigator,
// screens, focus, scroll positions - to make a settings change visible. That
// was demolition standing in for propagation: every consumer of the four
// values already watches its provider or depends on an inherited scope
// (`SkinScope` re-notifies on a request change, the theme extensions are
// re-published under it, and the tab controller re-derives its duration in
// `didChangeDependencies`), so the remount had nothing left to compensate
// for. These tests are the proof that deleting the key loses nothing: each
// changes one setting on the RUNNING application and asserts the rendering
// follows, and the last ones pin the very thing the key used to destroy -
// that the navigator survives a settings change.
//
// The design language travels the same channel as the four appearance
// settings (#441): the skin id is a config value, the provider rebuilds the
// root, and `SkinScope.updateShouldNotify` fires on the skin change. The two
// skin tests at the bottom are the running-application proof of #249's
// central claim - a person can pick another skin and watch the application
// redraw itself in place, navigator and shell intact.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart'
    show BlueprintText;

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/diff/models/diff_tool.dart';
import 'package:flutter_gitui/core/navigation/app_shell.dart';
import 'package:flutter_gitui/core/navigation/navigation_item.dart';
import 'package:flutter_gitui/main.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';

/// A fully configured app, so the shell's one-per-session "required settings
/// missing" redirect never fires: booting on defaults schedules a jump to the
/// Settings screen, which would replace the screen these tests measure. The
/// paths point at nothing: startup validation asks VersionDetector for a
/// version, which returns null for a file that does not exist without
/// launching a process, and a null version changes no value and triggers no
/// write.
final AppConfig _configured = AppConfig.defaults.copyWith(
  git: const GitConfig(
    executablePath: '/tools/git',
    gitVersion: '2.43.0',
    defaultUserName: 'Ada Lovelace',
    defaultUserEmail: 'ada@example.com',
  ),
  tools: const ToolsConfig(
    textEditor: '/tools/editor',
    diffTool: DiffToolType.vscode,
    diffToolPath: '/tools/diff',
    mergeTool: DiffToolType.vscode,
    mergeToolPath: '/tools/merge',
  ),
);

/// Keeps every setting change in memory.
///
/// Each real setter persists the whole configuration to the user's on-disk
/// config the moment it runs, which a test must never reach; the state
/// assignments are the part the application observes and are kept verbatim.
class _InMemoryConfigNotifier extends ConfigNotifier {
  _InMemoryConfigNotifier(Ref ref) : super.withConfig(ref, _configured);

  @override
  Future<void> setColorScheme(AppColorScheme scheme) async {
    state = state.copyWith(ui: state.ui.copyWith(colorScheme: scheme));
  }

  @override
  Future<void> setFontFamily(String fontFamily) async {
    state = state.copyWith(ui: state.ui.copyWith(fontFamily: fontFamily));
  }

  @override
  Future<void> setFontSize(AppFontSize size) async {
    state = state.copyWith(ui: state.ui.copyWith(fontSize: size));
  }

  @override
  Future<void> setAnimationSpeed(AppAnimationSpeed speed) async {
    state = state.copyWith(ui: state.ui.copyWith(animationSpeed: speed));
  }

  @override
  Future<void> setSkinId(String skinId) async {
    state = state.copyWith(ui: state.ui.copyWith(skinId: skinId));
  }
}

/// Boots the real application root past its splash and returns the notifier
/// the settings tests drive.
///
/// The registration is called from here for the same reason
/// `test/widget_test.dart` calls it: a test that pumps the real root cannot
/// know whether another already registered, so registering must be idempotent
/// and is exercised as such.
Future<ConfigNotifier> _bootApp(WidgetTester tester) async {
  registerSkins();
  late ConfigNotifier notifier;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configProvider.overrideWith((ref) {
          notifier = _InMemoryConfigNotifier(ref);
          return notifier;
        }),
      ],
      child: FlutterGitUIApp(initialConfig: _configured),
    ),
  );
  // The splash screen is dismissed by a Future.delayed; advance past it.
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  expect(find.byType(AppShell), findsOneWidget);
  return notifier;
}

/// A context below the skin's root treatment, where the application renders.
BuildContext _appContext(WidgetTester tester) =>
    tester.element(find.byType(AppShell));

/// The deferred update check schedules a timer at boot; let it elapse so no
/// timer is left pending when the tree is torn down (see #177).
Future<void> _drainDeferredTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  testWidgets('a font size change reaches the rendered text', (tester) async {
    final notifier = await _bootApp(tester);

    final String title = AppDestination.workspaces.label(_appContext(tester));
    final Finder titleText = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );
    final Size before = tester.getSize(titleText);
    expect(
      MediaQuery.of(_appContext(tester)).textScaler,
      const TextScaler.linear(1.0),
    );

    await notifier.setFontSize(AppFontSize.large);
    await tester.pumpAndSettle();

    // Both halves of the setting arrive: the application's own text scaler
    // (1.15 for large, applied in the MaterialApp builder) and the skin's
    // ramp (SkinRequest.textScale), measured where it matters - the laid-out
    // paragraph is taller than it was.
    expect(
      MediaQuery.of(_appContext(tester)).textScaler,
      const TextScaler.linear(1.15),
    );
    final Size after = tester.getSize(titleText);
    expect(
      after.height,
      greaterThan(before.height),
      reason:
          'The app bar title must be laid out larger after the font size '
          'setting grows.',
    );

    await _drainDeferredTimers(tester);
  });

  testWidgets('a font family change reaches the rendered text', (tester) async {
    final notifier = await _bootApp(tester);

    final String title = AppDestination.workspaces.label(_appContext(tester));
    final Finder titleText = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );
    final TextStyle styleBefore = tester
        .renderObject<RenderParagraph>(titleText)
        .text
        .style!;
    expect(styleBefore.fontFamily, startsWith('Inter'));

    await notifier.setFontFamily('JetBrains Mono');
    await tester.pumpAndSettle();

    final TextStyle styleAfter = tester
        .renderObject<RenderParagraph>(titleText)
        .text
        .style!;
    expect(
      styleAfter.fontFamily,
      startsWith('JetBrainsMono'),
      reason:
          'The interface family the user picked must be the one the '
          'paragraph is painted with.',
    );

    await _drainDeferredTimers(tester);
  });

  testWidgets('a colour scheme change reaches the painted accent', (
    tester,
  ) async {
    final notifier = await _bootApp(tester);

    final BuildContext context = _appContext(tester);
    final Color before = Theme.of(context).colorScheme.primary;

    await notifier.setColorScheme(AppColorScheme.green);
    await tester.pumpAndSettle();

    final Color after = Theme.of(_appContext(tester)).colorScheme.primary;
    expect(
      after,
      isNot(before),
      reason:
          'The accent the skin resolves from the seed must change with the '
          'scheme setting.',
    );

    // And the widget that paints the accent picked the new answer up: the
    // rail's brand mark states colorScheme.primary at build time, so its
    // rebuilt widget carries the new colour.
    final Icon brandMark = tester.widget<Icon>(
      find
          .descendant(
            of: find.byType(NavigationRail),
            matching: find.byIcon(PhosphorIconsBold.gitBranch),
          )
          .first,
    );
    expect(brandMark.color, after);

    await _drainDeferredTimers(tester);
  });

  testWidgets('an animation speed change reaches the motion readers', (
    tester,
  ) async {
    final notifier = await _bootApp(tester);

    expect(
      Theme.of(_appContext(tester)).extension<AnimationSpeedExtension>()!.speed,
      AppAnimationSpeed.normal,
    );

    await notifier.setAnimationSpeed(AppAnimationSpeed.none);
    await tester.pumpAndSettle();

    // The re-published extension is what the four remaining motion readers
    // (base_animated_widgets, base_switcher, branch_switcher, the branches
    // tab controller) resolve their durations from - "none" arriving here IS
    // reduced motion taking effect.
    expect(
      Theme.of(_appContext(tester)).extension<AnimationSpeedExtension>()!.speed,
      AppAnimationSpeed.none,
    );

    await _drainDeferredTimers(tester);
  });

  testWidgets('a settings change no longer tears the application down', (
    tester,
  ) async {
    final notifier = await _bootApp(tester);

    final NavigatorState navigatorBefore = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final State appShellBefore = tester.state(find.byType(AppShell));

    await notifier.setFontSize(AppFontSize.large);
    await notifier.setColorScheme(AppColorScheme.green);
    await tester.pumpAndSettle();

    // The remount key rebuilt the world on every one of these changes; with
    // propagation doing the work, the navigator and the shell keep their
    // state - which is what preserves the user's place, focus and scroll
    // positions across a settings change.
    expect(
      identical(
        navigatorBefore,
        tester.state<NavigatorState>(find.byType(Navigator).first),
      ),
      isTrue,
      reason: 'A settings change must not recreate the navigator.',
    );
    expect(
      identical(appShellBefore, tester.state(find.byType(AppShell))),
      isTrue,
      reason: 'A settings change must not remount the shell.',
    );

    await _drainDeferredTimers(tester);
  });

  testWidgets('a design language change reaches the pixels', (tester) async {
    final notifier = await _bootApp(tester);

    // Under the shipping skin the shell's bar is Material's own AppBar, and
    // nothing on screen is drawn by the blueprint.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BlueprintText), findsNothing);

    await notifier.setSkinId('blueprint');
    await tester.pumpAndSettle();

    // The application is now DRAWN by the other design language: Material's
    // app bar is gone and the blueprint's own text primitive is what renders
    // the words. This is #249's claim made visible - the look changed because
    // the skin did, with no other input changing.
    expect(
      find.byType(AppBar),
      findsNothing,
      reason:
          'After switching to the blueprint, the shell must no longer be '
          'drawn by the Material skin.',
    );
    expect(
      find.byType(BlueprintText),
      findsWidgets,
      reason:
          'After switching to the blueprint, the words on screen must be '
          'rendered by the blueprint\'s own primitives.',
    );

    await _drainDeferredTimers(tester);
  });

  testWidgets('a design language change does not tear the application down', (
    tester,
  ) async {
    final notifier = await _bootApp(tester);

    final NavigatorState navigatorBefore = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final State appShellBefore = tester.state(find.byType(AppShell));

    await notifier.setSkinId('blueprint');
    await tester.pumpAndSettle();

    // The swap travels like every other appearance setting (#425): the
    // provider rebuilds the root, SkinScope notifies, and the navigator -
    // held by its GlobalKey - is reparented into the new skin's root
    // treatment rather than recreated. Same State objects means the user's
    // place, focus and scroll positions survive the redraw.
    expect(
      identical(
        navigatorBefore,
        tester.state<NavigatorState>(find.byType(Navigator).first),
      ),
      isTrue,
      reason: 'A design language change must not recreate the navigator.',
    );
    expect(
      identical(appShellBefore, tester.state(find.byType(AppShell))),
      isTrue,
      reason: 'A design language change must not remount the shell.',
    );

    // And back again: the return trip is the same dissolve, not a fresh boot.
    await notifier.setSkinId(kShippingSkinId);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      identical(
        navigatorBefore,
        tester.state<NavigatorState>(find.byType(Navigator).first),
      ),
      isTrue,
      reason: 'Switching back must not recreate the navigator either.',
    );
    expect(
      identical(appShellBefore, tester.state(find.byType(AppShell))),
      isTrue,
      reason: 'Switching back must not remount the shell either.',
    );

    await _drainDeferredTimers(tester);
  });
}
