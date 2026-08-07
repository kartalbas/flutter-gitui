import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces that a `Widget` crosses into a skin only as a `ContentPort`
/// (#249, `docs/SKIN-CONTRACT.md` §2.10).
///
/// > The `no_widget_in_contract` lint enforces that any `Widget`-typed
/// > parameter on any contract member is a `ContentPort`.
///
/// **What it protects.** The attribution walk (§3.5) prunes at every
/// `SkinPainted` and resumes at every `ContentPortBoundary`, and a boundary is
/// planted in exactly one place: `ContentPort.mount()`. So a widget handed to a
/// skin any other way has no boundary above it, lands inside the pruned region,
/// and is invisible to the walk forever - along with every leak inside it. The
/// lint is what keeps that true as the contract grows, rather than as a habit
/// somebody has to keep at each new member.
///
/// This was not a hypothetical when the rule was written: `layout.column`,
/// `layout.row`, `layout.inset` and `GridSpec.children` all took raw widgets,
/// and those are the three most-called members in the whole contract. §3.6
/// books this rule's blast radius as "0 (a standing guarantee, not a
/// countdown)"; it was 5, and the rule is what makes the booked number true.
///
/// **The one exemption, and why it is not a hole.** `SkinChrome.wrapRoot`'s
/// `child` stays a `Widget`. Its argument is never supplied by application
/// code: the contract package composes it in `SkinScope.install` and in the
/// overlay hosts, and those two places have already planted the fence OUTSIDE
/// the call and the boundary INSIDE it, at the exact point the application's
/// own content resumes. Typing it as a port instead would put the resume above
/// the skin's own overlay frame and mis-attribute every skin-built popover,
/// menu and notice surface to the application - the same defect this rule
/// exists to remove, pointing the other way. The exemption is by member name
/// and parameter name together, so it cannot spread by accident.
class NoWidgetInContract extends DartLintRule {
  const NoWidgetInContract() : super(code: _code);

  static const _code = LintCode(
    name: 'no_widget_in_contract',
    problemMessage:
        'A Widget may cross into a skin only as a ContentPort. A raw Widget '
        'parameter has no ContentPortBoundary above it, so the attribution '
        'walk (SKIN-CONTRACT.md §3.5) never resumes inside it and every leak '
        'in that subtree is invisible - permanently, and silently.',
    correctionMessage:
        'Declare it as ContentPort (or List<ContentPort>) and let the skin '
        'call mount() where the content should appear. That plants the '
        'boundary the walk resumes at, in the one place it can be planted.',
  );

  /// The package this rule guards: the contract itself.
  static const String _contractPackage = 'gitui_skin_api';

  /// The widget-ish types a parameter may not be declared as.
  ///
  /// `PreferredSizeWidget` and the rest of Flutter's widget-shaped interfaces
  /// are included because a parameter typed as one of them is a widget seam by
  /// another name.
  static const Set<String> _widgetTypes = {
    'Widget',
    'PreferredSizeWidget',
    'StatelessWidget',
    'StatefulWidget',
    'InheritedWidget',
    'RenderObjectWidget',
  };

  /// The sanctioned raw-`Widget` parameters, as declaration name to parameter
  /// name. Changing this map is a change to the partition, not a convenience.
  ///
  ///  * `wrapRoot`'s `child` - see the class doc.
  ///  * `DialogKeyboardHostBuilder`'s `surface` and `SkinOverlayFrame`'s
  ///    `content` are the two function types the contract package composes
  ///    with internally. Neither is a seam: the widget flowing through them
  ///    has already been fenced by the caller, which in both cases is this
  ///    package itself, and both are handed to the layer ABOVE the skin rather
  ///    than into it.
  static const Map<String, String> _sanctioned = {
    'wrapRoot': 'child',
    'DialogKeyboardHostBuilder': 'surface',
    'SkinOverlayFrame': 'content',
  };

