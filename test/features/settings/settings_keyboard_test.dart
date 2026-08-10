// The settings screen as the keyboard drives it (#290). Unlike every other
// screen in the app the settings screen is a form, not a collection: it has no
// roving highlight, so Tab is the only navigation and each control must be a
// stop of its own. The contract this file pins down is:
//
//  - Tab walks every enabled control exactly once, in the order the eye reads
//    them (app bar first, then the sections top to bottom, each section's
//    header before its rows), and Shift+Tab walks the same sequence backwards.
//    The cycle is closed: Tab past the last control returns to the first.
//  - Space and Enter activate whatever holds focus: a switch flips, a section
//    header collapses and expands, a button fires, a dropdown opens.
//  - An open dropdown is navigated with ArrowUp/ArrowDown and committed with
//    Enter; Escape closes it and leaves the setting as it was.
//  - A collapsed section takes its controls out of the Tab cycle, so the
//    keyboard never lands on a control the user cannot see.
//  - While a dialog's text field has focus, the keys that would otherwise
//    drive the screen behind it (Space, the arrows) belong to the field - the
//    focusedEditableOwnsKey guard in lib/shared/utils/keyboard_guards.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show SkinMenuAnchor;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/diff/models/diff_tool.dart';
import 'package:flutter_gitui/features/settings/settings_screen.dart';
import 'package:flutter_gitui/features/settings/widgets/settings_section.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import '../../skin/pump_under_skin.dart';

/// Keeps every setting change in memory.
///
/// Each real setter persists the whole configuration to the user's on-disk
/// config the moment it runs, which a test must never reach; the state
/// assignments are the part the screen observes and are kept verbatim.
class _InMemoryConfigNotifier extends ConfigNotifier {
  _InMemoryConfigNotifier(Ref ref) : super.withConfig(ref, _configured);

  @override
  Future<void> setShowCommitGraph(bool show) async {
    state = state.copyWith(
      history: state.history.copyWith(showCommitGraph: show),
    );
  }

  @override
  Future<void> setUpdateAutoDownload(bool enabled) async {
    state = state.copyWith(
      updates: state.updates.copyWith(autoDownload: enabled),
    );
  }

  @override
  Future<void> setColorScheme(AppColorScheme scheme) async {
    state = state.copyWith(ui: state.ui.copyWith(colorScheme: scheme));
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
  Future<void> setDefaultCommitLimit(int limit) async {
    state = state.copyWith(
      history: state.history.copyWith(defaultCommitLimit: limit),
    );
  }
}

/// A fully configured app, so the controls that only exist once a tool is set
/// (the per-row Clear buttons, the log buttons that need a text editor) are
/// present and the sweep really covers every control the screen can show.
///
/// The paths point at nothing: startup validation asks VersionDetector for a
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

/// Names the control that holds primary focus, the way a user would name it:
/// by the kind of control it is and the label printed on it.
///
/// The focus node lives deep inside the component that owns it, so the name is
/// read from the nearest recognisable ancestor of the focused context. A
/// section header is the fallback: it is the only focusable part of a
/// [SettingsSection] that is not itself a button, dropdown or switch.
///
/// The overflow menu's trigger is the one control here the application does
/// not build: the SKIN draws it behind `Overlays.anchor`, so no application
/// widget class stands above its focus node any more. Its name travels as
/// data on the spec instead, and [SkinMenuAnchor] - the identity the contract
/// plants around every anchor it mounts - is where that data is read back.
String _focusedControl() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return 'nothing';

  String? name;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is DropdownButton) {
      name = 'dropdown:${widget.value}';
    } else if (widget is SwitchListTile) {
      name = 'switch:${(widget.title! as Text).data}';
    } else if (widget is BaseButton) {
      name = 'button:${widget.label}';
    } else if (widget is BaseIconButton) {
      name = 'iconButton:${widget.tooltip}';
    } else if (widget is SkinMenuAnchor) {
      name = 'menu:${widget.spec.tooltip}';
    } else if (widget is SettingsSection) {
      name = 'sectionHeader:${widget.title}';
    }
    return name == null;
  });
  return name ?? 'unnamed:${context.widget.runtimeType}';
}

/// Whether primary focus sits inside an editable text field - the condition
/// [focusedEditableOwnsKey] tests before any screen-level handler may claim an
/// unmodified key.
bool _editableHasFocus() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>() !=
    null;

