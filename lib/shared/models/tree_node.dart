/// Mixin for tree node types used in file trees and navigation trees.
///
/// This provides a common interface for tree nodes used in:
/// - FileTreeView (browse feature)
/// - GitStatusTreeView (changes feature)
/// - FileTreePanel (history feature)
mixin TreeNodeMixin {
  /// Display name of the node
  String get name;

  /// Full path to the file or directory
  String get fullPath;

  /// Whether this node represents a directory
  bool get isDirectory;

  /// Child nodes (for directories)
  List<TreeNodeMixin> get children;

  /// Whether the directory is currently expanded
  bool get isExpanded;

  /// Set the expanded state
  set isExpanded(bool value);
}
