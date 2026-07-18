import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/config_providers.dart';
import '../../shared/widgets/empty_state.dart';

/// Base class for screens that depend on a repository being open
///
/// Automatically handles the common pattern of:
/// - Checking if a repository is open
/// - Showing an empty state if no repository
/// - Showing content if repository exists
abstract class RepositoryScreen extends ConsumerStatefulWidget {
  const RepositoryScreen({super.key});
}

/// Base state class for repository-dependent screens
///
/// Subclasses must implement [buildContent] to provide the screen's main content.
/// Optionally override [buildEmptyState] to customize the "no repository" state.
abstract class RepositoryScreenState<T extends RepositoryScreen>
    extends ConsumerState<T> {
  /// Override to provide a custom empty state when no repository is open
  ///
  /// By default, shows a generic "No Repository Open" message.
  Widget buildEmptyState(BuildContext context) {
    return const NoRepositoryEmptyState();
  }

  /// Override to build the main content when a repository is available
  ///
  /// The [repositoryPath] parameter contains the path to the current repository.
  Widget buildContent(BuildContext context, String repositoryPath);

  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);

    if (repositoryPath == null) {
      return buildEmptyState(context);
    }

    return buildContent(context, repositoryPath);
  }
}
