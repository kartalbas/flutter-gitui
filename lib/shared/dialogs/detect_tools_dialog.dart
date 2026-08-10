import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show DialogRouteSpec, IconRole, Inset, Overlays, Proximity, TextRole, Tone;
import '../../core/services/shell_service.dart';

import '../../generated/app_localizations.dart';
import '../../core/diff/diff_tool_service.dart';
import '../../core/diff/models/diff_tool.dart';
import '../../core/services/logger_service.dart';
import '../../core/utils/executable_path.dart';
import '../components/base_label.dart';
import '../components/base_dialog.dart';
import '../components/base_layout.dart';
import '../widgets/empty_state.dart';

/// Dialog to detect and select available tools on Linux
class DetectToolsDialog extends StatefulWidget {
  final String? currentGitPath;
  final DiffToolType? currentDiffTool;
  final String? currentTextEditor;

  const DetectToolsDialog({
    super.key,
    this.currentGitPath,
    this.currentDiffTool,
    this.currentTextEditor,
  });

  @override
  State<DetectToolsDialog> createState() => _DetectToolsDialogState();
}

class _DetectToolsDialogState extends State<DetectToolsDialog> {
  bool _isDetecting = false;
  String? _gitPath;
  List<DiffTool> _diffTools = [];
  final List<_DetectedEditor> _textEditors = [];
  String? _selectedGit;
  DiffTool? _selectedDiffTool;
  _DetectedEditor? _selectedTextEditor;

  @override
  void initState() {
    super.initState();
    _detectTools();
  }

