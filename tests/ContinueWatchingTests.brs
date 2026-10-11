' Off-device tests for source/utils/ContinueWatching.bs, run by tests/run.js
' against the transpiled module (out/source/utils/ContinueWatching.brs). Data
' is from the live server row that showed each bug.

sub main()
    t = { passed: 0, failed: 0 }

    testBingedShowLeads(t)
    testJustStoppedEpisodeLeads(t)
    testFoldersDropped(t)
    testSeriesLastPlayed(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": got "; actual; " expected "; expected
    end if
end sub

function item(id as string, series as dynamic, played as dynamic, kind = "Episode" as string) as object
    data = {}
    if played <> invalid then data.LastPlayedDate = played
    it = { Id: id, Type: kind, UserData: data }
    if series <> invalid then it.SeriesId = series
    return it
end function

function ids(items as object) as string
    out = ""
    for each it in items
        if out <> "" then out = out + ","
        out = out + it.Id
    end for
    return out
end function

' 2026-10-10: The 100 binged all evening (S4E10 finished 20:53), its next
' episode unstarted and undated; a YouTube video stopped part-way the night
' before. Next Up lists The 100 first, behind... nothing: it must lead.
sub testBingedShowLeads(t as object)
    resume = [
        item("exploring-video", "exploring", "2026-10-10T02:03:13.3005753Z")
        item("gcn-video", "gcn", "2026-10-09T19:56:00.6602802Z")
    ]
    nextUp = [
        item("the100-s4e11", "the100", invalid)
        item("gcn-video", "gcn", "2026-10-09T19:56:00.6602802Z")
        item("insidejob-e2", "insidejob", invalid)
    ]
    dates = ContinueWatching_seriesLastPlayed([item("the100-s4e10", "the100", "2026-10-10T20:53:32.3531451Z")])
    eq(t, "binged show leads", ids(ContinueWatching_merge(resume, nextUp, dates)), "the100-s4e11,exploring-video,gcn-video,insidejob-e2")
end sub

' 2026-10-07: a video stopped part-way at 18:52 (Resume) and unstarted Next Up
' episodes, the first of another show, one the same channel's next video.
sub testJustStoppedEpisodeLeads(t as object)
    resume = [item("syd-ride", "syd", "2026-10-07T18:52:58.97Z")]
    nextUp = [
        item("insidejob-clone", "insidejob", invalid)
        item("syd-gravel", "syd", invalid)
    ]
    row = ids(ContinueWatching_merge(resume, nextUp, {}))
    eq(t, "just-stopped episode leads", row, "syd-ride,insidejob-clone")
end sub

sub testFoldersDropped(t as object)
    resume = [
        item("season-1", invalid, "2026-09-23T20:00:00Z", "Season")
        item("ep-1", "s", "2026-09-23T19:00:00Z")
        item("series-1", invalid, "2026-09-23T18:00:00Z", "Series")
        item("movie-1", invalid, "2026-09-23T17:00:00Z", "Movie")
    ]
    eq(t, "folders never reach the row", ids(ContinueWatching_merge(resume, [], {})), "ep-1,movie-1")
end sub

sub testSeriesLastPlayed(t as object)
    dates = ContinueWatching_seriesLastPlayed([
        item("a1", "a", "2026-10-01T00:00:00Z")
        item("a2", "a", "2026-10-02T00:00:00Z")
        item("b1", invalid, "2026-10-03T00:00:00Z")
        item("c1", "c", invalid)
    ])
    eq(t, "one entry per dated series", dates.Count(), 1)
    eq(t, "newest episode wins", dates["a"], ContinueWatching_isoSeconds("2026-10-02T00:00:00Z"))
end sub
