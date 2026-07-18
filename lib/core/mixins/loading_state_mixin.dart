import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Mixin for managing loading states in StatefulWidget
///
/// Provides methods to track loading states for different operations
/// and automatically manage setState calls.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with LoadingStateMixin {
///   Future<void> _saveData() async {
///     await withLoading(() async {
///       // Perform async operation
///     }, key: 'save');
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Stack(
///       children: [
///         // Main content
///         if (isLoading()) LoadingOverlay(),
///       ],
///     );
///   }
/// }
/// ```
mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  final Map<String, bool> _loadingStates = {};

  /// Check if any operation is loading, or a specific operation by key
  bool isLoading([String? key]) {
    if (key == null) {
      return _loadingStates.values.any((v) => v);
    }
    return _loadingStates[key] ?? false;
  }

  /// Execute an operation while managing its loading state
  ///
  /// Automatically sets loading state before operation and clears it after.
  /// Handles errors and ensures loading state is cleared even on exceptions.
  ///
  /// [operation] - The async operation to perform
  /// [key] - Optional key to track specific loading states
  Future<R> withLoading<R>(
    Future<R> Function() operation, {
    String? key,
  }) async {
    final loadingKey = key ?? 'default';

    if (mounted) {
      setState(() => _loadingStates[loadingKey] = true);
    }

    try {
      return await operation();
    } finally {
      if (mounted) {
        setState(() => _loadingStates[loadingKey] = false);
      }
    }
  }

  /// Execute an operation with a minimum loading duration
  ///
  /// Useful for preventing loading states that flash too quickly.
  ///
  /// [operation] - The async operation to perform
  /// [minDuration] - Minimum duration to show loading state
  /// [key] - Optional key to track specific loading states
  Future<R> withLoadingMinDuration<R>(
    Future<R> Function() operation, {
    Duration minDuration = UIConstants.minLoadingDuration,
    String? key,
  }) async {
    final loadingKey = key ?? 'default';

    if (mounted) {
      setState(() => _loadingStates[loadingKey] = true);
    }

    try {
      final results = await Future.wait([
        operation(),
        Future.delayed(minDuration),
      ]);
      return results[0] as R;
    } finally {
      if (mounted) {
        setState(() => _loadingStates[loadingKey] = false);
      }
    }
  }

  /// Clear a specific loading state or all loading states
  void clearLoading([String? key]) {
    if (mounted) {
      setState(() {
        if (key == null) {
          _loadingStates.clear();
        } else {
          _loadingStates.remove(key);
        }
      });
    }
  }

  /// Get all current loading keys
  List<String> get loadingKeys => _loadingStates.keys.toList();
}
