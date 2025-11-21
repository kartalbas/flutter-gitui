import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/update_service.dart';
import '../../core/services/update_providers.dart';
import '../../core/services/logger_service.dart';
import '../components/base_dialog.dart';
import '../components/base_button.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';

/// Dialog shown when an update is available
class UpdateAvailableDialog extends ConsumerStatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateAvailableDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  ConsumerState<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends ConsumerState<UpdateAvailableDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseDialog(
      title: 'Update Available',
      icon: PhosphorIconsRegular.downloadSimple,
      variant: DialogVariant.normal,
      maxWidth: 600,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version info
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.package,
                  size: 24,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppTheme.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleSmallLabel(
                        'Version ${widget.updateInfo.version}',
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: AppTheme.paddingXS),
                      BodySmallLabel(
                        'Released ${_formatDate(widget.updateInfo.releaseDate)} • ${widget.updateInfo.fileSizeFormatted}',
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.paddingL),

          // Changelog
          if (widget.updateInfo.changelog.isNotEmpty) ...[
            TitleSmallLabel('What\'s New'),
            const SizedBox(height: AppTheme.paddingS),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: SingleChildScrollView(
                child: BodyMediumLabel(
                  widget.updateInfo.changelog,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.paddingL),
          ],

          // Download progress
          if (_isDownloading) ...[
            LabelMediumLabel(
              'Downloading update...',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppTheme.paddingS),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BodySmallLabel(
              '${(_downloadProgress * 100).toStringAsFixed(0)}%',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.paddingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 20,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodySmallLabel(
                      _errorMessage!,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Checkbox for dismissing update
          if (!_isDownloading) ...[
            const SizedBox(height: AppTheme.paddingL),
            const Divider(),
            const SizedBox(height: AppTheme.paddingM),
            Row(
              children: [
                Checkbox(
                  value: _dontShowAgain,
                  onChanged: (value) {
                    setState(() {
                      _dontShowAgain = value ?? false;
                    });
                  },
                ),
                const SizedBox(width: AppTheme.paddingS),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _dontShowAgain = !_dontShowAgain;
                      });
                    },
                    child: BodySmallLabel(
                      "Don't show this update again",
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading) ...[
          BaseButton(
            label: 'Skip',
            variant: ButtonVariant.tertiary,
            onPressed: _handleSkipUpdate,
          ),
          BaseButton(
            label: 'Download Only',
            variant: ButtonVariant.secondary,
            leadingIcon: PhosphorIconsRegular.arrowSquareOut,
            onPressed: _openDownloadInBrowser,
          ),
          BaseButton(
            label: 'Download & Install',
            variant: ButtonVariant.primary,
            onPressed: _downloadAndInstall,
          ),
        ] else ...[
          BaseButton(
            label: 'Downloading...',
            variant: ButtonVariant.primary,
            onPressed: null,
          ),
        ],
      ],
    );
  }

  Future<void> _handleSkipUpdate() async {
    if (_dontShowAgain) {
      // Save dismissed version to preferences
      await dismissUpdateVersion(ref, widget.updateInfo.version);
      Logger.info('User dismissed update ${widget.updateInfo.version}');
    }
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _openDownloadInBrowser() async {
    final url = Uri.parse(widget.updateInfo.downloadUrl);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        Logger.error('Could not launch URL: $url');
        if (mounted) {
          setState(() {
            _errorMessage = 'Could not open browser. Please download manually from:\n${widget.updateInfo.downloadUrl}';
          });
        }
      } else {
        Logger.info('Opened download URL in browser: $url');
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      }
    } catch (e) {
      Logger.error('Error launching URL', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error opening browser: ${e.toString()}';
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Use timeago for recent dates (within a week)
    if (difference.inDays < 7) {
      return timeago.format(date);
    } else {
      // Use ISO date format for older dates
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      // Download update
      final filePath = await UpdateService.downloadUpdate(
        widget.updateInfo,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (filePath == null) {
        setState(() {
          _errorMessage = 'Failed to download update. Please try again later.';
          _isDownloading = false;
        });
        return;
      }

      // Install update
      if (mounted) {
        Logger.info('Starting update installation...', forceConsole: true);
        Logger.info('Update file: $filePath', forceConsole: true);

        final success = await UpdateService.installUpdate(filePath);

        Logger.info('Update installation result: $success', forceConsole: true);

        if (success) {
          Logger.info('Update successful, closing app...', forceConsole: true);
          // Close dialog and exit app
          if (mounted) {
            Navigator.of(context).pop(true);
          }

          // Give a moment for dialog to close
          await Future.delayed(const Duration(milliseconds: 500));

          Logger.info('Exiting application...', forceConsole: true);
          // Exit app to allow update script to run
          exit(0);
        } else {
          Logger.error('Update installation returned false', null, null, true);
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to install update. Check logs for details.';
              _isDownloading = false;
            });
          }
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Error downloading/installing update', e, stackTrace, true);
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: ${e.toString()}';
          _isDownloading = false;
        });
      }
    }
  }
}
