/// A repository as a hosting provider reports it.
class HostedRepository {
  const HostedRepository({
    required this.fullName,
    required this.cloneUrl,
    this.description,
    this.isPrivate = false,
  });

  /// Owner and name, e.g. `digitaplatform/digita-controller`.
  final String fullName;

  /// HTTPS URL to clone from.
  final String cloneUrl;

  final String? description;
  final bool isPrivate;

  /// The part after the owner, which is what the user usually types.
  String get name {
    final separator = fullName.lastIndexOf('/');
    return separator < 0 ? fullName : fullName.substring(separator + 1);
  }

  /// The part before the name, empty when the provider reports none.
  String get owner {
    final separator = fullName.lastIndexOf('/');
    return separator < 0 ? '' : fullName.substring(0, separator);
  }
}

/// Filters [repositories] by [query] and orders them by how well they match.
///
/// The list is held in memory and filtered on every keystroke, so this must
/// stay a plain pass over it rather than a request per character.
///
/// Ranking follows how people actually recall a repository: they type the
/// beginning of its name. A prefix match on the name therefore outranks a match
/// anywhere in it, which in turn outranks the owner, which outranks the
/// description - otherwise a repository merely *mentioning* the term in prose
/// could outrank the one actually called that. Ties break alphabetically so the
/// order never shuffles between keystrokes.
List<HostedRepository> filterRepositories(
  List<HostedRepository> repositories,
  String query,
) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return [...repositories]..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

  final scored = <({HostedRepository repository, int rank})>[];
  for (final repository in repositories) {
    final rank = _rankOf(repository, trimmed);
    if (rank != null) scored.add((repository: repository, rank: rank));
  }

  scored.sort((a, b) {
    if (a.rank != b.rank) return a.rank.compareTo(b.rank);
    return a.repository.fullName.toLowerCase().compareTo(
      b.repository.fullName.toLowerCase(),
    );
  });

  return [for (final entry in scored) entry.repository];
}

/// Lower is a better match; null means it does not match at all.
int? _rankOf(HostedRepository repository, String query) {
  final name = repository.name.toLowerCase();
  if (name.startsWith(query)) return 0;
  if (name.contains(query)) return 1;
  if (repository.owner.toLowerCase().contains(query)) return 2;
  if (repository.description?.toLowerCase().contains(query) ?? false) return 3;
  return null;
}
