import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// One place decides what a notice guarantees, and it is
/// `NotificationService`.
///
/// `Overlays.notify` is the contract's door and the service is what walks
/// through it. A call site that writes its own `NoticeSpec` skips the
/// decisions the service exists to make, and the skipping is not academic: it
/// was measured at 54 sites, 33 of them failures, 51 of them BRIEF. A failure
/// reported that way vanishes in two seconds with nothing to act on, while the
/// same failure through `NotificationService.showError` stays until the user
/// dismisses it and carries a copy affordance - because "a failure the user
/// never read is a failure they cannot act on" (#449).
///
/// So the rule is not about tidiness. Two call sites reporting the same git
/// failure behaved differently depending only on which one noticed it.
///
/// A site that needs a lifetime or an action the four methods do not offer
/// gets a FIFTH METHOD on the service - `showStandingInfo` is one, added for
/// exactly that reason - rather than a spec written by hand. That keeps the
/// question "what does a notice guarantee?" answerable by reading one file,
/// which is what #418 will need before it can answer it properly.
///
/// Scoped to the application's own code: the skin packages implement
/// `notify`, and the service itself is the one caller.
class AvoidRawNotice extends DartLintRule {
  const AvoidRawNotice() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_raw_notice',
    problemMessage:
        'Do not build a NoticeSpec at the call site: what a notice guarantees '
        '- whether it stays until read, and what the user can do about it - is '
        'decided once, in NotificationService. Use showSuccess / showError / '
        'showWarning / showInfo / showStandingInfo, or add a method there if '
        'none of them says what this means.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.uri.path;
    if (path.contains('/packages/') ||
        path.contains('/test/') ||
        path.endsWith('notification_service.dart')) {
      return;
    }

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'notify') return;
      // Matched on the written receiver rather than on a resolved element:
      // the door is a static method on one class with one name, and reading
      // the source text is what keeps this rule independent of which analyzer
      // element API is current.
      if (node.realTarget?.toSource() == 'Overlays') {
        reporter.atNode(node, code);
      }
    });
  }
}
