import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/managed_install.dart';
import '../../core/services/update_service.dart';
import '../../core/services/update_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/exit_guard.dart';
import '../../core/services/progress_service.dart';
import '../../generated/app_localizations.dart';
import '../components/base_dialog.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';

/// Dialog shown when an update is available
class UpdateAvailableDialog extends ConsumerStatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateAvailableDialog({super.key, required this.updateInfo});

  @override
  ConsumerState<UpdateAvailableDialog> createState() =>
      _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends ConsumerState<UpdateAvailableDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final staged = ref.watch(readyUpdateProvider);
    final hasStagedDownload =
        staged != null && staged.info.version == widget.updateInfo.version;

    return BaseDialog(
      title: l10n.updateAvailableTitle,
      icon: IconRole.downloadSimple,
      variant: DialogVariant.normal,
      maxWidth: 600,
      onSubmit: _isDownloading ? null : _downloadAndInstall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version info
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            // The panel names the foreground that pairs with its own fill, so
            // the two lines inside it do not have to name it again — and cannot
            // disagree with it.
            child: DefaultTextStyle.merge(
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
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
                        BaseLabel(
                          l10n.updateVersionHeading(widget.updateInfo.version),
                          role: TextRole.sectionTitle,
                        ),
                        const SizedBox(height: AppTheme.paddingXS),
                        BaseLabel(
                          l10n.updateReleasedOn(
                            _formatDate(context, widget.updateInfo.releaseDate),
                            widget.updateInfo.fileSizeFormatted,
                          ),
                          role: TextRole.detail,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.paddingL),

          // Changelog
          if (widget.updateInfo.changelog.isNotEmpty) ...[
            BaseLabel(l10n.updateWhatsNew, role: TextRole.sectionTitle),
            const SizedBox(height: AppTheme.paddingS),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: BaseLabel(
                  widget.updateInfo.changelog,
                  role: TextRole.body,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.paddingL),
          ],

          // Download progress
          if (_isDownloading) ...[
            BaseLabel(
              l10n.updateDownloadingProgress,
              role: TextRole.detail,
              tone: Tone.accent,
            ),
            const SizedBox(height: AppTheme.paddingS),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BaseLabel(
              '${(_downloadProgress * 100).toStringAsFixed(0)}%',
              role: TextRole.detail,
              tone: Tone.muted,
            ),
          ],

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.paddingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
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
                    // The error panel states its own paired foreground; the
                    // message inside reads it.
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      child: BaseLabel(_errorMessage!, role: TextRole.detail),
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
                    child: BaseLabel(
                      l10n.updateDontShowAgain,
                      role: TextRole.detail,
                      tone: Tone.muted,
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
          // Skipping this version records the choice and closes: it is how
          // the user declines the update, so it is the dismissal.
          DialogAction(
            label: l10n.skip,
            role: DialogActionRole.dismissive,
            onPressed: _handleSkipUpdate,
          ),
          // Downloading in the browser is a second, manual way forward - a
          // peer of installing, not the way the dialog is asking about.
          DialogAction(
            label: l10n.updateDownloadOnly,
            role: DialogActionRole.neutral,
            icon: IconRole.arrowSquareOut,
            onPressed: _openDownloadInBrowser,
          ),
          DialogAction(
            label: hasStagedDownload
                ? l10n.restartAndInstall
                : l10n.updateDownloadAndInstall,
            role: DialogActionRole.affirmative,
            onPressed: _downloadAndInstall,
          ),
        ] else ...[
          // Mid-download the affirmative action is still the affirmative one,
          // just not invokable, so the dialog keeps exactly one.
          DialogAction(
            label: l10n.updateDownloadingButton,
            role: DialogActionRole.affirmative,
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
    // Read before the first await: the messages are needed in branches that
    // run after it, where reaching for the context again is the unsafe form.
    final l10n = AppLocalizations.of(context)!;
    final url = Uri.parse(widget.updateInfo.downloadUrl);
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        Logger.error('Could not launch URL: $url');
        if (mounted) {
          setState(() {
            _errorMessage = l10n.updateBrowserOpenFailed(
              widget.updateInfo.downloadUrl,
            );
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
          _errorMessage = l10n.updateBrowserOpenError(e.toString());
        });
      }
    }
  }

  /// When the release appeared, in the language the application is running in.
  ///
  /// timeago defaults to English whatever the locale, which put "2 days ago"
  /// into an otherwise translated dialog; main.dart registers the messages for
  /// all six locales, so the current one only has to be named here.
  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Use timeago for recent dates (within a week)
    if (difference.inDays < 7) {
      return timeago.format(
        date,
        locale: Localizations.localeOf(context).languageCode,
      );
    } else {
      // Use ISO date format for older dates
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Whether exiting for the installer is acceptable right now.
  ///
  /// Refuses while a git operation is in flight - the exit would kill the
  /// process in the middle of it - and asks before discarding unsaved input
  /// such as a commit message being written.
  Future<bool> _confirmReadyToRestart() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;

    if (ref.read(progressProvider.notifier).hasActiveOperation) {
      await showDialog<void>(
        context: context,
        builder: (context) => BaseDialog(
          title: l10n.updateOperationRunningTitle,
          icon: IconRole.warningCircle,
          onSubmit: () => Navigator.of(context).pop(),
          content: BaseLabel(
            l10n.updateOperationRunningBody,
            role: TextRole.body,
          ),
          actions: [
            DialogAction(
              label: l10n.ok,
              role: DialogActionRole.affirmative,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return false;
    }

    if (ref.read(unsavedInputProvider).isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => BaseDialog(
          title: l10n.updateUnsavedInputTitle,
          icon: IconRole.warningCircle,
          variant: DialogVariant.destructive,
          content: BaseLabel(l10n.updateUnsavedInputBody, role: TextRole.body),
          actions: [
            DialogAction(
              label: l10n.cancel,
              role: DialogActionRole.dismissive,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            // Installing anyway exits the app over unsaved input, which is
            // what makes it destructive rather than merely affirmative.
            DialogAction(
              label: l10n.installAnyway,
              role: DialogActionRole.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      return proceed == true;
    }

    return true;
  }

  Future<void> _downloadAndInstall() async {
    // Every failure below is reported after an await, so the translations are
    // taken once here while the context is still known to be current.
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      // Last line of defence: every path that opens this dialog is closed for
      // an installation a package manager owns, but installing into one is the
      // failure that corrupts it silently -- winget keeps recording the old
      // version and overwrites the files again on its next upgrade -- so it is
      // refused here too rather than trusted to stay unreachable (#364).
      final managed = ref.read(managedInstallProvider);
      if (managed != null) {
        setState(() {
          _errorMessage = managed.explanation(l10n);
          _isDownloading = false;
        });
        return;
      }

      // A download staged in the background for exactly this version skips
      // the transfer; its digest was already verified against the manifest.
      final staged = ref.read(readyUpdateProvider);
      String filePath;
      if (staged != null &&
          staged.info.version == widget.updateInfo.version &&
          File(staged.filePath).existsSync()) {
        filePath = staged.filePath;
      } else {
        filePath = await UpdateService.downloadUpdate(
          widget.updateInfo,
          onProgress: (progress) {
            // The dialog can be dismissed mid-download and this callback
            // fires from inside the download stream: an unguarded setState
            // threw there and aborted the transfer.
            if (!mounted) return;
            setState(() {
              _downloadProgress = progress;
            });
          },
        ).then((result) => result.unwrapOr(''));
      }

      if (filePath.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = l10n.updateDownloadFailed;
            _isDownloading = false;
          });
        }
        return;
      }

      // Install update
      if (mounted) {
        // Installing replaces the running application and closes it, so this
        // is the last moment to notice work the exit would destroy (#294).
        final readyToRestart = await _confirmReadyToRestart();
        if (!readyToRestart) {
          if (mounted) {
            setState(() {
              _isDownloading = false;
            });
          }
          return;
        }
        if (!mounted) return;
        Logger.info('Starting update installation...', forceConsole: true);
        Logger.info('Update file: $filePath', forceConsole: true);

        final success = await UpdateService.installUpdate(
          filePath,
        ).then((result) => result.unwrapOr(false));

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
              _errorMessage = l10n.updateInstallFailed;
              _isDownloading = false;
            });
          }
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Error downloading/installing update', e, stackTrace, true);
      if (mounted) {
        setState(() {
          _errorMessage = l10n.updateUnexpectedError(e.toString());
          _isDownloading = false;
        });
      }
    }
  }
}
