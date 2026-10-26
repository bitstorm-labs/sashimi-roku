' Off-device tests for source/utils/SeasonPage.bs, run by tests/run.js
' against the transpiled module. The Season page (#246) plays the season's
' next unwatched episode (resumed if started; E1 once all are watched),
' flips Mark Season Watched to Unwatched when every episode is watched, and
' heads itself "Season 2 · 8 episodes · 5 of 8 watched".

sub main()
    t = { passed: 0, failed: 0 }

    testPlayTarget(t)
    testFullyPlayed(t)
    testMetaLine(t)
    testInfoLine(t)

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

function ep(n as integer, played as boolean, ticks as integer) as object
    return { Id: "e" + n.ToStr(), ParentIndexNumber: 2, IndexNumber: n, UserData: { Played: played, PlaybackPositionTicks: ticks } }
end function

sub testPlayTarget(t as object)
    eps = [ep(1, true, 0), ep(2, true, 0), ep(3, true, 0), ep(4, true, 0), ep(5, true, 0), ep(6, false, 0), ep(7, false, 0), ep(8, false, 0)]
    r = SeasonPage_playTarget(eps)
    eq(t, "next unwatched", r.episode.Id, "e6")
    eq(t, "next unwatched plays", r.action, "play")

    eps[5] = ep(6, false, 12345)
    r = SeasonPage_playTarget(eps)
    eq(t, "started episode resumes", r.episode.Id, "e6")
    eq(t, "started episode action", r.action, "resume")

    all = [ep(1, true, 0), ep(2, true, 999), ep(3, true, 0)]
    r = SeasonPage_playTarget(all)
    eq(t, "all watched starts at E1", r.episode.Id, "e1")
    eq(t, "all watched plays from the start", r.action, "play")

    eq(t, "first episode unwatched", SeasonPage_playTarget([ep(1, false, 0), ep(2, true, 0)]).episode.Id, "e1")
    eq(t, "missing UserData counts as unwatched", SeasonPage_playTarget([ep(1, true, 0), { Id: "e2" }]).episode.Id, "e2")
    eq(t, "empty season", SeasonPage_playTarget([]), invalid)
    eq(t, "no list", SeasonPage_playTarget(invalid), invalid)
end sub

sub testFullyPlayed(t as object)
    eq(t, "all watched", SeasonPage_fullyPlayed(invalid, [ep(1, true, 0), ep(2, true, 0)]), true)
    eq(t, "one left", SeasonPage_fullyPlayed(invalid, [ep(1, true, 0), ep(2, false, 0)]), false)
    ' The loaded list outranks the season's rolled-up flag.
    eq(t, "list wins", SeasonPage_fullyPlayed({ UserData: { Played: true } }, [ep(1, false, 0)]), false)
    eq(t, "no list, season flag", SeasonPage_fullyPlayed({ UserData: { Played: true } }, invalid), true)
    eq(t, "empty season is not watched", SeasonPage_fullyPlayed({}, []), false)
end sub

sub testMetaLine(t as object)
    b = " " + Chr(8226) + " "
    eps = [ep(1, true, 0), ep(2, true, 0), ep(3, false, 0)]
    eq(t, "meta", SeasonPage_metaLine({ Name: "Season 2" }, eps), "Season 2" + b + "3 episodes" + b + "2 of 3 watched")
    eq(t, "one episode", SeasonPage_metaLine({ Name: "Specials" }, [ep(1, false, 0)]), "Specials" + b + "1 episode" + b + "0 of 1 watched")
    eq(t, "before the list loads", SeasonPage_metaLine({ Name: "Season 2" }, invalid), "Season 2")
    eq(t, "nameless season", SeasonPage_metaLine({ IndexNumber: 4 }, invalid), "Season 4")
end sub

sub testInfoLine(t as object)
    b = " " + Chr(8226) + " "
    eq(t, "season year, series rating", SeasonPage_infoLine({ ProductionYear: 2026 }, { ProductionYear: 2022, OfficialRating: "TV-MA" }), "2026" + b + "TV-MA")
    eq(t, "falls back to the series' year", SeasonPage_infoLine({}, { ProductionYear: 2022 }), "2022")
    eq(t, "premiere date year", SeasonPage_infoLine({ PremiereDate: "2019-05-01T00:00:00Z" }, invalid), "2019")
    eq(t, "nothing known", SeasonPage_infoLine({}, invalid), "")
end sub
