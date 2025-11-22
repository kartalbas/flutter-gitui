import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import 'empty_state.dart';

/// A widget that builds different UI based on AsyncValue state
///
/// Handles loading, error, and data states consistently across the app.
/// Optionally handles empty data states as well.
class AsyncValueBuilder<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(BuildContext context, T data) dataBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace stackTrace)?
      errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool Function(T data)? isEmpty;

  const AsyncValueBuilder({
    super.key,
    required this.asyncValue,
    required this.dataBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (data) {
        // Check if data is empty
        if (isEmpty != null && isEmpty!(data)) {
          if (emptyBuilder != null) {
            return emptyBuilder!.call(context);
          }
          return Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return EmptyStateWidget(
                icon: PhosphorIconsRegular.file,
                title: l10n.emptyStateNoData,
                message: l10n.emptyStateNoItemsFound,
              );
            },
          );
        }
        return dataBuilder(context, data);
      },
      loading: () =>
          loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          errorBuilder?.call(context, error, stack) ??
          ErrorState(message: error.toString()),
    );
  }
}

/// Specialized builder for List-based AsyncValues
///
/// Automatically handles empty list detection
class AsyncListBuilder<T> extends StatelessWidget {
  final AsyncValue<List<T>> asyncValue;
  final Widget Function(BuildContext context, List<T> items) listBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace stackTrace)?
      errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final EmptyStateWidget? emptyState;

  const AsyncListBuilder({
    super.key,
    required this.asyncValue,
    required this.listBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncValueBuilder<List<T>>(
      asyncValue: asyncValue,
      dataBuilder: listBuilder,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      isEmpty: (items) => items.isEmpty,
      emptyBuilder: emptyState != null ? (_) => emptyState! : null,
    );
  }
}
