// Runs the off-device BrightScript tests: `npm test` transpiles the project
// (bsc) and this executes each tests/*Tests.brs against the transpiled module
// it covers, using the @rokucommunity/brs interpreter. Only pure logic is
// testable this way -- anything touching SceneGraph nodes, the registry or the
// network still needs a real device.
const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const root = path.resolve(__dirname, '..');
const brs = path.join(root, 'node_modules', '.bin', 'brs');

// test file -> the transpiled module(s) it needs
const suites = {
    'StreamQualityTests.brs': ['out/source/utils/StreamQuality.brs'],
    'ConfirmTests.brs': ['out/source/utils/Confirm.brs'],
    'NextEpisodeTests.brs': ['out/source/utils/NextEpisode.brs']
};

// SASHIMI_TEST_MODULE swaps in another build of the module under test, to
// check that the tests fail against code they are meant to catch. With more
// than one suite, SASHIMI_TEST_SUITE (a test file name) picks which one runs.
const override = process.env.SASHIMI_TEST_MODULE;
const only = process.env.SASHIMI_TEST_SUITE;
if (only && !suites[only]) {
    console.error(`unknown suite ${only}`);
    process.exit(1);
}

let failed = false;
for (const [test, modules] of Object.entries(suites)) {
    if (only && test !== only) continue;
    const files = (override ? [override] : modules.map((m) => path.join(root, m)));
    for (const f of files) {
        if (!fs.existsSync(f)) {
            console.error(`${test}: missing ${f} (run bsc first)`);
            process.exit(1);
        }
    }
    const run = spawnSync(brs, [...files, path.join(__dirname, test)], { encoding: 'utf8', cwd: __dirname });
    const output = `${run.stdout || ''}${run.stderr || ''}`;
    process.stdout.write(output);
    // The interpreter exits 0 even when a script errors, so the suite must
    // say it finished clean.
    if (run.status !== 0 || !output.includes('ALL PASSED') || output.includes('FAIL ')) {
        console.error(`${test}: FAILED`);
        failed = true;
    }
}
process.exit(failed ? 1 : 0);
