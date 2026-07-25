/// Why the app could not verify a repository against its remote.
///
/// The background sweep runs without credential prompts, so a repository whose
/// credentials are not cached fails instead of interrupting the user. Reporting
/// every such failure as "not checked yet" would hide the reason and leave
/// nothing to act on, so the cause is classified and shown.
enum RemoteCheckFailure {
  /// The remote was contacted, or has not been tried yet.
  none,

  /// The remote needs credentials the app was not allowed to ask for. This is
  /// the one the user can resolve: signing in once fixes it.
  authenticationRequired,

  /// The remote could not be reached at all - offline, DNS, a server that is
  /// down. Nothing to do but try again later.
  unreachable,

  /// Contacted and refused for some other reason, or an error that does not
  /// match a known shape.
  failed,
}

/// Classifies a failed remote check from git's error output.
///
/// The patterns are taken from what git actually writes when it runs with
/// prompts disabled - "unable to get password from user" when a credential
/// helper declines, "could not read Username ...: terminal prompts disabled"
/// when none is configured - rather than from what its documentation implies.
/// Anything unrecognised stays [RemoteCheckFailure.failed]: a wrong specific
/// answer is worse than an honest generic one.
RemoteCheckFailure classifyRemoteCheckFailure(String? errorOutput) {
  if (errorOutput == null || errorOutput.trim().isEmpty) {
    return RemoteCheckFailure.failed;
  }
  final output = errorOutput.toLowerCase();

  const authenticationMarkers = [
    'unable to get password',
    'could not read username',
    'could not read password',
    'terminal prompts disabled',
    'authentication failed',
    'invalid username or password',
    'permission denied (publickey',
    'access denied',
    'credential.interactive',
    'http basic: access denied',
    '403 forbidden',
    '401 unauthorized',
  ];
  for (final marker in authenticationMarkers) {
    if (output.contains(marker)) {
      return RemoteCheckFailure.authenticationRequired;
    }
  }

  const unreachableMarkers = [
    'could not resolve host',
    'could not resolve proxy',
    'failed to connect',
    'could not connect to server',
    'connection timed out',
    'connection refused',
    'network is unreachable',
    'operation timed out',
    'ssl certificate problem',
    'unable to access',
  ];
  for (final marker in unreachableMarkers) {
    if (output.contains(marker)) {
      return RemoteCheckFailure.unreachable;
    }
  }

  return RemoteCheckFailure.failed;
}
