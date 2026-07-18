import 'package:flutter/material.dart';

import '../services/notification_service.dart';

/// A type representing either a success or failure result
sealed class Result<T> {
  const Result();

  /// Returns true if this is a Success result
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a Failure result
  bool get isFailure => this is Failure<T>;

  /// Returns the value if Success, null otherwise
  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;

  /// Returns the error message if Failure, null otherwise
  String? get errorOrNull =>
      this is Failure<T> ? (this as Failure<T>).message : null;

  /// Executes one of the callbacks based on the result type
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error, StackTrace? stackTrace)
    failure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      Failure<T>(:final message, :final error, :final stackTrace) => failure(
        message,
        error,
        stackTrace,
      ),
    };
  }

  /// Maps the success value to another type
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => Success(transform(value)),
      Failure<T>(:final message, :final error, :final stackTrace) => Failure(
        message,
        error: error,
        stackTrace: stackTrace,
      ),
    };
  }

  /// Chains another Result-returning operation
  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => transform(value),
      Failure<T>(:final message, :final error, :final stackTrace) => Failure(
        message,
        error: error,
        stackTrace: stackTrace,
      ),
    };
  }

  /// Returns the value or throws an exception
  T unwrap() {
    return switch (this) {
      Success<T>(:final value) => value,
      Failure<T>(:final message) => throw Exception(message),
    };
  }

  /// Returns the value or a default value
  T unwrapOr(T defaultValue) {
    return switch (this) {
      Success<T>(:final value) => value,
      Failure<T>() => defaultValue,
    };
  }
}

/// Represents a successful result
class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Represents a failed result
class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.error, this.stackTrace});

  @override
  String toString() => 'Failure($message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Extension methods for Result type
extension ResultExtensions<T> on Result<T> {
  /// Shows the result in a SnackBar (errors only)
  void showInSnackBar(BuildContext context) {
    when(
      success: (value) {
        // Success notifications removed - silent on success
      },
      failure: (message, error, stackTrace) {
        NotificationService.showError(context, message);
      },
    );
  }

  /// Executes a callback on success
  Result<T> onSuccess(void Function(T value) callback) {
    if (this is Success<T>) {
      callback((this as Success<T>).value);
    }
    return this;
  }

  /// Executes a callback on failure
  Result<T> onFailure(
    void Function(String message, Object? error, StackTrace? stackTrace)
    callback,
  ) {
    if (this is Failure<T>) {
      final failure = this as Failure<T>;
      callback(failure.message, failure.error, failure.stackTrace);
    }
    return this;
  }
}

/// Extension for Future of Result of T
extension FutureResultExtensions<T> on Future<Result<T>> {
  /// Shows the result in a SnackBar when the future completes
  Future<void> showInSnackBar(BuildContext context) async {
    final result = await this;
    if (context.mounted) {
      result.showInSnackBar(context);
    }
  }

  /// Maps the success value to another type
  Future<Result<R>> map<R>(R Function(T value) transform) async {
    final result = await this;
    return result.map(transform);
  }

  /// Chains another Result-returning operation
  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T value) transform,
  ) async {
    final result = await this;
    return switch (result) {
      Success<T>(:final value) => await transform(value),
      Failure<T>(:final message, :final error, :final stackTrace) => Failure(
        message,
        error: error,
        stackTrace: stackTrace,
      ),
    };
  }
}

/// Helper function to wrap sync operations in Result
Result<T> runCatching<T>(T Function() operation) {
  try {
    return Success(operation());
  } catch (e, stackTrace) {
    return Failure(e.toString(), error: e, stackTrace: stackTrace);
  }
}

/// Helper function to wrap async operations in Result
Future<Result<T>> runCatchingAsync<T>(Future<T> Function() operation) async {
  try {
    return Success(await operation());
  } catch (e, stackTrace) {
    return Failure(e.toString(), error: e, stackTrace: stackTrace);
  }
}
