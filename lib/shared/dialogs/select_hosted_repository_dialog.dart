import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../core/hosting/hosted_repository.dart';
import '../../core/hosting/hosting_providers.dart';
import '../../generated/app_localizations.dart';
import '../components/base_button.dart';
import '../components/base_dialog.dart';
import '../components/base_label.dart';
import '../components/base_list_item.dart';
import '../components/base_text_field.dart';
import '../theme/app_theme.dart';

/// Picks a repository to clone from the hosts the workspace already uses.
///
/// One tab per host, because each is a separate account seeing a separate set
/// of repositories: results must not be mixed, and a host that cannot be
/// listed has to say so in its own tab rather than silently contribute
/// nothing. With a single host no tab bar is shown.
class SelectHostedRepositoryDialog extends ConsumerStatefulWidget {
  const SelectHostedRepositoryDialog({super.key});

  @override
  ConsumerState<SelectHostedRepositoryDialog> createState() =>
      _SelectHostedRepositoryDialogState();
}

class _SelectHostedRepositoryDialogState
    extends ConsumerState<SelectHostedRepositoryDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;
  String _query = '';
  int _sourceCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  /// Keeps the controller in step with the sources, which arrive with the
  /// workspace status and can therefore change while the dialog is open.
  void _syncTabController(int count) {
    if (count == _sourceCount && _tabController != null) return;
    _tabController?.dispose();
    _sourceCount = count;
    _tabController = count == 0
        ? null
        : TabController(length: count, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sources = ref.watch(repositorySourcesProvider);
    _syncTabController(sources.length);

    return BaseDialog(
      icon: PhosphorIconsRegular.cloudArrowDown,
      title: 'Select repository',
      content: SizedBox(
        width: 640,
        height: 460,
        child: sources.isEmpty
            ? const Center(
                child: BodyMediumLabel(
                  'No browsable host yet. Add a repository from a supported '
                  'provider first, then its repositories can be listed here.',
                ),
              )
            : Column(
                children: [
                  // A single host needs no chooser; showing one tab would be
                  // an empty frame around the only option.
                  if (sources.length > 1)
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: [
                        for (final source in sources) Tab(text: source.label),
                      ],
                    ),
                  const SizedBox(height: AppTheme.paddingM),
                  BaseTextField(
                    controller: _searchController,
                    label: l10n.search,
                    hintText: 'Filter by name, owner or description',
                    prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: AppTheme.paddingM),
                  Expanded(
                    child: sources.length == 1
                        ? _SourceResults(source: sources.first, query: _query)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              for (final source in sources)
                                _SourceResults(source: source, query: _query),
                            ],
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The result list of one host.
class _SourceResults extends ConsumerWidget {
  const _SourceResults({required this.source, required this.query});

  final RepositorySource source;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRepositories = ref.watch(sourceRepositoriesProvider(source));

    return asyncRepositories.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Message(
        icon: PhosphorIconsRegular.warningCircle,
        text: 'Could not list ${source.label}: $error',
        isError: true,
      ),
      data: (result) {
        if (result.hasFailed) {
          return _FailureMessage(source: source, result: result);
        }

        // Filtered here rather than by asking the provider again: the list is
        // already in memory, so typing costs nothing and never reorders while
        // a request is in flight.
        final matches = filterRepositories(result.repositories, query);
        if (matches.isEmpty) {
          return _Message(
            icon: PhosphorIconsRegular.magnifyingGlass,
            text: result.repositories.isEmpty
                ? 'This account can see no repositories on ${source.label}.'
                : 'Nothing matches "$query".',
          );
        }

        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final repository = matches[index];
            return BaseListItem(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingM,
                vertical: AppTheme.paddingS,
              ),
              leading: Icon(
                repository.isPrivate
                    ? PhosphorIconsRegular.lock
                    : PhosphorIconsRegular.bookOpen,
                size: AppTheme.iconS,
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BodyMediumLabel(
                    repository.fullName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (repository.description case final description?)
                    BodySmallLabel(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              onTap: () => Navigator.of(context).pop(repository),
            );
          },
        );
      },
    );
  }
}

/// Why a host contributes nothing, and what can be done about it.
class _FailureMessage extends ConsumerWidget {
  const _FailureMessage({required this.source, required this.result});

  final RepositorySource source;
  final SourceRepositories result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsSignIn =
        result.failure == SourceFailure.credentialsMissing ||
        result.failure == SourceFailure.authenticationRejected;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            needsSignIn
                ? PhosphorIconsRegular.signIn
                : PhosphorIconsRegular.warningCircle,
            size: AppTheme.iconXL,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingM),
          BodyMediumLabel(switch (result.failure!) {
            SourceFailure.credentialsMissing =>
              'No sign-in stored for ${source.host}.',
            SourceFailure.authenticationRejected =>
              'The stored sign-in for ${source.host} was refused.',
            SourceFailure.requestFailed =>
              'Could not reach ${source.host}.${result.detail == null ? '' : '\n${result.detail}'}',
          }, textAlign: TextAlign.center),
          if (needsSignIn) ...[
            const SizedBox(height: AppTheme.paddingM),
            // Signing in is offered rather than forced: the picker opening
            // must never make a credential helper take over the screen.
            BaseButton(
              label: 'Sign in',
              leadingIcon: PhosphorIconsRegular.signIn,
              onPressed: () =>
                  ref.invalidate(sourceRepositoriesProvider(source)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppTheme.iconXL, color: color),
          const SizedBox(height: AppTheme.paddingM),
          BodyMediumLabel(text, textAlign: TextAlign.center, color: color),
        ],
      ),
    );
  }
}

/// Opens the picker; resolves to the chosen repository, or null if cancelled.
Future<HostedRepository?> showSelectHostedRepositoryDialog(
  BuildContext context,
) {
  return showDialog<HostedRepository>(
    context: context,
    builder: (context) => const SelectHostedRepositoryDialog(),
  );
}
