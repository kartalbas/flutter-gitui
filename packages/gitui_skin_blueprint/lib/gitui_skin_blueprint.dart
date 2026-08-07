/// The blueprint skin: the instrument the contract is judged against.
///
/// It renders everything naked. A button is a square, a field is a box, a chip
/// is a rectangle. Two colours - paper `#FFFFFF` and ink `#0000FF` - a 1px ink
/// outline, and zero of everything else: zero corner radius, zero elevation,
/// zero duration, and, at the default distance, zero of every gap and every
/// inset. Its purpose is development-only: render the application under it and
/// anything that still looks styled is design that leaked out of a skin and
/// into application code.
///
/// **Naked, not inert.** It uses every primitive that carries BEHAVIOUR -
/// `Focus`, `Actions`, `Shortcuts`, `Semantics`, `EditableText`, `Scrollable`,
/// `showGeneralDialog` - and none that carries APPEARANCE. A blueprint that
/// could not be operated would measure nothing, because half the application's
/// contract with its user is what the keyboard does.
///
/// **It never destroys information, only appearance.** Meaning that a colour
/// would have carried renders as a text marker BESIDE the content and never
/// inside it, so `find.text('Delete')` still matches. That rule is what lets
/// the entire existing test suite run under this skin at all.
///
/// **It implements every member and accepts every parameter**
/// (`docs/SKIN-CONTRACT-MEMBERS.md` §9). Where a parameter can be rendered
/// distinguishably without becoming design - a wider box for a larger scale, a
/// heavier outline for a louder emphasis, a broken one for a link, `[x]`/`[ ]`
/// /`[-]` for the three states of a toggle - it is. Then a parameter the
/// application never varies shows up as a constant, and a parameter a skin
/// drops shows up as a difference from the blueprint. Where a naked square
/// genuinely cannot show a parameter, the member says why in its own doc
/// comment; §9.2 of the member list is the list of those cases.
///
/// **It is the template a fourth skin starts from**: copy this package,
/// replace the bodies.
library;

export 'src/blueprint_ink.dart';
export 'src/blueprint_skin.dart';
export 'src/facets/blueprint_chrome.dart';
export 'src/facets/blueprint_controls.dart';
export 'src/facets/blueprint_layout.dart';
export 'src/facets/blueprint_motion.dart';
export 'src/facets/blueprint_overlays.dart';
export 'src/facets/blueprint_surfaces.dart';
export 'src/facets/blueprint_type.dart';
