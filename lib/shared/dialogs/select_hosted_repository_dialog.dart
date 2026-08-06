import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Moves the highlight through the results while the caret stays in the
/// search field, so filtering and choosing are one keyboard flow.
class _MoveHighlightIntent extends Intent {
  const _MoveHighlightIntent(this.delta);

  final int delta;
}

/// Picks a repository to clone from the hosts the workspace already uses.
///
/// One tab per host, because each is a separate account seeing a separate set
/// of repositories: results must not be mixed, and a host that cannot be
/// listed has to say so in its own tab rather than silently contribute
/// nothing. With a single host no tab bar is shown.
///
/// Fully keyboard operable: the search field takes focus on open, the arrow
/// keys move through the results without leaving it, Enter takes the
/// highlighted one and Esc closes.
class SelectHostedRepositoryDialog extends ConsumerStatefulWidget {
  const SelectHostedRepositoryDialog({super.key});

  @override
  ConsumerState<SelectHostedRepositoryDialog> createState() =>
      _SelectHostedRepositoryDialogState();
}

class _SelectHostedRepositoryDialogState
    extends ConsumerState<SelectHostedRepositoryDialog>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  TabController? _tabController;
  String _query = '';
  int _highlight = 0;
  int _sourceCount = 0;

  /// Height of one result row, for scrolling the highlight into view.
  static const double _rowExtent = 56;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
        : (TabController(length: count, vsync: this)
            // Each host has its own result set, so the highlight cannot carry
            // over to a tab where that position means something else.
            ..addListener(() => setState(() => _highlight = 0)));
  }

  RepositorySource? _activeSource(List<RepositorySource> sources) {
    if (sources.isEmpty) return null;
    if (sources.length == 1) return sources.first;
    final index = _tabController?.index ?? 0;
    return sources[index.clamp(0, sources.length - 1)];
  }

  /// The results the keyboard acts on: those of the tab currently shown.
  List<HostedRepository> _matches(RepositorySource? source) {
    if (source == null) return const [];
    final result = ref.watch(sourceRepositoriesProvider(source)).value;
    if (result == null || result.hasFailed) return const [];
    return filterRepositories(result.repositories, _query);
  }

  void _moveHighlight(int delta, int matchCount) {
    if (matchCount == 0) return;
    setState(() {
      _highlight = (_highlight + delta).clamp(0, matchCount - 1);
    });
    if (!_scrollController.hasClients) return;
    // Keep the highlight in view; without this the arrow keys walk past the
    // bottom of the list and the selection becomes invisible.
    final target = _highlight * _rowExtent;
    final position = _scrollController.position;
    if (target < position.pixels) {
      _scrollController.jumpTo(target);
    } else if (target + _rowExtent >
        position.pixels + position.viewportDimension) {
      _scrollController.jumpTo(
        target + _rowExtent - position.viewportDimension,
      );
    }
  }

  void _confirm(List<HostedRepository> matches) {
    if (matches.isEmpty) return;
    Navigator.of(context).pop(matches[_highlight.clamp(0, matches.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sources = ref.watch(repositorySourcesProvider);
    _syncTabController(sources.length);

    final active = _activeSource(sources);
    final matches = _matches(active);
    if (_highlight >= matches.length) _highlight = 0;

    return BaseDialog(
      icon: PhosphorIconsRegular.cloudArrowDown,
      title: 'Select repository',
      // Enter confirms the highlighted match from anywhere in the dialog.
      onSubmit: matches.isEmpty ? null : () => _confirm(matches),
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
                  Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.arrowDown):
                          _MoveHighlightIntent(1),
                      SingleActivator(LogicalKeyboardKey.arrowUp):
                          _MoveHighlightIntent(-1),
                    },
                    child: Actions(
                      actions: {
                        _MoveHighlightIntent:
                            CallbackAction<_MoveHighlightIntent>(
                              onInvoke: (intent) {
                                _moveHighlight(intent.delta, matches.length);
                                return null;
                              },
                            ),
                      },
                      child: BaseTextField(
                        controller: _searchController,
                        label: l10n.search,
                        hintText: 'Filter by name, owner or description',
                        prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                        autofocus: true,
                        onChanged: (value) => setState(() {
                          _query = value;
                          // A new query is a new result set; the old position
                          // would point at an unrelated row.
                          _highlight = 0;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.paddingM),
                  Expanded(
                    child: sources.length == 1
                        ? _SourceResults(
                            source: sources.first,
                            query: _query,
                            highlight: _highlight,
                            scrollController: _scrollController,
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              for (final source in sources)
                                _SourceResults(
                                  source: source,
                                  query: _query,
                                  // Only the visible tab is the one the
                                  // keyboard is driving.
                                  highlight: source == active
                                      ? _highlight
                                      : null,
                                  scrollController: source == active
                                      ? _scrollController
                                      : null,
                                ),
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
        BaseButton(
          label: l10n.ok,
          leadingIcon: PhosphorIconsRegular.check,
          onPressed: matches.isEmpty ? null : () => _confirm(matches),
        ),
      ],
    );
  }
}

/// The result list of one host.
class _SourceResults extends ConsumerWidget {
  const _SourceResults({
    required this.source,
    required this.query,
    this.highlight,
    this.scrollController,
  });

  final RepositorySource source;
  final String query;

  /// Index the keyboard has moved to, or null when this tab is not in front.
  final int? highlight;

  final ScrollController? scrollController;

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
          controller: scrollController,
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final repository = matches[index];
            return BaseListItem(
              isSelected: index == highlight,
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
              'Could not reach ${source.host}.'
                  '${result.detail == null ? '' : '\n${result.detail}'}',
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
