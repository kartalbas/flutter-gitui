/// The instrument must not fail on the content it exists to measure.
///
/// A `RenderFlex` overflow paints the framework's yellow-and-black stripes,
/// and those stripes are pixels: the chromatic census reads them as a colour
/// the application painted, when in fact the SKIN's own row was too narrow.
/// The surfaces facet's own doc already names that hazard; these tests are the
/// same hazard on the members that still had it - the shell's status strip, a
/// screen's title, a field's validation message and a suggest field's label.
///
/// Every string in the cases below is the application's own, and this
/// application ships in six languages: a message that fits in English at 300
/// logical pixels routinely does not in German, so "long" here is the ordinary
/// case rather than an adversarial one. Under the zero-and-extremes sweep an
/// overflow would additionally read as a screen asserting design, which is a
/// second wrong answer from the same defect.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart';

/// A German-length sentence, of the kind the status line and a validator both
/// carry today.
const String _long =
    'Der Arbeitsbereich konnte nicht aktualisiert werden, weil das Repository '
    'noch von einem anderen Vorgang verwendet wird';

void main() {
  testWidgets('the shell status strip survives two long halves at 400px', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      width: 400,
      child: Builder(
        builder: (BuildContext context) => const BlueprintSkin().chrome.shell(
          context,
          ShellSpec(
            identity: _identity,
            destinations: const <ShellDestination>[],
            selectedIndex: 0,
            onSelect: _ignoreIndex,
            toolbar: const <ToolbarGroup>[],
            status: const ShellStatus(label: _long, detail: _long),
            activity: const ActivitySpec(operation: _long, indeterminate: true),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen keeps a long title inside its own width', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      width: 400,
      child: Builder(
        builder: (BuildContext context) => const BlueprintSkin().chrome.screen(
          context,
          ScreenSpec(title: _long, body: ContentPort(const SizedBox.shrink())),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a field shows a long validation message without overflowing', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      width: 300,
      child: Builder(
        builder: (BuildContext context) =>
            const BlueprintSkin().controls.textField(
              context,
              const FieldSpec(label: 'Repository', error: _long),
              const FieldHandles(),
            ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(_long), findsOneWidget);
  });

  testWidgets('a suggest field keeps its label line inside the field', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      width: 300,
      child: Builder(
        builder: (BuildContext context) =>
            const BlueprintSkin().controls.suggestField<String>(
              context,
              const SuggestFieldSpec<String>(
                label: _long,
                items: <SuggestItem<String>>[
                  SuggestItem<String>(value: 'main', label: 'main'),
                ],
                value: 'main',
                onSelected: _ignoreString,
                minQueryLength: 2,
              ),
              const FieldHandles(),
            ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

const AppIdentity _identity = AppIdentity(
  name: 'Flutter GitUI',
  icon: IconRole.gitBranch,
  appIcon: _NoImage(),
);

void _ignoreIndex(int _) {}

void _ignoreString(String _) {}

/// Pumps [child] under a real blueprint root at [width].
///
/// The root is the application's own composition - the fence, the scope and
/// `chrome.wrapRoot` - because the ink defaults an overflow would be measured
/// against are installed there and nowhere else.
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required Widget child,
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SkinScope.install(
        skin: const BlueprintSkin(),
        request: const SkinRequest(
          brightness: Brightness.light,
          accentSeed: 0,
          textScale: 1,
          codeScale: 1,
          animationScale: 0,
          monoFamily: 'monospace',
          uiFamily: 'sans-serif',
        ),
        dialogKeyboardHost:
            (BuildContext context, DialogSpec spec, Widget surface) => surface,
        app: ContentPort(child),
      ),
    ),
  );
  await tester.pump();
}

/// An image provider that never resolves.
///
/// `AppIdentity.appIcon` is required and the shell now paints it, but a test
/// about layout must not depend on decoding a real asset: an unresolved
/// provider paints nothing and lays out as the box it was given, which is
/// exactly the geometry under test.
class _NoImage extends ImageProvider<Object> {
  const _NoImage();

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      Future<Object>.value(this);

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
