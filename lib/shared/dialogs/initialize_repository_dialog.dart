import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        DialogRouteSpec,
        IconRole,
        NoticeSpec,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        ToggleKind,
        Tone;

import '../../generated/app_localizations.dart';
import '../components/base_dialog.dart';
import '../components/base_toggle_row.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
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
            BaseToggleRow(
              value: _bare,
              onChanged: _isInitializing
                  ? null
                  : (value) {
                      setState(() {
                        _bare = value ?? false;
                      });
                    },
              label: AppLocalizations.of(context)!.bareRepository,
              description: AppLocalizations.of(
                context,
              )!.bareRepositoryDescription,
              kind: ToggleKind.switching,
            ),

            // **Something about this whole surface needs saying**: what the
            // fields above are about to create, and how the bare switch
            // changes it. It said that from inside a hand-painted copy of the
            // member - a neutral wash, a 12 dp corner, an inset, a mark and a
            // line of `detail` - and all five leave together, because a notice
            // IS a surface and every one of them was the surface. `Tone.info`
            // is the sentence's own meaning ("this is worth knowing and
            // nothing is wrong"), which Material answers with the primary
            // container: the strip is tinted now instead of grey, and the info
            // mark is no longer the only thing carrying the meaning.
            const BaseGap(Proximity.grouped),
            SkinScope.render(context, (Skin skin, BuildContext inner) {
              return skin.surfaces.banner(
                inner,
                BannerSpec(
                  tone: Tone.info,
                  title: AppLocalizations.of(context)!.initializeRepositoryInfo(
                    _bare
                        ? ''
                        : AppLocalizations.of(
                            context,
                          )!.initializeRepositoryInfoBare,
                  ),
                  icon: IconRole.info,
                ),
              );
            }),

            // The same member as the notice above, one tone over: the mark and
            // the message had already agreed that what they say is
            // `Tone.danger`, and the surface they sat on was the third place
            // that same meaning was spelled out - as `errorContainer`. Now the
            // meaning is stated once, on the thing that has it, and the fill
            // that pairs with it is Material's answer rather than this
            // dialog's. The corner goes with the fill it belonged to.
            if (_errorMessage != null) ...[
              const BaseGap(Proximity.grouped),
              SkinScope.render(context, (Skin skin, BuildContext inner) {
                return skin.surfaces.banner(
                  inner,
                  BannerSpec(
                    tone: Tone.danger,
                    title: _errorMessage!,
                    icon: IconRole.warningCircle,
                  ),
                );
              }),
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
  return Overlays.dialogFrom<String>(
    context,
    route: DialogRouteSpec(
      title: AppLocalizations.of(context)!.initializeRepository,
      barrierDismissible: false,
    ),
    builder: (context) => const InitializeRepositoryDialog(),
  );
}
