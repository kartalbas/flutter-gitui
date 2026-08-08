/// Proves this skin's answer to "what happens when the text does not fit",
/// and — far more importantly — proves that asking the question does not
/// CHANGE the answer to "how many lines is this text allowed".
///
/// ## The regression this file exists to catch
///
/// `SkinType.text` carries no `overflow` parameter, on purpose: truncation is
/// a design language's idiom, Material ellipsizes at the end and AppKit
/// truncates a path in the middle, so a call site naming either would have
/// chosen it for all three languages. This skin therefore supplies the
/// ellipsis itself.
///
/// It supplied it UNCONDITIONALLY once, and that is not a cosmetic difference.
/// Flutter's own contract (`painting/text_painter.dart`) says the ellipsis is
/// applied "to the first line that is wider than the width constraint, if
/// `maxLines` is null" — so an unconditional ellipsis does not mark a
/// truncation, it causes one, and every wrapping paragraph in the application
/// collapsed to a single cut line: an empty state's explanation, a git error,
/// the release notes inside the update dialog. Nothing saw it. `find.text`
/// matches the string rather than the rendering, the semantics tree still
/// publishes the whole value, and all 34 golden scenes hold short strings.
/// Only a height measurement can tell the two apart, which is what this file
/// does.
///
/// The two halves of the question are split where the contract splits them:
/// WHETHER the text is confined is the application's fact, stated with
/// `maxLines` (or by refusing to wrap); WHAT the confinement looks like is
/// this skin's idiom.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole;
import 'package:google_fonts/google_fonts.dart';

import '../support/conformance_harness.dart';

/// Prose long enough that no reasonable ramp step fits it on one line in
/// [_kNarrow], and realistic rather than lorem: it is the shape of the git
/// failure the collapse made unreadable.
const String kProse =
    'fatal: unable to access https://github.com/kartalbas/flutter-gitui.git: '
    'Could not resolve host: github.com. Check your network connection and '
    'proxy settings, then try the fetch again.';

/// A box narrow enough to force many lines, and narrow enough that a single
/// ellipsized line is unmistakable in the measurement.
const double _kNarrow = 200;

Future<Size> _measure(WidgetTester tester, Widget label) async {
  await pumpConformance(
    tester,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: _kNarrow, child: label),
    ),
  );
  final Size size = tester.getSize(
    find.descendant(of: find.byType(BaseLabel), matching: find.byType(Text)),
  );
  // Drain the timers google_fonts schedules so teardown sees none pending.
  await tester.pump(const Duration(seconds: 30));
  return size;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('a label that states no line cap wraps instead of truncating', (
    WidgetTester tester,
  ) async {
    final Size size = await _measure(
      tester,
      const BaseLabel(kProse, role: TextRole.body),
    );

    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(BaseLabel), matching: find.byType(Text)),
    );
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason:
          'The application asked for no line cap, so nothing may be cut. When '
          'this skin stamped the ellipsis unconditionally, this paragraph '
          'reported an exceeded line count on a label that had never been '
          'given one.',
    );
    expect(
      size.height,
      greaterThan(60),
      reason:
          'Three or more lines of prose in a ${_kNarrow.toInt()} px box. A '
          'single line measures roughly 19 px, which is exactly what the '
          'unconditional ellipsis produced — the paragraph collapsed rather '
          'than wrapped, and the user lost every sentence after the first.',
    );
  });

  testWidgets('a label that states a line cap truncates at it, this skin\'s '
      'way', (WidgetTester tester) async {
    final Size capped = await _measure(
      tester,
      const BaseLabel(kProse, role: TextRole.body, maxLines: 1),
    );
    expect(
      capped.height,
      lessThan(30),
      reason: 'One line was asked for, so one line is what is drawn.',
    );

    final Text text = tester.widget<Text>(
      find.descendant(of: find.byType(BaseLabel), matching: find.byType(Text)),
    );
    expect(
      text.overflow,
      TextOverflow.ellipsis,
      reason:
          'The ellipsis is THIS skin\'s truncation idiom and it is supplied '
          'here rather than at the call site, which is why `SkinType.text` '
          'has no `overflow` parameter. AppKit truncates a path in the middle '
          'instead, and a call site naming either would have chosen it for '
          'every language.',
    );
  });

  testWidgets('the cap the caller states is the cap that is drawn', (
    WidgetTester tester,
  ) async {
    final Size oneLine = await _measure(
      tester,
      const BaseLabel(kProse, role: TextRole.body, maxLines: 1),
    );
    final Size threeLines = await _measure(
      tester,
      const BaseLabel(kProse, role: TextRole.body, maxLines: 3),
    );
    expect(
      threeLines.height,
      greaterThan(oneLine.height * 2),
      reason:
          'Three lines must be about three times one line. An ellipsis that '
          'ignored the cap would make both measurements identical.',
    );
  });

  testWidgets('hard newlines survive a label with no cap', (
    WidgetTester tester,
  ) async {
    // The regression ate these too, and worse: with the ellipsis on and no
    // cap, everything after the first over-wide line was dropped, so a block
    // the application had deliberately broken into lines rendered as one.
    final Size size = await _measure(
      tester,
      const BaseLabel(
        'Check that git is on your PATH.\n'
        'Check that the remote is reachable.\n'
        'Check that your credentials have not expired.\n'
        'Then try the fetch again.',
        role: TextRole.body,
      ),
    );
    expect(
      size.height,
      greaterThan(80),
      reason:
          'Four authored lines, each of which also wraps in a '
          '${_kNarrow.toInt()} px box. Anything near one line height means '
          'the paragraph was truncated at the first over-wide line.',
    );
  });
}
