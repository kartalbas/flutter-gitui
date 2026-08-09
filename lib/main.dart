import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'generated/app_localizations.dart';
import 'shared/theme/app_theme.dart';
import 'shared/components/base_dialog.dart';
import 'shared/components/base_label.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/config/config_providers.dart';
import 'core/config/config_service.dart';
import 'core/navigation/app_shell.dart';
import 'core/services/logger_service.dart';
import 'core/services/version_service.dart';
import 'core/services/update_check_policy.dart';
import 'core/services/update_providers.dart';
import 'core/services/notification_service.dart';
import 'features/merge/conflict_resolution_screen.dart';

// Global navigator key to show notifications from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  registerSkins();

  // Initialize logger FIRST so we can see all startup logs
  await Logger.init();

  // Capture all Flutter errors and log them + show notifications
  FlutterError.onError = (FlutterErrorDetails details) {
    final error = details.exception.toString();
    Logger.error('[FLUTTER ERROR] $error');
    Logger.error('[STACK TRACE] ${details.stack}');

    // Also call the default handler to show error in debug console
    FlutterError.presentError(details);

    // Show error notification
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      NotificationService.showError(context, 'Flutter Error: $error');
    }
  };

  // Capture errors outside Flutter framework (async errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorMsg = error.toString();
    Logger.error('[PLATFORM ERROR] $errorMsg');
    Logger.error('[STACK TRACE] $stack');

    // Show error notification
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      NotificationService.showError(context, 'Platform Error: $errorMsg');
    }

    return true; // Handled
  };

  // Load config synchronously BEFORE building any UI
  // This ensures splash screen displays with correct colors from first frame
  Logger.info('[MAIN] Loading configuration before UI initialization');
  // A damaged config file must never prevent the app from starting: unwrap()
  // here would throw before runApp() and leave the user with a window that
  // never appears and no way to repair the file from inside the app.
  final configResult = await ConfigService.load();
  final initialConfig = configResult.when(
    success: (config) => config,
    failure: (message, error, stackTrace) {
      Logger.error('[MAIN] Configuration could not be loaded: $message');
      unawaited(_backupUnreadableConfig());
      return AppConfig.defaults;
    },
  );
  Logger.info(
    '[MAIN] Configuration loaded: colorScheme=${initialConfig.ui.colorScheme}, fontFamily=${initialConfig.ui.fontFamily}',
  );

  // Initialize timeago locales for all supported languages
  timeago.setLocaleMessages('de', timeago.DeMessages());
  timeago.setLocaleMessages('es', timeago.EsMessages());
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('it', timeago.ItMessages());
  timeago.setLocaleMessages('tr', timeago.TrMessages());

  // Detect WSL2 environment and log for user awareness
  // Note: Environment variables must be set before launching the app
  // Users should set: export GDK_SYNCHRONIZE=0 before running flutter_gitui
  if (Platform.isLinux && !kIsWeb) {
    final isWSL2 = await _detectWSL2();
    if (isWSL2) {
      Logger.info('WSL2 environment detected');
      // Check if optimization env vars are set
      final gdkSync = Platform.environment['GDK_SYNCHRONIZE'];
      final flutterVsync = Platform.environment['FLUTTER_NO_WAIT_FOR_VSYNC'];

      if (gdkSync != '0' || flutterVsync != '1') {
        Logger.warning('WSL2 detected but rendering optimizations not applied');
        Logger.warning(
          'To reduce flickering, set environment variables before launching:',
        );
        Logger.warning('  export GDK_SYNCHRONIZE=0');
        Logger.warning('  export FLUTTER_NO_WAIT_FOR_VSYNC=1');
      } else {
        Logger.info('WSL2 rendering optimizations are active');
      }
    }
  }

  // Disable Google Fonts runtime fetching - all fonts are bundled locally
  // Fonts are pre-downloaded and included in assets/google_fonts/
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize version service for tracking app version and "What's New"
  final versionService = VersionService();
  await versionService.initialize();

  // Setup window for desktop (not web)
  if (!kIsWeb) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(
        AppConstants.defaultWindowWidth,
        AppConstants.defaultWindowHeight,
      ),
      minimumSize: Size(
        AppConstants.minWindowWidth,
        AppConstants.minWindowHeight,
      ),
      center: true,
      backgroundColor: Color(0x00000000),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appName,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        // Override configProvider with pre-loaded config
        // This ensures config is available from first frame
        configProvider.overrideWith(
          (ref) => ConfigNotifier.withConfig(ref, initialConfig),
        ),
      ],
      child: FlutterGitUIApp(initialConfig: initialConfig),
    ),
  );
}

