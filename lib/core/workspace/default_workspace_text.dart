import '../../generated/app_localizations.dart';
import 'models/workspace.dart';

/// The name and description of the default workspace, resolved from the active
/// locale instead of from `config.yaml`.
///
/// The application creates one workspace by itself on every installation
/// ([Workspace.defaultId]). Its name and description are written by the
/// application, not by the user, which makes them code rather than data:
/// storing the English sentences would freeze them into the user's config file,
/// where every later launch renders them verbatim no matter which of the six UI
/// languages is selected. So the file stores them as absent — an empty name, no
/// description — and the words are looked up here at display time. It is the
/// same rule the persisted update record follows: keep the datum, render the
/// prose in the reader's language.
///
/// A workspace the user has named is different: that text *is* data, it is
/// stored as typed and always shown exactly as typed. That includes the default
/// workspace once the user renames it, which is why the fallback is keyed on
/// the stored value being absent and not on the identifier alone.
///
/// The one behaviour this rule implies: the default workspace always describes
/// itself. Emptying its description in the edit dialog restores the
/// application's own sentence rather than leaving it blank, because "no stored
/// description" is precisely what asks for that sentence.
extension DefaultWorkspaceText on Workspace {
  /// Whether this is the workspace the application creates by itself.
  bool get isDefaultWorkspace => id == Workspace.defaultId;

  /// The name to put on screen, in the language the user reads.
  String displayName(AppLocalizations l10n) =>
      isDefaultWorkspace && name.isEmpty ? l10n.defaultLabel : name;

  /// The description to put on screen, or null when there is none to show.
  String? displayDescription(AppLocalizations l10n) {
    final stored = description;
    if (isDefaultWorkspace && (stored == null || stored.isEmpty)) {
      return l10n.defaultWorkspaceDescription;
    }
    return stored == null || stored.isEmpty ? null : stored;
  }
}

/// The name to store for the default workspace after the user submitted
/// [submitted] in the edit dialog.
///
/// The dialog prefills its fields with what [DefaultWorkspaceText.displayName]
/// resolved, so a user who only changed the colour submits the application's
/// own word straight back. Storing it verbatim would pin the current UI
/// language into the file, so text that still matches what this locale renders
/// goes back as absent and keeps following the language.
String storedDefaultWorkspaceName(String submitted, AppLocalizations l10n) =>
    submitted == l10n.defaultLabel ? '' : submitted;

/// The description to store for the default workspace after the user submitted
/// [submitted] in the edit dialog, or null to keep the application's own
/// sentence. See [storedDefaultWorkspaceName] for why an unchanged submission
/// is not stored.
String? storedDefaultWorkspaceDescription(
  String submitted,
  AppLocalizations l10n,
) => submitted.isEmpty || submitted == l10n.defaultWorkspaceDescription
    ? null
    : submitted;
