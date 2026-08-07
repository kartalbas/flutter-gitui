/// The Material 3 skin: this application's shipping design language, behind
/// the contract.
///
/// **It is an extraction, not a rewrite.** Every body in this package was
/// moved here from a `Base*` component in `lib/shared/components/`, which had
/// already been rebuilt on Material's own canonical widgets. What changes is
/// WHERE the delegation lives, not WHAT it renders - which is why the
/// acceptance test for the move is that the 68 golden baselines in
/// `test/conformance/goldens/images/` come out byte-identical. A pixel that
/// moves is an extraction that changed behaviour.
///
/// The second net is this package's own conformance suite: 65 registered
/// deviations in `docs/deviation_register.yaml`, each asserted in BOTH
/// directions. An extraction that quietly conformed to stock Material where
/// this application deliberately does not therefore fails as a **stale
/// deviation** rather than passing unnoticed.
///
/// **This package may import `package:flutter/material.dart`, and must.**
/// That is the one difference from `gitui_skin_api` and
/// `gitui_skin_blueprint`, whose widgets-only imports are the standing proof
/// that no contract member secretly requires Material. Rendering Material IS
/// this package's job; the proof lives in the other two.
///
/// **What it deliberately does not do is reach back into the application.**
/// `flutter_gitui` is a dev dependency (the conformance suite measures the app)
/// and never a dependency of `lib/`, so the numbers, the colours and the glyph
/// table this skin renders from are its OWN - carried in
/// `src/material_ink.dart` and `src/material_glyphs.dart` rather than read out
/// of `AppTheme`. Numbers live on the skin's side of the line; that is the
/// whole of `docs/SKIN-CONTRACT.md` §1.
library;

export 'src/material_glyphs.dart';
export 'src/material_ink.dart';
export 'src/material_skin.dart';
