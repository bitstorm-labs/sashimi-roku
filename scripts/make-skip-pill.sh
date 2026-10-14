#!/bin/bash
# Regenerates the player's skip pill ("countdown fill") assets (needs
# ImageMagick 7). Everything is drawn at 4x and scaled down, so the curves are
# anti-aliased, and cut for the exact sizes the player draws (PlayerScreen.xml
# skipPill: 340x56), so no capsule end is ever squashed into an ellipse.
#
# skip_pill_bg.9.png    56px capsule nine-patch: #14121C at 70% with a 1px
#                       white hairline at 16%. 28px end caps, 4px stretch.
# skip_pill_ring.9.png  the focus ring: a 3px white capsule stroke for a 62px
#                       box (the pill plus 3px all round). 31px end caps.
# skip_pill_mask.png    340x56 white capsule: the MaskGroup that clips the
#                       purple fill to the pill.
# skip_pill_mask_focus.png  the same at 368x60, the focused (1.08) pill.
# skip_glyph.png        the skip-forward glyph (two triangles and a bar), white,
#                       52x52 for a 26x26 draw.
set -euo pipefail
cd "$(dirname "$0")/../images"
S=4

# nine-patch <in> <out> <stretch-x-from> <stretch-x-to> <stretch-y-from> <stretch-y-to>
# (content coordinates): 1px transparent border with black stretch markers.
ninepatch() {
    magick "$1" -bordercolor none -border 1 -fill black \
        -draw "line $(( $3 + 1 )),0 $(( $4 + 1 )),0" \
        -draw "line 0,$(( $5 + 1 )) 0,$(( $6 + 1 ))" \
        -define png:color-type=6 -strip "$2"
    rm -f "$1"
}

# Background: 60x56 (28 + 4 + 28).
W=60 H=56 R=28
magick -size $((W*S))x$((H*S)) xc:none \
    -fill "rgba(20,18,28,0.70)" -stroke "rgba(255,255,255,0.16)" -strokewidth $S \
    -draw "roundrectangle $((S/2)),$((S/2)) $((W*S-S/2-1)),$((H*S-S/2-1)) $((R*S-S/2)),$((R*S-S/2))" \
    -resize ${W}x${H} /tmp/skip_bg_$$.png
ninepatch /tmp/skip_bg_$$.png skip_pill_bg.9.png 28 31 27 28

# Focus ring: 66x62 (31 + 4 + 31), 3px stroke inside the box.
W=66 H=62 R=31 T=3
magick -size $((W*S))x$((H*S)) xc:none \
    -fill none -stroke white -strokewidth $((T*S)) \
    -draw "roundrectangle $((T*S/2)),$((T*S/2)) $((W*S-T*S/2-1)),$((H*S-T*S/2-1)) $((R*S-T*S/2)),$((R*S-T*S/2))" \
    -resize ${W}x${H} /tmp/skip_ring_$$.png
ninepatch /tmp/skip_ring_$$.png skip_pill_ring.9.png 31 34 30 31

# Fill masks: the whole pill, and the pill at the focused 1.08 scale (whole
# pixels: a MaskGroup given a fractional maskSize/offset drew unmasked on the
# 9100X, so focus swaps to a mask cut for 368x60 instead of stretching this).
mask() {
    local W=$1 H=$2 R=$(( $2 / 2 ))
    magick -size $((W*S))x$((H*S)) xc:none -fill white \
        -draw "roundrectangle 0,0 $((W*S-1)),$((H*S-1)) $((R*S)),$((R*S))" \
        -resize ${W}x${H} -define png:color-type=6 -strip "$3"
}
mask 340 56 skip_pill_mask.png
mask 368 60 skip_pill_mask_focus.png

# Glyph: |>|>| style skip-forward, 52x52.
G=52
magick -size $((G*S))x$((G*S)) xc:none -fill white \
    -draw "polygon $((6*S)),$((12*S)) $((24*S)),$((26*S)) $((6*S)),$((40*S))" \
    -draw "polygon $((22*S)),$((12*S)) $((40*S)),$((26*S)) $((22*S)),$((40*S))" \
    -draw "roundrectangle $((40*S)),$((12*S)) $((46*S-1)),$((40*S-1)) $((2*S)),$((2*S))" \
    -resize ${G}x${G} -define png:color-type=6 -strip skip_glyph.png
