' Off-device tests for source/utils/HeroTrailer.bs, run by tests/run.js against
' the transpiled module (out/source/utils/HeroTrailer.brs): which title's
' trailer a detail screen plays, which stretch of it, and the once-per-visit
' ownership rules that decide start / hand off / stop.

sub main()
    t = { passed: 0, failed: 0 }

    testSourceId(t)
    testSource(t)
    testClip(t)
    testPlaysToEnd(t)
    testClipToEnd(t)
    testFadeAt(t)
    testFadeAtStreamEnd(t)
    testMute(t)
    testAppeared(t)
    testHandOffAndOncePerVisit(t)
    testDismissed(t)
    testSourceChanged(t)
    testPendingStartHandsOff(t)
    testStreamCaps(t)
    testShouldPrepare(t)

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

sub testPlaysToEnd(t as object)
    eq(t, "a movie plays its whole trailer", HeroTrailer_playsToEnd({ Id: "m1", Type: "Movie" }), true)
    ' Seasons and episodes play the series trailer, under the series rule.
    eq(t, "a series plays the clip", HeroTrailer_playsToEnd({ Id: "s1", Type: "Series" }), false)
    eq(t, "a season plays the clip", HeroTrailer_playsToEnd({ Id: "se1", Type: "Season", SeriesId: "s1" }), false)
    eq(t, "an episode plays the clip", HeroTrailer_playsToEnd({ Id: "e1", Type: "Episode", SeriesId: "s1" }), false)
    eq(t, "a bare deep-link id plays the clip", HeroTrailer_playsToEnd({ Id: "x" }), false)
    eq(t, "invalid item plays the clip", HeroTrailer_playsToEnd(invalid), false)
end sub

' Movies: the same start (the opening skip on a full trailer), but no 30 s cap.
sub testClipToEnd(t as object)
    c = HeroTrailer_clip(121, true)
    eq(t, "movie trailer still skips the opening", c.startSecs, 10)
    eq(t, "movie trailer plays to its own end", c.endSecs, 121)
    c = HeroTrailer_clip(44.9, true)
    eq(t, "short movie trailer from the start", c.startSecs, 0)
    eq(t, "short movie trailer past 30s", c.endSecs, 44.9)
    c = HeroTrailer_clip(20, true)
    eq(t, "very short movie trailer ends at its end", c.endSecs, 20)
    ' Unknown length: until the stream itself ends (see fadeAt).
    c = HeroTrailer_clip(invalid, true)
    eq(t, "unknown movie length from 0", c.startSecs, 0)
    eq(t, "unknown movie length has no fixed end", c.endSecs, invalid)
    ' The series rule is untouched by the flag being off.
    c = HeroTrailer_clip(121, false)
    eq(t, "series full trailer still ends at 40", c.endSecs, 40)
end sub

' The stream's own duration (Video.duration, 0 until known) can only bring
' the fade earlier, and is what an unknown-length movie trailer fades on.
sub testFadeAtStreamEnd(t as object)
    eq(t, "unknown length, duration not known yet", HeroTrailer_fadeAt({ startSecs: 0, endSecs: invalid }, 0), invalid)
    eq(t, "unknown length fades before the stream ends", HeroTrailer_fadeAt({ startSecs: 0, endSecs: invalid }, 95), 94.4)
    eq(t, "movie fades before the trailer ends", HeroTrailer_fadeAt({ startSecs: 10, endSecs: 121 }, 0), 120.4)
    eq(t, "a shorter stream wins", HeroTrailer_fadeAt({ startSecs: 10, endSecs: 121 }, 119), 118.4)
    eq(t, "a longer stream changes nothing", HeroTrailer_fadeAt({ startSecs: 10, endSecs: 40 }, 121), 39.4)
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
    HeroTrailer_settled(s, "s1") ' the delay passed and it plays
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

