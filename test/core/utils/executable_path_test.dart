// Reduction of a where/which lookup to the one path that can be launched,
// both when auto-detect produces it and when a broken value is read back.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/utils/executable_path.dart';

void main() {
  group('normalizeExecutablePath', () {
    test('keeps the first match of a two-line Windows lookup', () {
      // Verbatim shape of `where code` with VS Code installed per user.
      const stdout =
          r'C:\Users\dev\AppData\Local\Programs\Microsoft VS Code\bin\code'
          '\r\n'
          r'C:\Users\dev\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd'
          '\r\n';

      expect(
        normalizeExecutablePath(stdout),
        r'C:\Users\dev\AppData\Local\Programs\Microsoft VS Code\bin\code',
      );
    });

    test('leaves no carriage return behind that would break the path', () {
      final normalized = normalizeExecutablePath('/usr/bin/code\r\n/bin/code');

      expect(normalized, '/usr/bin/code');
      expect(normalized!.contains('\r'), isFalse);
      expect(normalized.contains('\n'), isFalse);
    });

    test('keeps a single match unchanged apart from the trailing newline', () {
      expect(normalizeExecutablePath('/usr/bin/nano\n'), '/usr/bin/nano');
    });

    test('reports an all-whitespace lookup as no match at all', () {
      expect(normalizeExecutablePath('  \r\n\n'), isNull);
      expect(normalizeExecutablePath(''), isNull);
      expect(normalizeExecutablePath(null), isNull);
    });
  });

  group('ToolsConfig.fromYaml repairs a stored editor path', () {
    test('reduces a stored multi-line value to a launchable path', () {
      final tools = ToolsConfig.fromYaml({
        'text_editor':
            r'C:\Users\dev\Microsoft VS Code\bin\code'
            '\r\n'
            r'C:\Users\dev\Microsoft VS Code\bin\code.cmd',
      });

      expect(tools.textEditor, r'C:\Users\dev\Microsoft VS Code\bin\code');
    });

    test('the repaired path survives a save/load round trip', () {
      final repaired = ToolsConfig.fromYaml({
        'text_editor': '/usr/bin/code\r\n/snap/bin/code',
      });

      expect(
        ToolsConfig.fromYaml(repaired.toYaml()).textEditor,
        '/usr/bin/code',
      );
    });

    test('leaves an intact configuration untouched', () {
      final tools = ToolsConfig.fromYaml({
        'text_editor': r'C:\Program Files\Notepad++\notepad++.exe',
        'text_editor_version': '8.6.9',
      });

      expect(tools.textEditor, r'C:\Program Files\Notepad++\notepad++.exe');
      expect(tools.textEditorVersion, '8.6.9');
    });

    test('an absent editor stays absent', () {
      expect(ToolsConfig.fromYaml({}).textEditor, isNull);
    });

    test('repairs the value as it actually sits in a stored config.yaml', () {
      // Double-quoted scalar with an escaped CRLF, exactly how the writer
      // persisted the raw output of `where code`.
      const yamlText =
          'tools:\n'
          r'  text_editor: "C:\\VS Code\\bin\\code\r\nC:\\VS Code\\bin\\code.cmd"'
          '\n';

      final yaml = loadYaml(yamlText) as Map;
      final tools = ToolsConfig.fromYaml(yaml['tools'] as Map);

      expect(tools.textEditor, r'C:\VS Code\bin\code');
    });
  });
}
