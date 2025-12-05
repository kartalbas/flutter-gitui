#!/usr/bin/env python3
"""
Generate static fonts from variable fonts for offline use with google_fonts package.

This script converts variable fonts (e.g., Font[wght].ttf) to static fonts
(e.g., Font-Regular.ttf, Font-Bold.ttf) required by google_fonts when
allowRuntimeFetching is disabled.

Requirements:
    pip install fonttools

Usage:
    python tools/generate_static_fonts.py
"""

import os
import sys
from pathlib import Path

try:
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer
except ImportError:
    print("ERROR: fonttools not installed. Run: pip install fonttools")
    sys.exit(1)


# Font configurations: source -> destination mappings
FONTS_TO_GENERATE = {
    'jetbrainsmono': {
        'source_dir': 'D:/repos/github/fonts/ofl/jetbrainsmono',
        'dest_dir': 'assets/google_fonts/jetbrainsmono',
        'files': [
            {
                'source': 'JetBrainsMono[wght].ttf',
                'instances': [
                    {'name': 'JetBrainsMono-Regular.ttf', 'wght': 400},
                    {'name': 'JetBrainsMono-Medium.ttf', 'wght': 500},
                    {'name': 'JetBrainsMono-Bold.ttf', 'wght': 700},
                ]
            },
            {
                'source': 'JetBrainsMono-Italic[wght].ttf',
                'instances': [
                    {'name': 'JetBrainsMono-Italic.ttf', 'wght': 400},
                    {'name': 'JetBrainsMono-MediumItalic.ttf', 'wght': 500},
                    {'name': 'JetBrainsMono-BoldItalic.ttf', 'wght': 700},
                ]
            },
        ]
    },
    'firacode': {
        'source_dir': 'D:/repos/github/fonts/ofl/firacode',
        'dest_dir': 'assets/google_fonts/firacode',
        'files': [
            {
                'source': 'FiraCode[wght].ttf',
                'instances': [
                    {'name': 'FiraCode-Regular.ttf', 'wght': 400},
                    {'name': 'FiraCode-Medium.ttf', 'wght': 500},
                    {'name': 'FiraCode-Bold.ttf', 'wght': 700},
                ]
            },
        ]
    },
    'notosansmono': {
        'source_dir': 'D:/repos/github/fonts/ofl/notosansmono',
        'dest_dir': 'assets/google_fonts/notosansmono',
        'files': [
            {
                'source': 'NotoSansMono[wdth,wght].ttf',
                'instances': [
                    {'name': 'NotoSansMono-Regular.ttf', 'wght': 400, 'wdth': 100},
                    {'name': 'NotoSansMono-Medium.ttf', 'wght': 500, 'wdth': 100},
                    {'name': 'NotoSansMono-Bold.ttf', 'wght': 700, 'wdth': 100},
                ]
            },
        ]
    },
    'overpassmono': {
        'source_dir': 'D:/repos/github/fonts/ofl/overpassmono',
        'dest_dir': 'assets/google_fonts/overpassmono',
        'files': [
            {
                'source': 'OverpassMono[wght].ttf',
                'instances': [
                    {'name': 'OverpassMono-Regular.ttf', 'wght': 400},
                    {'name': 'OverpassMono-Medium.ttf', 'wght': 500},
                    {'name': 'OverpassMono-Bold.ttf', 'wght': 700},
                ]
            },
        ]
    },
    'robotomono': {
        'source_dir': 'D:/repos/github/fonts/ofl/robotomono',
        'dest_dir': 'assets/google_fonts/robotomono',
        'files': [
            {
                'source': 'RobotoMono[wght].ttf',
                'instances': [
                    {'name': 'RobotoMono-Regular.ttf', 'wght': 400},
                    {'name': 'RobotoMono-Medium.ttf', 'wght': 500},
                    {'name': 'RobotoMono-Bold.ttf', 'wght': 700},
                ]
            },
            {
                'source': 'RobotoMono-Italic[wght].ttf',
                'instances': [
                    {'name': 'RobotoMono-Italic.ttf', 'wght': 400},
                    {'name': 'RobotoMono-MediumItalic.ttf', 'wght': 500},
                    {'name': 'RobotoMono-BoldItalic.ttf', 'wght': 700},
                ]
            },
        ]
    },
    'sourcecodepro': {
        'source_dir': 'D:/repos/github/fonts/ofl/sourcecodepro',
        'dest_dir': 'assets/google_fonts/sourcecodepro',
        'files': [
            {
                'source': 'SourceCodePro[wght].ttf',
                'instances': [
                    {'name': 'SourceCodePro-Regular.ttf', 'wght': 400},
                    {'name': 'SourceCodePro-Medium.ttf', 'wght': 500},
                    {'name': 'SourceCodePro-Bold.ttf', 'wght': 700},
                ]
            },
            {
                'source': 'SourceCodePro-Italic[wght].ttf',
                'instances': [
                    {'name': 'SourceCodePro-Italic.ttf', 'wght': 400},
                    {'name': 'SourceCodePro-MediumItalic.ttf', 'wght': 500},
                    {'name': 'SourceCodePro-BoldItalic.ttf', 'wght': 700},
                ]
            },
        ]
    },
}


def generate_static_font(source_path, dest_path, axes):
    """Generate a static font instance from a variable font."""
    print(f"  Generating {os.path.basename(dest_path)}...")

    try:
        # Load variable font
        font = TTFont(source_path)

        # Instantiate to specific axis values
        instancer.instantiateVariableFont(font, axes)

        # Save static font
        font.save(dest_path)
        font.close()

        print(f"    [OK] Created {os.path.basename(dest_path)}")
        return True
    except Exception as e:
        print(f"    [ERROR] {e}")
        return False


def main():
    """Generate all static fonts."""
    print("=" * 60)
    print("Static Font Generator for flutter-gitui")
    print("=" * 60)

    total_fonts = 0
    generated_fonts = 0

    for font_name, config in FONTS_TO_GENERATE.items():
        print(f"\n[{font_name.upper()}]")

        source_dir = Path(config['source_dir'])
        dest_dir = Path(config['dest_dir'])

        # Create destination directory
        dest_dir.mkdir(parents=True, exist_ok=True)

        for file_config in config['files']:
            source_file = source_dir / file_config['source']

            if not source_file.exists():
                print(f"  ✗ Source not found: {source_file}")
                continue

            print(f"  Processing {file_config['source']}...")

            for instance in file_config['instances']:
                total_fonts += 1
                dest_file = dest_dir / instance['name']

                # Build axes dict (remove 'name' key)
                axes = {k: v for k, v in instance.items() if k != 'name'}

                if generate_static_font(str(source_file), str(dest_file), axes):
                    generated_fonts += 1

    print("\n" + "=" * 60)
    print(f"Generation complete: {generated_fonts}/{total_fonts} fonts created")
    print("=" * 60)

    if generated_fonts < total_fonts:
        sys.exit(1)


if __name__ == '__main__':
    main()