/// The text the one open field is showing.
String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

/// Every control of the settings screen in reading order: the app bar's
/// overflow menu, then the six sections from top to bottom, each with its
/// header first and its rows in the order they are laid out.
const List<String> _readingOrder = <String>[
  'menu:More actions',

  'sectionHeader:Git Configuration',
  'button:Search Tools (Auto-detect)',
  'iconButton:Clear', // git executable
  'iconButton:Browse',
  'iconButton:Clear', // text editor
  'iconButton:Browse',
  'iconButton:Clear', // diff tool
  'iconButton:Browse',
  'iconButton:Clear', // merge tool
  'iconButton:Browse',
  'iconButton:Edit', // default user name
  'iconButton:Edit', // default user email

  'sectionHeader:Appearance',
  'dropdown:material', // design language (#441)
  'dropdown:AppColorScheme.deepPurple',
  'dropdown:Inter', // font family
  'dropdown:AppFontSize.medium',
  'dropdown:JetBrains Mono', // preview font family
  'dropdown:AppFontSize.medium', // preview font size
  // Behavior (#444). The interval's Edit button is deliberately absent: it is
  // only built while Auto Fetch is on, and the setting defaults to off, so a
  // stop for it here would assert a control this fixture never draws.
  'sectionHeader:Behavior',
  'switch:Auto Fetch',
  'switch:Confirm Push',
  'switch:Confirm destructive actions',

  'sectionHeader:Animations',
  'dropdown:AppAnimationSpeed.normal',

  'sectionHeader:History',
  'iconButton:Edit', // default commit limit
  'switch:Show Commit Graph',

  'sectionHeader:Updates',
  'dropdown:UpdateCheckFrequency.onStart',
  'switch:Download updates in the background',
  'button:Check for Updates',
  'button:View Release History',

  'sectionHeader:Config and Logs',
  'button:Open app.log',
  'button:Open git.log',
  'button:Open Config Folder',
  'button:Delete app.log',
  'button:Delete git.log',
];

