import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../shared/dialogs/update_available_dialog.dart';
import '../../../features/changelog/changelog_dialog.dart';
import 'settings_section.dart';

/// Updates section for settings
class UpdatesSection extends ConsumerStatefulWidget {
  const UpdatesSection({super.key});

  @override
  ConsumerState<UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends ConsumerState<UpdatesSection> {
  String _currentVersion = 'Loading...';
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
    });

    try {
      Logger.info('Manual update check initiated');
      final updateInfo = await UpdateService.checkForUpdates().then((result) => result.unwrapOr(null));

      if (!mounted) return;

      if (updateInfo != null) {
        // Update available - show dialog
        Logger.info('Update found: ${updateInfo.version}');
        await showDialog(
          context: context,
          builder: (context) => UpdateAvailableDialog(updateInfo: updateInfo),
        );
      } else {
        // No update available - show message
        Logger.info('No updates found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You\'re up to date! (v$_currentVersion)'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Update check failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check for updates: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Updates',
      icon: PhosphorIconsRegular.downloadSimple,
      children: [
        // Current version
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.package,
                size: AppTheme.iconS,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingS),
              BodyMediumLabel(
                'Current Version',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const Spacer(),
              LabelLargeLabel(_currentVersion),
            ],
          ),
        ),

        const Divider(),

        // Check for Updates button
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: BaseButton(
            label: _isChecking ? 'Checking...' : 'Check for Updates',
            variant: ButtonVariant.primary,
            leadingIcon: _isChecking
                ? null
                : PhosphorIconsRegular.arrowsClockwise,
            isLoading: _isChecking,
            onPressed: _isChecking ? null : _checkForUpdates,
            fullWidth: true,
          ),
        ),

        // View Changelog button
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.paddingM,
            right: AppTheme.paddingM,
            bottom: AppTheme.paddingM,
          ),
          child: BaseButton(
            label: 'View Release History',
            variant: ButtonVariant.secondary,
            leadingIcon: PhosphorIconsRegular.clockCounterClockwise,
            onPressed: () {
              ChangelogDialog.show(context);
            },
            fullWidth: true,
          ),
        ),
      ],
    );
  }
}
