/// Represents a single Git reflog entry
class ReflogEntry {
  final String hash;
  final String selector;
  final String action;
  final String message;
  final DateTime? timestamp;

  const ReflogEntry({
    required this.hash,
    required this.selector,
    required this.action,
    required this.message,
    this.timestamp,
  });

  /// Short hash (first 7 characters)
  String get shortHash => hash.length >= 7 ? hash.substring(0, 7) : hash;

  /// Get action type for display
  String get actionType {
    if (action.startsWith('commit')) return 'Commit';
    if (action.startsWith('checkout')) return 'Checkout';
    if (action.startsWith('merge')) return 'Merge';
    if (action.startsWith('rebase')) return 'Rebase';
    if (action.startsWith('reset')) return 'Reset';
    if (action.startsWith('pull')) return 'Pull';
    if (action.startsWith('clone')) return 'Clone';
    if (action.startsWith('branch')) return 'Branch';
    if (action.startsWith('cherry-pick')) return 'Cherry-pick';
    if (action.startsWith('revert')) return 'Revert';
    return 'Other';
  }

  /// Get full description combining action and message
  String get fullDescription {
    if (message.isNotEmpty) {
      return '$action: $message';
    }
    return action;
  }

  @override
  String toString() => '$selector $shortHash $action';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReflogEntry &&
          runtimeType == other.runtimeType &&
          hash == other.hash &&
          selector == other.selector;

  @override
  int get hashCode => hash.hashCode ^ selector.hashCode;
}
