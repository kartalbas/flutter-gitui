/// Where a remote lives, as far as its URL can tell.
///
/// A workspace can span several hosting providers, and the card cannot say
/// which account a repository needs without knowing where it points. This
/// matters most when a check fails for missing credentials: a GitHub sign-in
/// does nothing for an Azure DevOps remote.
enum GitHostingProvider {
  gitHub('GitHub'),
  gitLab('GitLab'),
  azureDevOps('Azure DevOps'),
  bitbucket('Bitbucket'),
  gitea('Gitea'),
  codeberg('Codeberg'),
  sourceHut('SourceHut'),

  /// A host that matches no known provider - most often a self-hosted server.
  /// Its label is empty because the host itself is the useful thing to show;
  /// guessing a provider would be worse than naming the machine.
  unknown('');

  const GitHostingProvider(this.label);

  /// Human-readable provider name, empty for [unknown].
  final String label;
}

/// The host, provider and (where the URL carries one) user of a remote.
class GitRemoteIdentity {
  const GitRemoteIdentity({
    required this.host,
    required this.provider,
    this.user,
  });

  /// Host the remote points at, e.g. `github.com` or `git.company.internal`.
  final String host;

  final GitHostingProvider provider;

  /// User embedded in the URL, if any. For SSH this is almost always `git`,
  /// which says nothing about the account, so it is not worth showing; an
  /// HTTPS URL carrying a user names the account the request is made as.
  final String? user;

  /// What to show: the provider when recognised, otherwise the bare host.
  String get label =>
      provider == GitHostingProvider.unknown ? host : provider.label;

  /// The user only when it identifies an account, so the generic SSH `git`
  /// does not masquerade as one.
  String? get accountHint {
    final value = user;
    if (value == null || value.isEmpty || value == 'git') return null;
    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRemoteIdentity &&
          host == other.host &&
          provider == other.provider &&
          user == other.user;

  @override
  int get hashCode => Object.hash(host, provider, user);

  @override
  String toString() =>
      'GitRemoteIdentity(host: $host, provider: $provider, user: $user)';
}

// git accepts three shapes, and a remote in the wild uses all of them:
// `https://host/path`, `ssh://user@host:port/path`, and the scp-like
// `user@host:path` which has no scheme and is not a URI at all.
final RegExp _scpLikePattern = RegExp(r'^([^/@]+)@([^/:]+):(?!//)(.*)$');

/// Reads the host, provider and user out of a remote URL.
///
/// Returns null when the remote is a local path, which has no host to show and
/// no account to need. Parsing is deliberate rather than a bare `Uri.parse`,
/// because the scp-like form git accepts is not a valid URI and would silently
/// yield nonsense.
GitRemoteIdentity? parseRemoteIdentity(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final scpMatch = _scpLikePattern.firstMatch(trimmed);
  if (scpMatch != null) {
    final host = scpMatch.group(2)!;
    return GitRemoteIdentity(
      host: host,
      provider: providerForHost(host),
      user: scpMatch.group(1),
    );
  }

  if (!trimmed.contains('://')) {
    // A bare path, absolute or relative, including Windows drive letters.
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) return null;

  // Uri keeps any password in userInfo; only the user names an account.
  final userInfo = uri.userInfo;
  final user = userInfo.isEmpty ? null : userInfo.split(':').first;

  return GitRemoteIdentity(
    host: uri.host,
    provider: providerForHost(uri.host),
    user: user == null || user.isEmpty ? null : user,
  );
}

/// Maps a host to the provider running it.
///
/// Matched on a substring rather than an exact name so self-hosted instances
/// are recognised too - an enterprise GitHub at `github.company.com`, a GitLab
/// at `gitlab.internal`. Azure DevOps is matched exactly, because its two
/// hosts are fixed and `azure` alone would claim unrelated machines.
GitHostingProvider providerForHost(String host) {
  final value = host.toLowerCase();

  if (value == 'dev.azure.com' ||
      value == 'ssh.dev.azure.com' ||
      value.endsWith('.visualstudio.com')) {
    return GitHostingProvider.azureDevOps;
  }
  if (value == 'codeberg.org' || value.endsWith('.codeberg.org')) {
    return GitHostingProvider.codeberg;
  }
  if (value == 'sr.ht' || value.endsWith('.sr.ht')) {
    return GitHostingProvider.sourceHut;
  }
  if (value.contains('github')) return GitHostingProvider.gitHub;
  if (value.contains('gitlab')) return GitHostingProvider.gitLab;
  if (value.contains('bitbucket')) return GitHostingProvider.bitbucket;
  if (value.contains('gitea')) return GitHostingProvider.gitea;

  return GitHostingProvider.unknown;
}
