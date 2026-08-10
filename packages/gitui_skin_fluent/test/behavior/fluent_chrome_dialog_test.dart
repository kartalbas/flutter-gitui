/// chrome.dialogSurface, measured: the ContentDialog, and above all its
/// ACTION ORDER.
///
/// This file is the falsification test the chrome facet exists for.
/// `DialogSpec.actions` arrives in the application's reading order and its
/// doc promises that "a language that arranges them differently derives
/// its own order from the roles rather than from the position in this
/// list" - Fluent is that language, and these tests prove the promise by
/// handing the SAME actions over in both orders and measuring where the
/// paint landed: the affirmative on the LEFT, the dismissive on the
/// RIGHT, stretched to equal widths across the surface
/// (fluent_ui@4.16.1 flyouts/content_dialog.dart:141-161; WinUI lays
/// ContentDialog out primary / secondary / close, left to right - the
/// delete dialog the reference cites as its cover, content_dialog.dart:22,
/// reads Delete first and Cancel last).
///
/// Every pinned literal restates its source beside it, independently of
/// the constants in lib/.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_button.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_chrome.dart';

import 'support/fluent_behavior_harness.dart';
import 'support/fluent_chrome_harness.dart';

// The menu/flyout surface every overlay stands on: FluentThemeData.menuColor
// (fluent_ui styles/theme.dart:461), #F9F9F9 light / #2C2C2C dark.
const Color _menuSurfaceLight = Color(0xFFF9F9F9);
const Color _menuSurfaceDark = Color(0xFF2C2C2C);

// The action strip's ground: micaBackgroundColor :=
// SolidBackgroundFillColorBase (content_dialog.dart:501-505,
// styles/theme.dart:460; color_resources.dart:340 light, :253 dark).
const Color _stripLight = Color(0xFFf3f3f3);
const Color _stripDark = Color(0xFF202020);

// The Windows default accent swatch's resting brush on light grounds
// (fluent_ui color.dart:171, :347-352) - what the affirmative action fills
// with.
const Color _accentRestLight = Color(0xff0066b4);

// ControlFillColorDefault, light (color_resources.dart:287) - the standard
// button every non-affirmative action wears.
const Color _standardRestLight = Color(0xb3ffffff);

DialogAction _action(
  String label,
  DialogActionRole role, {
  VoidCallback? onPressed,
  bool isLoading = false,
}) => DialogAction(
  label: label,
  onPressed: onPressed ?? () {},
  role: role,
  isLoading: isLoading,
);

Future<void> _pumpDialog(
  WidgetTester tester,
  DialogSpec spec, {
  Brightness brightness = Brightness.light,
}) => pumpFluentChrome(
  tester,
  brightness: brightness,
  (BuildContext context) => const FluentChrome().dialogSurface(context, spec),
);

DialogSpec _spec(List<DialogAction> actions, {DialogExtent? extent}) =>
    DialogSpec(
      title: 'Create branch',
      content: const ContentPort(Text('dialog-content')),
      actions: actions,
      extent: extent ?? DialogExtent.form,
    );

Finder _button(String label) => find.widgetWithText(FluentButton, label);

Finder _buttonBox(String label) => find.descendant(
  of: _button(label),
  matching: find.byType(AnimatedContainer),
);

