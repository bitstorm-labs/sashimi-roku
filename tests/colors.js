// Flags colours written alpha-first. SceneGraph colours are #RRGGBBAA (alpha
// LAST), but Android (#AARRGGBB) and habit put it first: "#40FFFFFF" meant
// "white at 25%" and rendered opaque CYAN (the player's scrubber track, the
// OSD's "Finishes at" and subtitle lines). The tell: read as RRGGBBAA it is a
// tinted colour, while its last six digits are a grey (equal channels) --
// i.e. it only makes sense as AARRGGBB. Such a colour is ambiguous at best, so
// write the intended one (#FFFFFF40) instead. Runs from `npm test`.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const dirs = ['components', 'source'];
const colour = /(?:#|0x)([0-9A-Fa-f]{8})\b/g;

function walk(dir, out) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) walk(p, out);
        else if (/\.(bs|brs|xml)$/.test(e.name)) out.push(p);
    }
    return out;
}

// Exported for the self-test below.
function alphaFirst(hex) {
    const h = hex.toUpperCase();
    const [r, g, b] = [h.slice(0, 2), h.slice(2, 4), h.slice(4, 6)];
    const [x, y, z] = [h.slice(2, 4), h.slice(4, 6), h.slice(6, 8)];
    const tinted = !(r === g && g === b);
    const greyIfArgb = x === y && y === z;
    return tinted && greyIfArgb;
}

// The rule must catch what bit us and leave real colours alone.
const selfTest = [
    ['40FFFFFF', true], ['E6FFFFFF', true], ['99FFFFFF', true], ['80000000', true],
    ['FFFFFF40', false], ['00000066', false], ['8C5CC7FF', false],
    ['0A0A10C8', false], ['FFFFFFFF', false], ['1A1A1FF2', false],
];
let failed = false;
for (const [hex, want] of selfTest) {
    if (alphaFirst(hex) !== want) {
        console.error(`colors.js self-test: ${hex} should ${want ? '' : 'not '}be flagged`);
        failed = true;
    }
}

const files = process.argv.length > 2 ? process.argv.slice(2) : dirs.flatMap((d) => walk(path.join(root, d), []));
for (const f of files) {
    const lines = fs.readFileSync(f, 'utf8').split('\n');
    lines.forEach((line, i) => {
        for (const m of line.matchAll(colour)) {
            if (alphaFirst(m[1])) {
                console.error(`${path.relative(root, f)}:${i + 1}: ${m[0]} looks alpha-first; SceneGraph is #RRGGBBAA (write #${m[1].slice(2)}${m[1].slice(0, 2)})`);
                failed = true;
            }
        }
    });
}
if (failed) process.exit(1);
console.log('colors: no alpha-first colours');
