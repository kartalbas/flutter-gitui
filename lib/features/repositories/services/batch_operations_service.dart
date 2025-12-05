import '../../../core/git/git_service.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../core/workspace/models/repository_status.dart';

/// Result of a batch operation on a single repository
class BatchOperationResult {
  final WorkspaceRepository repository;
  final bool success;
  final String? message;
  final String? error;

  const BatchOperationResult({
    required this.repository,
    required this.success,
    this.message,
    this.error,
  });

  @override
  String toString() => 'BatchOperationResult(${repository.displayName}: ${success ? 'success' : 'failed'})';
}

/// Progress callback for batch operations
typedef BatchProgressCallback = void Function(
  WorkspaceRepository repository,
  int current,
  int total,
  String status,
);

/// Service for performing batch operations on multiple repositories
class BatchOperationsService {
  final String? gitExecutablePath;
  final void Function(String)? onLog;

  BatchOperationsService({
    this.gitExecutablePath,
    this.onLog,
  });

  /// Detect the main branch for a repository
  /// Tries common names in order of preference
  Future<String?> detectMainBranch(String repoPath) async {
    final gitService = GitService(repoPath, gitExecutablePath: gitExecutablePath);

    // Try common branch names in order of preference
    final commonNames = ['main', 'master', 'develop', 'development', 'trunk'];

    try {
      final branches = await gitService.getBranches();

      // First, try the common names in order
      for (final branchName in commonNames) {
        if (branches.contains(branchName)) {
          return branchName;
        }
      }

      // If no common name found, use the first branch
      if (branches.isNotEmpty) {
        return branches.first;
      }
    } catch (e) {
      onLog?.call('Error detecting main branch: $e');
    }

    return null;
  }