/// The design language the application renders under.
///
/// An id rather than a class, because that is what a saved preference, a test
/// parameterisation and a bug report all name, and because the settings picker
/// that will let a user change it (P6) resolves exactly this way. It is the one
/// place outside [registerSkins] where the application says which language it
/// is in.
const String kShippingSkinId = 'material';

/// Adds this build's design languages to the registry (#249, P2).
///
/// This is the whole of what "plugin" can mean on a desktop AOT build with no
/// dynamic code loading: one pubspec dependency and one `register()` call.
/// Nothing else in the application learns either package's name - every other
/// file reaches the active language through `SkinScope`, which is the property
/// the blueprint exists to falsify.
///
/// The blueprint registers only in debug. It is an instrument, not a look: a
/// user who selected it would find the application drawn in blue outlines on
/// white paper, which is exactly what makes it useful to a developer measuring
/// where design still leaks out of the skin and into `lib/`.
///
/// Public, and idempotent, because [FlutterGitUIApp] can be booted without
/// going through [main] - a test that pumps the real application root does
/// exactly that - and an application root whose skin is not registered fails on
/// the first frame. `SkinRegistry.register` returns early for a skin EQUAL to
/// the one already under that id, so calling this from both places costs
/// nothing however often it happens.
void registerSkins() {
  MaterialSkin.register();
  if (kDebugMode) {
    BlueprintSkin.register();
  }
}

/// The user's configuration, as the data a skin resolves a look from.
///
/// Every value crosses as a *question* rather than as an answer: a seed index
/// rather than a `Color`, a multiplier rather than a `Duration`, a family name
/// rather than a `TextStyle`. That is the spine rule seen from the application's
/// side - there is no design value here for `lib/` to hold, only the user's
/// choices for the skin to interpret.
SkinRequest _skinRequest({
  required Brightness brightness,
  required AppColorScheme colorScheme,
  required AppFontSize fontSize,
  required AppFontSize codeFontSize,
  required AppAnimationSpeed animationSpeed,
  required String uiFamily,
  required String monoFamily,
}) => SkinRequest(
  brightness: brightness,
  // The seed is the enum's declaration index and nothing more. What a skin
  // makes of it - a Material tonal palette, the host system accent, a fixed
  // AppKit blue - is the skin's answer to the question "which colour is this
  // application's own".
  accentSeed: colorScheme.index,
  textScale: _kTextScale[fontSize]!,
  codeScale: _kCodeScale[codeFontSize]!,
  animationScale: _kAnimationScale[animationSpeed]!,
  monoFamily: monoFamily,
  uiFamily: uiFamily,
);

/// The multiplier each font-size setting means, matching `AppTheme`'s own
/// `_fontSizeFactor` exactly so the skin's ramp resolves to the sizes the
/// application has always rendered.
const Map<AppFontSize, double> _kTextScale = <AppFontSize, double>{
  AppFontSize.tiny: 0.85,
  AppFontSize.small: 0.92,
  AppFontSize.medium: 1.0,
  AppFontSize.large: 1.10,
};

/// The multiplier each CODE font-size setting means - the size half of the
/// decision whose family half is `SkinRequest.monoFamily`, both fed from the
/// same Settings section ("Code Font Size", `AppConfig.previewFontSize`).
///
/// The factors are the diff viewer's own, moved: `_getFontSizeScale` applied
/// exactly these to every diff and preview line the owner has verified, and
/// they are deliberately NOT `_kTextScale`'s - the two settings have always
/// meant different steps.
const Map<AppFontSize, double> _kCodeScale = <AppFontSize, double>{
  AppFontSize.tiny: 0.8,
  AppFontSize.small: 0.9,
  AppFontSize.medium: 1.0,
  AppFontSize.large: 1.15,
};

