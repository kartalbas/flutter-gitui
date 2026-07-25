import 'dart:convert';
import 'dart:io';

import '../services/logger_service.dart';
import '../utils/executable_path.dart';

/// A username and secret for one host, as git's credential machinery holds it.
class GitCredential {
  const GitCredential({required this.username, required this.password});

  final String username;

  /// The secret git would send. For the hosted providers this is the token a
  /// credential helper stored, which their APIs accept as a bearer token - so
  /// browsing a host needs no separate access token from the user.
  final String password;
}

/// Reads the credential git would use for [host], from whatever helper is
/// configured - on Windows that is usually the OS credential store.
///
/// Nothing is stored by the app: the secret is asked for when needed and used
/// for that one request. Returns null when no credential is available, which is
/// the normal case for a host the user never authenticated against.
///
/// [allowPrompts] decides whether a helper may open its own sign-in window.
/// Left off, this is a silent question - suitable for populating a view. Turn
/// it on only for an action the user explicitly asked for, or a background
/// screen would throw a login dialog over their work.
Future<GitCredential?> readGitCredential({
  required String host,
  String? gitExecutablePath,
  String protocol = 'https',
  bool allowPrompts = false,
}) async {
  final executable = normalizeExecutablePath(gitExecutablePath) ?? 'git';
  try {
    final process = await Process.start(
      executable,
      [
        if (!allowPrompts) ...['-c', 'credential.interactive=false'],
        'credential',
        'fill',
      ],
      environment: {if (!allowPrompts) 'GIT_TERMINAL_PROMPT': '0'},
    );

    // git reads the query as key=value lines terminated by a blank line.
    process.stdin.write('protocol=$protocol\nhost=$host\n\n');
    await process.stdin.flush();
    await process.stdin.close();

    final output = await utf8.decoder
        .bind(process.stdout)
        .join()
        .timeout(const Duration(seconds: 30), onTimeout: () => '');
    final exitCode = await process.exitCode;
    if (exitCode != 0) return null;

    return parseGitCredentialOutput(output);
  } on Object catch (error) {
    // A missing helper or an unreadable store is not exceptional here; the
    // caller simply learns the host cannot be browsed.
    Logger.debug('Could not read credential for $host: $error');
    return null;
  }
}

/// Parses the `key=value` lines `git credential fill` writes.
///
/// Split on the first `=` only: a token can contain one, and splitting on every
/// occurrence would truncate the secret and produce a request that fails
/// authentication for no visible reason.
GitCredential? parseGitCredentialOutput(String output) {
  String? username;
  String? password;

  for (final line in const LineSplitter().convert(output)) {
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator);
    final value = line.substring(separator + 1);
    if (key == 'username') username = value;
    if (key == 'password') password = value;
  }

  if (username == null || password == null || password.isEmpty) return null;
  return GitCredential(username: username, password: password);
}