  Future<void> _detectTools() async {
    setState(() {
      _isDetecting = true;
    });

    try {
      // Detect git executable
      await _detectGit();

      // Detect diff/merge tools
      _diffTools = await DiffToolService.detectAvailableTools();

      // Detect text editors
      await _detectTextEditors();

      // Pre-select current tools if they were detected
      _preselectCurrentTools();

      Logger.info(
        'Tool detection complete: git=${_gitPath ?? "not found"}, diff tools=${_diffTools.length}, editors=${_textEditors.length}',
      );
    } catch (e, stack) {
      Logger.error('Error detecting tools', e, stack);
    } finally {
      // Detection runs several seconds of shell probes while Cancel stays
      // enabled, so the dialog can be gone by the time this resolves.
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  void _preselectCurrentTools() {
    // Pre-select current git path if it matches detected
    if (widget.currentGitPath != null && _gitPath == widget.currentGitPath) {
      _selectedGit = _gitPath;
    }

    // Pre-select current diff tool if detected. firstOrNull instead of a
    // firstWhere fallback: fabricating a tool with an empty executablePath
    // let "Apply Selected" overwrite a working diff/merge configuration
    // when detection found nothing.
    if (widget.currentDiffTool != null) {
      _selectedDiffTool = _diffTools
          .where((tool) => tool.type == widget.currentDiffTool)
          .firstOrNull;
    }

    // Pre-select current text editor if detected
    if (widget.currentTextEditor != null) {
      try {
        _selectedTextEditor = _textEditors.firstWhere(
          (editor) => editor.path == widget.currentTextEditor,
        );
      } catch (e) {
        // Current editor not detected
      }
    }
  }

  Future<void> _detectGit() async {
    try {
      // which does not exist on Windows; the equivalent is where.
      final lookup = Platform.isWindows ? 'where' : 'which';
      final command = '$lookup git';
      final result = await ShellService.run(command).then((r) => r.unwrap());
      if (result.first.exitCode == 0) {
        // where prints one line per PATH match, so storing the raw stdout would
        // persist a multi-line string that no git invocation can execute.
        final matches = result.first.stdout
            .toString()
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (matches.isNotEmpty) {
          _gitPath = matches.first;
          _selectedGit = _gitPath; // Auto-select if found
          Logger.info('Detected git at: $_gitPath');
        }
      }
    } catch (e) {
      Logger.warning('Failed to detect git', e);
    }
  }

  Future<void> _detectTextEditors() async {
    final commonEditors = [
      _EditorInfo('code', 'Visual Studio Code'),
      _EditorInfo('codium', 'VSCodium'),
      _EditorInfo('nano', 'Nano'),
      _EditorInfo('vim', 'Vim'),
      _EditorInfo('nvim', 'Neovim'),
      _EditorInfo('emacs', 'Emacs'),
      _EditorInfo('gedit', 'gedit'),
      _EditorInfo('kate', 'Kate'),
      _EditorInfo('subl', 'Sublime Text'),
      _EditorInfo('atom', 'Atom'),
      _EditorInfo('idea', 'IntelliJ IDEA'),
    ];

    for (final editorInfo in commonEditors) {
      try {
        final result = await ShellService.run(
          '${Platform.isWindows ? 'where' : 'which'} ${editorInfo.command}',
        ).then((r) => r.unwrap());
        if (result.first.exitCode == 0) {
          // Same reduction the git lookup above performs: the raw stdout can
          // list several matches, and only the first one is a usable path.
          final path = normalizeExecutablePath(result.first.stdout.toString());
          if (path == null) continue;
          _textEditors.add(
            _DetectedEditor(name: editorInfo.displayName, path: path),
          );
          Logger.info('Detected ${editorInfo.displayName} at: $path');
        }
      } catch (e) {
        // Editor not found, continue
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.detectTools,
      icon: IconRole.magnifyingGlass,
      onSubmit:
          (_selectedGit != null ||
              _selectedDiffTool != null ||
              _selectedTextEditor != null)
          ? () {
              Navigator.of(context).pop({
                'git': _selectedGit,
                'diffTool': _selectedDiffTool,
                'textEditor': _selectedTextEditor,
              });
            }
          : null,
      content: _isDetecting
          ? const Center(
              child: BaseInset(
                all: Inset.roomy,
                child: CircularProgressIndicator(),
              ),
            )
          : _buildContent(context, l10n),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.applySelected,
          role: DialogActionRole.affirmative,
          enabled:
              _selectedGit != null ||
              _selectedDiffTool != null ||
              _selectedTextEditor != null,
          onPressed: () {
            Navigator.of(context).pop({
              'git': _selectedGit,
              'diffTool': _selectedDiffTool,
              'textEditor': _selectedTextEditor,
            });
          },
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    if (_gitPath == null && _diffTools.isEmpty && _textEditors.isEmpty) {
      // The facade (#430), now that its hero can say a failure (#431). This
      // column was already the member's shape - hero, headline, the sentence
      // explaining it - laid out by hand, down to the roomy inset the member
      // applies itself; what kept it hand-built was that the facade painted
      // every hero in the supporting foreground, and that is a `Tone` now.
      //
      // The state SAYS failure and keeps saying it: `Tone.danger` resolves to
      // the very scheme role this mark was handed by hand, so the hero's
      // colour is unchanged. Two deltas ride along with the member and are
      // deliberate rather than discovered later: the hero takes the member's
      // 64 dp instead of this copy's 48, and the headline takes the member's
      // treatment - a neutral page title, with the failure now stated by the
      // mark above it rather than twice. Both are the member owning what a
      // copy of it had drifted on.
      return EmptyStateWidget(
        icon: PhosphorIconsRegular.warningCircle,
        title: l10n.noToolsDetected,
        message: l10n.noToolsDetectedHint,
        tone: Tone.danger,
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_gitPath != null) ...[
            // The header's own space is composed rather than carried as four
            // per-side numbers: the gap above and below belongs BETWEEN the
            // header and its neighbours, and only the indent belongs inside
            // it. Per-side rungs would be the token bag returning.
            const BaseGap(Proximity.grouped),
            BaseInset(
              x: Inset.roomy,
              y: Inset.none,
              child: BaseLabel(
                'Git Executable',
                role: TextRole.sectionTitle,
                tone: Tone.accent,
              ),
            ),
            const BaseGap(Proximity.related),
            RadioListTile<String>(
              title: const BaseLabel('Use detected git', role: TextRole.body),
              subtitle: BaseLabel(
                _gitPath!,
                role: TextRole.detail,
                tone: Tone.muted,
              ),
              value: _gitPath!,
              // ignore: deprecated_member_use
              groupValue: _selectedGit,
              // ignore: deprecated_member_use
              onChanged: (value) {
                setState(() {
                  _selectedGit = value;
                });
              },
            ),
            const BaseSeparator(),
          ],
          if (_diffTools.isNotEmpty) ...[
            const BaseGap(Proximity.grouped),
            BaseInset(
              x: Inset.roomy,
              y: Inset.none,
              child: BaseLabel(
                'Diff/Merge Tools (${_diffTools.length} found)',
                role: TextRole.sectionTitle,
                tone: Tone.accent,
              ),
            ),
            const BaseGap(Proximity.related),
            ..._diffTools.map((tool) {
              return RadioListTile<DiffTool>(
                title: BaseLabel(tool.displayName, role: TextRole.body),
                subtitle: BaseLabel(
                  tool.executablePath,
                  role: TextRole.detail,
                  tone: Tone.muted,
                ),
                value: tool,
                // ignore: deprecated_member_use
                groupValue: _selectedDiffTool,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  setState(() {
                    _selectedDiffTool = value;
                  });
                },
              );
            }),
          ],
          if (_textEditors.isNotEmpty) ...[
            const BaseSeparator(),
            const BaseGap(Proximity.grouped),
            BaseInset(
              x: Inset.roomy,
              y: Inset.none,
              child: BaseLabel(
                'Text Editors (${_textEditors.length} found)',
                role: TextRole.sectionTitle,
                tone: Tone.accent,
              ),
            ),
            const BaseGap(Proximity.related),
            ..._textEditors.map((editor) {
              return RadioListTile<_DetectedEditor>(
                title: BaseLabel(editor.name, role: TextRole.body),
                subtitle: BaseLabel(
                  editor.path,
                  role: TextRole.detail,
                  tone: Tone.muted,
                ),
                value: editor,
                // ignore: deprecated_member_use
                groupValue: _selectedTextEditor,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  setState(() {
                    _selectedTextEditor = value;
                  });
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Helper class for editor detection info
class _EditorInfo {
  final String command;
  final String displayName;

  _EditorInfo(this.command, this.displayName);
}

/// Detected editor with name and path
class _DetectedEditor {
  final String name;
  final String path;

  _DetectedEditor({required this.name, required this.path});
}

/// Show the detect tools dialog
Future<Map<String, dynamic>?> showDetectToolsDialog(
  BuildContext context, {
  String? currentGitPath,
  DiffToolType? currentDiffTool,
  String? currentTextEditor,
}) async {
  return Overlays.dialogFrom<Map<String, dynamic>>(
    context,
    route: DialogRouteSpec(title: AppLocalizations.of(context)!.detectTools),
    builder: (context) => DetectToolsDialog(
      currentGitPath: currentGitPath,
      currentDiffTool: currentDiffTool,
      currentTextEditor: currentTextEditor,
    ),
  );
}