/// Which brightness the user's [themeMode] resolves to right now.
///
/// The same rule `MaterialApp` applies to its own `theme`/`darkTheme` pair
/// (Flutter 3.44.4 packages/flutter/lib/src/material/app.dart,
/// `_MaterialAppState._materialBuilder`): the mode decides, and `system` is
/// answered by the platform.
///
/// It is answered here rather than read back off `Theme.of(context).brightness`
/// - which looks like the more honest source and is not. `MaterialApp` puts an
/// `AnimatedTheme` above this builder, so during a light/dark switch the theme
/// resolved here is the *lerping* one, and `ThemeData.lerp` picks `brightness`
/// as a step at the halfway point rather than blending it. Reading it back
/// therefore holds the request at the old brightness for the first half of the
/// transition and flips it in one frame, which is a hard cut in the middle of
/// what the user experiences as a dissolve. Deriving it from the mode makes the
/// request change on the frame the user asked for it, and the skin's own
/// `AnimatedTheme` (see `chrome.wrapRoot`) does the dissolving.
Brightness _brightnessFor(BuildContext context, ThemeMode themeMode) =>
    switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

/// Re-publishes the application's own `ThemeExtension`s below the skin.
///
/// **A bridge with a known end date, not a design.** `chrome.wrapRoot` installs
/// the skin's `ThemeData`, and a `ThemeData` carries its extensions with it, so
/// everything the application attached to its own theme stops existing for
/// every widget below the scope. Two extensions are attached today and both are
/// still read by widgets that P2 could not migrate:
///
///  * `AnimationSpeedExtension` - the user's Settings -> Animation choice, read
///    by `base_animated_widgets.dart` (every `BasePopupMenuButton`'s open
///    duration), `base_switcher.dart` (the toolbar pickers suppress splash,
///    highlight and hover ink entirely at "none"), `branch_switcher.dart` (the
///    branch menu) and `branches_screen.dart` (the tab controller). Dropping it
///    silently turns reduced motion back on for all four, which is an
///    accessibility setting failing quietly rather than a look changing.
///  * `GitSemanticColors` - inert either way, because `context.gitColors` falls
///    back to exactly the per-brightness palette `AppTheme` attaches. It is
///    carried anyway rather than argued about: the rule is that the seam does
///    not eat what the application published, and a rule with one exception in
///    it is a rule nobody can apply.
///
/// Each of the four readers goes away with the member that owns its motion -
/// `overlays.presentMenu` for the two menus, `chrome.shell` for the pickers,
/// `surfaces.tabs` for the tab set - at which point the application holds no
/// motion value at all and this widget goes with them.
///
/// **The list is asked of [AppTheme.themeExtensions] rather than read off the
/// ambient theme with `Theme.of(context).extensions`, and the difference is
/// visible on screen.** Reading the theme here makes this builder depend on it,
/// and `MaterialApp` re-runs the builder on every tick of its own theme lerp -
/// so the skin's root treatment would be handed a freshly built `ThemeData`
/// sixty times a second. `ThemeData` equality cannot see through the
/// `WidgetStateProperty` closures the chip sub-theme carries, so every one of
/// those looks like a new target and restarts the skin's cross-fade from where
/// it had got to. Measured: the light-to-dark dissolve turned into a
/// decelerating ramp that took roughly twice as long to arrive. Asking the
/// configuration instead leaves this builder with no dependency on the theme at
/// all, so it runs once per settings change and the cross-fade runs once.
class _ApplicationThemeExtensions extends StatelessWidget {
  const _ApplicationThemeExtensions({
    required this.extensions,
    required this.child,
  });

  /// What the application root attached to its own theme.
  final Iterable<ThemeExtension<dynamic>> extensions;

  /// The application, below the skin's root treatment.
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    // `Theme.of` here is the skin's theme, so this adds the extensions to it
    // and changes nothing else about it: same colour scheme, same type ramp,
    // same sub-themes, same icon theme.
    data: Theme.of(context).copyWith(extensions: extensions),
    child: child,
  );
}

/// The multiplier each animation-speed setting means, matching
/// `AppTheme.getAnimationDuration`. Zero is "no motion", which a skin honours
/// by resolving every motion role to nothing.
const Map<AppAnimationSpeed, double> _kAnimationScale =
    <AppAnimationSpeed, double>{
      AppAnimationSpeed.none: 0.0,
      AppAnimationSpeed.fast: 0.7,
      AppAnimationSpeed.normal: 1.0,
      AppAnimationSpeed.slow: 1.5,
    };

class FlutterGitUIApp extends ConsumerStatefulWidget {
  final AppConfig initialConfig;

  const FlutterGitUIApp({super.key, required this.initialConfig});

