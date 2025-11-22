import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'generated/app_localizations.dart';
import 'shared/theme/app_theme.dart';
import 'shared/components/base_label.dart';
import 'core/config/app_config.dart';
import 'core/config/config_providers.dart';
import 'core/config/config_service.dart';
import 'core/navigation/app_shell.dart';
import 'core/services/logger_service.dart';
import 'core/services/version_service.dart';
import 'core/services/update_providers.dart';
import 'core/services/notification_service.dart';
import 'features/merge/conflict_resolution_screen.dart';

// Global navigator key to show notifications from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final initialConfig = await ConfigService.load();
  Logger.info(
    '[MAIN] Configuration loaded: colorScheme=${initialConfig.ui.colorScheme}, fontFamily=${initialConfig.ui.fontFamily}',
  );

  // Initialize timeago locales for all supported languages
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('de', timeago.DeMessages());
  timeago.setLocaleMessages('es', timeago.EsMessages());
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('it', timeago.ItMessages());
  timeago.setLocaleMessages('ru', timeago.RuMessages());
  timeago.setLocaleMessages('tr', timeago.TrMessages());
  timeago.setLocaleMessages('zh', timeago.ZhMessages());

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
      size: Size(1728, 972), // FHD (1920x1080) minus 10%
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Color(0x00000000),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Flutter GitUI',
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
  }

  @override
  Widget build(BuildContext context) {
    Logger.debug('[APP] Building FlutterGitUIApp, showSplash=$_showSplash');

    // Show splash screen with CORRECT colors from pre-loaded config
    if (_showSplash) {
      return _NativeLoadingScreen(config: widget.initialConfig);
    }

    // Initialize update checker on startup (after config is loaded)
    // Load dismissed update version and check for updates 5 seconds after app starts
    Future.delayed(const Duration(seconds: 5), () async {
      await loadDismissedUpdateVersion(ref);
      await checkForUpdates(ref);
    });

    // Config loaded - now we can read user's theme preferences
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final localeCode = ref.watch(localeProvider);
    final animationSpeed = ref.watch(uiConfigProvider).animationSpeed;

    return MaterialApp(
      navigatorKey: navigatorKey,
      key: ValueKey('$fontSize-$fontFamily-$colorScheme-$animationSpeed'),
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
        Locale('ar'), // Arabic
        Locale('de'), // German
        Locale('es'), // Spanish
        Locale('fr'), // French
        Locale('it'), // Italian
        Locale('ru'), // Russian
        Locale('tr'), // Turkish
        Locale('zh'), // Chinese (Simplified)
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

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
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
              HeadlineMediumLabel(
                'Flutter GitUI',
                color: primaryColor,
              ),
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
