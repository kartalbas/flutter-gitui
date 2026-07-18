import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/services/shell_service.dart';

import '../../generated/app_localizations.dart';
import '../../core/diff/diff_tool_service.dart';
import '../../core/diff/models/diff_tool.dart';
import '../../core/services/logger_service.dart';
import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../components/base_dialog.dart';

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

      Logger.info('Tool detection complete: git=${_gitPath ?? "not found"}, diff tools=${_diffTools.length}, editors=${_textEditors.length}');
    } catch (e, stack) {
      Logger.error('Error detecting tools', e, stack);
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  void _preselectCurrentTools() {
    // Pre-select current git path if it matches detected
    if (widget.currentGitPath != null && _gitPath == widget.currentGitPath) {
      _selectedGit = _gitPath;
    }

    // Pre-select current diff tool if detected
    if (widget.currentDiffTool != null) {
      _selectedDiffTool = _diffTools.firstWhere(
        (tool) => tool.type == widget.currentDiffTool,
        orElse: () => _diffTools.isEmpty ? const DiffTool(type: DiffToolType.vscode, executablePath: '', diffArgs: '', mergeArgs: '') : _diffTools.first,
      );
      if (_selectedDiffTool?.type != widget.currentDiffTool) {
        _selectedDiffTool = null; // Current tool not detected
      }
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
      final command = 'which git';
      final result = await ShellService.run(command).then((r) => r.unwrap());
      if (result.first.exitCode == 0) {
        _gitPath = result.first.stdout.toString().trim();
        _selectedGit = _gitPath; // Auto-select if found
        Logger.info('Detected git at: $_gitPath');
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
        final result = await ShellService.run('which ${editorInfo.command}').then((r) => r.unwrap());
        if (result.first.exitCode == 0) {
          final path = result.first.stdout.toString().trim();
          _textEditors.add(_DetectedEditor(
            name: editorInfo.displayName,
            path: path,
          ));
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
      title: 'Detect Tools',
      icon: PhosphorIconsRegular.magnifyingGlass,
      content: _isDetecting
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.paddingXL),
                child: CircularProgressIndicator(),
              ),
            )
          : _buildContent(context, l10n),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: 'Apply Selected',
          variant: ButtonVariant.primary,
          onPressed: (_selectedGit != null || _selectedDiffTool != null || _selectedTextEditor != null)
              ? () {
                  Navigator.of(context).pop({
                    'git': _selectedGit,
                    'diffTool': _selectedDiffTool,
                    'textEditor': _selectedTextEditor,
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    if (_gitPath == null && _diffTools.isEmpty && _textEditors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.paddingL),
            BodyMediumLabel(
              'No tools detected',
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.paddingM),
            BodySmallLabel(
              'Make sure git, diff tools, and editors are installed on your system',
              textAlign: TextAlign.center,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_gitPath != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.paddingL,
                top: AppTheme.paddingM,
                bottom: AppTheme.paddingS,
              ),
              child: TitleSmallLabel(
                'Git Executable',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            RadioListTile<String>(
              title: const BodyMediumLabel('Use detected git'),
              subtitle: BodySmallLabel(
                _gitPath!,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              value: _gitPath!,
              groupValue: _selectedGit, // ignore: deprecated_member_use
              onChanged: (value) { // ignore: deprecated_member_use
                setState(() {
                  _selectedGit = value;
                });
              },
            ),
            const Divider(),
          ],
          if (_diffTools.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.paddingL,
                top: AppTheme.paddingM,
                bottom: AppTheme.paddingS,
              ),
              child: TitleSmallLabel(
                'Diff/Merge Tools (${_diffTools.length} found)',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ..._diffTools.map((tool) {
              return RadioListTile<DiffTool>(
                title: BodyMediumLabel(tool.displayName),
                subtitle: BodySmallLabel(
                  tool.executablePath,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                value: tool,
                groupValue: _selectedDiffTool, // ignore: deprecated_member_use
                onChanged: (value) { // ignore: deprecated_member_use
                  setState(() {
                    _selectedDiffTool = value;
                  });
                },
              );
            }),
          ],
          if (_textEditors.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.paddingL,
                top: AppTheme.paddingM,
                bottom: AppTheme.paddingS,
              ),
              child: TitleSmallLabel(
                'Text Editors (${_textEditors.length} found)',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ..._textEditors.map((editor) {
              return RadioListTile<_DetectedEditor>(
                title: BodyMediumLabel(editor.name),
                subtitle: BodySmallLabel(
                  editor.path,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                value: editor,
                groupValue: _selectedTextEditor, // ignore: deprecated_member_use
                onChanged: (value) { // ignore: deprecated_member_use
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
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => DetectToolsDialog(
      currentGitPath: currentGitPath,
      currentDiffTool: currentDiffTool,
      currentTextEditor: currentTextEditor,
    ),
  );
}
