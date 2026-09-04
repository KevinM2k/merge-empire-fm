"""Regenerate src/fonts/*.woff2 from the app's own .ttf faces.

The originals live in ../assets/fonts and are NOT duplicated into this package;
only the derived woff2 are checked in. Run from design-system/:
    python3 tool/gen_fonts.py     (needs: pip install fonttools brotli)
"""
import os
from fontTools.ttLib import TTFont

FACES = ['Barlow-SemiBold', 'Barlow-Bold', 'Barlow-Black', 'LilitaOne-Regular']

for name in FACES:
    src = f'../assets/fonts/{name}.ttf'
    dst = f'src/fonts/{name}.woff2'
    font = TTFont(src)
    font.flavor = 'woff2'
    font.save(dst)
    print(f'{name}: {os.path.getsize(src) // 1024}KB ttf -> {os.path.getsize(dst) // 1024}KB woff2')
