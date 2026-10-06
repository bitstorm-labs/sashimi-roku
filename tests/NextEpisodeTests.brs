' Off-device tests for source/utils/NextEpisode.bs, run by tests/run.js against the
' transpiled module (out/source/utils/NextEpisode.brs): which episode comes next
' (rolling over seasons), the countdown/Skip/Cancel state machine, and what
' the Up Next screen shows in each case.

sub main()
    t = { passed: 0, failed: 0 }

    testQueueRollsOverSeasons(t)
    testQueueFiltersAndOrders(t)
    testQueueEdgeCases(t)
    testOffersNext(t)
    testInitialState(t)
    testCountdown(t)
    testSkip(t)
    testCancelAndPlay(t)
    testScreenText(t)
    testCreditsSkip(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else if (type(actual) = "Integer" or type(actual) = "roInt" or type(actual) = "roInteger") and (type(expected) = "Integer" or type(expected) = "roInt" or type(expected) = "roInteger") and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub

function ep(id as string, season as dynamic, index as dynamic) as object
    e = { Id: id, Type: "Episode", SeriesId: "series", SeasonId: "season" + Str(season).Trim(), Name: "Episode " + id }
    if season <> invalid then e.ParentIndexNumber = season
    if index <> invalid then e.IndexNumber = index
    return e
end function

function ids(list as object) as string
    out = ""
    for each e in list
        if out <> "" then out = out + ","
        out = out + e.Id
    end for
    return out
end function

sub testQueueRollsOverSeasons(t as object)
    ' The season finale is followed by the next season's premiere -- the old
    ' season-only lookup ended the binge here.
    items = [ep("s1e9", 1, 9), ep("s1e10", 1, 10), ep("s2e1", 2, 1), ep("s2e2", 2, 2)]
    eq(t, "finale rolls into next season", ids(NextEpisode_queueAfter(items, ep("s1e10", 1, 10))), "s2e1,s2e2")
    eq(t, "mid-season continues in order", ids(NextEpisode_queueAfter(items, ep("s1e9", 1, 9))), "s1e10,s2e1,s2e2")
    eq(t, "last episode of the series has nothing after", NextEpisode_queueAfter(items, ep("s2e2", 2, 2)).count(), 0)
end sub

sub testQueueFiltersAndOrders(t as object)
    ' Server order is not trusted: the season-sibling fallback sorts by index
    ' only, and a gap (E3 missing) still leads to the next one that exists.
    items = [ep("s2e1", 2, 1), ep("s1e5", 1, 5), ep("s1e2", 1, 2), ep("s1e1", 1, 1)]
    eq(t, "sorted by season then episode", ids(NextEpisode_queueAfter(items, ep("s1e1", 1, 1))), "s1e2,s1e5,s2e1")

    ' Specials are not part of the run when the viewer is in a real season.
    items = [ep("sp1", 0, 1), ep("s1e1", 1, 1), ep("s1e2", 1, 2)]
    eq(t, "specials skipped", ids(NextEpisode_queueAfter(items, ep("s1e1", 1, 1))), "s1e2")
    ' ...but a viewer working through the specials gets the next special.
    items = [ep("sp1", 0, 1), ep("sp2", 0, 2), ep("s1e1", 1, 1)]
    eq(t, "special to special", ids(NextEpisode_queueAfter(items, ep("sp1", 0, 1))), "sp2,s1e1")

    ' The answer may include the finished episode and a second version of it.
    items = [ep("s1e1", 1, 1), ep("s1e1-4k", 1, 1), ep("s1e2", 1, 2), ep("s1e2-4k", 1, 2), ep("s1e3", 1, 3)]
    eq(t, "current and its duplicates dropped, one per episode", ids(NextEpisode_queueAfter(items, ep("s1e1", 1, 1))), "s1e2,s1e3")

    ' A double episode E1-E2 is followed by E3.
    dbl = ep("s1e1-2", 1, 1)
    dbl.IndexNumberEnd = 2
    items = [dbl, ep("s1e2", 1, 2), ep("s1e3", 1, 3)]
    eq(t, "double episode skips its second half", ids(NextEpisode_queueAfter(items, dbl)), "s1e3")

    ' Items with no episode number cannot be ordered and are left out.
    items = [ep("s1e2", 1, 2), ep("noidx", 1, invalid)]
    eq(t, "unnumbered items ignored", ids(NextEpisode_queueAfter(items, ep("s1e1", 1, 1))), "s1e2")
end sub

sub testQueueEdgeCases(t as object)
    eq(t, "invalid items", NextEpisode_queueAfter(invalid, ep("a", 1, 1)).count(), 0)
    eq(t, "invalid current", NextEpisode_queueAfter([ep("a", 1, 1)], invalid).count(), 0)
    eq(t, "current without index", NextEpisode_queueAfter([ep("b", 1, 2)], ep("a", 1, invalid)).count(), 0)
    ' No season numbers anywhere (some YouTube-style libraries): order within
    ' the finished episode's own season, as the old lookup did.
    a = { Id: "a", IndexNumber: 1, SeasonId: "x" }
    b = { Id: "b", IndexNumber: 2, SeasonId: "x" }
    c = { Id: "c", IndexNumber: 3, SeasonId: "y" }
    eq(t, "no season numbers: same SeasonId only", ids(NextEpisode_queueAfter([c, b, a], a)), "b")
end sub

sub testOffersNext(t as object)
    eq(t, "episode offers next", NextEpisode_offersNext(ep("a", 1, 1), false), true)
    eq(t, "channel never does", NextEpisode_offersNext(ep("a", 1, 1), true), false)
    eq(t, "movie does not", NextEpisode_offersNext({ Id: "m", Type: "Movie" }, false), false)
    eq(t, "episode with no series or season does not", NextEpisode_offersNext({ Id: "e", Type: "Episode" }, false), false)
    eq(t, "season only is enough", NextEpisode_offersNext({ Id: "e", Type: "Episode", SeasonId: "s" }, false), true)
    eq(t, "invalid item", NextEpisode_offersNext(invalid, false), false)
end sub

sub testInitialState(t as object)
    q = [ep("b", 1, 2), ep("c", 1, 3)]
    s = NextEpisode_initialState(q, true, true)
    eq(t, "autoplay on: countdown", s.mode, "countdown")
    eq(t, "autoplay on: ten seconds", s.remaining, 10)
    eq(t, "autoplay on: first in queue", s.index, 0)
    s = NextEpisode_initialState(q, false, true)
    eq(t, "autoplay off: same screen, no countdown", s.mode, "manual")
    eq(t, "autoplay off: nothing counting", s.remaining, 0)
    eq(t, "autoplay off: tick never plays", NextEpisode_tick(s), "")
    s = NextEpisode_initialState([], true, true)
    eq(t, "nothing next: ended", s.mode, "ended")
    eq(t, "nothing next: final", s.reason, "final")
    s = NextEpisode_initialState(invalid, true, false)
    eq(t, "lookup failed: ended", s.mode, "ended")
    eq(t, "lookup failed: failed", s.reason, "failed")
    ' A failed lookup is not "the last episode", even with an empty queue.
    s = NextEpisode_initialState([], false, false)
    eq(t, "failed beats final", s.reason, "failed")
end sub

sub testCountdown(t as object)
    s = NextEpisode_initialState([ep("b", 1, 2)], true, true)
    plays = 0
    ticksToPlay = 0
    for i = 1 to 15
        if NextEpisode_tick(s) = "play"
            plays = plays + 1
            if ticksToPlay = 0 then ticksToPlay = i
        end if
    end for
    eq(t, "plays after exactly ten ticks", ticksToPlay, 10)
    eq(t, "plays exactly once", plays, 1)
    eq(t, "leaves countdown once playing", s.mode, "starting")

    s = NextEpisode_initialState([ep("b", 1, 2)], true, true)
    NextEpisode_tick(s)
    NextEpisode_tick(s)
    eq(t, "remaining counts down", s.remaining, 8)
    eq(t, "label shows remaining seconds", NextEpisode_label("play", s), "Play in 8")
end sub

sub testSkip(t as object)
    q = [ep("b", 1, 2), ep("c", 1, 3), ep("d", 2, 1)]
    s = NextEpisode_initialState(q, true, true)
    for i = 1 to 6
        NextEpisode_tick(s)
    end for
    eq(t, "skip allowed with more after", NextEpisode_canSkip(s), true)
    eq(t, "skip happens", NextEpisode_skip(s), true)
    eq(t, "skip shows the next one", s.index, 1)
    eq(t, "skip restarts the countdown", s.remaining, 10)
    eq(t, "skip focus stays on Skip", NextEpisode_focusAfterSkip(s), 1)
    eq(t, "skip again", NextEpisode_skip(s), true)
    eq(t, "repeatable, across a season", s.index, 2)
    eq(t, "no more to skip to", NextEpisode_canSkip(s), false)
    eq(t, "Skip button hidden", Instr(1, joined(NextEpisode_buttons(s)), "skip"), 0)
    eq(t, "focus falls back to Play, not Cancel", NextEpisode_focusAfterSkip(s), 0)
    eq(t, "skip past the end refused", NextEpisode_skip(s), false)
    eq(t, "index unchanged", s.index, 2)

    s = NextEpisode_initialState(q, false, true)
    NextEpisode_skip(s)
    eq(t, "manual skip keeps no countdown", s.remaining, 0)
    eq(t, "manual skip stays manual", s.mode, "manual")
    eq(t, "single next: no Skip", joined(NextEpisode_buttons(NextEpisode_initialState([ep("b", 1, 2)], true, true))), "play,cancel")
end sub

sub testCancelAndPlay(t as object)
    s = NextEpisode_initialState([ep("b", 1, 2), ep("c", 1, 3)], true, true)
    eq(t, "offering buttons", joined(NextEpisode_buttons(s)), "play,skip,cancel")
    eq(t, "cancel", NextEpisode_cancel(s), true)
    eq(t, "cancel ends", s.mode, "ended")
    eq(t, "cancel reason", s.reason, "cancelled")
    eq(t, "cancel stops the countdown", NextEpisode_tick(s), "")
    eq(t, "end options", joined(NextEpisode_buttons(s)), "replay,back")
    eq(t, "no skip after cancel", NextEpisode_skip(s), false)
    eq(t, "no play after cancel", NextEpisode_play(s), false)
    eq(t, "cancel twice is a no-op", NextEpisode_cancel(s), false)

    s = NextEpisode_initialState([ep("b", 1, 2)], true, true)
    eq(t, "play by hand", NextEpisode_play(s), true)
    eq(t, "play by hand stops the countdown", NextEpisode_tick(s), "")
    eq(t, "play only once", NextEpisode_play(s), false)

    eq(t, "final: end options", joined(NextEpisode_buttons(NextEpisode_initialState([], true, true))), "replay,back")
    eq(t, "failed: end options", joined(NextEpisode_buttons(NextEpisode_initialState(invalid, true, false))), "replay,back")
end sub

sub testScreenText(t as object)
    s = NextEpisode_initialState([ep("b", 1, 2)], false, true)
    eq(t, "eyebrow offering", NextEpisode_eyebrow(s), "UP NEXT")
    eq(t, "manual Play label", NextEpisode_label("play", s), "Play")
    eq(t, "no message while offering", NextEpisode_message(s), "")
    eq(t, "final message", NextEpisode_message(NextEpisode_initialState([], true, true)), "There are no more episodes.")
    eq(t, "failed message", Instr(1, NextEpisode_message(NextEpisode_initialState(invalid, true, false)), "unavailable") > 0, true)
    c = NextEpisode_initialState([ep("b", 1, 2)], true, true)
    NextEpisode_cancel(c)
    eq(t, "cancelled: no message", NextEpisode_message(c), "")
    eq(t, "cancelled eyebrow", NextEpisode_eyebrow(c), "EPISODE COMPLETE")

    e = ep("x", 2, 5)
    e.Name = "The Rains"
    eq(t, "heading", NextEpisode_heading(e), "S2:E5 " + Chr(8226) + " The Rains")
    d = ep("y", 1, 1)
    d.IndexNumberEnd = 2
    d.Name = "Pilot"
    eq(t, "double heading", NextEpisode_heading(d), "S1:E1-2 " + Chr(8226) + " Pilot")
    eq(t, "heading without numbers", NextEpisode_heading({ Name: "Special" }), "Special")
    eq(t, "runtime", NextEpisode_runtimeLabel(25200000000&), "42 min")
    eq(t, "runtime missing", NextEpisode_runtimeLabel(invalid), "")
    eq(t, "runtime zero", NextEpisode_runtimeLabel(0), "")
    eq(t, "rating one decimal", NextEpisode_ratingLabel(7.86), "7.8")
    eq(t, "rating whole", NextEpisode_ratingLabel(8), "8")
    eq(t, "rating missing", NextEpisode_ratingLabel(invalid), "")
end sub

sub testCreditsSkip(t as object)
    eq(t, "credits to the end finish", NextEpisode_creditsSkipEndsPlayback(2580, 2600), true)
    eq(t, "credits exactly at the end", NextEpisode_creditsSkipEndsPlayback(2600, 2600), true)
    eq(t, "post-credits scene still seeks", NextEpisode_creditsSkipEndsPlayback(2400, 2600), false)
    eq(t, "unknown duration seeks", NextEpisode_creditsSkipEndsPlayback(2400, 0), false)
    eq(t, "invalid", NextEpisode_creditsSkipEndsPlayback(invalid, 2600), false)
end sub

function joined(list as object) as string
    out = ""
    for each x in list
        if out <> "" then out = out + ","
        out = out + x
    end for
    return out
end function
