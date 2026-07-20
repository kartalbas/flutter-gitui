/// Reduces a shell lookup result to the single executable path it should be.
///
/// `where` on Windows and `which -a` on Unix print one line per PATH hit, and
/// tool auto-detection stored that output verbatim. A multi-line value is not
/// something `Process.start` can ever execute, and because it survives every
/// later save it has to be repaired wherever such a value is read back.
/// Trimming each line individually also removes the carriage return that
/// `where` emits, which a single [String.trim] over the whole output leaves in
/// place between the lines.
///
/// Returns null when nothing but whitespace remains, so an unusable value is
/// indistinguishable from an unconfigured one.
String? normalizeExecutablePath(String? value) {
  if (value == null) return null;

  for (final line in value.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }

  return null;
}
