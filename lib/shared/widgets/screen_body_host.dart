import 'package:flutter/material.dart';

/// Supplies the [Material] ancestor a screen's own content still needs, on the
/// application's side of `ScreenSpec.body`'s port.
///
/// The screen seam has the same migration-window problem the dialog seam had,
/// and the same answer. A screen's body is still built from Material widgets —
/// `TextField`, `TabBar`, `ListTile`, `InkWell`, `Chip` all assert a [Material]
/// ancestor — and under the shipped Material skin that ancestor used to arrive
/// by coincidence: the screen was a raw [Scaffold], which builds one. The
/// blueprint's `chrome.screen` deliberately builds no Material at all (a
/// neutral frame that quietly provided one would be Material leaking under
/// another name), so the moment a screen moves behind `chrome.screen` every
/// Material control in its body throws "No Material widget found" under the
/// blueprint — measured on the stashes scene the first time this file did not
/// exist.
///
/// The contract's answer is `ContentPort`'s own: content crosses a port **with
/// its ambient needs already satisfied**, and it is the APPLICATION that
/// satisfies them, inside the port, where the attribution walk has already
/// resumed. `base_dialog.dart`'s `_MigrationMaterialHost` is the same widget
/// for the dialog seam; this is the screen's, public because five screens plant
/// it rather than one component.
///
/// [MaterialType.transparency] paints nothing, casts nothing and takes no
/// gesture, and the text style re-states the one already in force at the port,
/// so under the Material skin this wrapper is pixel-neutral. It dies with the
/// migration window: when a screen's body no longer contains Material widgets,
/// drop it from that screen, and delete the file when the last screen has.
class ScreenBodyHost extends StatelessWidget {
  /// Wraps [child], the screen's own body, exactly as the screen wrote it.
  const ScreenBodyHost({super.key, required this.child});

  /// The screen's body.
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    textStyle: DefaultTextStyle.of(context).style,
    child: child,
  );
}
