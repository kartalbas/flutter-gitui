$ErrorActionPreference = 'Stop'
$pkg  = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\phosphor_flutter-2.1.0\lib\src"
$dest = 'D:\repos\kartalbas\flutter-gitui\lib\shared\icons'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$weights = @(
    @{ src = 'phosphor_icons_regular.dart'; cls = 'PhosphorIconsRegular'; out = 'phosphor_icons_regular.dart' },
    @{ src = 'phosphor_icons_bold.dart';    cls = 'PhosphorIconsBold';    out = 'phosphor_icons_bold.dart' },
    @{ src = 'phosphor_icons_fill.dart';    cls = 'PhosphorIconsFill';    out = 'phosphor_icons_fill.dart' }
)

$header = @'
// GENERATED -- do not edit by hand.
//
// Mirrors the phosphor_flutter icon constants as plain IconData.
//
// phosphor_flutter declares `class PhosphorIconData extends IconData`, and
// IconData is a final class in current Flutter, so importing the package fails
// to compile on every platform. The package stays as a dependency purely so its
// font assets are bundled; its Dart code is never imported.
//
// Regenerate with tools/generate_phosphor_icons.ps1 after a package upgrade.

import 'package:flutter/widgets.dart';

'@

foreach ($w in $weights) {
    $text = Get-Content (Join-Path $pkg $w.src) -Raw

    # static const name = PhosphorFlatIconData(0xABCD, 'Style');
    $converted = [regex]::Replace(
        $text,
        "static const (\w+) = PhosphorFlatIconData\((0x[0-9a-fA-F]+),\s*'(\w+)'\);",
        {
            param($m)
            $name  = $m.Groups[1].Value
            $code  = $m.Groups[2].Value
            $style = $m.Groups[3].Value
            "static const IconData $name = IconData($code, fontFamily: 'Phosphor$style', fontPackage: 'phosphor_flutter', matchTextDirection: true);"
        }
    )

    # Some definitions are line-wrapped by the package's formatter.
    $converted = [regex]::Replace(
        $converted,
        "static const (\w+) =\s*\r?\n\s*PhosphorFlatIconData\((0x[0-9a-fA-F]+),\s*'(\w+)'\);",
        {
            param($m)
            "static const IconData $($m.Groups[1].Value) = IconData($($m.Groups[2].Value), fontFamily: 'Phosphor$($m.Groups[3].Value)', fontPackage: 'phosphor_flutter', matchTextDirection: true);"
        }
    )
    # Keep only the class body; drop the package's own imports and doc images.
    $start = $converted.IndexOf("class $($w.cls)")
    if ($start -lt 0) { throw "class $($w.cls) not found in $($w.src)" }
    $body = $converted.Substring($start)
    $body = [regex]::Replace($body, '(?m)^\s*///.*\r?\n', '')
    $body = $body -replace '@staticIconProvider\s*', ''

    $out = $header + $body
    Set-Content (Join-Path $dest $w.out) $out -Encoding utf8 -NoNewline

    $count = ([regex]::Matches($out, 'static const IconData ')).Count
    Write-Output "  $($w.out): $count icons"
}

# Barrel file so call sites change only their import line.
$barrel = @'
// GENERATED -- do not edit by hand.
//
// Drop-in replacement for `package:phosphor_flutter/phosphor_flutter.dart`.
// See phosphor_icons_regular.dart for why this exists.

export 'phosphor_icons_regular.dart';
export 'phosphor_icons_bold.dart';
export 'phosphor_icons_fill.dart';
'@
Set-Content (Join-Path $dest 'phosphor_icons.dart') $barrel -Encoding utf8 -NoNewline
Write-Output "  phosphor_icons.dart (barrel)"
