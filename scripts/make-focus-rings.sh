#!/bin/bash
# Regenerates the focus-ring assets in the app's accent purple (needs
# ImageMagick 7).
#
# The templates in scripts/focus-rings/ are the original assets: each one's
# ring is a single flat colour (the old focus blue #5CADE6, or white) whose
# anti-aliasing lives entirely in alpha, so recolouring the ring's RGB and
# leaving alpha alone keeps every edge exactly as smooth as it was. Fills (the
# white / dark button bodies, the card and selected-pill backgrounds) and the
# black nine-patch stretch markers are a different colour and are untouched.
#
# ACCENT is the purple the rest of the app already uses ("Ends at", progress
# bars, guide and channel accents).
#
# Also written, from the same templates, in their original white:
#   current_ring_r8.9.png  the current-episode marker on episode cards. It used
#                          to share focus_ring_r8 with focus; it stays white so
#                          "current" and "focused" never look alike.
#   ring_r16_white.9.png   for rings tinted by blendColor (which multiplies, so
#                          its base must be white to land on the exact colour).
set -euo pipefail
cd "$(dirname "$0")"
SRC=focus-rings
OUT=../images
ACCENT="#8C5CC7"

# recolour <template> <ring colour> <output>
recolour() { paint "$1" "$2" "$ACCENT" "$3"; }

# paint <template> <ring colour> <new colour> <output>: the match runs on the
# colour with alpha switched off, then the template's own alpha goes back on,
# so the ring's semi-transparent edge pixels are recoloured too.
paint() {
    magick "$SRC/$1" \( +clone -alpha extract \) \( -clone 0 -alpha off \
        -fuzz 1% -fill "$3" -opaque "$2" \) -delete 0 +swap \
        -compose CopyOpacity -composite -define png:color-type=6 -strip "$OUT/$4"
}

recolour focus_ring_r8.9.png      "#FFFFFF" focus_ring_r8.9.png
recolour focus_ring_r16.9.png     "#5CADE6" focus_ring_r16.9.png
recolour circle_ring.png          "#5CADE6" circle_ring.png
recolour btn_white_focus.9.png    "#5CADE6" btn_white_focus.9.png
recolour btn_dark_focus.9.png     "#5CADE6" btn_dark_focus.9.png
recolour card_r16_focus.9.png     "#5CADE6" card_r16_focus.9.png
recolour pill_selected_focus.9.png "#FFFFFF" pill_selected_focus.9.png

cp "$SRC/focus_ring_r8.9.png" "$OUT/current_ring_r8.9.png"
paint focus_ring_r16.9.png "#5CADE6" "#FFFFFF" ring_r16_white.9.png
