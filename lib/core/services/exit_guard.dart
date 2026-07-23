import 'package:riverpod/legacy.dart';

/// A kind of unsaved user input that an application exit would destroy.
enum UnsavedInputKind { commitMessage }

/// Registry of unsaved input across the app.
///
/// Installing an update replaces the running application and closes it, so
/// the moment before that exit has to know whether anything the user typed
/// would be lost. Widgets holding such input register themselves here while
/// the input is non-empty and unregister when it is saved or discarded.
class UnsavedInputNotifier extends StateNotifier<Set<UnsavedInputKind>> {
  UnsavedInputNotifier() : super(const {});

  void register(UnsavedInputKind kind) {
    if (state.contains(kind)) return;
    state = {...state, kind};
  }

  void unregister(UnsavedInputKind kind) {
    if (!state.contains(kind)) return;
    state = {...state}..remove(kind);
  }
}

/// Unsaved input currently held anywhere in the app.
final unsavedInputProvider =
    StateNotifierProvider<UnsavedInputNotifier, Set<UnsavedInputKind>>(
      (ref) => UnsavedInputNotifier(),
    );