  @override
  ConsumerState<FlutterGitUIApp> createState() => _FlutterGitUIAppState();
}

class _FlutterGitUIAppState extends ConsumerState<FlutterGitUIApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Show splash screen for 2 seconds for branding
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });

    // Ask five seconds after launch whether an update check is due. The user
    // owns this schedule (#294): the frequency setting decides, "never" sends
    // no request at all, and a failed check stays in the log and in Settings
    // instead of opening anything over the user's work.
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await loadDismissedUpdateVersion(ref);
      if (!mounted) return;
      final updates = ref.read(configProvider).updates;
      final checkIsDue = shouldCheckForUpdates(
        frequency: updates.checkFrequency,
        lastCheck: updates.lastCheckTime,
        now: DateTime.now(),
      );
      if (!checkIsDue) return;
      await checkForUpdates(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    Logger.debug('[APP] Building FlutterGitUIApp, showSplash=$_showSplash');

    // Show splash screen with CORRECT colors from pre-loaded config
    if (_showSplash) {
      return _NativeLoadingScreen(config: widget.initialConfig);
    }

    // Config loaded - now we can read user's theme preferences
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final localeCode = ref.watch(localeProvider);
    final animationSpeed = ref.watch(uiConfigProvider).animationSpeed;
    final previewFontFamily = ref.watch(uiConfigProvider).previewFontFamily;
    final previewFontSize = ref.watch(uiConfigProvider).previewFontSize;

    // Deliberately NO `key:` here (#425). A ValueKey over the four appearance
    // settings used to force the whole MaterialApp to remount on every change,
    // demolition standing in for propagation. Every consumer already follows
    // the ordinary channels - the providers rebuild this widget, the builder
    // re-runs with the new values, `SkinScope` notifies on a request change,
    // and the re-published theme extensions notify their readers - so the
    // remount had nothing left to do except cost: it discarded the
    // ScaffoldMessenger (killing any visible notice) and replaced the theme
    // dissolve with a hard cut. The `navigatorKey` GlobalKey even reparented
    // the navigator subtree through each remount, so the "clean slate" the key
    // suggested never actually happened. test/settings_propagation_test.dart
    // proves each of the four settings still reaches the pixels, and that a
    // settings change no longer tears the application down.
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: localeCode != null ? Locale(localeCode) : null,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('de'), // German
        Locale('es'), // Spanish
        Locale('fr'), // French
        Locale('it'), // Italian
        Locale('tr'), // Turkish
      ],
      theme: AppTheme.lightTheme(
        colorScheme: colorScheme,
        fontFamily: fontFamily,
        fontSize: fontSize,
        animationSpeed: animationSpeed,
      ),
      darkTheme: AppTheme.darkTheme(
        colorScheme: colorScheme,
        fontFamily: fontFamily,
        fontSize: fontSize,
        animationSpeed: animationSpeed,
      ),
      themeMode: themeMode,
      builder: (context, child) {
        // Apply text scale factor based on font size setting
        double textScaleFactor;
        switch (fontSize) {
          case AppFontSize.tiny:
            textScaleFactor = 0.8;
            break;
          case AppFontSize.small:
            textScaleFactor = 0.9;
            break;
          case AppFontSize.medium:
            textScaleFactor = 1.0;
            break;
          case AppFontSize.large:
            textScaleFactor = 1.15;
            break;
        }

        // The skin is installed BENEATH the single application root and above
        // the navigator, which is where SKIN-CONTRACT.md §2.7 puts it: the one
        // `WidgetsApp` stays exactly here and the design language wraps under
        // it. `SkinScope.install` is what plants the skin-painted fence, makes
        // the skin reachable from every widget below, and calls
        // `chrome.wrapRoot` - so from this line on the running application's
        // theme, its type ramp and its glyph treatment come out of a package
        // that `lib/` names in exactly one file.
        // One answer, used twice: the request the skin resolves its look from
        // and the palette the application's own extensions carry have to be
        // talking about the same brightness, or a theme switch would recolour
        // the surfaces and leave the git colours behind.
        final Brightness brightness = _brightnessFor(context, themeMode);

        return SkinScope.install(
          skin: SkinRegistry.byId(kShippingSkinId),
          request: _skinRequest(
            brightness: brightness,
            colorScheme: colorScheme,
            fontSize: fontSize,
            codeFontSize: previewFontSize,
            animationSpeed: animationSpeed,
            uiFamily: fontFamily,
            monoFamily: previewFontFamily,
          ),
          // The application's own dialog keyboard contract, installed once
          // here so it travels with the envelope into every route a skin
          // pushes. Escape cancels and Enter submits are WHAT THE USER CAN DO,
          // so no skin may weaken them - and making the host a required
          // argument of the one installation point is what stops it being
          // dropped by forgetting to opt in.
          dialogKeyboardHost:
              (BuildContext context, DialogSpec spec, Widget surface) =>
                  DialogKeyboardHost(
                    barrierDismissible: spec.barrierDismissible,
                    onSubmit: spec.onSubmit,
                    child: surface,
                  ),
          app: ContentPort(
            _ApplicationThemeExtensions(
              extensions: AppTheme.themeExtensions(
                brightness: brightness,
                animationSpeed: animationSpeed,
              ),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
                child: child!,
              ),
            ),
          ),
        );
      },
      home: const AppShell(),
      routes: {'/conflicts': (context) => const ConflictResolutionScreen()},
    );
  }
}

