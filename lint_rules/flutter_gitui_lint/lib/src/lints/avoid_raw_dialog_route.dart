import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Application code opens OVERLAYS through the contract, never through a
/// framework route helper.
///
/// `showDialog` and `showGeneralDialog` are Material's own routes: they decide
/// the barrier, the transition and the navigator for every design language at
/// once, which is exactly the decision a skin exists to make. Both doors in
/// the contract reach the same skin route and the same surface:
///
///  * `Overlays.dialog(context, spec)` for a dialog that can be stated before
///    it exists - the frame is the same on every build and every callback only
///    pops;
///  * `Overlays.dialogFrom(context, route: ..., builder: ...)` for a dialog
///    whose frame depends on state created inside the route, which is the
///    commoner case: an affirmative action that turns on once a field
///    validates cannot be stated before that field exists.
///
/// This rule arrived with the last of the 66 call sites (#412). It is a gate
/// against regression rather than a migration nag, so it has nothing to
/// delete later: there is no correct use of a framework dialog route in this
/// application.
///
/// It watches CALLS. A tear-off handed to something else to invoke would slip
/// past, and that is left uncovered on purpose rather than half-covered: no
/// call site in this application has ever done it, and a rule that claims
/// more than it checks is worse than one that says where it stops.
class AvoidRawDialogRoute extends DartLintRule {
  const AvoidRawDialogRoute() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_raw_dialog_route',
    problemMessage:
        'Do not open an overlay with a framework route helper: it decides the '
        'barrier, the transition and the navigator for every skin at once. '
        'Use Overlays.dialog for a dialog that can be stated up front, '
        'Overlays.dialogFrom when its frame depends on state created inside '
        'the route, Overlays.menu or Overlays.anchor for a menu, and '
        'Overlays.popover for content attached to a control.',
  );

  /// The whole FAMILY, not the two names I first thought of.
  ///
  /// The first version of this rule watched `showDialog` and
  /// `showGeneralDialog`, and I closed #412 on a search for `showMenu(` that
  /// returned zero - because the four switchers wrote `showMenu<Workspace>(`,
  /// with a type argument between the name and the paren. Five raw overlay
  /// routes were still in the application, in a phase called "move every
  /// OVERLAY behind the contract". A set is what stops the next member being
  /// missed the same way; the analyzer sees the invocation whatever type
  /// arguments it carries.
  static const Set<String> _banned = <String>{
    'showDialog',
    'showGeneralDialog',
    'showMenu',
    'showModalBottomSheet',
    'showBottomSheet',
    'showDatePicker',
    'showTimePicker',
    'showAboutDialog',
    'showLicensePage',
    'showSearch',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // APPLICATION code only. A skin package pushing a framework route is not
    // a violation - it is the member doing its job: `MaterialOverlays` opens
    // Material's own `showDialog`, and the naked blueprint opens a general
    // route on purpose. Test harnesses pump a dialog widget directly to
    // measure it, which is not the application deciding anything either. The
    // ban is on `lib/` of the application, which is exactly what P6 (#414)
    // means by design leaving application code.
    final String path = resolver.source.uri.path;
    if (path.contains('/packages/') || path.contains('/test/')) return;

    context.registry.addMethodInvocation((node) {
      if (_banned.contains(node.methodName.name)) {
        reporter.atNode(node, code);
      }
    });
  }
}