' Issue #186: the start waits out a 2 s delay (and on Roku a theme song), so a
' quick series -> episode arrives while nothing is playing yet. The pending
' start must be handed over, not counted as already played and stopped.
sub testPendingStartHandsOff(t as object)
    s = HeroTrailer_newOwners()
    d = HeroTrailer_appeared(s, "series", "s1", "")
    eq(t, "series schedules a start", d.kind, "start")
    d = HeroTrailer_appeared(s, "episode", "s1", "")
    eq(t, "episode inside the delay takes the pending start", d.kind, "handOff")
    eq(t, "and hands over the series' source", d.sourceId, "s1")
    eq(t, "the episode is top", HeroTrailer_topOwner(s), "episode")
    ' Back to the series before it starts: the pending start comes back too.
    d = HeroTrailer_dismissed(s, "episode", "")
    eq(t, "back inside the delay keeps the pending start", d.kind, "handOff")
    ' Go to Series from an episode screen, same show.
    d = HeroTrailer_appeared(s, "series2", "s1", "")
    eq(t, "Go to Series inside the delay hands off", d.kind, "handOff")

    ' Still waiting for the theme song to end: same rule, nothing has played.
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "series", "s1", "")
    d = HeroTrailer_appeared(s, "season", "s1", "")
    eq(t, "a hand-off while waiting for the theme keeps the start", d.kind, "handOff")

    ' Once it plays, the playing source carries hand-offs; after it ends,
    ' the same show doesn't replay.
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "series", "s1", "")
    HeroTrailer_settled(s, "s1")
    d = HeroTrailer_appeared(s, "episode", "s1", "s1")
    eq(t, "playing trailer still hands off", d.kind, "handOff")
    d = HeroTrailer_appeared(s, "episode2", "s1", "")
    eq(t, "a started-then-finished trailer does not replay", d.kind, "stop")

    ' A pending start that gave up (no trailer, failed stream) is not handed on.
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "series", "s1", "")
    HeroTrailer_settled(s, "s1")
    d = HeroTrailer_appeared(s, "episode", "s1", "")
    eq(t, "a start that gave up is not handed off", d.kind, "stop")

    ' A stop cancels the pending start: nothing to hand over afterwards.
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "series", "s1", "")
    HeroTrailer_appeared(s, "person", "", "")
    d = HeroTrailer_appeared(s, "episode", "s1", "")
    eq(t, "a stopped pending start is not handed off", d.kind, "stop")
    ' Another title's start replaces the pending one.
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "series", "s1", "")
    HeroTrailer_appeared(s, "movie", "m2", "")
    HeroTrailer_settled(s, "s1")
    d = HeroTrailer_appeared(s, "movie2", "m2", "")
    eq(t, "a stale settle leaves the newer pending start", d.kind, "handOff")
    HeroTrailer_dismissed(s, "movie2", "")
    d = HeroTrailer_dismissed(s, "movie", "")
    eq(t, "back to the series after another title stops", d.kind, "stop")
    ' The stack emptying ends the visit and its pending start.
    s = HeroTrailer_newOwners()
    HeroTrailer_appeared(s, "series", "s1", "")
    HeroTrailer_dismissed(s, "series", "")
    d = HeroTrailer_appeared(s, "series", "s1", "")
    eq(t, "a new visit starts afresh", d.kind, "start")
end sub

' The hero fills ~55% of a 1080p screen and most local trailers are 1080p, so
' it asks for a 1920-wide, 8 Mbps transcode (it was 1280 / 4 Mbps when the
' hero was a small corner, and looked soft once it grew).
sub testStreamCaps(t as object)
    c = HeroTrailer_streamCaps()
    eq(t, "trailer width cap", c.maxWidth, 1920)
    eq(t, "trailer bitrate cap", c.maxBitrate, 8000000)
end sub

sub testShouldPrepare(t as object)
    ' A trailer following the theme readies its stream 8 s before the end.
    eq(t, "theme length unknown: wait", HeroTrailer_shouldPrepare(-1), false)
    eq(t, "no theme figure at all: wait", HeroTrailer_shouldPrepare(invalid), false)
    eq(t, "well before the end: wait", HeroTrailer_shouldPrepare(25.0), false)
    eq(t, "just outside the lead: wait", HeroTrailer_shouldPrepare(8.5), false)
    eq(t, "at the lead: prepare", HeroTrailer_shouldPrepare(8.0), true)
    eq(t, "inside the lead: prepare", HeroTrailer_shouldPrepare(3.2), true)
    eq(t, "at the very end: prepare", HeroTrailer_shouldPrepare(0), true)
end sub
