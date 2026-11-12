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
    'NextEpisodeTests.brs': ['out/source/utils/NextEpisode.brs'],
    'ContinueWatchingTests.brs': ['out/source/utils/ContinueWatching.brs'],
    'HeroTrailerTests.brs': ['out/source/utils/HeroTrailer.brs'],
    'ShowStatusTests.brs': ['out/source/utils/ShowStatus.brs'],
    'SeriesMetaTests.brs': ['out/source/utils/SeriesMeta.brs'],
    'ImageUrlTests.brs': ['out/source/utils/ImageUrl.brs'],
    'RowWindowTests.brs': ['out/source/utils/RowWindow.brs'],
    'SkipPillTests.brs': ['out/source/utils/SkipPill.brs'],
    'AdminDashTests.brs': ['out/source/utils/AdminDash.brs'],
    'RemoteControlTests.brs': ['out/source/utils/RemoteControl.brs'],
    'WatchStateTests.brs': ['out/source/utils/WatchState.brs'],
    'RailItemsTests.brs': ['out/source/utils/RailItems.brs'],
    'DetailActionsTests.brs': ['out/source/utils/DetailActions.brs'],
    'SeasonPageTests.brs': ['out/source/utils/SeasonPage.brs'],
    'DetailNavTests.brs': ['out/source/utils/DetailNav.brs'],
    'DetailLayoutTests.brs': ['out/source/utils/DetailLayout.brs'],
    'FadesTests.brs': ['out/source/utils/Fades.brs'],
    'LanguagePrefsTests.brs': ['out/source/utils/LanguagePrefs.brs'],
    'SharedListsTests.brs': ['out/source/utils/SharedLists.brs'],
    'ListsModelTests.brs': ['out/source/utils/SharedLists.brs', 'out/source/utils/ListsModel.brs'],
    'SeerrTests.brs': ['out/source/utils/Seerr.brs', 'out/source/utils/SeerrSeasons.brs'],
    'SeerrSeasonsTests.brs': ['out/source/utils/Seerr.brs', 'out/source/utils/SeerrSeasons.brs'],
    'ListLayoutTests.brs': ['out/source/utils/ListLayout.brs'],
    'EntitiesTests.brs': ['out/source/utils/Entities.brs'],
    'PlayerSessionTests.brs': ['out/source/utils/PlayerSession.brs'],
    'WatchlistTests.brs': ['out/source/utils/Seerr.brs', 'out/source/utils/SeerrSeasons.brs', 'out/source/utils/Watchlist.brs'],
    'SettingsSyncTests.brs': ['out/source/utils/RailItems.brs', 'out/source/utils/SettingsSync.brs']
};

// SASHIMI_TEST_MODULE swaps in another build of the module under test, to
// check that the tests fail against code they are meant to catch. With more
// than one suite, SASHIMI_TEST_SUITE (a test file name) picks which one runs.
// A suite that loads several modules swaps only the one with the same file
// name (a mutant SettingsSync.brs still runs beside the real RailItems.brs).
const override = process.env.SASHIMI_TEST_MODULE;
const only = process.env.SASHIMI_TEST_SUITE;
if (only && !suites[only]) {
    console.error(`unknown suite ${only}`);
    process.exit(1);
}

let failed = false;
for (const [test, modules] of Object.entries(suites)) {
    if (only && test !== only) continue;
    let files = modules.map((m) => path.join(root, m));
    if (override) {
        const at = modules.length === 1 ? 0 : modules.findIndex((m) => path.basename(m) === path.basename(override));
        if (at < 0) {
            console.error(`${test}: ${path.basename(override)} is none of ${modules.join(', ')}`);
            process.exit(1);
        }
        files[at] = override;
    }
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
