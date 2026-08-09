import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        IconRole,
        NoticeSpec,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../generated/app_localizations.dart';
import '../components/base_text_field.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../../core/git/git_service.dart';
import '../../core/git/git_providers.dart';
import '../../core/config/config_providers.dart';
import '../components/base_dialog.dart';
import 'select_hosted_repository_dialog.dart';
import '../components/base_layout.dart';

/// One standing statement about the whole dialog, drawn by the skin.
///
/// The same move the bisect and merge dialogs already made: a tinted fill, a
/// corner, a 16 dp inset, a mark and a line of words are `surfaces.banner` —
/// *something about this whole surface needs saying* — so the hand-painted
/// container leaves whole and its corner leaves with it.
Widget _banner(BuildContext context, BannerSpec spec) => SkinScope.render(
  context,
  (Skin skin, BuildContext inner) => skin.surfaces.banner(inner, spec),
);

/// Dialog for cloning a Git repository
class CloneRepositoryDialog extends ConsumerStatefulWidget {
  const CloneRepositoryDialog({super.key});

  @override
  ConsumerState<CloneRepositoryDialog> createState() =>
      _CloneRepositoryDialogState();
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
      icon: IconRole.downloadSimple,
      title: AppLocalizations.of(context)!.cloneRepository,
      // Enter clones, from any field; Esc cancels. The dialog must be
      // completable without reaching for the mouse.
      onSubmit: _isCloning ? null : _cloneRepository,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BaseLabel(
              AppLocalizations.of(context)!.cloneGitRepositoryFromUrl,
              role: TextRole.body,
            ),
            const BaseGap(Proximity.separate),

            // Repository URL. Looking one up is this field's own action, so it
            // sits inside it as the trailing icon rather than as a button
            // floating underneath, detached from what it belongs to.
            BaseTextField(
              controller: _urlController,
              label: AppLocalizations.of(context)!.repositoryUrl,
              hintText: AppLocalizations.of(context)!.repositoryUrlHint,
              prefixIcon: IconRole.globe,
              suffixIcon: IconRole.cloudArrowDown,
              onSuffixTap: _selectHostedRepository,
              suffixTooltip: 'Browse repositories',
              enabled: !_isCloning,
              autofocus: true,
              onChanged: (_) => _autoFillPath(),
            ),
            const BaseGap(Proximity.grouped),

            // Destination path, with the folder picker as its trailing action.
            // The icon used to be decorative and a separate "Browse" button sat
            // below it - two affordances for one job.
            BaseTextField(
              controller: _pathController,
              label: AppLocalizations.of(context)!.destinationPath,
              hintText: AppLocalizations.of(context)!.destinationPathHint,
              prefixIcon: IconRole.folder,
              suffixIcon: kIsWeb ? null : IconRole.folderOpen,
              onSuffixTap: kIsWeb ? null : _browsePath,
              suffixTooltip: AppLocalizations.of(context)!.browse,
              enabled: !_isCloning,
            ),
            const BaseGap(Proximity.grouped),

