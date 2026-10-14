' Off-device tests for source/utils/HeroTrailer.bs, run by tests/run.js against
' the transpiled module (out/source/utils/HeroTrailer.brs): which title's
' trailer a detail screen plays, which stretch of it, and the once-per-visit
' ownership rules that decide start / hand off / stop.

sub main()
    t = { passed: 0, failed: 0 }

    testSourceId(t)
    testSource(t)
    testClip(t)
    testFadeAt(t)
    testMute(t)
    testAppeared(t)
    testHandOffAndOncePerVisit(t)
    testDismissed(t)
    testSourceChanged(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if actual <> invalid and expected <> invalid and type(actual) <> type(expected)
        ' Integer vs Float/Double: compare numerically.
        if isNumber(actual) and isNumber(expected) and Abs(actual - expected) < 0.0001
            t.passed = t.passed + 1
            return
        end if
    else if actual = invalid and expected = invalid
        t.passed = t.passed + 1
        return
    else if actual <> invalid and expected <> invalid and actual = expected
        t.passed = t.passed + 1
        return
    end if
    t.failed = t.failed + 1
    print "FAIL "; name; ": expected "; expected; " got "; actual
end sub

function isNumber(v as dynamic) as boolean
    k = type(v)
    return (k = "Integer" or k = "roInt" or k = "roInteger" or k = "Float" or k = "roFloat" or k = "Double" or k = "roDouble" or k = "LongInteger" or k = "roLongInteger")
end function

sub testSourceId(t as object)
    eq(t, "movie with trailers", HeroTrailer_sourceId({ Id: "m1", Type: "Movie", LocalTrailerCount: 1 }), "m1")
    eq(t, "movie, count unknown", HeroTrailer_sourceId({ Id: "m1", Type: "Movie" }), "m1")
    eq(t, "movie with no trailers is skipped", HeroTrailer_sourceId({ Id: "m1", Type: "Movie", LocalTrailerCount: 0 }), "")
    eq(t, "series with trailers", HeroTrailer_sourceId({ Id: "s1", Type: "Series", LocalTrailerCount: 2 }), "s1")
    eq(t, "series with no trailers is skipped", HeroTrailer_sourceId({ Id: "s1", Type: "Series", LocalTrailerCount: 0 }), "")
    eq(t, "season uses its series", HeroTrailer_sourceId({ Id: "se1", Type: "Season", SeriesId: "s1" }), "s1")
    eq(t, "episode uses its series", HeroTrailer_sourceId({ Id: "e1", Type: "Episode", SeriesId: "s1", LocalTrailerCount: 0 }), "s1")
    eq(t, "episode without a series", HeroTrailer_sourceId({ Id: "e1", Type: "Episode" }), "")
    eq(t, "other types never play", HeroTrailer_sourceId({ Id: "x", Type: "MusicVideo" }), "")
    eq(t, "bare deep-link id never plays", HeroTrailer_sourceId({ Id: "x" }), "")
    eq(t, "another server's title never plays", HeroTrailer_sourceId({ Id: "m1", Type: "Movie", _server: { id: "b" } }), "")
    eq(t, "invalid item", HeroTrailer_sourceId(invalid), "")
end sub

sub testSource(t as object)
    eq(t, "no trailers", HeroTrailer_source([]), invalid)
    eq(t, "invalid list", HeroTrailer_source(invalid), invalid)
    s = HeroTrailer_source([{ Id: "t1", RunTimeTicks: 1210000000& }, { Id: "t2", RunTimeTicks: 600000000& }])
    eq(t, "first trailer id", s.id, "t1")
    eq(t, "length from ticks", s.seconds, 121)
    ' Past the 32-bit range: a CDbl-style conversion would go negative.
    s = HeroTrailer_source([{ Id: "t1", RunTimeTicks: 3570000000& }])
    eq(t, "long trailer stays positive", s.seconds, 357)
    s = HeroTrailer_source([{ Id: "t1" }])
    eq(t, "unknown length", s.seconds, invalid)
    s = HeroTrailer_source([{ Id: "t1", RunTimeTicks: 0 }])
    eq(t, "zero ticks is unknown", s.seconds, invalid)
end sub

sub testClip(t as object)
    c = HeroTrailer_clip(121)
    eq(t, "full trailer skips the opening", c.startSecs, 10)
    eq(t, "full trailer plays 30s", c.endSecs, 40)
    c = HeroTrailer_clip(45)
    eq(t, "45s trailer skips", c.startSecs, 10)
    eq(t, "45s trailer ends at 40", c.endSecs, 40)
    c = HeroTrailer_clip(44.9)
    eq(t, "short clip from the start", c.startSecs, 0)
    eq(t, "short clip capped at 30", c.endSecs, 30)
    c = HeroTrailer_clip(20)
    eq(t, "very short clip from 0", c.startSecs, 0)
    eq(t, "very short clip ends at its own end", c.endSecs, 20)
    c = HeroTrailer_clip(invalid)
    eq(t, "unknown length from 0", c.startSecs, 0)
    eq(t, "unknown length plays 30", c.endSecs, 30)
end sub

sub testFadeAt(t as object)
    eq(t, "fade starts before the end", HeroTrailer_fadeAt({ startSecs: 10, endSecs: 40 }), 39.4)
    eq(t, "fade never before the start", HeroTrailer_fadeAt({ startSecs: 0, endSecs: 0.3 }), 0)
end sub

sub testMute(t as object)
    eq(t, "muted under a theme", HeroTrailer_shouldMute(true), true)
    eq(t, "audible without one", HeroTrailer_shouldMute(false), false)
end sub

sub testAppeared(t as object)
    s = HeroTrailer_newOwners()
    d = HeroTrailer_appeared(s, "a", "m1", "")
    eq(t, "first visit starts", d.kind, "start")
    eq(t, "starts the screen's source", d.sourceId, "m1")
    eq(t, "the new screen is top", HeroTrailer_topOwner(s), "a")
    d = HeroTrailer_appeared(s, "b", "", "m1")
    eq(t, "a covering screen stops it", d.kind, "stop")
    eq(t, "the cover is top", HeroTrailer_topOwner(s), "b")
end sub

sub testHandOffAndOncePerVisit(t as object)
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "series", "s1", "")
    ' Drilling into an episode of the same show while the trailer runs.
    d = HeroTrailer_appeared(s, "episode", "s1", "s1")
    eq(t, "same show hands off", d.kind, "handOff")
    ' Back to the series: the trailer carries on there.
    d = HeroTrailer_dismissed(s, "episode", "s1")
    eq(t, "back to the series hands off", d.kind, "handOff")
    ' Same show again after the trailer finished: no replay.
    d = HeroTrailer_appeared(s, "episode2", "s1", "")
    eq(t, "finished trailer does not replay", d.kind, "stop")
    d = HeroTrailer_appeared(s, "other", "m2", "")
    eq(t, "another title still starts", d.kind, "start")
    ' Every detail screen dismissed: the visit is over.
    HeroTrailer_dismissed(s, "other", "")
    HeroTrailer_dismissed(s, "episode2", "")
    d = HeroTrailer_dismissed(s, "series", "")
    eq(t, "last screen gone stops", d.kind, "stop")
    d = HeroTrailer_appeared(s, "again", "s1", "")
    eq(t, "a new visit plays again", d.kind, "start")
