/// chrome.wrapRoot, measured: what the root treatment actually installs.
///
/// The composition under test is the reference's own (fluent_ui@4.16.1
/// styles/theme.dart:77-79 wraps the theme scope's child in an IconTheme
/// and a DefaultTextStyle over typography.body; :474-475 gives the icon
/// default black-on-light / white-on-dark at 18; :464-467 stamps
/// `textFillColorPrimary` onto the ramp), plus the window ground the
/// translucent control fills composite against
/// (`SolidBackgroundFillColorBase`, the reference's `micaBackgroundColor`,
/// theme.dart:460). Every pinned literal restates its source beside it,
/// independently of the constants in lib/.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/fluent_request_scope.dart';
import 'package:gitui_skin_fluent/src/fluent_theme.dart';

import 'support/fluent_chrome_harness.dart';

// SolidBackgroundFillColorBase: light color_resources.dart:340, dark :253.
const Color _groundLight = Color(0xFFf3f3f3);
const Color _groundDark = Color(0xFF202020);

// TextFillColorPrimary: light color_resources.dart:277, dark :190.
const Color _textPrimaryLight = Color(0xe4000000);
const Color _textPrimaryDark = Color(0xFFffffff);

void main() {
  testWidgets('installs the theme scope and the request scope, so every '
      'facet below can resolve', (WidgetTester tester) async {
    late BuildContext probe;
    await pumpFluentChrome(tester, (BuildContext context) {
      probe = context;
      return const SizedBox.shrink();
    });
    expect(FluentTheme.of(probe).brightness, Brightness.light);
    final SkinRequest? request = FluentRequestScope.maybeOf(probe);
    expect(request, isNotNull);
    expect(request!.brightness, Brightness.light);
  });

  testWidgets('paints the window ground the language specifies - the solid '
      'stand-in for Mica', (WidgetTester tester) async {
    await pumpFluentChrome(tester, (_) => const SizedBox.shrink());
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is ColoredBox && widget.color == _groundLight,
      ),
      findsOneWidget,
      reason:
          'the root must paint SolidBackgroundFillColorBase '
          '(color_resources.dart:340) - the ground every translucent '
          'control fill composites against',
    );
  });

  testWidgets('a dark request flips the ground, the dictionary and the '
      'ambient ink together', (WidgetTester tester) async {
    late BuildContext probe;
    await pumpFluentChrome(tester, brightness: Brightness.dark, (
      BuildContext context,
    ) {
      probe = context;
      return const SizedBox.shrink();
    });
    expect(FluentTheme.of(probe).brightness, Brightness.dark);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is ColoredBox && widget.color == _groundDark,
      ),
      findsOneWidget,
    );
    expect(
      DefaultTextStyle.of(probe).style.color!.toARGB32(),
      _textPrimaryDark.toARGB32(),
    );
    expect(
      IconTheme.of(probe).color!.toARGB32(),
      0xFFFFFFFF,
      reason:
          'the icon default is white on dark grounds '
          '(fluent_ui styles/theme.dart:474-475)',
    );
  });

  testWidgets('the ambient text default is body in the primary ink - the '
      'reference\'s own root arrangement', (WidgetTester tester) async {
    late BuildContext probe;
    await pumpFluentChrome(tester, (BuildContext context) {
      probe = context;
      return const SizedBox.shrink();
    });
    final TextStyle ambient = DefaultTextStyle.of(probe).style;
    expect(
      ambient.fontSize,
      14,
      reason: 'Body is 14/20 Regular (SPEC type-ramp table)',
    );
    expect(ambient.fontWeight, FontWeight.w400);
    expect(
      ambient.color!.toARGB32(),
      _textPrimaryLight.toARGB32(),
      reason:
          'the reference stamps TextFillColorPrimary onto every ramp step '
          '(theme.dart:464-467); this skin\'s ramp carries no colour, so '
          'the root supplies it',
    );
    expect(
      IconTheme.of(probe).size,
      18,
      reason: 'the icon default is 18 (theme.dart:474-475)',
    );
  });

  testWidgets('the user\'s text scale multiplies the ambient style, rounded '
      'to a whole pixel', (WidgetTester tester) async {
    late BuildContext probe;
    await pumpFluentChrome(tester, textScale: 1.5, (BuildContext context) {
      probe = context;
      return const SizedBox.shrink();
    });
    expect(
      DefaultTextStyle.of(probe).style.fontSize,
      21,
      reason: '14 x 1.5 = 21 - the one preference means one thing here too',
    );
  });
}
