import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show CardSpec, ContentPort, Inset, RowSelection, Skin, SkinScope, Tone;

/// Base component for all card patterns in the app.
///
/// **This is a façade** (#249, §2.11), on the same terms as `BaseDialog` and
/// `BaseListItem`: the constructor is the one thirteen call sites already
/// write, and the body is one delegation to `surfaces.card`. Everything the
/// card used to draw itself — the 12 dp corner and the `ClipRRect` that
/// repeated it, the three container tones, the 1 px resting outline and the
/// 2 px focus ring, the `readableForeground` pairing, the transparency
/// `Material` that lets ink children paint their state layers, and the rules
/// above the header and below the footer — moved into the skin verbatim
/// (`material_surfaces.dart`, `MaterialSurfaces.card`). Nothing was
/// re-decided on the way: the member is the extraction of this build method,
/// comment for comment.
///
/// **What the move deletes is the pair of `Color` parameters.**
/// `customBackgroundColor` and `customBorderColor` let a call site hand this
/// component half of a decision — a fill without the foreground that pairs
/// with it — and only a skin may resolve the other half. They are replaced by
/// [tone], which is what the two call sites that used them were actually
/// saying: a workspace card is painted in *its own* place in the skin's
/// series (`Tone.series`), and a selected repository card is painted in the
/// *accent* (`Tone.accent`). The colour itself never crosses the seam again.
///
/// Example usage:
/// ```dart
/// BaseCard(
///   header: BaseInset(
///     child: BaseLabel('Card Header', role: TextRole.sectionTitle),
///   ),
///   content: ListView(
///     children: [
///       ListTile(title: BaseLabel('Item 1', role: TextRole.body)),
///       ListTile(title: BaseLabel('Item 2', role: TextRole.body)),
///     ],
///   ),
///   footer: BaseInset(
///     child: Row(
///       mainAxisAlignment: MainAxisAlignment.end,
///       children: [
///         TextButton(onPressed: () {}, child: Text('Cancel')),
///         ElevatedButton(onPressed: () {}, child: Text('Save')),
///       ],
///     ),
///   ),
///   isSelected: true,
///   onTap: () => print('Card tapped'),
/// )
/// ```
class BaseCard extends StatelessWidget {
  const BaseCard({
    super.key,
    required this.content,
    this.header,
    this.footer,
    this.isSelected = false,
    this.isMultiSelected = false,
    this.isSelectable = true,
    this.containerHasFocus = true,
    this.tone = Tone.neutral,
    this.onTap,
    this.inset = Inset.roomy,
  });

  /// Main content area (required) - typically scrollable
  final Widget content;

  /// Header widget (optional) - displayed above content
  final Widget? header;

  /// Footer widget (optional) - displayed below content
  final Widget? footer;

  /// Whether this card is currently selected (primary selection)
  final bool isSelected;

  /// Whether this card is part of a multi-selection (secondary selection)
  final bool isMultiSelected;

  /// Whether this card can be selected/tapped
  final bool isSelectable;

  /// Whether the collection rendering this card holds keyboard focus.
  ///
  /// A card grid is a single Tab stop with a roving highlight: while it is
  /// focused the selected card wears its focus ring, and while focus lives
  /// elsewhere the selection keeps the tinted background with the resting
  /// outline — still clearly the selection, no longer claiming the keyboard.
  /// Defaults to true so a card outside a focus-aware collection keeps the
  /// full treatment.
  final bool containerHasFocus;

  /// What this card is ABOUT, where the object it stands for carries its own
  /// identity.
  ///
  /// The successor to `customBackgroundColor` and `customBorderColor`: those
  /// two took a `Color` a screen had picked, which is a design decision taken
  /// in a screen and half of a pairing the screen cannot complete.
  /// [Tone.series] lets a workspace's own colour reach the card without the
  /// application ever learning which colour that is, and [Tone.neutral] is
  /// the card that carries no identity and keeps the scheme's tonal
  /// containers.
  final Tone tone;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// How far the content sits from the card's own edge.
  ///
  /// A rung rather than an `EdgeInsets`, because "a card is a deliberately
  /// generous surface" is a question three design languages answer with three
  /// distances and all three are right, whereas 24 is Material's answer chosen
  /// once for every language. [Inset.none] is the answer a card gives when its
  /// content draws its own edges — a list that must reach the card's border, a
  /// preview that bleeds.
  final Inset inset;

  /// The card's selection state, as the contract names it.
  RowSelection get _selection => isSelected
      ? RowSelection.primary
      : isMultiSelected
      ? RowSelection.multi
      : RowSelection.none;

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.surfaces.card(
          inner,
          CardSpec(
            content: ContentPort(content),
            header: header == null ? null : ContentPort(header!),
            footer: footer == null ? null : ContentPort(footer!),
            selection: _selection,
            containerFocused: containerHasFocus,
            tone: tone,
            inset: inset,
            // [isSelectable] is this façade's second way of saying "nothing
            // happens when you press me", so it is resolved into the callback
            // rather than carried into the spec, exactly as `BaseListItem`
            // resolves its own.
            onTap: isSelectable ? onTap : null,
          ),
        );
      });
}
