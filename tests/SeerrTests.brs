' Off-device tests for source/utils/Seerr.bs, run by tests/run.js against the
' transpiled module. Vectors are the Apple app's (SeerrStatusTests,
' SeerrRequestManagementTests, SeerrViewModelTests, SeerrSearchMergeTests,
' SeerrClientTests, SeerrSessionTests): permissions, the poster pill, request
' states and their lines, Home's row, the Requests list's filter, scope,
' actions and paging, Discover, the quota line, search's "Not in your library"
' merge, and the wire (queries, bodies, the session cookie). Nothing here
' talks to a server.

sub main()
    t = { passed: 0, failed: 0 }

    testPermissions(t)
    testNames(t)
    testServerAndCookie(t)
    testWire(t)
    testBadges(t)
    testRequestStates(t)
    testSubtitles(t)
    testHomeRow(t)
    testRowLabels(t)
    testActions(t)
    testListControls(t)
    testPaging(t)
    testDiscover(t)
    testQuota(t)
    testSearchMerge(t)
    testDetails(t)
    testDetailsExternalIds(t)
    testSession(t)
    testPlex(t)

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

sub near(t as object, name as string, actual as dynamic, expected as double)
    if abs(actual - expected) < 0.001
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

function info(status as integer) as object
    return { status: status }
end function

' A request as Seerr's GET /request lists it.
function req(id as integer, status as integer, by as integer, media as dynamic, kind = "movie" as string, seasons = invalid as dynamic, created = "2026-11-06T09:00:00.000Z" as string, updated = "" as string) as object
    if updated = "" then updated = created
    r = { id: id, status: status, type: kind, createdAt: created, updatedAt: updated, requestedBy: { id: by, displayName: "user" + Str(by).Trim() } }
    if media <> invalid then r.media = media
    if seasons <> invalid
        list = []
        for each n in seasons
            list.push({ seasonNumber: n, status: status })
        end for
        r.seasons = list
    end if
    return r
end function

function movieMedia(tmdbId as integer, status as integer) as object
    return { tmdbId: tmdbId, mediaType: "movie", status: status }
end function

function nowSecs() as integer
    return Seerr_parseDate("2026-11-06T18:00:00.000Z")
end function

' ---------- Permissions ----------

sub testPermissions(t as object)
    eq(t, "REQUEST only: own requests", Seerr_canViewAllRequests(32), false)
    eq(t, "REQUEST only: no managing", Seerr_canManageRequests(32), false)
    eq(t, "ADMIN sees everyone's", Seerr_canViewAllRequests(2), true)
    eq(t, "ADMIN manages", Seerr_canManageRequests(2), true)
    eq(t, "MANAGE_REQUESTS sees", Seerr_canViewAllRequests(16 or 32), true)
    eq(t, "MANAGE_REQUESTS manages", Seerr_canManageRequests(16 or 32), true)
    eq(t, "REQUEST_VIEW sees", Seerr_canViewAllRequests(16384 or 32), true)
    eq(t, "REQUEST_VIEW can't approve", Seerr_canManageRequests(16384 or 32), false)
    eq(t, "nothing", Seerr_canViewAllRequests(0), false)
end sub

sub testNames(t as object)
    eq(t, "display name first", Seerr_userName({ displayName: "Ann", username: "a" }), "Ann")
    eq(t, "blank skipped", Seerr_userName({ displayName: "  ", plexUsername: "plexy" }), "plexy")
    eq(t, "email last", Seerr_userName({ email: "e@x.test" }), "e@x.test")
    eq(t, "fallback", Seerr_userName({ id: 4 }), "Seerr user")
    eq(t, "requester", Seerr_requesterName({ id: 9, displayName: "user9" }), "user9")
    eq(t, "requester without a name", Seerr_requesterName({ id: 3, avatar: "https://x.test/a" }), "User 3")
    eq(t, "no requester", Seerr_requesterName(invalid), "Unknown")
end sub

' ---------- Server address and session cookie ----------

sub testServerAndCookie(t as object)
    eq(t, "no server: only the address can be set", Seerr_accountButtonKinds("").Join(","), "server")
    eq(t, "a server: sign-in offered", Seerr_accountButtonKinds("https://seerr.test").Join(","), "server,plex,local")
    ' Watchlist v2: an address set by the server is locked; only sign-in.
    eq(t, "set by the server: no address button", Seerr_accountButtonKinds("https://seerr.test", true).Join(","), "plex,local")
    eq(t, "the server's address wins", Seerr_effectiveServer("https://set.test", "https://typed.test"), "https://set.test")
    eq(t, "none set: the device's", Seerr_effectiveServer("", "https://typed.test"), "https://typed.test")
    eq(t, "locked line", Seerr_lockedServerLine(), "Requests server " + Chr(183) + " Set by your server")
    eq(t, "no server reads as not set", Seerr_serverLabel(""), "Not set")
    eq(t, "a server reads as itself", Seerr_serverLabel("https://seerr.test"), "https://seerr.test")
    eq(t, "bare host gets https", Seerr_normalizedServer("seerr.test"), "https://seerr.test")
    eq(t, "trailing slashes", Seerr_normalizedServer(" https://seerr.test// "), "https://seerr.test")
    eq(t, "http kept", Seerr_normalizedServer("http://seerr.test:5055"), "http://seerr.test:5055")
    eq(t, "scheme lower-cased", Seerr_normalizedServer("HTTPS://seerr.test"), "https://seerr.test")
    eq(t, "ftp refused", Seerr_normalizedServer("ftp://seerr.test"), "")
    eq(t, "empty refused", Seerr_normalizedServer("   "), "")
    eq(t, "no host refused", Seerr_normalizedServer("https://"), "")
    eq(t, "path kept", Seerr_normalizedServer("https://seerr.test/seerr/"), "https://seerr.test/seerr")
    eq(t, "cookie per server", Seerr_cookieKey("https://A.test") = Seerr_cookieKey("https://b.test"), false)
    eq(t, "cookie key case-insensitive", Seerr_cookieKey("https://A.test"), Seerr_cookieKey("https://a.test"))

    headers = [{ "Content-Type": "application/json" }, { "set-cookie": "other=1; Path=/" }, { "Set-Cookie": "connect.sid=s%3Aabc.def; Path=/; Expires=Wed, 01 Dec 2027 00:00:00 GMT; HttpOnly" }]
    eq(t, "session cookie, attributes dropped", Seerr_sessionCookie(headers), "connect.sid=s%3Aabc.def")
    eq(t, "no session cookie", Seerr_sessionCookie([{ "Set-Cookie": "other=1" }]), "")
    eq(t, "empty session cookie", Seerr_sessionCookie([{ "Set-Cookie": "connect.sid=; Path=/" }]), "")
    eq(t, "no headers", Seerr_sessionCookie(invalid), "")
end sub

' ---------- The wire (SeerrClientTests) ----------

sub testWire(t as object)
    eq(t, "strict encoding", Seerr_encodeQuery("Jodorowsky's Dune (2013)"), "Jodorowsky%27s%20Dune%20%282013%29")
    eq(t, "unreserved kept", Seerr_encodeQuery("a-b_c.d~e"), "a-b_c.d~e")
    eq(t, "UTF-8", Seerr_encodeQuery("Amélie"), "Am%C3%A9lie")
    eq(t, "search query", Seerr_searchQuery(" the bear ", 1), "query=the%20bear&page=1")
    eq(t, "everyone's page", Seerr_requestPageQuery("pending", 20, 0, -1), "take=20&skip=0&filter=pending&sort=added&sortDirection=desc")
    eq(t, "mine", Seerr_requestPageQuery("all", 20, 40, 45), "take=20&skip=40&filter=all&sort=added&sortDirection=desc&requestedBy=45")
    eq(t, "own requests newest first", Seerr_myRequestsQuery(45), "take=50&skip=0&sort=added&requestedBy=45")
    b = Seerr_movieRequestBody(603)
    eq(t, "movie body", b.mediaType + ":" + Str(b.mediaId).Trim(), "movie:603")
    eq(t, "movie body has no seasons", b.seasons = invalid, true)
    b = Seerr_showRequestBody(5, [3, 0, 1, 3, -1])
    eq(t, "show body sorted, never specials", joined(b.seasons), "1,3")
    eq(t, "show body type", b.mediaType, "tv")
    eq(t, "nothing to request: nothing sent", Seerr_showRequestBody(5, [0]) = invalid, true)
    eq(t, "2xx ok", Seerr_outcome(204, false), "ok")
    eq(t, "401 unauthorized", Seerr_outcome(401, false), "unauthorized")
    eq(t, "403 unauthorized", Seerr_outcome(403, false), "unauthorized")
    eq(t, "wrong password", Seerr_outcome(401, true), "invalidCredentials")
    eq(t, "no answer", Seerr_outcome(0, false), "network")
    eq(t, "5xx", Seerr_outcome(500, false), "server")
    eq(t, "server message wins", Seerr_errorMessage("server", 409, { message: "Only pending requests can be approved or declined." }), "Only pending requests can be approved or declined.")
    eq(t, "error field", Seerr_errorMessage("server", 500, { error: "boom" }), "boom")
    eq(t, "no message", Seerr_errorMessage("server", 502, invalid), "The request server answered with an error (502).")
    eq(t, "credentials", Seerr_errorMessage("invalidCredentials", 401, invalid), "That email and password didn't work.")
    eq(t, "poster url", Seerr_posterUrl("/abc.jpg", 342), "https://image.tmdb.org/t/p/w342/abc.jpg")
    eq(t, "no poster path", Seerr_posterUrl("", 342), "")
end sub

' ---------- Poster pills (SeerrStatusTests) ----------

sub testBadges(t as object)
    eq(t, "nothing known", Seerr_badge(invalid, 7), "request")
    eq(t, "unknown", Seerr_badge(info(1), 7), "request")
    eq(t, "pending", Seerr_badge(info(2), 7), "pending")
    eq(t, "processing", Seerr_badge(info(3), 7), "coming")
    eq(t, "available", Seerr_badge(info(5), 7), "available")
    eq(t, "partially available can still be asked", Seerr_badge(info(4), 7), "request")
    eq(t, "blocklisted reads unknown", Seerr_badge(info(6), 7), "request")
    eq(t, "deleted reads unknown", Seerr_badge(info(7), 7), "request")
    mine = { status: 1, requests: [req(1, 3, 7, invalid)] }
    eq(t, "my declined request", Seerr_badge(mine, 7), "declined")
    theirs = { status: 1, requests: [req(1, 3, 99, invalid)] }
    eq(t, "someone else's declined doesn't stop me", Seerr_badge(theirs, 7), "request")
    again = { status: 1, requests: [req(1, 3, 7, invalid, "movie", invalid, "2026-10-01T00:00:00.000Z"), req(2, 1, 7, invalid, "movie", invalid, "2026-11-01T00:00:00.000Z")] }
    eq(t, "newest request decides", Seerr_badge(again, 7), "request")
    eq(t, "labels", Seerr_badgeLabel("request") + "/" + Seerr_badgeLabel("pending") + "/" + Seerr_badgeLabel("coming") + "/" + Seerr_badgeLabel("declined"), "Request/Pending/Coming/Declined")
end sub

' ---------- Request states ----------

sub testRequestStates(t as object)
    eq(t, "pending", Seerr_requestState(req(1, 1, 7, info(2))), "pending")
    eq(t, "declined", Seerr_requestState(req(1, 3, 7, info(1))), "declined")
    eq(t, "approved, processing", Seerr_requestState(req(1, 2, 7, info(3))), "coming")
    eq(t, "approved, available", Seerr_requestState(req(1, 2, 7, info(5))), "ready")
    eq(t, "completed", Seerr_requestState(req(1, 5, 7, info(5))), "ready")
    eq(t, "failed", Seerr_requestState(req(1, 4, 7, info(3))), "failed")

    media = { status: 3, downloadStatus: [{ size: 100, sizeLeft: 50 }, { size: 300, sizeLeft: 102 }] }
    near(t, "progress adds up every download", Seerr_progress(media), 0.62)
    eq(t, "no download, no progress", Seerr_progress(info(3)) < 0, true)
    big = { downloadStatus: [{ size: 4000000000.0#, sizeLeft: 1000000000.0# }] }
    near(t, "sizes past 2^31", Seerr_progress(big), 0.75)

    tv = { status: 4, seasons: [{ seasonNumber: 1, status: 5 }, { seasonNumber: 2, status: 3 }] }
    eq(t, "a show waits for every asked season", Seerr_requestState(req(1, 2, 7, tv, "tv", [1, 2])), "coming")
    eq(t, "a show is ready once its seasons are", Seerr_requestState(req(1, 2, 7, tv, "tv", [1])), "ready")
end sub

sub testSubtitles(t as object)
    now = nowSecs()
    downloading = { status: 3, downloadStatus: [{ size: 100, sizeLeft: 38 }] }
    arrived = { status: 5, mediaAddedAt: "2026-11-05T20:00:00.000Z" }
    eq(t, "pending", Seerr_subtitle(req(1, 1, 7, invalid, "movie", invalid, "2026-11-06T09:00:00.000Z"), now, 0), "Requested today")
    eq(t, "approved and downloading", Seerr_subtitle(req(1, 2, 7, downloading, "movie", invalid, "2026-11-02T09:00:00.000Z", "2026-11-03T09:00:00.000Z"), now, 0), "Approved Tue " + Chr(183) + " 62% downloaded")
    eq(t, "arrived", Seerr_subtitle(req(1, 2, 7, arrived, "movie", invalid, "2026-10-30T09:00:00.000Z"), now, 0), "Arrived yesterday")
    eq(t, "declined", Seerr_subtitle(req(1, 3, 7, invalid, "movie", invalid, "2026-10-01T09:00:00.000Z"), now, 0), "Requested Oct 1")
    eq(t, "failed", Seerr_subtitle(req(1, 4, 7, info(3)), now, 0), "Approved, but it couldn't be sent for download")
    ' The viewer's own zone: 23:00 UTC is already tomorrow at UTC+2.
    eq(t, "time zone", Seerr_dayLabel(Seerr_parseDate("2026-11-05T23:00:00Z"), now, 7200), "today")
    eq(t, "offset dates", Seerr_parseDate("2026-11-06T20:00:00+02:00"), now)
    eq(t, "bare air date is midnight UTC", Seerr_parseDate("2026-11-06"), now - 64800)
    eq(t, "nonsense", Seerr_parseDate("soon") = invalid, true)
end sub

' ---------- Home's row (SeerrStatusTests + SeerrViewModelTests) ----------

sub testHomeRow(t as object)
    now = nowSecs()
    recent = { status: 5, mediaAddedAt: "2026-11-02T10:00:00.000Z" }
    old = { status: 5, mediaAddedAt: "2026-10-20T10:00:00.000Z" }
    eq(t, "pending shows", Seerr_showsOnHome(req(1, 1, 7, invalid), now), true)
    eq(t, "coming shows", Seerr_showsOnHome(req(1, 2, 7, info(3)), now), true)
    eq(t, "arrived this week shows", Seerr_showsOnHome(req(1, 2, 7, recent), now), true)
    eq(t, "arrived weeks ago doesn't", Seerr_showsOnHome(req(1, 2, 7, old), now), false)
    eq(t, "declined doesn't", Seerr_showsOnHome(req(1, 3, 7, invalid), now), false)

    eq(t, "everyone's title", Seerr_homeTitle(2), "Recent Requests")
    eq(t, "own title", Seerr_homeTitle(32), "Your Requests")
    titles = { "movie-100": { title: "Dune", posterPath: "/d.jpg", mediaInfo: invalid } }
    ' Newest first: two people asking for one title is one poster, the newest.
    requests = [
        req(3, 1, 9, movieMedia(100, 2)),
        req(2, 1, 7, movieMedia(100, 2)),
        req(1, 3, 7, movieMedia(101, 1)),
        req(4, 1, 7, invalid)
    ]
    rows = Seerr_homeRows(requests, titles, now, 0)
    eq(t, "one poster per title, declined and titleless left out", rows.count(), 1)
    eq(t, "the newest request", rows[0].id, 3)
    eq(t, "title from the details", rows[0].title, "Dune")
    eq(t, "requester shown on everyone's row", Seerr_homeRequester(rows[0], 2), "user9")
    eq(t, "no name on Your Requests", Seerr_homeRequester(rows[0], 32), "")
    missing = Seerr_missingTitles(requests, {})
    eq(t, "details fetched once per title", missing.count(), 2)
    eq(t, "nothing missing when known", Seerr_missingTitles([requests[0]], titles).count(), 0)
    eq(t, "unknown title", Seerr_row(req(5, 1, 7, movieMedia(555, 2)), {}, now, 0).title, "Unknown title")
end sub

sub testRowLabels(t as object)
    request = {
        id: 8, status: 2, type: "tv", createdAt: "2026-11-02T10:00:00.000Z",
        seasons: [{ seasonNumber: 1 }, { seasonNumber: 2 }, { seasonNumber: 3 }],
        media: { tmdbId: 5, mediaType: "tv", status: 3, downloadStatus: [{ size: 100, sizeLeft: 25 }] },
        requestedBy: { id: 3, displayName: "alex" }
    }
    r = Seerr_row(request, { "tv-5": { title: "Dune: Prophecy", posterPath: "", mediaInfo: invalid } }, nowSecs(), 0)
    eq(t, "kind label", Seerr_kindLabel(r), "Series " + Chr(183) + " S1" + Chr(8211) + "3")
    eq(t, "display title", Seerr_displayTitle(r), "Dune: Prophecy " + Chr(183) + " S1" + Chr(8211) + "3")
    eq(t, "requester", Seerr_requesterName(r.request.requestedBy), "alex")
    eq(t, "request status", Seerr_requestStatusLabel(r.request).label + "/" + Seerr_requestStatusLabel(r.request).tone, "Approved/coming")
    eq(t, "media status", Seerr_mediaStatusLabel(r.request).label, "Processing")
    near(t, "progress", Seerr_progress(r.request.media), 0.75)
    one = Seerr_row(req(9, 1, 3, { tmdbId: 6, status: 2 }, "tv", [2]), {}, nowSecs(), 0)
    eq(t, "one season", Seerr_kindLabel(one), "Series " + Chr(183) + " S2")
    gaps = Seerr_row(req(9, 1, 3, { tmdbId: 6, status: 2 }, "tv", [1, 4]), {}, nowSecs(), 0)
    eq(t, "gaps", Seerr_kindLabel(gaps), "Series " + Chr(183) + " 2 seasons")
    eq(t, "movie", Seerr_kindLabel(Seerr_row(req(9, 1, 3, movieMedia(1, 2)), {}, nowSecs(), 0)), "Movie")
    eq(t, "nobody has it: no media status", Seerr_mediaStatusLabel(req(9, 1, 3, movieMedia(1, 2))) = invalid, true)
    eq(t, "requested label", Seerr_requestedLabel(req(9, 1, 3, invalid, "movie", invalid, "2026-11-02T10:00:00.000Z"), nowSecs(), 0), "Requested Mon")
end sub

' ---------- Actions (SeerrRequestManagementTests) ----------

sub testActions(t as object)
    now = nowSecs()
    pending = Seerr_row(req(1, 1, 45, movieMedia(100, 2)), {}, now, 0)
    approved = Seerr_row(req(2, 2, 45, movieMedia(101, 3)), {}, now, 0)
    theirs = Seerr_row(req(3, 1, 7, movieMedia(102, 2)), {}, now, 0)
    eq(t, "requester cancels own pending", joined(Seerr_actions(pending, 32, 45)), "cancel")
    eq(t, "nothing on own approved", joined(Seerr_actions(approved, 32, 45)), "")
    eq(t, "nothing on someone else's", joined(Seerr_actions(theirs, 32, 45)), "")
    eq(t, "approve not offered", Seerr_hasAction(pending, "approve", 32, 45), false)
    eq(t, "manager on pending", joined(Seerr_actions(theirs, 2, 1)), "approve,decline,delete")
    eq(t, "manager on approved", joined(Seerr_actions(approved, 16 or 32, 1)), "delete")
    eq(t, "viewer can't manage", joined(Seerr_actions(theirs, 16384 or 32, 1)), "")
    eq(t, "titles", Seerr_actionTitle("cancel") + "/" + Seerr_actionTitle("delete"), "Cancel Request/Delete Request")
    eq(t, "approve isn't destructive", Seerr_isDestructive("approve"), false)
    eq(t, "cancel's confirm keeps first", joined(Seerr_confirmButtons("cancel")), "Keep Request,Cancel Request")
    eq(t, "delete's confirm", joined(Seerr_confirmButtons("delete")), "Cancel,Delete Request")
    eq(t, "decline is", Seerr_isDestructive("decline"), true)

    list = [theirs, approved]
    after = Seerr_afterAction(list, 3, "approve", "pending", now, 0)
    eq(t, "approved leaves the Pending filter", after.count(), 1)
    after = Seerr_afterAction(list, 3, "decline", "all", now, 0)
    eq(t, "declined under All stays", after.count(), 2)
    eq(t, "now Declined", Seerr_requestStatusLabel(after[0].request).label, "Declined")
    eq(t, "then only delete", joined(Seerr_actions(after[0], 2, 1)), "delete")
    eq(t, "the original is untouched", Seerr_requestStatusLabel(theirs.request).label, "Pending")
    after = Seerr_afterAction(list, 2, "delete", "all", now, 0)
    eq(t, "deleted leaves", after.count() = 1 and after[0].id = 3, true)
    after = Seerr_afterAction([pending], 1, "cancel", "all", now, 0)
    eq(t, "cancelled leaves", after.count(), 0)
end sub

sub testListControls(t as object)
    ids = []
    for each f in Seerr_filters()
        ids.push(f.title)
    end for
    eq(t, "filters", joined(ids), "All,Pending,Approved,Processing,Available,Failed")
    eq(t, "REQUEST only: no scope switch", Seerr_scopes(32).count(), 0)
    eq(t, "REQUEST only: always mine", Seerr_effectiveScope(32, "everyone"), "mine")
    eq(t, "own id sent", Seerr_requestedByFor(32, "everyone", 45), 45)
    sc = Seerr_scopes(2)
    eq(t, "Everyone first", sc[0].id + "," + sc[1].id, "everyone,mine")
    eq(t, "admins default to everyone", Seerr_effectiveScope(2, ""), "everyone")
    eq(t, "nobody's id for everyone", Seerr_requestedByFor(2, "everyone", 1), -1)
    eq(t, "mine for an admin", Seerr_requestedByFor(2, "mine", 1), 1)
    eq(t, "count summary", Seerr_countSummary({ total: 493, pending: 0, processing: 78, available: 56 }), "493 requests " + Chr(183) + " 0 pending " + Chr(183) + " 78 processing " + Chr(183) + " 56 available")
    eq(t, "no count", Seerr_countSummary(invalid), "")
end sub

sub testPaging(t as object)
    eq(t, "more by total", Seerr_canLoadMore(3, 4, 3, 3), true)
    eq(t, "all fetched", Seerr_canLoadMore(4, 4, 1, 3), false)
    eq(t, "no total: a full page means more", Seerr_canLoadMore(20, -1, 20, 20), true)
    eq(t, "no total: a short page ends it", Seerr_canLoadMore(25, -1, 5, 20), false)
    eq(t, "near the end", Seerr_nearEnd(15, 20), true)
    eq(t, "not yet", Seerr_nearEnd(10, 20), false)
    now = nowSecs()
    a = Seerr_rows([req(1, 2, 45, movieMedia(101, 3)), req(2, 2, 45, movieMedia(102, 3))], {}, now, 0)
    b = Seerr_rows([req(2, 2, 45, movieMedia(102, 3)), req(4, 2, 45, movieMedia(104, 3))], {}, now, 0)
    merged = Seerr_appendRows(a, b)
    out = []
    for each r in merged
        out.push(r.id)
    end for
    eq(t, "pages append without repeats", joined(out), "1,2,4")
end sub

' ---------- Discover ----------

sub testDiscover(t as object)
    ids = []
    for each s in Seerr_sliders()
        ids.push(s.id)
    end for
    eq(t, "Seerr web's order", joined(ids), "recentRequests,trending,popularMovies,upcomingMovies,popularSeries,upcomingSeries,watchlist")
    eq(t, "Recent Requests is GET /request", Seerr_sliders()[0].path, "")
    
    page = { page: 1, totalPages: 3, results: [{ id: 10, mediaType: "movie", title: "M10", mediaInfo: { status: 5 } }, { id: 11, mediaType: "person", name: "Somebody" }, { id: 13, mediaType: "tv", name: "S13", firstAirDate: "2024-01-02" }] }
    list = Seerr_results(page)
    eq(t, "people dropped", list.count(), 2)
    eq(t, "show name", list[1].title, "S13")
    eq(t, "show year", list[1].year, 2024)
    items = Seerr_uniqueItems(list, 45)
    eq(t, "available pill", items[0].tag.label, "Available")
    eq(t, "badge", items[0].badge, "available")
    eq(t, "nobody asked: no pill", items[1].tag = invalid, true)
    eq(t, "processing pill", Seerr_discoverTag(info(3), "coming").label, "Processing")
    eq(t, "pending pill", Seerr_discoverTag(info(2), "pending").label, "Requested")
    eq(t, "partial pill", Seerr_discoverTag(info(4), "request").label, "Partially Available")
    eq(t, "declined pill", Seerr_discoverTag(info(1), "declined").label, "Declined")
    eq(t, "duplicates once", Seerr_uniqueItems([list[0], list[0], list[1]], 45).count(), 2)

    ' A local watchlist names the TMDB id tmdbId; its id is the entry's own.
    w = Seerr_results({ results: [{ id: 4, tmdbId: 603, title: "The Matrix", mediaType: "movie" }] })
    eq(t, "watchlist reads tmdbId", w[0].tmdbId, 603)
    filled = Seerr_fillFromTitles(w, { "movie-603": { title: "The Matrix", posterPath: "/m.jpg", mediaInfo: { status: 5 } } })
    eq(t, "watchlist poster from details", filled[0].posterPath, "/m.jpg")
    eq(t, "watchlist state from details", Seerr_uniqueItems(filled, 45)[0].badge, "available")

    recent = Seerr_recentItems([req(1, 1, 45, movieMedia(9, 2)), req(2, 1, 7, movieMedia(9, 2))], { "movie-9": { title: "Requested", posterPath: "/r.jpg", mediaInfo: invalid } }, 45)
    eq(t, "recent: one per title", recent.count(), 1)
    eq(t, "recent: title from details", recent[0].title, "Requested")
    eq(t, "recent: request's state", recent[0].tag.label, "Requested")

    loaded = {
        watchlist: { id: "watchlist", items: [], page: 1, totalPages: 1 },
        trending: { id: "trending", items: [items[0]], page: 1, totalPages: 2 },
        recentRequests: { id: "recentRequests", items: recent, page: 1, totalPages: 1 }
    }
    rows = Seerr_discoverRows(loaded)
    ids = []
    for each r in rows
        ids.push(r.id)
    end for
    eq(t, "empty watchlist dropped, order kept", joined(ids), "recentRequests,trending")
    eq(t, "trending pages", Seerr_rowCanLoadMore(rows[1]), true)
    eq(t, "recent requests never page", Seerr_rowCanLoadMore({ id: "recentRequests", page: 1, totalPages: 5 }), false)
    more = Seerr_appendItems(rows[1].items, Seerr_uniqueItems(Seerr_results({ results: [{ id: 10, mediaType: "movie", title: "M10" }, { id: 2, mediaType: "movie", title: "B" }] }), 45))
    eq(t, "next page appends new titles", more.count(), 2)
end sub

' ---------- Quota ----------

sub testQuota(t as object)
    unlimited = { movie: { days: 7, limit: 0, used: 0, restricted: false }, tv: { days: 7, limit: 0, used: 0, restricted: false } }
    eq(t, "unlimited movie", Seerr_quotaSummary(unlimited, "movie"), "")
    eq(t, "unlimited tv", Seerr_quotaSummary(unlimited, "tv"), "")
    limited = { movie: { days: 7, limit: 5, used: 2, remaining: 3, restricted: false }, tv: { days: 1, limit: 4, used: 4, remaining: 0, restricted: true } }
    eq(t, "movies left", Seerr_quotaSummary(limited, "movie"), "3 of 5 movie requests left " + Chr(183) + " resets over 7 days")
    eq(t, "seasons used up", Seerr_quotaSummary(limited, "tv"), "You've used all 4 of your season requests " + Chr(183) + " resets over 1 day")
    eq(t, "remaining from used", Seerr_quotaSummary({ movie: { days: 7, limit: 5, used: 1 } }, "movie"), "4 of 5 movie requests left " + Chr(183) + " resets over 7 days")
    eq(t, "no quota", Seerr_quotaSummary(invalid, "movie"), "")
end sub

' ---------- Search's row (SeerrSearchMergeTests) ----------

sub testSearchMerge(t as object)
    seerr = Seerr_results({ results: [
        { id: 90228, mediaType: "tv", name: "Dune: Prophecy", firstAirDate: "2024-11-17" },
        { id: 438631, mediaType: "movie", title: "Dune", releaseDate: "2021-09-15", mediaInfo: { status: 5 } },
        { id: 841, mediaType: "movie", title: "Dune", releaseDate: "1984-12-14", mediaInfo: { status: 2 } },
        { id: 693134, mediaType: "movie", title: "Dune: Part Two", releaseDate: "2024-02-27" },
        { id: 777, mediaType: "movie", title: "Unmatched Film", releaseDate: "2020-01-01" },
        { id: 841, mediaType: "movie", title: "Dune", releaseDate: "1984-12-14" }
    ] })
    library = [
        { Id: "jf-1", Name: "Dune: Part Two", Type: "Movie", ProviderIds: { Tmdb: "693134" } },
        { Id: "jf-2", Name: "Unmatched Film", Type: "Movie", ProductionYear: 2020 },
        { Id: "jf-3", Name: "Dune: Prophecy", Type: "Episode", ProviderIds: { Tmdb: "90228" } }
    ]
    out = []
    for each r in Seerr_requestable(seerr, library)
        out.push(r.tmdbId)
    end for
    eq(t, "drops what the server and the library row have, each once", joined(out), "90228,841")
    eq(t, "library TMDB id", Seerr_libraryTmdbId(library[0]), 693134)
    eq(t, "no provider ids", Seerr_libraryTmdbId(library[1]), -1)
    same = Seerr_requestable(Seerr_results({ results: [{ id: 5, mediaType: "movie", title: "A" }, { id: 5, mediaType: "tv", name: "B" }] }), [{ Type: "Series", ProviderIds: { Tmdb: "5" } }])
    eq(t, "a movie and a show with one TMDB number differ", same.count() = 1 and same[0].kind = "movie", true)
    hit = Seerr_libraryMatch(library, 693134, "movie")
    eq(t, "library match by TMDB id", hit.Id, "jf-1")
    eq(t, "wrong kind doesn't match", Seerr_libraryMatch(library, 693134, "tv") = invalid, true)
end sub

' ---------- Details and the main button (SeerrViewModelTests) ----------

sub testDetails(t as object)
    raw = {
        id: 1, name: "Love Is Blind", firstAirDate: "2020-02-13", status: "Returning Series",
        genres: [{ name: "Reality" }], seasons: [{ seasonNumber: 1, episodeCount: 10, airDate: "2020-02-13" }],
        contentRatings: { results: [{ iso_3166_1: "GB", rating: "15" }, { iso_3166_1: "US", rating: "TV-MA" }] },
        mediaInfo: { status: 1 }
    }
    d = Seerr_details(raw)
    eq(t, "a show", d.kind, "tv")
    eq(t, "name", d.title, "Love Is Blind")
    eq(t, "US rating", d.contentRating, "TV-MA")
    eq(t, "series status", Seerr_seriesStatus(d.tmdbStatus), "Continuing")
    movie = Seerr_details({ id: 2, title: "Jodorowsky's Dune", releaseDate: "2013-05-18", releases: { results: [{ iso_3166_1: "FR", release_dates: [{ certification: "" }, { certification: "U" }] }, { iso_3166_1: "US", release_dates: [{ certification: "PG-13" }] }] } })
    eq(t, "a movie", movie.kind, "movie")
    eq(t, "US certification", movie.contentRating, "PG-13")
    eq(t, "movie: one press", Seerr_detailAction(movie, invalid, 45).kind, "request")
    movie.mediaInfo = info(2)
    eq(t, "pending status line", Seerr_detailAction(movie, invalid, 45).text, "Requested " + Chr(8226) + " waiting for approval")
    movie.mediaInfo = info(3)
    eq(t, "coming", Seerr_detailAction(movie, invalid, 45).text, "Coming soon")
    movie.mediaInfo = info(5)
    eq(t, "available", Seerr_detailAction(movie, invalid, 45).text, "On your server")
    eq(t, "opens the library title", Seerr_isOnServer(movie), true)
    now = nowSecs()
    eq(t, "a show with an aired missing season: picker", Seerr_detailAction(d, SeerrSeasons_plan(d, now), 45).kind, "chooseSeasons")
    d.mediaInfo = { status: 4, seasons: [{ seasonNumber: 1, status: 5 }] }
    eq(t, "everything on the server", Seerr_detailAction(d, SeerrSeasons_plan(d, now), 45).text, "Every season is on the server or requested")
    eq(t, "people are no title", Seerr_details(invalid) = invalid, true)
end sub

' ---------- Session (SeerrSessionTests) ----------

sub testSession(t as object)
    eq(t, "cookie checks out", Seerr_restoreOutcome(200, true), "signedIn")
    eq(t, "expired cookie", Seerr_restoreOutcome(401, true), "expired")
    eq(t, "forbidden too", Seerr_restoreOutcome(403, false), "expired")
    eq(t, "offline keeps the account", Seerr_restoreOutcome(0, true), "offline")
    eq(t, "server error keeps it", Seerr_restoreOutcome(500, true), "offline")
    eq(t, "never saved: nothing", Seerr_restoreOutcome(0, false), "none")
    eq(t, "a 401 later expires once me agrees", Seerr_expiresAfterCheck(401), true)
    eq(t, "me still fine: stays signed in", Seerr_expiresAfterCheck(200), false)
    eq(t, "me unreachable: not a sign-out", Seerr_expiresAfterCheck(0), false)
    eq(t, "signed in", Seerr_accountLabel("signedIn", "Ann"), "Signed in as Ann")
    eq(t, "expired", Seerr_accountLabel("expired", ""), "Sign-in expired")
    eq(t, "not set up", Seerr_accountLabel("none", ""), "Not set up")
    eq(t, "menu while expired", Seerr_menuAvailable("expired"), true)
    eq(t, "no menu while signed out", Seerr_menuAvailable("none"), false)
    eq(t, "requests only while signed in", Seerr_isActive("expired"), false)
end sub

sub testPlex(t as object)
    eq(t, "create pin", Seerr_plexPinUrl(-1), "https://plex.tv/api/v2/pins?strong=false")
    eq(t, "check pin", Seerr_plexPinUrl(42), "https://plex.tv/api/v2/pins/42")
    h = Seerr_plexHeaders("abc", "1.6.29")
    eq(t, "product", h["X-Plex-Product"], "Sashimi")
    eq(t, "client id", h["X-Plex-Client-Identifier"], "abc")
    p = Seerr_plexPin({ id: 42, code: "AB12", authToken: invalid })
    eq(t, "pin code", p.code, "AB12")
    eq(t, "not linked yet", p.token, "")
    eq(t, "linked", Seerr_plexPin({ id: 42, code: "AB12", authToken: "tok" }).token, "tok")
    eq(t, "garbage", Seerr_plexPin({ code: "X" }) = invalid, true)
    ' One check at a time: a linked code makes a check sign in and link the
    ' Watchlist, which must not run again on every tick while it is going.
    eq(t, "poll: check", Seerr_plexPollStep(100, 130, false), "check")
    eq(t, "poll: a check is running", Seerr_plexPollStep(100, 130, true), "wait")
    eq(t, "poll: expired", Seerr_plexPollStep(100, 1001, false), "expire")
    eq(t, "poll: expired while checking", Seerr_plexPollStep(100, 1001, true), "expire")
    ' Connect Plex for the Watchlist works with Requests never set up: the code
    ' is plex.tv's and the token goes to the Watchlist plugin, not to Seerr.
    eq(t, "watchlist without a Seerr server", Seerr_plexCheckRoute("watchlist", ""), "watchlist")
    eq(t, "watchlist with a Seerr server", Seerr_plexCheckRoute("watchlist", "https://requests.example.com"), "watchlist")
    eq(t, "requests sign-in", Seerr_plexCheckRoute("", "https://requests.example.com"), "seerr")
    eq(t, "requests sign-in without a server", Seerr_plexCheckRoute("", ""), "noServer")
end sub

sub testDetailsExternalIds(t as object)
    mv = Seerr_details({ id: 2, title: "Arrival", externalIds: { imdbId: "tt2543164" } })
    eq(t, "movie imdb from externalIds", mv.imdbId, "tt2543164")
    eq(t, "movie without tvdb", mv.tvdbId, "")
    eq(t, "movie top-level imdb", Seerr_details({ id: 3, title: "X", imdbId: "tt1" }).imdbId, "tt1")
    tv = Seerr_details({ id: 95396, name: "Severance", externalIds: { tvdbId: 371980 } })
    eq(t, "tv tvdb as a string", tv.tvdbId, "371980")
    eq(t, "tv without imdb", tv.imdbId, "")
    none = Seerr_details({ id: 4, title: "Y" })
    eq(t, "no ids: imdb empty", none.imdbId, "")
    eq(t, "no ids: tvdb empty", none.tvdbId, "")
end sub
