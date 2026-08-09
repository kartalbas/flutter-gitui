/// The Fluent 2 skin for Flutter GitUI: every contract member drawn against
/// the published Fluent 2 / WinUI specification, with no widget library
/// underneath.
///
/// The application consumes exactly one symbol: [FluentSkin], whose
/// `register()` adds the skin to the build's registry from `lib/main.dart`.
/// Everything else in this package is implementation and stays behind
/// `src/`.
library;

export 'src/fluent_skin.dart' show FluentSkin;
