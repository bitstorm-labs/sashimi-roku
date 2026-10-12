' Off-device tests for source/utils/ContinueWatching.bs, run by tests/run.js
' against the transpiled module (out/source/utils/ContinueWatching.brs). Data
' is from the live server row that showed each bug.

sub main()
    t = { passed: 0, failed: 0 }

    testBingedShowLeads(t)
    testJustStoppedEpisodeLeads(t)
    testFoldersDropped(t)
    testSeriesLastPlayed(t)
    testStaleNextUpDateUsesSeries(t)
    testServerRowRequest(t)
    testServerRowAnswer(t)

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

' 2026-10-12: The 100's next episode had been opened weeks ago, so it carried
' that stale date while the season before it was binged, and sank to the end.
' A Next Up item ranks by the newer of its own date and its series' last watch.
sub testStaleNextUpDateUsesSeries(t as object)
    resume = [
        item("gcn-video", "gcn", "2026-10-12T01:12:39.5072017Z")
        item("exploring-video", "exploring", "2026-10-10T02:03:13.3005753Z")
        item("sabrina-e2", "sabrina", "2026-10-01T17:35:26.9334059Z")
        item("the100-s1e13", "the100", "2026-09-22T01:32:59.8909118Z")
    ]
    nextUp = [
        item("the100-s5e1", "the100", "2026-09-22T02:11:50.7976901Z")
        item("gcn-video", "gcn", "2026-10-12T01:12:39.5072017Z")
        item("darkmatter-s2e5", "darkmatter", "2026-10-02T18:13:24.3329621Z")
    ]
    dates = ContinueWatching_seriesLastPlayed([
        item("the100-s4e13", "the100", "2026-10-12T05:41:17.0124389Z")
        item("gcn-old", "gcn", "2026-10-12T01:05:36.656826Z")
    ])
    eq(t, "stale next-up date uses series", ids(ContinueWatching_merge(resume, nextUp, dates)), "the100-s5e1,gcn-video,exploring-video,darkmatter-s2e5,sabrina-e2")
end sub

' The server's Continue Watching plugin: the request asks for this user's row with
' the same fields and images as Resume, so the cards render identically.
sub testServerRowRequest(t as object)
    path = ContinueWatching_serverRowPath("u1", 20)
    eq(t, "server row path", Left(path, 30), "/ContinueWatching?userId=u1&li")
    eq(t, "server row limit", Instr(1, path, "&limit=20&") > 0, true)
    eq(t, "server row user data", Instr(1, path, "UserData") > 0, true)
    eq(t, "server row images", Instr(1, path, "&enableImageTypes=Primary,Backdrop,Thumb") > 0, true)
end sub

' A usable answer is used as-is; no answer (plugin absent: 404 -> invalid) or a
' malformed one sends the caller to its own merge.
sub testServerRowAnswer(t as object)
    eq(t, "server row items", ids(ContinueWatching_serverRowItems({ Items: [item("the100-s5e1", "the100", invalid), item("gcn", "gcn", invalid)] })), "the100-s5e1,gcn")
    eq(t, "no plugin", type(ContinueWatching_serverRowItems(invalid)), "Invalid")
    eq(t, "malformed answer", type(ContinueWatching_serverRowItems({ Error: "x" })), "Invalid")
    eq(t, "empty row is still an answer", ContinueWatching_serverRowItems({ Items: [] }).count(), 0)
end sub
