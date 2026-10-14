#!/bin/bash
# Regenerates the detail-screen hero fade assets (needs ImageMagick 7).
#
# The picture sits flush against the top-right corner and fades only on its
# LEFT 35% (transparent -> opaque, into the title text) and BOTTOM 40% (opaque
# -> transparent, into the rows) -- the home hero's shape, and the Apple app's
# MediaDetailView mask.
#
# backdrop_feather.png  MaskGroup alpha mask for the image. A real mask, so the
#                       page gradient shows through and no colour has to match.
# trailer_feather.png   Overlay for the trailer Video, which a MaskGroup can't
#                       mask: alpha is the mask inverted (video*m + page*(1-m)
#                       is exactly what the masked image composites to), and
#                       each row is painted in bg_gradient.png's colour at that
#                       screen row, since a flat colour can't feather against a
#                       gradient. bg_gradient.png is 8x540 drawn at 1920x1080,
#                       so the hero's 0..594 screen rows are its rows 0..297.
set -euo pipefail
cd "$(dirname "$0")/../images"
W=1056 H=594   # 55% of 1920, 16:9 -- the movie/episode size (stretched to fit)
FX="min(i/(0.35*w),1)*min((h-1-j)/(0.4*h),1)"
magick -size ${W}x${H} xc:white -alpha set -channel A -fx "$FX" +channel \
    -strip PNG32:backdrop_feather.png
magick bg_gradient.png -crop 1x297+4+0 +repage -alpha off -filter Triangle \
    -resize ${W}x${H}\! -alpha set -channel A -fx "1-($FX)" +channel \
    -strip PNG32:trailer_feather.png
