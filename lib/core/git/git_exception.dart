/// Exception thrown when a Git operation fails
class GitException implements Exception {
  final String message;
  final int? exitCode;
  final String? stderr;
  final String? stdout;

  GitException(
    this.message, {
    this.exitCode,
    this.stderr,
    this.stdout,
  });

  @override
  String toString() {
    final buffer = StringBuffer('GitException: $message');
    if (exitCode != null) {
      buffer.write('\nExit code: $exitCode');
    }
    if (stderr != null && stderr!.isNotEmpty) {
      buffer.write('\nStderr: $stderr');
    }
    return buffer.toString();
  }
}

/// Exception thrown when repository is not found or invalid
class RepositoryNotFoundException extends GitException {
  RepositoryNotFoundException(String path)
      : super('Repository not found at path: $path');
}

/// Exception thrown when Git is not installed
class GitNotFoundException extends GitException {
  GitNotFoundException()
      : super('Git executable not found. Please install Git.');
}