void main() {
  group('the role-derived order - the contract\'s own claim, proven', () {
    testWidgets('the affirmative action paints LEFT of the dismissive one, '
        'even when the application wrote it last', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Cancel', DialogActionRole.dismissive),
          _action('Create', DialogActionRole.affirmative),
        ]),
      );
      expect(
        tester.getTopLeft(_button('Create')).dx,
        lessThan(tester.getTopLeft(_button('Cancel')).dx),
        reason:
            'WinUI lays its dialog out primary / secondary / close, left '
            'to right - the exact mirror of Material\'s end-aligned row. '
            'A surface that read the list\'s order would have painted '
            'Cancel first.',
      );
    });

    testWidgets('...and the SAME actions in the opposite list order paint '
        'identically, because position never decides', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Create', DialogActionRole.affirmative),
          _action('Cancel', DialogActionRole.dismissive),
        ]),
      );
      expect(
        tester.getTopLeft(_button('Create')).dx,
        lessThan(tester.getTopLeft(_button('Cancel')).dx),
      );
    });

    testWidgets('a destructive action outranks the neutral way forward, and '
        'the dismissive way out is always last', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Cancel', DialogActionRole.dismissive),
          _action('Keep both', DialogActionRole.neutral),
          _action('Delete', DialogActionRole.destructive),
        ]),
      );
      final double deleteX = tester.getTopLeft(_button('Delete')).dx;
      final double keepX = tester.getTopLeft(_button('Keep both')).dx;
      final double cancelX = tester.getTopLeft(_button('Cancel')).dx;
      expect(deleteX, lessThan(keepX));
      expect(keepX, lessThan(cancelX));
    });
  });

  group('the equal-width strip', () {
    testWidgets('several actions stretch to EQUAL widths filling the '
        'surface, 10 apart inside the 20 padding', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Cancel', DialogActionRole.dismissive),
          _action('Create', DialogActionRole.affirmative),
        ]),
      );
      final Size create = tester.getSize(_button('Create'));
      final Size cancel = tester.getSize(_button('Cancel'));
      expect(
        create.width,
        cancel.width,
        reason:
            'the reference wraps every action in an Expanded '
            '(content_dialog.dart:147-161) - intrinsic-width buttons are '
            'Material\'s arrangement, not this one',
      );
      // The surface is the published 368 (content_dialog.dart:11-14); the
      // strip pads 20 either side (:506) and spaces 10 between (:500):
      // 368 - 40 - 10 = 318, shared equally.
      expect(create.width, (368 - 2 * 20 - 10) / 2);
    });

    testWidgets('a single action keeps its own width at the END of the '
        'strip', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[_action('Close', DialogActionRole.dismissive)]),
      );
      final Finder surface = find.byKey(FluentDialogSurface.surfaceKey);
      expect(
        tester.getTopRight(_button('Close')).dx,
        tester.getTopRight(surface).dx - 20,
        reason:
            'one action aligns to the end at its own width '
            '(content_dialog.dart:141-145) - it does not stretch',
      );
      expect(
        tester.getSize(_button('Close')).width,
        lessThan(368 / 2),
        reason: 'its width is the label\'s, not half the surface',
      );
    });
  });

  group('what each role wears', () {
    testWidgets('the affirmative action alone wears the accent; the '
        'dismissive is a STANDARD button, never a quiet text one', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Cancel', DialogActionRole.dismissive),
          _action('Create', DialogActionRole.affirmative),
        ]),
      );
      expect(
        singleFillOf(tester, _buttonBox('Create')).toARGB32(),
        _accentRestLight.toARGB32(),
        reason:
            'the affirmative action is the accent (filled) button - the '
            'default WinUI singles out',
      );
      expect(
        singleFillOf(tester, _buttonBox('Cancel')).toARGB32(),
        _standardRestLight.toARGB32(),
        reason:
            'Cancel wears ControlFillColorDefault: WinUI\'s dialog knows '
            'no text button, so mapping dismissive onto a quiet treatment '
            'would be Material\'s answer wearing Fluent clothes',
      );
      expect(
        paintedOutlines(tester, _buttonBox('Cancel')),
        isNotEmpty,
        reason:
            'a standard button carries its elevation stroke - visibly '
            'a button, not a label',
      );
    });

    testWidgets('a destructive dialog with NO affirmative action singles '
        'out no default: nothing wears the accent', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Delete', DialogActionRole.destructive),
          _action('Cancel', DialogActionRole.dismissive),
        ]),
      );
      expect(
        singleFillOf(tester, _buttonBox('Delete')).toARGB32(),
        _standardRestLight.toARGB32(),
        reason:
            'the reference\'s own delete dialog says "Delete" in an '
            'ordinary button - Fluent keeps the danger in the words, and '
            'a dialog whose affirmative was withheld has no default to '
            'dress',
      );
      expect(
        singleFillOf(tester, _buttonBox('Cancel')).toARGB32(),
        _standardRestLight.toARGB32(),
      );
      // And the destructive action still outranks the way out.
      expect(
        tester.getTopLeft(_button('Delete')).dx,
        lessThan(tester.getTopLeft(_button('Cancel')).dx),
      );
    });

    testWidgets('a loading action is never invokable', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action(
            'Create',
            DialogActionRole.affirmative,
            onPressed: () => pressed++,
            isLoading: true,
          ),
          _action('Cancel', DialogActionRole.dismissive),
        ]),
      );
      await tester.tap(_button('Create'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pressed, 0);
    });
  });

  group('the two-region surface', () {
    testWidgets('the content stands on the menu surface, the action strip '
        'on the window ground beneath it', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Cancel', DialogActionRole.dismissive),
          _action('Create', DialogActionRole.affirmative),
        ]),
      );
      expect(
        paintedFillColors(
          tester,
          find.byKey(FluentDialogSurface.surfaceKey),
        ).map((Color c) => c.toARGB32()),
        contains(_menuSurfaceLight.toARGB32()),
        reason:
            'the dialog fills with menuColor, the solid flyout surface '
            '(content_dialog.dart:493-495, styles/theme.dart:461)',
      );
      expect(
        paintedFillColors(
          tester,
          find.byKey(FluentDialogSurface.actionsKey),
        ).map((Color c) => c.toARGB32()),
        contains(_stripLight.toARGB32()),
        reason:
            'the action strip stands on micaBackgroundColor - the window '
            'ground - one layer beneath the content '
            '(content_dialog.dart:501-505, theme.dart:460)',
      );
    });

    testWidgets('the surface rounds at the OVERLAY corner, 8 - the WinUI '
        'resource, not the reference\'s 12', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[_action('Close', DialogActionRole.dismissive)]),
      );
      final List<RRect> rects = paintedRRects(
        tester,
        find.byKey(FluentDialogSurface.surfaceKey),
      );
      expect(rects, isNotEmpty);
      expect(
        rects.first.tlRadiusX,
        8,
        reason:
            'WinUI OverlayCornerRadius is 8 (XAML theme resources, the '
            'pair FluentGeometry declares); the reference writes 12 '
            '(content_dialog.dart:495) and the published specification '
            'wins, the same judgement the caption weight records',
      );
    });

    testWidgets('the title renders at the Title step - 28 Semibold, the '
        'window-scale rung no TextRole reaches', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[_action('Close', DialogActionRole.dismissive)]),
      );
      final RenderParagraph title = tester.renderObject<RenderParagraph>(
        find.text('Create branch'),
      );
      expect(
        title.text.style?.fontSize,
        28,
        reason:
            'the ContentDialog title is typography.title '
            '(content_dialog.dart:508): 28/36 Semibold (SPEC type-ramp '
            'table)',
      );
      expect(title.text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('dark: both regions come from the dark dictionary', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Cancel', DialogActionRole.dismissive),
          _action('Create', DialogActionRole.affirmative),
        ]),
        brightness: Brightness.dark,
      );
      expect(
        paintedFillColors(
          tester,
          find.byKey(FluentDialogSurface.surfaceKey),
        ).map((Color c) => c.toARGB32()),
        contains(_menuSurfaceDark.toARGB32()),
      );
      expect(
        paintedFillColors(
          tester,
          find.byKey(FluentDialogSurface.actionsKey),
        ).map((Color c) => c.toARGB32()),
        contains(_stripDark.toARGB32()),
      );
    });
  });

  group('the extents', () {
    testWidgets('alert and form both land on the one published dialog '
        'surface: 368 wide', (WidgetTester tester) async {
      for (final DialogExtent extent in <DialogExtent>[
        DialogExtent.alert,
        DialogExtent.form,
      ]) {
        await _pumpDialog(
          tester,
          _spec(<DialogAction>[
            _action('Close', DialogActionRole.dismissive),
          ], extent: extent),
        );
        expect(
          tester.getSize(find.byKey(FluentDialogSurface.surfaceKey)).width,
          368,
          reason:
              'Fluent publishes exactly one dialog width '
              '(content_dialog.dart:11-14, "following the Windows design '
              'guidelines") - the same one-size posture as its one '
              'control height. The collapse is the language\'s own '
              'statement, recorded on FluentDialogSurface.',
        );
      }
    });

    testWidgets('the browser extent alone diverges: something to look '
        'through takes the 90% viewer frame', (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        _spec(<DialogAction>[
          _action('Close', DialogActionRole.dismissive),
        ], extent: DialogExtent.browser),
      );
      final Size surface = tester.getSize(
        find.byKey(FluentViewerDialogSurface.surfaceKey),
      );
      expect(surface.width, kFluentBehaviorSurface.width * 0.9);
      expect(surface.height, kFluentBehaviorSurface.height * 0.9);
    });
  });
}