/// Native loading screen shown with CORRECT colors from pre-loaded config
/// Shows for 2 seconds for branding purposes
class _NativeLoadingScreen extends StatelessWidget {
  final AppConfig config;

  const _NativeLoadingScreen({required this.config});

  @override
  Widget build(BuildContext context) {
    Logger.debug(
      '[SPLASH] Building with colorScheme=${config.ui.colorScheme}, fontFamily=${config.ui.fontFamily}',
    );

    // Use pre-loaded config to generate theme
    final lightTheme = AppTheme.lightTheme(
      colorScheme: config.ui.colorScheme,
      fontFamily: config.ui.fontFamily,
      fontSize: AppFontSize.medium,
      animationSpeed: AppAnimationSpeed.normal,
    );
    final darkTheme = AppTheme.darkTheme(
      colorScheme: config.ui.colorScheme,
      fontFamily: config.ui.fontFamily,
      fontSize: AppFontSize.medium,
      animationSpeed: AppAnimationSpeed.normal,
    );

    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = brightness == Brightness.dark;
    final theme = isDark ? darkTheme : lightTheme;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.colorScheme.primary;
    final subtextColor = theme.colorScheme.onSurfaceVariant;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon/logo
              Icon(
                PhosphorIconsBold.gitBranch,
                size: AppTheme.iconXL * 3 + AppTheme.paddingS,
                color: primaryColor,
              ),
              const SizedBox(height: AppTheme.paddingXL),
              // App title
              HeadlineMediumLabel('Flutter GitUI', color: primaryColor),
              const SizedBox(height: AppTheme.iconXL * 2),
              // Loading indicator
              SizedBox(
                width: 200,
                height: 3,
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  backgroundColor: primaryColor.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: AppTheme.paddingM),
              // Loading text
              BodyMediumLabel('Initializing...', color: subtextColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detect if running in WSL2 environment
/// Checks for WSL-specific environment variables and /proc/version
Future<bool> _detectWSL2() async {
  try {
    // Check for WSL environment variable
    if (Platform.environment.containsKey('WSL_DISTRO_NAME') ||
        Platform.environment.containsKey('WSL_INTEROP')) {
      return true;
    }

    // Check /proc/version for Microsoft/WSL2 kernel
    final procVersion = File('/proc/version');
    if (await procVersion.exists()) {
      final content = await procVersion.readAsString();
      if (content.toLowerCase().contains('microsoft') ||
          content.toLowerCase().contains('wsl2')) {
        return true;
      }
    }
  } catch (e) {
    Logger.warning('Failed to detect WSL2 environment', e);
  }

  return false;
}

/// Moves an unreadable configuration file aside so the app can start with
/// defaults without silently discarding whatever the user had configured.
///
/// Writing defaults over a merely unparseable file would destroy the user's
/// repositories and workspaces; keeping a timestamped copy lets them recover
/// or report it.
Future<void> _backupUnreadableConfig() async {
  try {
    final path = await ConfigService.getConfigFilePath();
    final file = File(path);
    if (!await file.exists()) return;

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final backup = '$path.corrupt-$stamp.bak';
    await file.copy(backup);
    Logger.warning('[MAIN] Unreadable configuration backed up to $backup');
  } catch (e) {
    Logger.error('[MAIN] Could not back up unreadable configuration: $e');
  }
}
