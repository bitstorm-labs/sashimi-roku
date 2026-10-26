// Checks the detail screen's baked fade assets against the "Lightest" fade
// (#255) in source/utils/Fades.bs: backdrop_feather.png (the image's alpha
// mask) is transparent at the left edge, opaque from LEFT of the width, opaque
// down to 1 - BOTTOM of the height and transparent at the bottom edge, and
// trailer_feather.png (the overlay that fades the trailer Video, which a
// MaskGroup can't mask) is exactly its inverse, so the trailer feathers like
// the still image. Regenerate both with scripts/make-detail-fades.sh. Runs
// from `npm test`; pass a directory to check another copy of the images.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const root = path.resolve(__dirname, '..');
const imgDir = process.argv[2] || path.join(root, 'images');
const fadesSrc = fs.readFileSync(path.join(root, 'source/utils/Fades.bs'), 'utf8');
const LEFT = Number(/const LEFT = ([0-9.]+)/.exec(fadesSrc)[1]);
const BOTTOM = Number(/const BOTTOM = ([0-9.]+)/.exec(fadesSrc)[1]);

// Minimal PNG reader: 8-bit RGBA, non-interlaced (what magick PNG32 writes).
function readRGBA(file) {
    const buf = fs.readFileSync(file);
    let pos = 8, w = 0, h = 0, idat = [];
    while (pos < buf.length) {
        const len = buf.readUInt32BE(pos);
        const type = buf.toString('ascii', pos + 4, pos + 8);
        const data = buf.subarray(pos + 8, pos + 8 + len);
        if (type === 'IHDR') {
            w = data.readUInt32BE(0); h = data.readUInt32BE(4);
            if (data[8] !== 8 || data[9] !== 6 || data[12] !== 0) throw new Error(`${file}: not 8-bit RGBA non-interlaced`);
        } else if (type === 'IDAT') idat.push(data);
        pos += 12 + len;
    }
    const raw = zlib.inflateSync(Buffer.concat(idat));
    const stride = w * 4, out = Buffer.alloc(h * stride);
    for (let y = 0; y < h; y++) {
        const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
        for (let x = 0; x < stride; x++) {
            const a = x >= 4 ? out[y * stride + x - 4] : 0;
            const b = y > 0 ? out[(y - 1) * stride + x] : 0;
            const c = x >= 4 && y > 0 ? out[(y - 1) * stride + x - 4] : 0;
            let p = line[x];
            if (f === 1) p += a;
            else if (f === 2) p += b;
            else if (f === 3) p += (a + b) >> 1;
            else if (f === 4) { const q = a + b - c, pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c); p += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
            out[y * stride + x] = p & 255;
        }
    }
    return { w, h, alpha: (x, y) => out[(y * w + x) * 4 + 3] / 255 };
}

let failed = 0;
function near(name, actual, expected) {
    if (Math.abs(actual - expected) > 0.04) { failed++; console.log(`FAIL ${name}: expected ${expected.toFixed(2)} got ${actual.toFixed(2)}`); }
}

const mask = readRGBA(path.join(imgDir, 'backdrop_feather.png'));
const over = readRGBA(path.join(imgDir, 'trailer_feather.png'));
const { w, h } = mask;
const midY = Math.round(h * 0.3), midX = Math.round(w * 0.6);
const leftEnd = Math.round(w * LEFT), bottomStart = Math.round(h * (1 - BOTTOM));

near('mask transparent at the left edge', mask.alpha(0, midY), 0);
near('mask half way through the left fade', mask.alpha(Math.round(leftEnd / 2), midY), 0.5);
near('mask opaque where the left fade ends', mask.alpha(leftEnd, midY), 1);
near('mask opaque where the bottom fade starts', mask.alpha(midX, bottomStart - 1), 1);
near('mask half way through the bottom fade', mask.alpha(midX, Math.round((bottomStart + h - 1) / 2)), 0.5);
near('mask transparent at the bottom edge', mask.alpha(midX, h - 1), 0);
for (const [x, y] of [[0, midY], [Math.round(leftEnd / 2), midY], [midX, midY], [midX, h - 1], [Math.round(leftEnd / 2), Math.round((bottomStart + h) / 2)]]) {
    near(`trailer overlay is the mask inverted at ${x},${y}`, over.alpha(x, y), 1 - mask.alpha(x, y));
}
if (over.w !== w || over.h !== h) { failed++; console.log('FAIL trailer overlay and mask differ in size'); }

if (failed) { console.error(`fades: ${failed} failed`); process.exit(1); }
console.log(`fades: backdrop mask and trailer overlay match Fades (left ${LEFT}, bottom ${BOTTOM})`);
