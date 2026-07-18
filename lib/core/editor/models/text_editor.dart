import 'package:flutter/foundation.dart';

/// Type of text editor
enum TextEditorType {
  vscode,
  vscodium,
  notepad,
  notepadPlusPlus,
  sublimeText,
  vim,
  gvim,
  nvim,
  emacs,
  atom,
  nano,
  gedit,
  kate,
  textmate,
  custom;

  String get displayName {
    switch (this) {
      case TextEditorType.vscode:
        return 'Visual Studio Code';
      case TextEditorType.vscodium:
        return 'VSCodium';
      case TextEditorType.notepad:
        return 'Notepad';
      case TextEditorType.notepadPlusPlus:
        return 'Notepad++';
      case TextEditorType.sublimeText:
        return 'Sublime Text';
      case TextEditorType.vim:
        return 'Vim';
      case TextEditorType.gvim:
        return 'GVim';
      case TextEditorType.nvim:
        return 'Neovim';
      case TextEditorType.emacs:
        return 'Emacs';
      case TextEditorType.atom:
        return 'Atom';
      case TextEditorType.nano:
        return 'Nano';
      case TextEditorType.gedit:
        return 'Gedit';
      case TextEditorType.kate:
        return 'Kate';
      case TextEditorType.textmate:
        return 'TextMate';
      case TextEditorType.custom:
        return 'Custom Editor';
    }
  }

  /// Get standard arguments for opening a file
  /// Placeholder: $FILE
  String get fileArgs {
    switch (this) {
      case TextEditorType.vscode:
      case TextEditorType.vscodium:
        return '\$FILE';
      case TextEditorType.notepad:
        return '\$FILE';
      case TextEditorType.notepadPlusPlus:
        return '-multiInst -nosession \$FILE';
      case TextEditorType.sublimeText:
        return '\$FILE';
      case TextEditorType.vim:
      case TextEditorType.gvim:
      case TextEditorType.nvim:
        return '\$FILE';
      case TextEditorType.emacs:
        return '\$FILE';
      case TextEditorType.atom:
        return '\$FILE';
      case TextEditorType.nano:
        return '\$FILE';
      case TextEditorType.gedit:
        return '\$FILE';
      case TextEditorType.kate:
        return '\$FILE';
      case TextEditorType.textmate:
        return '\$FILE';
      case TextEditorType.custom:
        return '\$FILE';
    }
  }

  /// Get standard arguments for opening a folder
  /// Placeholder: $FOLDER
  /// Returns null if the editor doesn't support opening folders
  String? get folderArgs {
    switch (this) {
      case TextEditorType.vscode:
      case TextEditorType.vscodium:
        return '\$FOLDER';
      case TextEditorType.notepad:
        return null; // Notepad doesn't support folders
      case TextEditorType.notepadPlusPlus:
        return null; // Notepad++ doesn't directly open folders
      case TextEditorType.sublimeText:
        return '\$FOLDER';
      case TextEditorType.vim:
      case TextEditorType.gvim:
      case TextEditorType.nvim:
        return '\$FOLDER'; // Opens folder in file browser
      case TextEditorType.emacs:
        return '\$FOLDER';
      case TextEditorType.atom:
        return '\$FOLDER';
      case TextEditorType.nano:
        return null; // Nano doesn't support folders
      case TextEditorType.gedit:
        return null; // Gedit doesn't directly open folders
      case TextEditorType.kate:
        return '\$FOLDER';
      case TextEditorType.textmate:
        return '\$FOLDER';
      case TextEditorType.custom:
        return '\$FOLDER';
    }
  }

  /// Whether this editor supports opening folders
  bool get supportsFolders => folderArgs != null;
}

/// Represents an external text editor
@immutable
class TextEditor {
  final TextEditorType type;
  final String executablePath;
  final String fileArgs;
  final String? folderArgs;
  final bool isAvailable;

  const TextEditor({
    required this.type,
    required this.executablePath,
    required this.fileArgs,
    this.folderArgs,
    this.isAvailable = false,
  });

  /// Display name of the editor
  String get displayName => type.displayName;

  /// Whether this editor supports opening folders
  bool get supportsFolders => folderArgs != null;

  /// Command to open a file
  List<String> openFileCommand(String filePath) {
    final args = fileArgs.replaceAll('\$FILE', filePath);
    return [executablePath, ...args.split(' ').where((a) => a.isNotEmpty)];
  }

  /// Command to open a folder
  /// Returns null if the editor doesn't support folders
  List<String>? openFolderCommand(String folderPath) {
    if (folderArgs == null) return null;

    final args = folderArgs!.replaceAll('\$FOLDER', folderPath);
    return [executablePath, ...args.split(' ').where((a) => a.isNotEmpty)];
  }

  TextEditor copyWith({
    TextEditorType? type,
    String? executablePath,
    String? fileArgs,
    String? folderArgs,
    bool? isAvailable,
  }) {
    return TextEditor(
      type: type ?? this.type,
      executablePath: executablePath ?? this.executablePath,
      fileArgs: fileArgs ?? this.fileArgs,
      folderArgs: folderArgs ?? this.folderArgs,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextEditor &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          executablePath == other.executablePath;

  @override
  int get hashCode => type.hashCode ^ executablePath.hashCode;

  @override
  String toString() => '$displayName ($executablePath)';
}
