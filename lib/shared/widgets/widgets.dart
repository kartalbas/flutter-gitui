/// Barrel export for all core widgets
library;

export 'async_value_builder.dart';
export 'command_log_panel.dart';
export 'empty_state.dart';
export 'repository_switcher.dart';
// `searchable_dropdown.dart` used to be exported here. It was the SECOND
// hand-built searchable dropdown in the application - the same question
// `SearchableBaseDropdown` asks, hand-painted a second time, in a second
// shape - and it had no call site anywhere in `lib/`. `controls.suggestField`
// answers that question now, and keeping a second façade over one member
// would be two ways to ask for one thing, so the unreachable copy is deleted
// rather than converted.
export '../components/base_switcher.dart';
