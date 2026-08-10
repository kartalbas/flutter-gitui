# tools/

Six things live here, and they are not the same kind of thing. The distinction
is the whole point of this file: a script that nothing invokes reads like a
gate that has quietly stopped running, and this repository has shipped that
misunderstanding three times (#385, #388, #429, and the audit in #445 that
produced this file). So each entry below says WHO runs it and WHEN.

## Gates — CI runs these, and a red result blocks the build

| Tool | Run by | What a failure means |
| --- | --- | --- |
| `check_translations.dart` | `.github/workflows/ci.yml`, the *Check translation coverage* step in the `analyze` job | A locale under `lib/l10n/` is missing a key that `app_en.arb` has. It exits non-zero on the first incomplete locale; the printed report names the keys. |

Run it locally the same way CI does:

```bash
dart run tools/check_translations.dart
```

## Build steps — the release pipeline runs these

| Tool | Run by | Notes |
| --- | --- | --- |
| `sync-icons.ps1` | the release build, marked `BUILD-STEP: 2` in its own header | Copies the application icon from its one source into every per-platform location the build expects. |

## Regenerators — a HUMAN runs these, by hand, rarely

These produce checked-in artefacts. Nothing invokes them, and nothing should:
their output is committed, so a build that re-ran them would either be a no-op
or an unreviewed change to files a human is supposed to look at. Each one is
listed with the event that is the reason to run it.

| Tool | Run it when | It writes |
| --- | --- | --- |
| `convert-icon.ps1` | the application icon's SVG changes | the `.ico` the Windows build embeds. Needs ImageMagick (`magick`) on PATH. |
| `generate_static_fonts.py` | a bundled font is added or upgraded | static weights (`Font-Regular.ttf`, `Font-Bold.ttf`, …) from a variable font, because `google_fonts` needs them once runtime fetching is off. Needs `pip install fonttools`. |
| `generate_phosphor_icons.ps1` | the `phosphor_flutter` dependency is upgraded | the vendored icon tables under `lib/shared/icons/`. Note that it reads the package out of the local pub cache and writes to an absolute path, so check both before running it. |

## Data, not code

`changelog/` and `translation_reports/` hold generated output, not scripts.
