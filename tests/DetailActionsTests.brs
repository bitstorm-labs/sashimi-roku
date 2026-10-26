' Off-device tests for source/utils/DetailActions.bs, run by tests/run.js
' against the transpiled module. The detail screen's action row keeps to
' playing and the watched toggle; Go to Series, Go to Season N and the
' administrators' Add to Channel live in More (#246).

sub main()
    t = { passed: 0, failed: 0 }

    testEpisodeRow(t)
    testMovieAndSeriesRow(t)
    testSeasonRow(t)
    testPinnedRow(t)
    testEpisodeMore(t)
    testOtherMore(t)
    testSeasonChipMenu(t)
    testEpisodeSuffix(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub

' Kinds (or labels) joined with "|", so a whole row compares in one line.
function kinds(defs as object) as string
    out = ""
    for each d in defs
        if out <> "" then out = out + "|"
        out = out + d.kind
    end for
    return out
end function

function labelsOf(defs as object) as string
    out = ""
    for each d in defs
        if out <> "" then out = out + "|"
        out = out + d.label
    end for
    return out
end function

sub testEpisodeRow(t as object)
    ' Series and Add to Channel left the row; an admin's row is the same.
    row = DetailActions_mainRow({ itemType: "Episode", hasSeries: true, seasonId: "s2", canAddToChannel: true })
    eq(t, "episode row", kinds(row), "play|markPlayed|more")
    eq(t, "episode row labels", labelsOf(row), "Play|Mark Watched|More")
    eq(t, "Play is primary", row[0].primary, true)

    row = DetailActions_mainRow({ itemType: "Episode", hasSeries: true, hasProgress: true, isPlayed: true })
    eq(t, "part-watched episode", labelsOf(row), "Resume|Start Over|Watched|More")
    eq(t, "Watched toggles off", row[2].kind, "markUnplayed")
end sub

sub testMovieAndSeriesRow(t as object)
    row = DetailActions_mainRow({ itemType: "Movie", hasTrailer: true, canAddToChannel: true, hasProgress: true })
    eq(t, "movie row: Play, Start Over, Trailer, Watched, More", kinds(row), "resume|play|trailer|markPlayed|more")

    ' Shuffle went to More with Add to Channel; a container never offers Start Over.
    row = DetailActions_mainRow({ itemType: "Series", hasTrailer: true, canAddToChannel: true, hasProgress: true, epSuffix: " S1:E2" })
    eq(t, "series row", labelsOf(row), "Resume S1:E2|Trailer|Mark Watched|More")
end sub

sub testSeasonRow(t as object)
    row = DetailActions_mainRow({ itemType: "Season", hasSeries: true, epSuffix: " S2:E6", seasonPlayed: false })
    eq(t, "season row", labelsOf(row), "Play S2:E6|Mark Season Watched|Series")
    eq(t, "season row kinds", kinds(row), "play|seasonWatch|series")

    row = DetailActions_mainRow({ itemType: "Season", hasSeries: true, epSuffix: " S2:E1", seasonPlayed: true })
    eq(t, "fully watched season flips the toggle", labelsOf(row), "Play S2:E1|Mark Season Unwatched|Series")

    row = DetailActions_mainRow({ itemType: "Season", hasSeries: true, epSuffix: " S2:E3", hasProgress: true })
    eq(t, "season resumes", row[0].label, "Resume S2:E3")
    eq(t, "no Start Over on a season", row[1].kind, "seasonWatch")

    ' Neither More nor Trailer nor Add to Channel on the Season page.
    row = DetailActions_mainRow({ itemType: "Season", hasSeries: true, hasTrailer: true, canAddToChannel: true })
    eq(t, "season page is the mockup's row only", kinds(row), "play|seasonWatch|series")
end sub

sub testPinnedRow(t as object)
    row = DetailActions_mainRow({ itemType: "Movie", pinnedLabel: "Other", hasTrailer: true })
    eq(t, "pinned title switches servers, no trailer", labelsOf(row), "Switch to Other|Mark Watched|More")
end sub

sub testEpisodeMore(t as object)
    items = DetailActions_moreItems({ itemType: "Episode", hasSeries: true, seasonId: "s2", seasonNumber: 2, canAddToChannel: true })
    eq(t, "admin episode More", labelsOf(items), "Go to Series|Go to Season 2|Add to Channel|Add to Favorites")
    eq(t, "admin episode More kinds", kinds(items), "series|season|addToChannel|favorite")

    items = DetailActions_moreItems({ itemType: "Episode", hasSeries: true, seasonId: "s2", seasonNumber: 2, canAddToChannel: false, isFavorite: true })
    eq(t, "non-admin episode More", labelsOf(items), "Go to Series|Go to Season 2|Remove from Favorites")

    items = DetailActions_moreItems({ itemType: "Episode", hasSeries: true, seasonId: "s0", seasonNumber: 0 })
    eq(t, "season 0 is Specials", items[1].label, "Go to Specials")

    items = DetailActions_moreItems({ itemType: "Episode", hasSeries: false })
    eq(t, "no series or season known", labelsOf(items), "Add to Favorites")
end sub

sub testOtherMore(t as object)
    eq(t, "admin movie More", labelsOf(DetailActions_moreItems({ itemType: "Movie", canAddToChannel: true })), "Add to Channel|Add to Favorites")
    eq(t, "movie More", labelsOf(DetailActions_moreItems({ itemType: "Movie" })), "Add to Favorites")
    eq(t, "admin series More", labelsOf(DetailActions_moreItems({ itemType: "Series", canAddToChannel: true })), "Shuffle|Add to Channel|Add to Favorites")
    eq(t, "pinned series cannot shuffle", labelsOf(DetailActions_moreItems({ itemType: "Series", pinnedLabel: "Other" })), "Add to Favorites")
end sub

sub testSeasonChipMenu(t as object)
    eq(t, "chip menu", labelsOf(DetailActions_seasonChipMenu(false)), "Open Season|Mark Season Watched")
    eq(t, "chip menu, season watched", labelsOf(DetailActions_seasonChipMenu(true)), "Open Season|Mark Season Unwatched")
end sub

sub testEpisodeSuffix(t as object)
    eq(t, "suffix", DetailActions_episodeSuffix({ ParentIndexNumber: 2, IndexNumber: 6 }), " S2:E6")
    eq(t, "no index, no suffix", DetailActions_episodeSuffix({ ParentIndexNumber: 2 }), "")
    eq(t, "no episode", DetailActions_episodeSuffix(invalid), "")
end sub
