' Off-device tests for source/utils/WatchState.bs, run by tests/run.js against
' the transpiled module (out/source/utils/WatchState.brs): the played routes
' and their fall-back rule, when a detail screen's watched state is stale, and
' how a re-read episode list is applied to the row on screen.

sub main()
    t = { passed: 0, failed: 0 }

    testPlayedPaths(t)
    testShouldTryLegacy(t)
    testIsStale(t)
    testEpisodePlan(t)
    testReturnScenario(t)

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

function ep(id as string, played as boolean, pct as float, ticks as dynamic) as object
    return { Id: id, UserData: { Played: played, PlayedPercentage: pct, PlaybackPositionTicks: ticks } }
end function

function joined(list as object) as string
    s = ""
    for each v in list
        if s <> "" then s = s + ","
        s = s + v.ToStr()
    end for
    return s
end function

sub testPlayedPaths(t as object)
    p = WatchState_playedPaths("u1", "s9")
    eq(t, "two routes", p.count(), 2)
    eq(t, "modern route first", p[0], "/UserPlayedItems/s9?userId=u1")
    eq(t, "legacy route second", p[1], "/Users/u1/PlayedItems/s9")
end sub

sub testShouldTryLegacy(t as object)
    eq(t, "404 = route missing", WatchState_shouldTryLegacy(404), true)
    eq(t, "405 = verb not mapped", WatchState_shouldTryLegacy(405), true)
    eq(t, "200 is the answer", WatchState_shouldTryLegacy(200), false)
    eq(t, "204 is the answer", WatchState_shouldTryLegacy(204), false)
    eq(t, "401 is the answer", WatchState_shouldTryLegacy(401), false)
    eq(t, "500 is the answer", WatchState_shouldTryLegacy(500), false)
    eq(t, "timeout is not retried", WatchState_shouldTryLegacy(0), false)
    eq(t, "never sent is not retried", WatchState_shouldTryLegacy(-1), false)
end sub

sub testIsStale(t as object)
    eq(t, "same version", WatchState_isStale(3, 3), false)
    eq(t, "a write since", WatchState_isStale(3, 4), true)
    eq(t, "never recorded", WatchState_isStale(invalid, 0), true)
    eq(t, "no global yet", WatchState_isStale(2, invalid), false)
end sub

sub testEpisodePlan(t as object)
    shown = [ep("a", false, 0, 0), ep("b", false, 0, 0), ep("c", false, 0, 0)]

    p = WatchState_episodePlan(shown, [ep("a", false, 0, 0), ep("b", true, 0, 0), ep("c", false, 0, 0)])
    eq(t, "same list patches", p.mode, "patch")
    eq(t, "only the marked episode", joined(p.indices), "1")

    p = WatchState_episodePlan(shown, [ep("a", false, 0, 0), ep("b", false, 0, 0), ep("c", false, 42.5, 12345678901&)])
    eq(t, "progress counts", joined(p.indices), "2")

    p = WatchState_episodePlan([ep("a", false, 50, 600&)], [ep("a", false, 50, 900&)])
    eq(t, "a moved resume point counts", joined(p.indices), "0")

    p = WatchState_episodePlan(shown, [ep("a", false, 0, 0), ep("b", false, 0, 0), ep("c", false, 0, 0)])
    eq(t, "nothing changed patches nothing", p.mode + ":" + joined(p.indices), "patch:")

    p = WatchState_episodePlan(shown, [ep("a", false, 0, 0), ep("b", false, 0, 0)])
    eq(t, "fewer episodes rebuilds", p.mode, "rebuild")

    p = WatchState_episodePlan(shown, [ep("a", false, 0, 0), ep("c", false, 0, 0), ep("b", false, 0, 0)])
    eq(t, "reordered rebuilds", p.mode, "rebuild")

    p = WatchState_episodePlan([], [ep("a", true, 0, 0)])
    eq(t, "first episodes rebuild", p.mode, "rebuild")

    ' getEpisodes answers a failed fetch with success and no items.
    p = WatchState_episodePlan(shown, [])
    eq(t, "empty answer keeps the row", p.mode, "keep")
    p = WatchState_episodePlan(shown, invalid)
    eq(t, "no answer keeps the row", p.mode, "keep")

    ' Episodes missing UserData read as unwatched, no progress.
    p = WatchState_episodePlan([{ Id: "a" }], [ep("a", false, 0, 0)])
    eq(t, "missing UserData = unwatched", joined(p.indices), "")
    p = WatchState_episodePlan([{ Id: "a" }], [ep("a", true, 0, 0)])
    eq(t, "missing UserData then played", joined(p.indices), "0")
end sub

' The tester's report: mark S1:E2 watched on its own page, back to the series.
sub testReturnScenario(t as object)
    seen = 0
    version = 0
    ' Episode page's Mark Watched answers: the series screen beneath is stale.
    version = version + 1
    eq(t, "series page is stale on return", WatchState_isStale(seen, version), true)
    shown = [ep("e1", true, 0, 0), ep("e2", false, 0, 0), ep("e3", false, 0, 0)]
    fresh = [ep("e1", true, 0, 0), ep("e2", true, 0, 0), ep("e3", false, 0, 0)]
    p = WatchState_episodePlan(shown, fresh)
    eq(t, "E2's card is patched in place", p.mode + ":" + joined(p.indices), "patch:1")
    eq(t, "and reads watched", WatchState_played(fresh[1]), true)
    seen = version
    eq(t, "then up to date", WatchState_isStale(seen, version), false)
end sub
