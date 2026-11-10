' Off-device tests for source/utils/ListLayout.bs, run by tests/run.js. The
' Lists page's poster-stack covers and the Spotlight list page: the stack's
' layers for 0-3 posters and their fan on focus, the spotlight's meta line,
' backdrop, headline, the focused title's action, the button rows and where
' Up and Down go.

sub main()
    t = { passed: 0, failed: 0 }

    testStack(t)
    testStackFocus(t)
    testRuntime(t)
    testMetaLine(t)
    testMissingMeta(t)
    testBackdrop(t)
    testHeadline(t)
    testTitleAction(t)
    testListButtons(t)
    testWatchlistButtons(t)
    testZones(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else if isNum(actual) and isNum(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub

function isNum(v as dynamic) as boolean
    k = type(v)
    return k = "Integer" or k = "roInt" or k = "roInteger" or k = "Float" or k = "roFloat" or k = "Double" or k = "roDouble"
end function

function near(a as float, b as float) as boolean
    return Abs(a - b) < 0.0001
end function

function kinds(defs as object) as string
    out = ""
    for each d in defs
        if out <> "" then out = out + ","
        out = out + d.kind
    end for
    return out
end function

' ---------- Poster stack ----------

sub testStack(t as object)
    eq(t, "empty list: one placeholder layer", ListLayout_stackLayers(0, 0.0).count(), 1)
    eq(t, "empty list's layer is the placeholder", ListLayout_stackLayers(0, 0.0)[0].slot, 0)
    eq(t, "one title: one poster", ListLayout_stackLayers(1, 0.0).count(), 1)
    eq(t, "two titles: two", ListLayout_stackLayers(2, 0.0).count(), 2)
    eq(t, "three titles: three", ListLayout_stackLayers(3, 0.0).count(), 3)
    eq(t, "never more than three", ListLayout_stackLayers(9, 0.0).count(), 3)

    ' Back to front: the drawing order, so the first poster ends on top.
    three = ListLayout_stackLayers(3, 0.0)
    eq(t, "drawn back first", three[0].slot, 2)
    eq(t, "front drawn last", three[2].slot, 0)
    front = three[2]
    mid = three[1]
    back = three[0]
    eq(t, "front is sharp", front.opacity, 1.0)
    eq(t, "front is upright", front.rotation, 0.0)
    eq(t, "back is slightly faded", back.opacity < 1.0, true)
    eq(t, "middle is not faded", mid.opacity, 1.0)
    eq(t, "front is biggest", front.w > mid.w and mid.w > back.w, true)
    eq(t, "fanned to the right", front.x < mid.x and mid.x < back.x, true)
    ' About 3 and 7 degrees, clockwise (SceneGraph's positive is anticlockwise).
    eq(t, "middle about 3 degrees", near(mid.rotation, -3.0 * 3.14159265 / 180.0), true)
    eq(t, "back about 7 degrees", near(back.rotation, -7.0 * 3.14159265 / 180.0), true)
    eq(t, "posters keep 2:3", Abs(front.h - front.w * 1.5) <= 1, true)
    ' Every layer, rotated and fanned out, stays inside the 330-wide cell.
    for each l in ListLayout_stackLayers(3, 1.0)
        eq(t, "fits the cell (slot " + l.slot.ToStr() + ")", l.x >= 0 and l.x + l.w + l.h * 0.18 <= ListLayout_COVER_W(), true)
    end for
end sub

sub testStackFocus(t as object)
    rest = ListLayout_stackLayers(3, 0.0)
    fanned = ListLayout_stackLayers(3, 1.0)
    eq(t, "front stays put", fanned[2].x, rest[2].x)
    eq(t, "middle moves out", fanned[1].x > rest[1].x, true)
    eq(t, "back moves out further", fanned[0].x - rest[0].x > fanned[1].x - rest[1].x, true)
    eq(t, "back tilts more", fanned[0].rotation < rest[0].rotation, true)
    half = ListLayout_stackLayers(3, 0.5)
    eq(t, "half way is between", half[0].x > rest[0].x and half[0].x < fanned[0].x, true)
end sub

' ---------- Spotlight ----------

sub testRuntime(t as object)
    eq(t, "hours and minutes", ListLayout_runtime(11580 * 10000000&), "3h 13m")
    eq(t, "minutes only", ListLayout_runtime(47 * 60 * 10000000&), "47m")
    eq(t, "whole hours", ListLayout_runtime(2 * 3600 * 10000000&), "2h")
    eq(t, "nothing", ListLayout_runtime(invalid), "")
    eq(t, "zero", ListLayout_runtime(0), "")
end sub

sub testMetaLine(t as object)
    dot = " " + Chr(183) + " "
    movie = { Type: "Movie", ProductionYear: 1983, RunTimeTicks: 11580 * 10000000&, OfficialRating: "PG", Genres: ["Drama", "History", "Adventure"] }
    eq(t, "movie", ListLayout_metaLine(movie), "1983" + dot + "3h 13m" + dot + "PG" + dot + "Drama, History")
    show = { Type: "Series", ProductionYear: 2011, ChildCount: 3, OfficialRating: "TV-MA", Genres: ["Drama"], RunTimeTicks: 3000 * 10000000& }
    eq(t, "show: seasons, not a runtime", ListLayout_metaLine(show), "2011" + dot + "3 Seasons" + dot + "TV-MA" + dot + "Drama")
    eq(t, "one season", ListLayout_metaLine({ Type: "Series", ChildCount: 1 }), "1 Season")
    eq(t, "fields it lacks are left out", ListLayout_metaLine({ Type: "Movie", ProductionYear: 2001 }), "2001")
    eq(t, "nothing at all", ListLayout_metaLine({ Type: "Movie" }), "")
    eq(t, "not an object", ListLayout_metaLine(invalid), "")
    ep = { Type: "Episode", ParentIndexNumber: 2, IndexNumber: 4, Name: "Pilot", RunTimeTicks: 47 * 60 * 10000000& }
    eq(t, "an episode says which", ListLayout_metaLine(ep), "S2:E4" + dot + "Pilot" + dot + "47m")
end sub

sub testMissingMeta(t as object)
    dot = " " + Chr(183) + " "
    eq(t, "missing movie", ListLayout_missingMeta({ type: "Movie", year: 2025 }), "2025" + dot + "Movie")
    eq(t, "missing show", ListLayout_missingMeta({ type: "Series", year: -1 }), "Show")
end sub

sub testBackdrop(t as object)
    own = ListLayout_backdrop({ Id: "m1", BackdropImageTags: ["b1", "b2"] })
    eq(t, "own backdrop", own.id + ":" + own.tag, "m1:b1")
    ep = ListLayout_backdrop({ Id: "e1", Type: "Episode", BackdropImageTags: [], ParentBackdropItemId: "s1", ParentBackdropImageTags: ["sb"] })
    eq(t, "an episode borrows its show's", ep.id + ":" + ep.tag, "s1:sb")
    eq(t, "none", ListLayout_backdrop({ Id: "x" }), invalid)
    eq(t, "not an object", ListLayout_backdrop(invalid), invalid)
end sub

sub testHeadline(t as object)
    dot = " " + Chr(183) + " "
    eq(t, "headline", ListLayout_headline("Watchlist", "8 titles"), "WATCHLIST" + dot + "8 titles")
    eq(t, "no line", ListLayout_headline("Mine", ""), "MINE")
    eq(t, "your own list", ListLayout_listLine(true, "Marge", "3 titles"), "3 titles")
    eq(t, "someone else's says whose", ListLayout_listLine(false, "Marge", "3 titles"), "By Marge" + dot + "3 titles")
    eq(t, "nobody to name", ListLayout_listLine(false, "", "3 titles"), "3 titles")
end sub

sub testTitleAction(t as object)
    movie = { Id: "m1", Type: "Movie", UserData: { PlaybackPositionTicks: 0 } }
    eq(t, "a movie plays", ListLayout_titleAction({ item: movie }).kind, "play")
    eq(t, "Play", ListLayout_titleAction({ item: movie }).label, "Play")
    started = { Id: "m1", Type: "Movie", UserData: { PlaybackPositionTicks: 600000000 } }
    eq(t, "a started movie resumes", ListLayout_titleAction({ item: started }).kind, "resume")
    eq(t, "Resume", ListLayout_titleAction({ item: started }).label, "Resume")
    eq(t, "a show plays its next episode", ListLayout_titleAction({ item: { Id: "s1", Type: "Series" } }).kind, "playSeries")
    eq(t, "no user data plays", ListLayout_titleAction({ item: { Id: "m2", Type: "Movie" } }).kind, "play")

    missing = { type: "Movie", tmdbId: "12", itemId: "" }
    eq(t, "signed in: Request", ListLayout_titleAction({ entry: missing, seerrActive: true, requested: false }).kind, "request")
    eq(t, "Request label", ListLayout_titleAction({ entry: missing, seerrActive: true, requested: false }).label, "Request")
    eq(t, "already asked", ListLayout_titleAction({ entry: missing, seerrActive: true, requested: true }).kind, "requested")
    eq(t, "Requested label", ListLayout_titleAction({ entry: missing, seerrActive: true, requested: true }).label, "Requested")
    eq(t, "signed out", ListLayout_titleAction({ entry: missing, seerrActive: false, requested: false }).kind, "signin")
    eq(t, "signed out label", ListLayout_titleAction({ entry: missing, seerrActive: false, requested: false }).label, "Sign in to Requests")
    noTmdb = { type: "Movie", tmdbId: "", itemId: "" }
    eq(t, "nothing to request it by", ListLayout_titleAction({ entry: noTmdb, seerrActive: true, requested: false }).kind, "none")
    eq(t, "nothing focused", ListLayout_titleAction({}).kind, "none")
end sub

sub testListButtons(t as object)
    play = { kind: "play", label: "Play" }
    none = { kind: "none", label: "" }
    eq(t, "the focused title's action first", kinds(ListLayout_listButtons(play, true, false, true)), "play,shuffle,subscribe,edit")
    eq(t, "someone else's subscribed list", kinds(ListLayout_listButtons(play, false, true, true)), "play,shuffle,unsubscribe")
    eq(t, "empty list", kinds(ListLayout_listButtons(none, true, false, false)), "subscribe,edit")
    defs = ListLayout_listButtons(play, true, false, true)
    eq(t, "play is primary", defs[0].primary, true)
    eq(t, "subscribe is not, next to play", defs[2].primary, false)
    eq(t, "subscribed label", ListLayout_listButtons(none, false, true, false)[0].label, Chr(10003) + " Subscribed")
    alone = ListLayout_listButtons(none, false, false, false)
    eq(t, "subscribe is primary when it leads", alone[0].primary, true)
end sub

sub testWatchlistButtons(t as object)
    eq(t, "title action then More", kinds(ListLayout_watchlistButtons({ kind: "request", label: "Request" }, true)), "request,shuffle,options")
    eq(t, "requested is not primary", ListLayout_watchlistButtons({ kind: "requested", label: "Requested" }, true)[0].primary, false)
    eq(t, "nothing playable: no shuffle", kinds(ListLayout_watchlistButtons({ kind: "none", label: "" }, false)), "options")
    eq(t, "More label", ListLayout_watchlistButtons({ kind: "none", label: "" }, false)[0].label, "More")
end sub

sub testZones(t as object)
    eq(t, "starts on the posters", ListLayout_firstZone(false, 3), "strip")
    eq(t, "the Plex card first", ListLayout_firstZone(true, 3), "card")
    eq(t, "empty: the buttons", ListLayout_firstZone(false, 0), "buttons")
    eq(t, "up from the posters", ListLayout_upFrom("strip", true), "buttons")
    eq(t, "up from the buttons to the card", ListLayout_upFrom("buttons", true), "card")
    eq(t, "up from the buttons, no card", ListLayout_upFrom("buttons", false), "buttons")
    eq(t, "down from the card", ListLayout_downFrom("card", 3), "buttons")
    eq(t, "down from the buttons", ListLayout_downFrom("buttons", 3), "strip")
    eq(t, "down from the buttons, nothing below", ListLayout_downFrom("buttons", 0), "buttons")
    eq(t, "down from the posters stays", ListLayout_downFrom("strip", 3), "strip")
end sub