  /// Checkout repositories to their main branch
  /// Git will handle uncommitted changes if they conflict
  Future<List<BatchOperationResult>> checkoutToMain(
    List<WorkspaceRepository> repositories,
    Map<String, RepositoryStatus> statuses, {
    BatchProgressCallback? onProgress,
  }) async {
    final results = <BatchOperationResult>[];
    int current = 0;
    final total = repositories.length;

    for (final repo in repositories) {
      current++;
      onProgress?.call(repo, current, total, 'Detecting main branch...');

      final status = statuses[repo.path];

      try {
        // Detect main branch
        final mainBranch = await detectMainBranch(repo.path);

        if (mainBranch == null) {
          results.add(BatchOperationResult(
            repository: repo,
            success: false,
            error: 'Could not detect main branch',
          ));
          continue;
        }

        // Check if already on main branch
        if (status?.currentBranch == mainBranch) {
          results.add(BatchOperationResult(
            repository: repo,
            success: true,
            message: 'Already on $mainBranch',
          ));
          continue;
        }

        onProgress?.call(repo, current, total, 'Checking out $mainBranch...');

        // Checkout to main branch - git will handle uncommitted changes
        final gitService = GitService(repo.path, gitExecutablePath: gitExecutablePath);
        final result = await gitService.checkoutBranch(mainBranch);
        result.unwrap(); // Throw on error to trigger catch block

        results.add(BatchOperationResult(
          repository: repo,
          success: true,
          message: 'Checked out to $mainBranch',
        ));
        onLog?.call('✓ ${repo.displayName}: Checked out to $mainBranch');
      } catch (e) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: e.toString(),
        ));
        onLog?.call('✗ ${repo.displayName}: $e');
      }
    }

    return results;
  }

  /// Fetch all repositories
  /// Updates remote tracking branches without merging
  Future<List<BatchOperationResult>> fetchAll(
    List<WorkspaceRepository> repositories,
    Map<String, RepositoryStatus> statuses, {
    BatchProgressCallback? onProgress,
  }) async {
    final results = <BatchOperationResult>[];
    int current = 0;
    final total = repositories.length;

    for (final repo in repositories) {
      current++;
      onProgress?.call(repo, current, total, 'Fetching changes...');

      final status = statuses[repo.path];

      // Skip if repo has no remote
      if (!(status?.hasRemote ?? false)) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: 'No remote configured',
        ));
        continue;
      }

      try {
        final gitService = GitService(repo.path, gitExecutablePath: gitExecutablePath);
        final outputResult = await gitService.fetch();
        final output = outputResult.unwrap();

        results.add(BatchOperationResult(
          repository: repo,
          success: true,
          message: output,
        ));
        onLog?.call('✓ ${repo.displayName}: $output');
      } catch (e) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: e.toString(),
        ));
        onLog?.call('✗ ${repo.displayName}: $e');
      }
    }

    return results;
  }

  /// Pull all repositories
  /// Only requires remote to be configured - git will handle uncommitted changes
  Future<List<BatchOperationResult>> pullAll(
    List<WorkspaceRepository> repositories,
    Map<String, RepositoryStatus> statuses, {
    BatchProgressCallback? onProgress,
  }) async {
    final results = <BatchOperationResult>[];
    int current = 0;
    final total = repositories.length;

    for (final repo in repositories) {
      current++;
      onProgress?.call(repo, current, total, 'Pulling changes...');

      final status = statuses[repo.path];

      // Skip if repo has no remote
      if (!(status?.hasRemote ?? false)) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: 'No remote configured',
        ));
        continue;
      }

      try {
        final gitService = GitService(repo.path, gitExecutablePath: gitExecutablePath);
        final outputResult = await gitService.pull();
        final output = outputResult.unwrap();

        results.add(BatchOperationResult(
          repository: repo,
          success: true,
          message: output,
        ));
        onLog?.call('✓ ${repo.displayName}: $output');
      } catch (e) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: e.toString(),
        ));
        onLog?.call('✗ ${repo.displayName}: $e');
      }
    }

    return results;
  }

  /// Push all repositories
  /// Only operates on repositories with clean status and remote configured
  Future<List<BatchOperationResult>> pushAll(
    List<WorkspaceRepository> repositories,
    Map<String, RepositoryStatus> statuses, {
    BatchProgressCallback? onProgress,
  }) async {
    final results = <BatchOperationResult>[];
    int current = 0;
    final total = repositories.length;

    for (final repo in repositories) {
      current++;
      onProgress?.call(repo, current, total, 'Pushing changes...');

      final status = statuses[repo.path];

      // Skip if repo has no remote
      if (!(status?.hasRemote ?? false)) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: 'No remote configured',
        ));
        continue;
      }

      try {
        final gitService = GitService(repo.path, gitExecutablePath: gitExecutablePath);
        final outputResult = await gitService.push();
        final output = outputResult.unwrap();

        results.add(BatchOperationResult(
          repository: repo,
          success: true,
          message: output,
        ));
        onLog?.call('✓ ${repo.displayName}: $output');
      } catch (e) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: e.toString(),
        ));
        onLog?.call('✗ ${repo.displayName}: $e');
      }
    }

    return results;
  }

  /// Checkout a specific branch in multiple repositories
  /// Skips repositories that don't have the branch
  Future<List<BatchOperationResult>> checkoutBranchInAll(
    List<WorkspaceRepository> repositories,
    Map<String, RepositoryStatus> statuses,
    String branchName, {
    BatchProgressCallback? onProgress,
  }) async {
    final results = <BatchOperationResult>[];
    int current = 0;
    final total = repositories.length;

    for (final repo in repositories) {
      current++;
      onProgress?.call(repo, current, total, 'Checking out $branchName...');

      final status = statuses[repo.path];

      try {
        // Check if already on the target branch
        if (status?.currentBranch == branchName) {
          results.add(BatchOperationResult(
            repository: repo,
            success: true,
            message: 'Already on $branchName',
          ));
          continue;
        }

        // Check if branch exists before attempting checkout
        final gitService = GitService(repo.path, gitExecutablePath: gitExecutablePath);
        final branches = await gitService.getBranches();

        if (!branches.contains(branchName)) {
          results.add(BatchOperationResult(
            repository: repo,
            success: false,
            error: 'Branch "$branchName" not found in repository',
          ));
          onLog?.call('- ${repo.displayName}: Branch "$branchName" not found');
          continue;
        }

        // Checkout to the branch
        final checkoutResult = await gitService.checkoutBranch(branchName);
        checkoutResult.unwrap(); // Throw on error to trigger catch block

        results.add(BatchOperationResult(
          repository: repo,
          success: true,
          message: 'Checked out to $branchName',
        ));
        onLog?.call('✓ ${repo.displayName}: Checked out to $branchName');
      } catch (e) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: e.toString(),
        ));
        onLog?.call('✗ ${repo.displayName}: $e');
      }
    }

    return results;
  }

  /// Create a branch in multiple repositories
  /// [branchName] - Name of the branch without prefix
  /// [prefix] - Prefix to add (feature/, release/, etc.)
  /// [setUpstream] - Whether to push and set upstream
  /// [checkout] - Whether to checkout the new branch after creation
  Future<List<BatchOperationResult>> createBranch(
    List<WorkspaceRepository> repositories, {
    required String branchName,
    String prefix = '',
    bool setUpstream = false,
    bool checkout = false,
    BatchProgressCallback? onProgress,
  }) async {
    final results = <BatchOperationResult>[];
    final fullBranchName = prefix.isEmpty ? branchName : '$prefix$branchName';
    int current = 0;
    final total = repositories.length;

    for (final repo in repositories) {
      current++;
      onProgress?.call(repo, current, total, 'Creating branch $fullBranchName...');

      try {
        final gitService = GitService(repo.path, gitExecutablePath: gitExecutablePath);

        // Check if branch already exists
        final branches = await gitService.getBranches();
        if (branches.contains(fullBranchName)) {
          results.add(BatchOperationResult(
            repository: repo,
            success: false,
            error: 'Branch $fullBranchName already exists',
          ));
          continue;
        }

        // Create branch
        final createResult = await gitService.createBranch(fullBranchName, checkout: checkout);
        createResult.unwrap(); // Throw on error to trigger catch block

        // Set upstream if requested
        if (setUpstream) {
          onProgress?.call(repo, current, total, 'Setting upstream...');

          try {
            final pushOutput = await gitService.push(
              remote: 'origin',
              branch: fullBranchName,
              setUpstream: true,
            );

            results.add(BatchOperationResult(
              repository: repo,
              success: true,
              message: 'Branch created: $pushOutput',
            ));
            onLog?.call('✓ ${repo.displayName}: Created $fullBranchName: $pushOutput');
          } catch (e) {
            // Branch was created but push failed
            results.add(BatchOperationResult(
              repository: repo,
              success: true,
              message: 'Branch created (push failed: $e)',
            ));
            onLog?.call('⚠ ${repo.displayName}: Created $fullBranchName but push failed: $e');
          }
        } else {
          results.add(BatchOperationResult(
            repository: repo,
            success: true,
            message: 'Branch created',
          ));
          onLog?.call('✓ ${repo.displayName}: Created $fullBranchName');
        }
      } catch (e) {
        results.add(BatchOperationResult(
          repository: repo,
          success: false,
          error: e.toString(),
        ));
        onLog?.call('✗ ${repo.displayName}: $e');
      }
    }

    return results;
  }
}
