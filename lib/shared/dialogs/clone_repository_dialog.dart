import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../../core/git/git_service.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';

/// Dialog for cloning a Git repository
class CloneRepositoryDialog extends ConsumerStatefulWidget {
  const CloneRepositoryDialog({super.key});

  @override
  ConsumerState<CloneRepositoryDialog> createState() => _CloneRepositoryDialogState();
}

class _CloneRepositoryDialogState extends ConsumerState<CloneRepositoryDialog> {
  final _urlController = TextEditingController();
  final _pathController = TextEditingController();
  final _branchController = TextEditingController();

  bool _isCloning = false;
  bool _shallowClone = false;
  int _depth = 1;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _pathController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      icon: PhosphorIconsRegular.downloadSimple,
      title: AppLocalizations.of(context)!.cloneRepository,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              BodyMediumLabel(AppLocalizations.of(context)!.cloneGitRepositoryFromUrl),
              const SizedBox(height: AppTheme.paddingL),

              // Repository URL
              BaseTextField(
                controller: _urlController,
                label: AppLocalizations.of(context)!.repositoryUrl,
                hintText: AppLocalizations.of(context)!.repositoryUrlHint,
                prefixIcon: PhosphorIconsRegular.globe,
                enabled: !_isCloning,
                autofocus: true,
                onChanged: (_) => _autoFillPath(),
              ),
              const SizedBox(height: AppTheme.paddingM),

              // Destination path
              BaseTextField(
                controller: _pathController,
                label: AppLocalizations.of(context)!.destinationPath,
                hintText: AppLocalizations.of(context)!.destinationPathHint,
                prefixIcon: PhosphorIconsRegular.folder,
                suffixIcon: kIsWeb ? null : PhosphorIconsRegular.folderOpen,
                enabled: !_isCloning,
              ),
              if (!kIsWeb && !_isCloning)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppTheme.paddingS),
                    child: BaseButton(
                      label: AppLocalizations.of(context)!.browse,
                      variant: ButtonVariant.tertiary,
                      leadingIcon: PhosphorIconsRegular.folderOpen,
                      onPressed: _browsePath,
                    ),
                  ),
                ),
              const SizedBox(height: AppTheme.paddingM),

              // Branch name (optional)
              BaseTextField(
                controller: _branchController,
                label: AppLocalizations.of(context)!.branchOptional,
                hintText: AppLocalizations.of(context)!.hintTextDefaultBranch,
                prefixIcon: PhosphorIconsRegular.gitBranch,
                enabled: !_isCloning,
              ),
              const SizedBox(height: AppTheme.paddingM),

              // Shallow clone option
              SwitchListTile(
                value: _shallowClone,
                onChanged: _isCloning
                    ? null
                    : (value) {
                        setState(() {
                          _shallowClone = value;
                        });
                      },
                title: BodyMediumLabel(AppLocalizations.of(context)!.shallowClone),
                subtitle: BodySmallLabel(AppLocalizations.of(context)!.shallowCloneDescription),
                contentPadding: EdgeInsets.zero,
              ),

              if (_shallowClone) ...[
                const SizedBox(height: AppTheme.paddingS),
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.gitCommit, size: 20),
                    const SizedBox(width: AppTheme.paddingS),
                    BodyMediumLabel(AppLocalizations.of(context)!.depth),
                    const SizedBox(width: AppTheme.paddingM),
                    Expanded(
                      child: Slider(
                        value: _depth.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        label: _depth.toString(),
                        onChanged: _isCloning
                            ? null
                            : (value) {
                                setState(() {
                                  _depth = value.toInt();
                                });
                              },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: BodyMediumLabel(
                        _depth.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: AppTheme.paddingM),
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.warningCircle,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: AppTheme.paddingS),
                      Expanded(
                        child: BodyMediumLabel(
                          _errorMessage!,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Progress indicator
              if (_isCloning) ...[
                const SizedBox(height: AppTheme.paddingL),
                const LinearProgressIndicator(),
                const SizedBox(height: AppTheme.paddingS),
                BaseLabel(
                  AppLocalizations.of(context)!.cloningRepository,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      actions: [
        BaseButton(
          label: AppLocalizations.of(context)!.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: _isCloning ? null : () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.clone,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.downloadSimple,
          onPressed: _isCloning ? null : _cloneRepository,
        ),
      ],
    );
  }

  void _autoFillPath() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Extract repository name from URL
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final lastSegment = segments.last;
        final repoName = lastSegment.endsWith('.git')
            ? lastSegment.substring(0, lastSegment.length - 4)
            : lastSegment;

        // Only auto-fill if path is empty
        if (_pathController.text.isEmpty && repoName.isNotEmpty) {
          // Use a default location (user can change it)
          // In a real app, you might use platform-specific defaults
          _pathController.text = repoName;
        }
      }
    } catch (e) {
      // Invalid URL, ignore
    }
  }

  Future<void> _browsePath() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.directorySelectionNotAvailable;
      });
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context)!.selectDestinationForClone,
    );

    if (result != null && mounted) {
      setState(() {
        _pathController.text = result;
      });
    }
  }

  Future<void> _cloneRepository() async {
    setState(() {
      _errorMessage = null;
    });

    final url = _urlController.text.trim();
    final path = _pathController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.enterRepositoryUrl;
      });
      return;
    }

    if (path.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.enterDestinationPath;
      });
      return;
    }

    setState(() {
      _isCloning = true;
      _errorMessage = null;
    });

    try {
      final branchName = _branchController.text.trim();

      final clonedPath = await GitService.cloneRepository(
        url: url,
        destinationPath: path,
        branchName: branchName.isEmpty ? null : branchName,
        depth: _shallowClone ? _depth : null,
      );

      if (mounted) {
        // Open the cloned repository
        final success = await ref.read(gitActionsProvider).openRepository(clonedPath);

        if (success && mounted) {
          Navigator.of(context).pop(clonedPath);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.repositoryClonedSuccess(clonedPath)),
              backgroundColor: AppTheme.gitAdded,
            ),
          );
        } else if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.repositoryClonedButFailedToOpen;
            _isCloning = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.failedToCloneRepository(e.toString());
          _isCloning = false;
        });
      }
    }
  }
}

/// Show clone repository dialog
Future<String?> showCloneRepositoryDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const CloneRepositoryDialog(),
  );
}
