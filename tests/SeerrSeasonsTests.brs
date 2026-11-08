' Off-device tests for source/utils/SeerrSeasons.bs (the season picker), the
' Apple app's SeerrSeasonPlanTests vectors: which seasons start ticked, which
' can't be picked, and what gets sent.

sub main()
    t = { passed: 0, failed: 0 }

    testDefaults(t)
    testServerRun(t)
    testToggle(t)
    testUnaired(t)
    testAlreadyRequested(t)
    testWholeShow(t)
    testNothingMissing(t)

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

function joined(list as object) as string
    s = ""
    for each v in list
        if s <> "" then s = s + ","
        if type(v) = "roString" or type(v) = "String" then s = s + v else s = s + Str(v).Trim()
    end for
    return s
end function

function nowSecs() as integer
    return Seerr_parseDate("2026-11-06T12:00:00.000Z")
end function

' seasons: [[number, episodes, airDate]], statuses: { "<n>": status }
function show(seasons as object, statuses as object, requests = invalid as dynamic) as object
    list = []
    for each s in seasons
        list.push({ seasonNumber: s[0], episodeCount: s[1], airDate: s[2] })
    end for
    st = []
    for each k in statuses
        st.push({ seasonNumber: Val(k), status: statuses[k] })
    end for
    info = { status: 4, seasons: st }
    if requests <> invalid then info.requests = requests
    return Seerr_details({ id: 1, name: "Love Is Blind", seasons: list, mediaInfo: info })
end function

function loveIsBlind() as object
    seasons = [[0, 3, "2020-01-01"]]
    onServer = {}
    for n = 1 to 9
        seasons.push([n, 10, "2020-02-13"])
        onServer[Str(n).Trim()] = 5
    end for
    seasons.push([10, 12, "2026-03-01"])
    seasons.push([11, 10, "2026-10-01"])
    return show(seasons, onServer)
end function

function titles(rows as object) as string
    out = []
    for each r in rows
        out.push(r.title)
    end for
    return joined(out)
end function

function details(rows as object) as string
    out = []
    for each r in rows
        out.push(r.detail)
    end for
    return joined(out)
end function

sub testDefaults(t as object)
    p = SeerrSeasons_plan(loveIsBlind(), nowSecs())
    eq(t, "ticked: every season not on the server", joined(SeerrSeasons_requestSeasons(p)), "10,11")
    eq(t, "missing", joined(SeerrSeasons_missing(p)), "10,11")
    specials = false
    for each s in p.seasons
        if s.number = 0 then specials = true
    end for
    eq(t, "never specials", specials, false)
    eq(t, "button", SeerrSeasons_buttonTitle(p), "Request 2 seasons")
    eq(t, "all missing selected", SeerrSeasons_allMissingSelected(p), true)
end sub

sub testServerRun(t as object)
    rows = SeerrSeasons_rows(SeerrSeasons_plan(loveIsBlind(), nowSecs()))
    eq(t, "server seasons collapse", titles(rows), "Seasons 1" + Chr(8211) + "9,Season 10,Season 11")
    eq(t, "run can't be picked", rows[0].pickable, false)
    eq(t, "run detail", rows[0].detail, "On server")
    eq(t, "episodes", rows[1].detail, "12 episodes")
end sub

sub testToggle(t as object)
    p = SeerrSeasons_plan(loveIsBlind(), nowSecs())
    p = SeerrSeasons_toggle(p, 11)
    eq(t, "unticked", joined(SeerrSeasons_requestSeasons(p)), "10")
    eq(t, "not all", SeerrSeasons_allMissingSelected(p), false)
    eq(t, "one season", SeerrSeasons_buttonTitle(p), "Request 1 season")
    p = SeerrSeasons_toggle(p, 5)
    eq(t, "a season on the server can't be ticked", joined(SeerrSeasons_requestSeasons(p)), "10")
    p = SeerrSeasons_setAllMissing(p, true)
    eq(t, "all missing", joined(SeerrSeasons_requestSeasons(p)), "10,11")
    p = SeerrSeasons_setAllMissing(p, false)
    eq(t, "none", SeerrSeasons_requestSeasons(p).count(), 0)
    eq(t, "nothing to send", Seerr_showRequestBody(1, SeerrSeasons_requestSeasons(p)) = invalid, true)
end sub

sub testUnaired(t as object)
    p = SeerrSeasons_plan(show([[1, 6, "2024-11-17"], [2, 0, ""], [3, 8, "2027-05-01"]], {}), nowSecs())
    eq(t, "only the aired one ticked", joined(SeerrSeasons_requestSeasons(p)), "1")
    rows = SeerrSeasons_rows(p)
    eq(t, "details", details(rows), "6 episodes,Not aired,Not aired")
    eq(t, "unaired can be picked", rows[1].pickable, true)
    eq(t, "button", SeerrSeasons_buttonTitle(p), "Request 1 season")
end sub

sub testAlreadyRequested(t as object)
    pending = { id: 9, status: 1, seasons: [{ seasonNumber: 2, status: 1 }] }
    declined = { id: 10, status: 3, seasons: [{ seasonNumber: 3, status: 3 }] }
    d = show([[1, 6, "2020-01-01"], [2, 6, "2021-01-01"], [3, 6, "2022-01-01"], [4, 6, "2023-01-01"]], { "4": 3 }, [pending, declined])
    p = SeerrSeasons_plan(d, nowSecs())
    eq(t, "a declined season can be asked for again", joined(SeerrSeasons_requestSeasons(p)), "1,3")
    rows = SeerrSeasons_rows(p)
    eq(t, "details", details(rows), "6 episodes,Requested,6 episodes,Requested")
    eq(t, "requested can't be picked", rows[1].pickable, false)
end sub

sub testWholeShow(t as object)
    p = SeerrSeasons_plan(loveIsBlind(), nowSecs(), false)
    p = SeerrSeasons_toggle(p, 10)
    eq(t, "every missing season goes together", joined(SeerrSeasons_requestSeasons(p)), "10,11")
    eq(t, "rows can't be picked one by one", SeerrSeasons_rows(p)[1].pickable, false)
end sub

sub testNothingMissing(t as object)
    p = SeerrSeasons_plan(show([[1, 6, "2020-01-01"]], { "1": 5 }), nowSecs())
    eq(t, "nothing missing", SeerrSeasons_hasMissing(p), false)
    eq(t, "nothing ticked", SeerrSeasons_requestSeasons(p).count(), 0)
    eq(t, "row ticked state", SeerrSeasons_rowSelected(p, SeerrSeasons_rows(p)[0]), false)
end sub