end sub

sub testDismissed(t as object)
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "a", "m1", "")
    HeroTrailer_appeared(s, "b", "m2", "")
    d = HeroTrailer_dismissed(s, "b", "m2")
    eq(t, "back to a different title stops", d.kind, "stop")
    eq(t, "the screen below is top", HeroTrailer_topOwner(s), "a")
    d = HeroTrailer_dismissed(s, "zzz", "")
    eq(t, "unknown owner is ignored", d.kind, "ignore")
    HeroTrailer_appeared(s, "c", "", "")
    d = HeroTrailer_dismissed(s, "a", "")
    eq(t, "a screen below the top is ignored", d.kind, "ignore")
    eq(t, "and the top stays", HeroTrailer_topOwner(s), "c")
    ' Returning from the player (a covering screen) never replays.
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "a", "m1", "")
    HeroTrailer_appeared(s, "player", "", "")
    d = HeroTrailer_dismissed(s, "player", "")
    eq(t, "back from the player stays on the image", d.kind, "stop")
    HeroTrailer_reset(s)
    eq(t, "reset empties the stack", HeroTrailer_topOwner(s), "")
    d = HeroTrailer_appeared(s, "a", "m1", "")
    eq(t, "reset forgets what played", d.kind, "start")
end sub

sub testSourceChanged(t as object)
    s = HeroTrailer_newOwners()
    ' A deep link pushes with no source; the loaded item supplies it.
    HeroTrailer_appeared(s, "a", "", "")
    d = HeroTrailer_sourceChanged(s, "a", "m1", "")
    eq(t, "late source on the top screen starts", d.kind, "start")
    d = HeroTrailer_sourceChanged(s, "a", "m1", "")
    eq(t, "an unchanged source is ignored", d.kind, "ignore")
    ' A row item without LocalTrailerCount, then the item says zero.
    d = HeroTrailer_sourceChanged(s, "a", "", "m1")
    eq(t, "source withdrawn stops", d.kind, "stop")
    HeroTrailer_appeared(s, "b", "m2", "")
    d = HeroTrailer_sourceChanged(s, "a", "m3", "m2")
    eq(t, "a screen below records silently", d.kind, "ignore")
    eq(t, "without becoming top", HeroTrailer_topOwner(s), "b")
    d = HeroTrailer_dismissed(s, "b", "")
    eq(t, "and back on top it does not start", d.kind, "stop")
    d = HeroTrailer_sourceChanged(s, "nobody", "m1", "")
    eq(t, "unknown owner", d.kind, "ignore")
end sub