void main() {
  setUp(() {
    // The sections remember whether they are expanded in shared preferences,
    // and the updates section reads the running version from the platform.
    // Both are plugin calls that would throw asynchronously in a test.
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'flutter_gitui',
      packageName: 'dev.kartalbas.flutter_gitui',
      version: '0.5.14-alpha',
      buildNumber: '',
      buildSignature: '',
    );
  });

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWith((ref) => _InMemoryConfigNotifier(ref)),
        ],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
  }

  Future<String> tab(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    return _focusedControl();
  }

  Future<String> shiftTab(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    return _focusedControl();
  }

  /// Tabs until [control] holds focus, so a test can start from any control
  /// without hard-coding how many stops precede it.
  Future<void> tabTo(WidgetTester tester, String control) async {
    for (var i = 0; i <= _readingOrder.length; i++) {
      if (await tab(tester) == control) return;
    }
    fail('Tab never reached $control');
  }

  testWidgets('Tab walks every control in reading order and back again', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Forward: one stop per control, in the order they are read, and one more
    // Tab to prove the cycle closes on the first control instead of stranding
    // the keyboard at the bottom of the form.
    final forward = <String>[];
    for (var i = 0; i < _readingOrder.length; i++) {
      forward.add(await tab(tester));
    }
    expect(forward, _readingOrder);
    expect(await tab(tester), _readingOrder.first);

    // Backward from that same first control: Shift+Tab wraps to the last
    // control and then retraces the sequence in reverse.
    final backward = <String>[];
    for (var i = 0; i < _readingOrder.length; i++) {
      backward.add(await shiftTab(tester));
    }
    expect(backward, [
      ..._readingOrder.reversed.take(_readingOrder.length - 1),
      _readingOrder.first,
    ]);
  });

  testWidgets('Space and Enter flip the focused switch', (tester) async {
    final container = await pumpScreen(tester);
    expect(container.read(historyConfigProvider).showCommitGraph, isTrue);

    await tabTo(tester, 'switch:Show Commit Graph');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(container.read(historyConfigProvider).showCommitGraph, isFalse);
    // The rendered switch follows the setting, not only the provider.
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Show Commit Graph'),
          )
          .value,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(container.read(historyConfigProvider).showCommitGraph, isTrue);

    // Focus stayed on the switch, so a second toggle needs no renavigation.
    expect(_focusedControl(), 'switch:Show Commit Graph');
  });

  testWidgets('Enter opens a dropdown, the arrows pick a value, Enter commits', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    expect(
      container.read(uiConfigProvider).colorScheme,
      AppColorScheme.deepPurple,
    );

    await tabTo(tester, 'dropdown:AppColorScheme.deepPurple');

    // 'Teal' tells an open menu from a closed one: every item also lives in the
    // closed button's IndexedStack, where it is built but never painted or
    // hit-tested, and a scheme that is not the chosen one is shown nowhere
    // else on the screen.
    expect(find.text('Teal').hitTestable(), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Teal').hitTestable(), findsOneWidget);

    // The menu opens on the current value, so one ArrowDown moves to the next
    // scheme and Enter commits that one.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(container.read(uiConfigProvider).colorScheme, AppColorScheme.indigo);
    // The menu is gone, and both the row's subtitle and the closed button now
    // read the chosen scheme.
    expect(find.text('Teal').hitTestable(), findsNothing);
    expect(find.text('Indigo').hitTestable(), findsNWidgets(2));
  });

  testWidgets('Escape closes an open dropdown without changing the value', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    await tabTo(tester, 'dropdown:AppAnimationSpeed.normal');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Slow').hitTestable(), findsOneWidget);

    // Move the highlight first: Escape must discard the pending choice, not
    // commit whatever the arrows landed on.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Slow').hitTestable(), findsNothing);
    expect(
      container.read(uiConfigProvider).animationSpeed,
      AppAnimationSpeed.normal,
    );
    // Focus returns to the dropdown, so the sequence can carry on from here.
    expect(_focusedControl(), 'dropdown:AppAnimationSpeed.normal');
  });

  testWidgets('Enter on a section header collapses it and empties its Tab '
      'cycle', (tester) async {
    await pumpScreen(tester);

    // The section's own height is what collapsing changes; the card shrinks
    // back to its header.
    double sectionHeight() => tester
        .getSize(
          find.ancestor(
            of: find.text('Animations'),
            matching: find.byType(SettingsSection),
          ),
        )
        .height;
    final expanded = sectionHeight();

    await tabTo(tester, 'sectionHeader:Animations');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // The section is closed, and its controls have left the cycle with it:
    // the next Tab skips straight to the following section's header.
    expect(sectionHeight(), lessThan(expanded));
    expect(await tab(tester), 'sectionHeader:History');

    // Shift+Tab back onto the header and Space opens it again.
    expect(await shiftTab(tester), 'sectionHeader:Animations');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(sectionHeight(), expanded);
    expect(await tab(tester), 'dropdown:AppAnimationSpeed.normal');
  });

  testWidgets('a focused dialog field keeps the keys the screen would use', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    // The commit limit is only editable through its dialog, so reaching that
    // dialog from the keyboard is part of the screen's contract.
    await tabTo(tester, 'iconButton:Edit'); // default user name
    await tabTo(tester, 'iconButton:Edit'); // default user email
    await tabTo(tester, 'iconButton:Edit'); // default commit limit
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // 'Commits' is the dialog field's label; the row behind it is titled
    // 'Default Commit Limit', so this text appears only while the dialog is up.
    expect(find.text('Commits'), findsOneWidget);
    // The dialog autofocuses its field on the current value, which is where
    // the guard applies.
    expect(_editableHasFocus(), isTrue);
    expect(_fieldText(tester), '100');

    // Keys the screen behind the dialog binds: Space activates whatever holds
    // focus, the arrows walk a list. While the field has focus they are the
    // field's, so neither the switch nor the section behind the dialog reacts
    // and the keyboard stays in the field.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(container.read(historyConfigProvider).showCommitGraph, isTrue);
    expect(find.text('Commits'), findsOneWidget);
    expect(_editableHasFocus(), isTrue);

    // Escape belongs to the filled field first: it clears the text and keeps
    // the keyboard there, so a typo is corrected without leaving the dialog.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_fieldText(tester), isEmpty);
    expect(find.text('Commits'), findsOneWidget);
    expect(_editableHasFocus(), isTrue);

    // The empty field passes the second Escape on to the dialog, which closes
    // with the setting untouched.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Commits'), findsNothing);
    expect(container.read(historyConfigProvider).defaultCommitLimit, 100);
  });
}
