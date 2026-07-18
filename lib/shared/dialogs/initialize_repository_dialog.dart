import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_dialog.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_service.dart';
import '../../core/git/git_providers.dart';

/// Dialog for initializing a new Git repository
class InitializeRepositoryDialog extends ConsumerStatefulWidget {
  const InitializeRepositoryDialog({super.key});

  @override
  ConsumerState<InitializeRepositoryDialog> createState() =>
      _InitializeRepositoryDialogState();
}

class _InitializeRepositoryDialogState
    extends ConsumerState<InitializeRepositoryDialog> {
  final _pathController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');

  bool _isInitializing = false;
  bool _bare = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pathController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      icon: PhosphorIconsRegular.plus,
      title: AppLocalizations.of(context)!.initializeRepository,
      content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BodyMediumLabel(AppLocalizations.of(context)!.createNewGitRepository),
              const SizedBox(height: AppTheme.paddingL),

              // Directory path
              BaseTextField(
                controller: _pathController,
                label: AppLocalizations.of(context)!.directoryPath,
                hintText: AppLocalizations.of(context)!.directoryPathHint,
                prefixIcon: PhosphorIconsRegular.folder,
                suffixIcon: kIsWeb ? null : PhosphorIconsRegular.folderOpen,
                enabled: !_isInitializing,
                autofocus: true,
              ),
              if (!kIsWeb && !_isInitializing)
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

              // Initial branch name
              BaseTextField(
                controller: _branchController,
                label: AppLocalizations.of(context)!.initialBranchName,
                hintText: AppLocalizations.of(context)!.hintTextDefaultBranch,
                prefixIcon: PhosphorIconsRegular.gitBranch,
                enabled: !_isInitializing,
              ),
              const SizedBox(height: AppTheme.paddingM),

              // Bare repository option
              SwitchListTile(
                value: _bare,
                onChanged: _isInitializing
                    ? null
                    : (value) {
                        setState(() {
                          _bare = value;
                        });
                      },
                title: BodyMediumLabel(AppLocalizations.of(context)!.bareRepository),
                subtitle: BodySmallLabel(AppLocalizations.of(context)!.bareRepositoryDescription),
                contentPadding: EdgeInsets.zero,
              ),

              // Info card
              const SizedBox(height: AppTheme.paddingM),
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.info,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    Expanded(
                      child: BodySmallLabel(AppLocalizations.of(context)!.initializeRepositoryInfo(_bare ? '' : AppLocalizations.of(context)!.initializeRepositoryInfoBare)),
                    ),
                  ],
                ),
              ),

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
              if (_isInitializing) ...[
                const SizedBox(height: AppTheme.paddingL),
                const LinearProgressIndicator(),
                const SizedBox(height: AppTheme.paddingS),
                BodyMediumLabel(
                  AppLocalizations.of(context)!.initializingRepository,
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
          onPressed: _isInitializing ? null : () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.initialize,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.plus,
          onPressed: _isInitializing ? null : _initializeRepository,
        ),
      ],
    );
  }

  Future<void> _browsePath() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.directorySelectionNotAvailable;
      });
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context)!.selectDirectoryToInitialize,
    );

    if (result != null && mounted) {
      setState(() {
        _pathController.text = result;
      });
    }
  }

  Future<void> _initializeRepository() async {
    setState(() {
      _errorMessage = null;
    });

    final path = _pathController.text.trim();
    final branchName = _branchController.text.trim();

    if (path.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.enterDirectoryPath;
      });
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await GitService.initializeRepository(
        path: path,
        bare: _bare,
        initialBranch: branchName.isEmpty ? null : branchName,
      );

      if (mounted) {
        // Open the initialized repository
        final success = await ref.read(gitActionsProvider).openRepository(path);

        if (success && mounted) {
          Navigator.of(context).pop(path);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.repositoryInitializedSuccess(path)),
              backgroundColor: AppTheme.gitAdded,
            ),
          );
        } else if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.repositoryInitializedButFailedToOpen;
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.failedToInitializeRepository(e.toString());
          _isInitializing = false;
        });
      }
    }
  }
}

/// Show initialize repository dialog
Future<String?> showInitializeRepositoryDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const InitializeRepositoryDialog(),
  );
}