  /// Declarations that are not contract members and so are not seams.
  ///
  /// The contract ships two widgets of its own - the form-field host that
  /// makes `validate()` work under every skin, and the controller bridge
  /// inside it - and a widget's own `child` field is not a place a design
  /// language crosses. They are recognised by being a class that extends a
  /// Flutter widget, which is a property of the declaration rather than a
  /// list of names to keep up to date.
  static const Set<String> _widgetSuperclasses = {
    'StatelessWidget',
    'StatefulWidget',
    'InheritedWidget',
    'State',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isContractLibrary(resolver)) return;

    context.registry.addSimpleFormalParameter((SimpleFormalParameter node) {
      final TypeAnnotation? declared = node.type;
      final String? typeName = switch (declared) {
        NamedType(name: final Token name) => name.lexeme,
        _ => null,
      };
      if (typeName == null) return;
      if (!_namesAWidget(typeName, declared)) return;
      if (_isSanctioned(node)) return;
      if (_isInsideAWidgetClass(node)) return;
      reporter.atNode(node, _code);
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? type = node.fields.type;
      final String? typeName = switch (type) {
        NamedType(name: final Token name) => name.lexeme,
        _ => null,
      };
      if (typeName == null) return;
      if (!_namesAWidget(typeName, type)) return;
      if (_isInsideAWidgetClass(node)) return;
      if (_isPrivate(node)) return;
      reporter.atNode(node, _code);
    });
  }

  /// Whether every name this declaration introduces is private.
  ///
  /// A private field is not a seam: nothing outside its own library can hand
  /// a widget to it or read one out of it. `ContentPort._child` is the case
  /// that matters - it is the one legitimate holder of an unfenced widget in
  /// the whole package, and it is unreachable by construction, which is
  /// exactly the property the port exists for.
  static bool _isPrivate(FieldDeclaration node) => node.fields.variables.every(
    (VariableDeclaration variable) => variable.name.lexeme.startsWith('_'),
  );

  /// Whether this annotation names a widget, directly or as the element type
  /// of a collection - `List<Widget>` is the same seam spelled longer.
  static bool _namesAWidget(String typeName, TypeAnnotation? annotation) {
    if (_widgetTypes.contains(typeName)) return true;
    if (annotation is! NamedType) return false;
    final List<TypeAnnotation> arguments =
        annotation.typeArguments?.arguments ?? const <TypeAnnotation>[];
    return arguments.any(
      (TypeAnnotation argument) =>
          argument is NamedType &&
          _namesAWidget(argument.name.lexeme, argument),
    );
  }

  /// Whether this parameter is one of the sanctioned raw-`Widget` seams.
  static bool _isSanctioned(SimpleFormalParameter node) {
    final String? parameter = node.name?.lexeme;
    if (parameter == null) return false;
    for (AstNode? at = node.parent; at != null; at = at.parent) {
      final String? declaration = switch (at) {
        MethodDeclaration(name: final Token name) => name.lexeme,
        GenericTypeAlias(name: final Token name) => name.lexeme,
        FunctionTypeAlias(name: final Token name) => name.lexeme,
        _ => null,
      };
      if (declaration != null) return _sanctioned[declaration] == parameter;
      if (at is FunctionDeclaration || at is ClassDeclaration) return false;
    }
    return false;
  }

  /// Whether the declaration belongs to a widget the contract package builds
  /// itself, rather than to a contract member.
  static bool _isInsideAWidgetClass(AstNode node) {
    for (AstNode? at = node.parent; at != null; at = at.parent) {
      if (at is! ClassDeclaration) continue;
      final String? superclass = at.extendsClause?.superclass.name.lexeme;
      return superclass != null && _widgetSuperclasses.contains(superclass);
    }
    return false;
  }

  /// True for a library inside the contract package. Both URI forms are
  /// handled for the reason given in `no_value_in_contract`: a scope test that
  /// silently excludes its own population reports a reassuring zero.
  static bool _isContractLibrary(CustomLintResolver resolver) {
    final Uri uri = resolver.source.uri;
    if (uri.scheme == 'package') {
      return uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == _contractPackage;
    }
    final String path = resolver.path.replaceAll(r'\', '/');
    return path.contains('/packages/$_contractPackage/lib/');
  }
}