            // Branch name (optional)
            BaseTextField(
              controller: _branchController,
              label: AppLocalizations.of(context)!.branchOptional,
              hintText: AppLocalizations.of(context)!.hintTextDefaultBranch,
              prefixIcon: IconRole.gitBranch,
              enabled: !_isCloning,
            ),
            const BaseGap(Proximity.grouped),

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
              title: BaseLabel(
                AppLocalizations.of(context)!.shallowClone,
                role: TextRole.body,
              ),
              subtitle: BaseLabel(
                AppLocalizations.of(context)!.shallowCloneDescription,
                role: TextRole.detail,
              ),
              contentPadding: EdgeInsets.zero,
            ),

            if (_shallowClone) ...[
              const BaseGap(Proximity.related),
              Row(
                children: [
                  // The mark that names the depth control, at the ordinary
                  // size: it belongs to the row it labels.
                  const BaseIcon(IconRole.gitCommit),
                  const BaseGap(Proximity.related),
                  BaseLabel(
                    AppLocalizations.of(context)!.depth,
                    role: TextRole.body,
                  ),
                  const BaseGap(Proximity.grouped),
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
                    child: BaseLabel(
                      _depth.toString(),
                      role: TextRole.body,
                      align: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],

            // Why the clone could not start: `surfaces.banner`, the member
            // for *something about this whole surface needs saying*.
            //
            // What the hand-painted copy got wrong is the pairing, and it got
            // it wrong twice at one site. The box was filled with the
            // scheme's `errorContainer` while BOTH the mark and the words on
            // it were painted `Tone.danger`, which the Material skin resolves
            // to `colorScheme.error` — the error FOREGROUND on the error
            // CONTAINER. That is not an M3 pair and nothing had ever measured
            // it; M3 pairs `errorContainer` with `onErrorContainer`. Stating
            // the tone once on the banner hands the member both halves, and
            // it is the member's business to keep a container and the ink on
            // it together.
            //
            // The repair does not stop at the pairing - the banner is also
            // louder than the copy was: the 8 dp corner goes to the member's
            // square 0, the words rise from `body` to the banner's
            // `titleMedium`, and the 20 dp mark grows to the ambient 24. The
            // `errorContainer` fill stays, now under `onErrorContainer` ink -
            // an error that stops the clone is exactly the statement the
            // banner's full strength exists for.
            if (_errorMessage != null) ...[
              const BaseGap(Proximity.grouped),
              _banner(
                context,
                BannerSpec(
                  tone: Tone.danger,
                  icon: IconRole.warningCircle,
                  title: _errorMessage!,
                ),
              ),
            ],

            // Progress indicator
            if (_isCloning) ...[
              const BaseGap(Proximity.separate),
              const LinearProgressIndicator(),
              const BaseGap(Proximity.related),
              // The italic goes with the `TextStyle` that carried it: slanting
              // an aside is Material's answer to "this line is a remark about
              // what is happening, not part of the form", and another design
              // language answers the same question with a colour or a size.
              // `TextRole.detail` asks it instead.
              BaseLabel(
                AppLocalizations.of(context)!.cloningRepository,
                role: TextRole.detail,
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
          enabled: !_isCloning,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: AppLocalizations.of(context)!.clone,
          role: DialogActionRole.affirmative,
          icon: IconRole.downloadSimple,
          enabled: !_isCloning,
          onPressed: _cloneRepository,
        ),
      ],
    );
  }

  /// Looks up a repository on a host the workspace already uses and puts its
  /// URL in the field, so the destination path is derived exactly as it would
  /// be for a URL typed by hand.
  Future<void> _selectHostedRepository() async {
    final selected = await showSelectHostedRepositoryDialog(context);
    if (selected == null || !mounted) return;

    setState(() {
      _urlController.text = selected.cloneUrl;
      _errorMessage = null;
    });
    _autoFillPath();
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
        _errorMessage = AppLocalizations.of(
          context,
        )!.directorySelectionNotAvailable;
      });
      return;
    }

    final result = await FilePicker.getDirectoryPath(
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
        gitExecutablePath: ref.read(gitExecutablePathProvider),
      );

      if (mounted) {
        // Open the cloned repository
        final success = await ref
            .read(gitActionsProvider)
            .openRepository(clonedPath);

        if (success && mounted) {
          Navigator.of(context).pop(clonedPath);

          // The clone finished and the repository opened, which is what
          // `success` says. The fill it used to borrow was the git-ADDED
          // green - a word about a file's state in the index, not about an
          // operation that worked.
          Overlays.notify(
            context,
            NoticeSpec(
              tone: Tone.success,
              title: AppLocalizations.of(
                context,
              )!.repositoryClonedSuccess(clonedPath),
            ),
          );
        } else if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(
              context,
            )!.repositoryClonedButFailedToOpen;
            _isCloning = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.failedToCloneRepository(e.toString());
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
