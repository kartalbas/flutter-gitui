import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// Where the user's request lives while this skin is drawing.
///
/// The same arrangement, for the same reason, as `MaterialRequestScope` in
/// `packages/gitui_skin_material/lib/src/material_theme.dart`: the facets need
/// per-user values that no theme object publishes - the type resolution reads
/// `monoFamily`, `uiFamily` and `textScale`, and the motion facet will read
/// `animationScale` - so `chrome.wrapRoot` installs the request once and the
/// facets reach it from the tree. It lives in its own file rather than inside
/// the typography because it serves more than one facet; typography is merely
/// its first consumer.
final class FluentRequestScope extends InheritedWidget {
  /// Installs [request] over [child].
  const FluentRequestScope({
    super.key,
    required this.request,
    required super.child,
  });

  /// The user's choices, as the application stated them.
  final SkinRequest request;

  /// The request in force at [context], or null outside `wrapRoot` - which
  /// only a test that renders a facet without its root can arrange.
  static SkinRequest? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FluentRequestScope>()?.request;

  @override
  bool updateShouldNotify(covariant FluentRequestScope oldWidget) =>
      oldWidget.request != request;
}
