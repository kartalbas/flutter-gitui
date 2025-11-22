import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/git/models/file_status.dart';

/// Utility class for file icon selection based on extension or status.
class FileIconUtils {
  FileIconUtils._();

  /// Get icon based on file extension
  static IconData getIconForExtension(String extension) {
    switch (extension.toLowerCase()) {
      // Code files
      case 'dart':
      case 'js':
      case 'ts':
      case 'jsx':
      case 'tsx':
      case 'py':
      case 'java':
      case 'c':
      case 'cpp':
      case 'cs':
      case 'go':
      case 'rs':
      case 'rb':
      case 'php':
      case 'swift':
      case 'kt':
      case 'scala':
        return PhosphorIconsBold.fileCode;

      // Web files
      case 'html':
      case 'htm':
        return PhosphorIconsBold.fileHtml;
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return PhosphorIconsBold.fileCss;

      // Config/data files
      case 'json':
      case 'yaml':
      case 'yml':
      case 'xml':
      case 'toml':
      case 'ini':
      case 'conf':
        return PhosphorIconsBold.code;

      // Document files
      case 'md':
      case 'txt':
      case 'doc':
      case 'docx':
      case 'rtf':
        return PhosphorIconsBold.fileText;

      // Image files
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'bmp':
      case 'ico':
      case 'webp':
        return PhosphorIconsBold.fileImage;

      // PDF
      case 'pdf':
        return PhosphorIconsBold.filePdf;

      // Archive files
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
      case 'bz2':
        return PhosphorIconsBold.fileZip;

      // Video files
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return PhosphorIconsBold.fileVideo;

      // Audio files
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
      case 'aac':
        return PhosphorIconsBold.fileAudio;

      default:
        return PhosphorIconsBold.file;
    }
  }

  /// Get icon based on git status type
  static IconData getIconForStatus(FileStatusType? status) {
    if (status == null) return PhosphorIconsBold.file;

    switch (status) {
      case FileStatusType.added:
        return PhosphorIconsBold.filePlus;
      case FileStatusType.modified:
        return PhosphorIconsBold.pencilSimple;
      case FileStatusType.deleted:
        return PhosphorIconsBold.fileMinus;
      case FileStatusType.renamed:
        return PhosphorIconsBold.arrowsLeftRight;
      case FileStatusType.copied:
        return PhosphorIconsBold.copy;
      case FileStatusType.untracked:
        return PhosphorIconsBold.question;
      case FileStatusType.ignored:
        return PhosphorIconsBold.fileX;
      case FileStatusType.unchanged:
        return PhosphorIconsBold.file;
    }
  }
}
