import 'package:url_launcher/url_launcher.dart';

/// Git hosting platform types
enum GitPlatform {
  github,
  gitlab,
  bitbucket,
  azureDevOps,
  gitea,
  unknown,
}

/// Service for detecting git platforms and generating platform-specific URLs
class GitPlatformService {
  /// Detect the git platform from a remote URL
  static GitPlatform detectPlatform(String remoteUrl) {
    final url = remoteUrl.toLowerCase();

    if (url.contains('github.com')) {
      return GitPlatform.github;
    } else if (url.contains('gitlab.com') || url.contains('gitlab')) {
      return GitPlatform.gitlab;
    } else if (url.contains('bitbucket.org') || url.contains('bitbucket')) {
      return GitPlatform.bitbucket;
    } else if (url.contains('dev.azure.com') || url.contains('visualstudio.com')) {
      return GitPlatform.azureDevOps;
    } else if (url.contains('gitea')) {
      return GitPlatform.gitea;
    }

    return GitPlatform.unknown;
  }

  /// Parse repository info from remote URL
  static Map<String, String>? parseRemoteUrl(String remoteUrl) {
    // Handle both HTTPS and SSH URLs
    String cleanUrl = remoteUrl;

    // Special handling for Azure DevOps SSH URLs
    // Format: git@ssh.dev.azure.com:v3/org/project/repo
    if (cleanUrl.contains('ssh.dev.azure.com')) {
      final match = RegExp(r'git@ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/(.+?)(?:\.git)?$')
          .firstMatch(cleanUrl);
      if (match != null) {
        final org = match.group(1)!;
        final project = match.group(2)!;
        final repo = match.group(3)!;
        return {
          'host': 'dev.azure.com',
          'owner': org,
          'project': project,
          'repo': repo,
          'baseUrl': 'https://dev.azure.com',
        };
      }
    }

    // Standard SSH format: git@github.com:user/repo.git
    if (cleanUrl.startsWith('git@')) {
      cleanUrl = cleanUrl.replaceFirst('git@', 'https://');
      cleanUrl = cleanUrl.replaceFirst(':', '/');
    }

    // Remove .git suffix
    if (cleanUrl.endsWith('.git')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 4);
    }

    try {
      final uri = Uri.parse(cleanUrl);
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      if (pathSegments.length >= 2) {
        final result = {
          'host': uri.host,
          'owner': pathSegments[pathSegments.length - 2],
          'repo': pathSegments[pathSegments.length - 1],
          'baseUrl': '${uri.scheme}://${uri.host}',
        };

        // For Azure DevOps HTTPS URLs, extract project info
        // Format: https://dev.azure.com/org/project/_git/repo
        if (uri.host.contains('dev.azure.com') && pathSegments.length >= 4) {
          result['project'] = pathSegments[1];
        }

        return result;
      }
    } catch (e) {
      // Parse failed
    }

    return null;
  }

  /// Generate PR creation URL for the detected platform
  static String? generatePRUrl({
    required GitPlatform platform,
    required String remoteUrl,
    required String sourceBranch,
    required String targetBranch,
    String? title,
    String? description,
    bool draft = false,
  }) {
    final repoInfo = parseRemoteUrl(remoteUrl);
    if (repoInfo == null) return null;

    final encodedTitle = Uri.encodeComponent(title ?? '');
    final encodedDescription = Uri.encodeComponent(description ?? '');
    final encodedSource = Uri.encodeComponent(sourceBranch);
    final encodedTarget = Uri.encodeComponent(targetBranch);

    switch (platform) {
      case GitPlatform.github:
        // GitHub PR creation URL
        // https://github.com/owner/repo/compare/base...head?quick_pull=1&title=...&body=...
        final draftParam = draft ? '&draft=1' : '';
        return '${repoInfo['baseUrl']}/${repoInfo['owner']}/${repoInfo['repo']}/compare/$encodedTarget...$encodedSource?quick_pull=1&title=$encodedTitle&body=$encodedDescription$draftParam';

      case GitPlatform.gitlab:
        // GitLab merge request creation URL
        // https://gitlab.com/owner/repo/-/merge_requests/new?merge_request[source_branch]=...&merge_request[target_branch]=...
        return '${repoInfo['baseUrl']}/${repoInfo['owner']}/${repoInfo['repo']}/-/merge_requests/new?merge_request[source_branch]=$encodedSource&merge_request[target_branch]=$encodedTarget&merge_request[title]=$encodedTitle&merge_request[description]=$encodedDescription';

      case GitPlatform.bitbucket:
        // Bitbucket pull request creation URL
        // https://bitbucket.org/owner/repo/pull-requests/new?source=...&dest=...
        return '${repoInfo['baseUrl']}/${repoInfo['owner']}/${repoInfo['repo']}/pull-requests/new?source=$encodedSource&dest=$encodedTarget&title=$encodedTitle&description=$encodedDescription';

      case GitPlatform.azureDevOps:
        // Azure DevOps pull request creation URL
        // https://dev.azure.com/org/project/_git/repo/pullrequestcreate?sourceRef=...&targetRef=...
        final org = repoInfo['owner'];
        final project = repoInfo['project'];
        final repo = repoInfo['repo'];

        if (org != null && project != null && repo != null) {
          return '${repoInfo['baseUrl']}/$org/$project/_git/$repo/pullrequestcreate?sourceRef=$encodedSource&targetRef=$encodedTarget&title=$encodedTitle&description=$encodedDescription';
        }
        return null;

      case GitPlatform.gitea:
        // Gitea pull request creation URL
        // https://gitea.example.com/owner/repo/compare/base...head
        return '${repoInfo['baseUrl']}/${repoInfo['owner']}/${repoInfo['repo']}/compare/$encodedTarget...$encodedSource?title=$encodedTitle&body=$encodedDescription';

      case GitPlatform.unknown:
        return null;
    }
  }

  /// Open PR creation in browser
  static Future<bool> openPRCreation({
    required String remoteUrl,
    required String sourceBranch,
    required String targetBranch,
    String? title,
    String? description,
    bool draft = false,
  }) async {
    final platform = detectPlatform(remoteUrl);
    final url = generatePRUrl(
      platform: platform,
      remoteUrl: remoteUrl,
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
      title: title,
      description: description,
      draft: draft,
    );

    if (url == null) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      return false;
    }

    return false;
  }

  /// Get platform display name
  static String getPlatformName(GitPlatform platform) {
    switch (platform) {
      case GitPlatform.github:
        return 'GitHub';
      case GitPlatform.gitlab:
        return 'GitLab';
      case GitPlatform.bitbucket:
        return 'Bitbucket';
      case GitPlatform.azureDevOps:
        return 'Azure DevOps';
      case GitPlatform.gitea:
        return 'Gitea';
      case GitPlatform.unknown:
        return 'Unknown';
    }
  }
}
