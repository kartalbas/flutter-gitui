import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'result.dart';

/// UI-focused extensions for Result<T> to simplify error handling in widgets
extension ResultUIExtensions<T> on Result<T> {
  /// Unwrap with automatic error notification on failure
  /// Shows user-friendly error message via NotificationService
  T unwrapOrNotify(
    BuildContext context, {
    String? errorPrefix,
    VoidCallback? onError,
  }) {
    return when(
      success: (value) => value,
      failure: (message, error, stackTrace) {
        if (context.mounted) {
          final displayMessage = errorPrefix != null
              ? '$errorPrefix: $message'
              : message;
          NotificationService.showError(context, displayMessage);
        }
        onError?.call();
        throw error ?? Exception(message);
      },
    );
  }

  /// Unwrap with automatic error notification, returning null on failure
  /// Useful for non-critical operations where you want to continue on error
  T? unwrapOrNotifyNull(
    BuildContext context, {
    String? errorPrefix,
    VoidCallback? onError,
  }) {
    return when(
      success: (value) => value,
      failure: (message, error, stackTrace) {
        if (context.mounted) {
          final displayMessage = errorPrefix != null
              ? '$errorPrefix: $message'
              : message;
          NotificationService.showError(context, displayMessage);
        }
        onError?.call();
        return null;
      },
    );
  }

  /// Execute and show success notification on success, error notification on failure
  /// Returns true if successful, false otherwise
  bool executeWithNotification(
    BuildContext context, {
    required String successMessage,
    String? errorPrefix,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) {
    return when(
      success: (value) {
        if (context.mounted) {
          NotificationService.showSuccess(context, successMessage);
        }
        onSuccess?.call();
        return true;
      },
      failure: (message, error, stackTrace) {
        if (context.mounted) {
          final displayMessage = errorPrefix != null
              ? '$errorPrefix: $message'
              : message;
          NotificationService.showError(context, displayMessage);
        }
        onError?.call();
        return false;
      },
    );
  }

  /// Map Result<T> to Result<R> with automatic error forwarding
  Result<R> mapResult<R>(R Function(T value) transform) {
    return when(
      success: (value) {
        try {
          return Success(transform(value));
        } catch (e, stackTrace) {
          return Failure(e.toString(), error: e, stackTrace: stackTrace);
        }
      },
      failure: (message, error, stackTrace) {
        return Failure(message, error: error, stackTrace: stackTrace);
      },
    );
  }

  /// Fold Result<T> into a widget, handling both success and error cases
  Widget fold({
    required Widget Function(T value) onSuccess,
    required Widget Function(String message) onError,
  }) {
    return when(
      success: onSuccess,
      failure: (message, error, stackTrace) => onError(message),
    );
  }
}

/// Extensions for Future<Result<T>> to simplify async UI operations
extension FutureResultUIExtensions<T> on Future<Result<T>> {
  /// Execute async operation with loading state and automatic error handling
  /// Returns the result value on success, null on error
  Future<T?> executeWithLoading(
    BuildContext context, {
    String? loadingMessage,
    String? successMessage,
    String? errorPrefix,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      final result = await this;
      return result.when(
        success: (value) {
          if (successMessage != null && context.mounted) {
            NotificationService.showSuccess(context, successMessage);
          }
          onSuccess?.call();
          return value;
        },
        failure: (message, error, stackTrace) {
          if (context.mounted) {
            final displayMessage = errorPrefix != null
                ? '$errorPrefix: $message'
                : message;
            NotificationService.showError(context, displayMessage);
          }
          onError?.call();
          return null;
        },
      );
    } catch (e) {
      if (context.mounted) {
        final displayMessage = errorPrefix != null
            ? '$errorPrefix: $e'
            : e.toString();
        NotificationService.showError(context, displayMessage);
      }
      onError?.call();
      return null;
    }
  }
}

/// Safe context operations that check mounted state
extension SafeContextExtensions on BuildContext {
  /// Execute action only if context is still mounted
  void ifMounted(VoidCallback action) {
    if (mounted) {
      action();
    }
  }

  /// Show error notification if context is mounted
  void showErrorIfMounted(String message) {
    if (mounted) {
      NotificationService.showError(this, message);
    }
  }

  /// Show success notification if context is mounted
  void showSuccessIfMounted(String message) {
    if (mounted) {
      NotificationService.showSuccess(this, message);
    }
  }
}
