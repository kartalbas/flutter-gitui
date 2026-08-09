import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, NoticeSpec, Overlays, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_dialog.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_service.dart';
import '../../core/git/git_providers.dart';
import '../../core/config/config_providers.dart';
import '../components/base_layout.dart';

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
      icon: IconRole.plus,
      title: AppLocalizations.of(context)!.initializeRepository,
      onSubmit: _isInitializing ? null : _initializeRepository,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BaseLabel(
              AppLocalizations.of(context)!.createNewGitRepository,
              role: TextRole.body,
            ),
            const BaseGap(Proximity.separate),

            // Directory path
            BaseTextField(
              controller: _pathController,
              label: AppLocalizations.of(context)!.directoryPath,
              hintText: AppLocalizations.of(context)!.directoryPathHint,
              prefixIcon: IconRole.folder,
              suffixIcon: kIsWeb ? null : IconRole.folderOpen,
              enabled: !_isInitializing,
              autofocus: true,
            ),
            // The space above the button belongs BETWEEN it and the field, so
            // it is said as a gap rather than as the button's own top padding.
            if (!kIsWeb && !_isInitializing) ...<Widget>[
              const BaseGap(Proximity.related),
              Align(
                alignment: Alignment.centerRight,
                child: BaseButton(
                  label: AppLocalizations.of(context)!.browse,
                  variant: ButtonVariant.tertiary,
                  leadingIcon: IconRole.folderOpen,
                  onPressed: _browsePath,
                ),
              ),
            ],
            const BaseGap(Proximity.grouped),

            // Initial branch name
            BaseTextField(
              controller: _branchController,
              label: AppLocalizations.of(context)!.initialBranchName,
              hintText: AppLocalizations.of(context)!.hintTextDefaultBranch,
              prefixIcon: IconRole.gitBranch,
              enabled: !_isInitializing,
            ),
            const BaseGap(Proximity.grouped),

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
              title: BaseLabel(
                AppLocalizations.of(context)!.bareRepository,
                role: TextRole.body,
              ),
              subtitle: BaseLabel(
                AppLocalizations.of(context)!.bareRepositoryDescription,
                role: TextRole.detail,
              ),
              contentPadding: EdgeInsets.zero,
            ),

            // Info card
            const BaseGap(Proximity.grouped),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: BaseInset(
                child: Row(
                  children: [
                    // The mark of an ordinary notice, at the ordinary size: it
                    // belongs to the line beside it rather than standing over
                    // it.
                    const BaseIcon(IconRole.info),
                    const BaseGap(Proximity.related),
                    Expanded(
                      child: BaseLabel(
                        AppLocalizations.of(context)!.initializeRepositoryInfo(
                          _bare
                              ? ''
                              : AppLocalizations.of(
                                  context,
                                )!.initializeRepositoryInfoBare,
                        ),
                        role: TextRole.detail,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const BaseGap(Proximity.grouped),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: BaseInset(
                  child: Row(
                    children: [
                      // The mark says what the message beside it already says,
                      // so it says it the same way: the danger this label had
                      // already named, stated once as a meaning instead of a
                      // second time as a scheme role. The mark stated no size
                      // at all and took whatever the dialog's ambient theme
                      // handed it; the info banner a few lines above asks for
                      // the ordinary size, so the difference was drift rather
                      // than a distinction and both now say the same rung.
                      const BaseIcon(IconRole.warningCircle, tone: Tone.danger),
                      const BaseGap(Proximity.related),
                      Expanded(
                        child: BaseLabel(
                          _errorMessage!,
                          role: TextRole.body,
                          tone: Tone.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Progress indicator
            if (_isInitializing) ...[
              const BaseGap(Proximity.separate),
              const LinearProgressIndicator(),
              const BaseGap(Proximity.related),
              BaseLabel(
                AppLocalizations.of(context)!.initializingRepository,
                role: TextRole.body,
                align: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        DialogAction(
          label: AppLocalizations.of(context)!.cancel,
          role: DialogActionRole.dismissive,
          enabled: !_isInitializing,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: AppLocalizations.of(context)!.initialize,
          role: DialogActionRole.affirmative,
          icon: IconRole.plus,
          enabled: !_isInitializing,
          onPressed: _initializeRepository,
        ),
      ],
    );
  }

  Future<void> _browsePath() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = AppLocalizations.of(
          context,
        )!.directorySelectionNotAvailable;
      });
      return;
    }

    final result = await FilePicker.getDirectoryPath(
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
        gitExecutablePath: ref.read(gitExecutablePathProvider),
      );

      if (mounted) {
        // Open the initialized repository
        final success = await ref.read(gitActionsProvider).openRepository(path);

        if (success && mounted) {
          Navigator.of(context).pop(path);

          // As in the clone dialog: the repository exists and is open, which
          // is `success` rather than the git-added green it used to borrow.
          Overlays.notify(
            context,
            NoticeSpec(
              tone: Tone.success,
              title: AppLocalizations.of(
                context,
              )!.repositoryInitializedSuccess(path),
            ),
          );
        } else if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(
              context,
            )!.repositoryInitializedButFailedToOpen;
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.failedToInitializeRepository(e.toString());
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
