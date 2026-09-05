"""Crop the remastered Kenney hills to the rows the diorama can show.

The strip's bottom sits behind the stand, so of the 400-row sprite only the
ridge and a little body under it are ever visible. Run from the repo root:
    python3 tool/crop_kenney_hills.py
"""
from PIL import Image

SRC = 'kenneynl/kenney_background-elements-remastered/Backgrounds/Elements/'
ROWS = 240
for name in ['hills', 'hillsLarge', 'mountains']:
    im = Image.open(SRC + name + '.png').convert('RGBA')
    im.crop((0, 0, im.width, ROWS)).save(f'assets/bg/kenney/{name}Redux.png')
