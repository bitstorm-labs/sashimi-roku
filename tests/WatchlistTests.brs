' Off-device tests for source/utils/Watchlist.bs (with Seerr.bs), run by
' tests/run.js. The Watchlist's rules: the plugin's 404, which titles qualify,
' add bodies from a library item or a Seerr title, the any-agreeing-id check,
' tiles and their pills, what OK does, the Plex card, line and * menu, and the
' link and auto-link outcomes.

sub main()
    t = { passed: 0, failed: 0 }

    testFromResponse(t)
    testAccepts(t)
    testBodies(t)
    testContains(t)
    testTiles(t)
    testRequestedKeys(t)
    testOnSelect(t)
    testPlexCard(t)
    testLinkOutcome(t)
    testAutoLink(t)
    testCover(t)
    testMetaLine(t)
    testLinkErrors(t)
    testItemBatches(t)
    testLinkResult(t)
    testSettingsRow(t)
    testOptedOut(t)
    testCoverTags(t)
    testSearchReady(t)
    testSearchResponse(t)
    testSearchRows(t)
    testHitBody(t)
    testHitOpen(t)
    testDetailsQuery(t)
    testDetailsResponse(t)
    testDetailsMeta(t)
    testDetailsButtons(t)
    testRequestsAddress(t)
    testEntryOpensDetails(t)
    testTitleSources(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else if isInt(actual) and isInt(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub

function isInt(v as dynamic) as boolean
    k = type(v)
    return k = "Integer" or k = "roInt" or k = "roInteger"
end function

function joined(list as object) as string
    s = ""
    for each v in list
        if s <> "" then s = s + ","
        s = s + v
    end for
    return s
end function

function kinds(menu as object) as string
    out = []
    for each it in menu
        out.push(it.kind)
    end for
    return joined(out)
end function

function entry(id as string, kind as string, itemId as string, tmdbId as string) as object
    return { id: id, type: kind, title: "T " + id, year: 2020, posterUrl: "", tmdbId: tmdbId, tvdbId: "", imdbId: "", addedAt: "", itemId: itemId }
end function

sub testFromResponse(t as object)
    v = Watchlist_fromResponse(404, invalid)
    eq(t, "404: no watchlist", v.available, false)
    eq(t, "404: not a failure", v.failed, false)
    eq(t, "500 fails", Watchlist_fromResponse(500, invalid).failed, true)
    eq(t, "0 fails", Watchlist_fromResponse(0, invalid).failed, true)
    eq(t, "200 junk fails", Watchlist_fromResponse(200, "nope").failed, true)
    body = {
        plex: { username: "alex", needsReconnect: false }, cardDismissed: true,
        entries: [
            { id: "a", type: "Movie", title: "Arrival", year: 2016, tmdbId: "329865", itemId: "abc", addedAt: "2026-11-09T00:00:00Z" },
            { id: "b", type: "Series", title: "Severance", tvdbId: "371980", itemId: invalid },
            { id: "c", type: "Episode", title: "Pilot", tmdbId: "1" },
            { type: "Movie", title: "No id", tmdbId: "2" }
        ]
    }
    v = Watchlist_fromResponse(200, body)
    eq(t, "200 available", v.available, true)
    eq(t, "200 not failed", v.failed, false)
    eq(t, "plex username", v.plex.username, "alex")
    eq(t, "plex reconnect", v.plex.needsReconnect, false)
    eq(t, "card dismissed", v.cardDismissed, true)
    eq(t, "movies and series with an id only", v.entries.count(), 2)
    eq(t, "order kept", v.entries[0].id, "a")
    eq(t, "on server", v.entries[0].itemId, "abc")
    eq(t, "not on server", v.entries[1].itemId, "")
    eq(t, "year kept", v.entries[0].year, 2016)
    eq(t, "year missing", v.entries[1].year, -1)
    eq(t, "missing id is empty", v.entries[1].tmdbId, "")
    eq(t, "poster missing is empty", v.entries[1].posterUrl, "")
    eq(t, "unlinked plex", Watchlist_fromResponse(200, { entries: [] }).plex, invalid)
    eq(t, "no entries key", Watchlist_fromResponse(200, {}).entries.count(), 0)
end sub

sub testAccepts(t as object)
    eq(t, "movie with tmdb", Watchlist_accepts({ Type: "Movie", ProviderIds: { Tmdb: "1" } }), true)
    eq(t, "series with lower-case imdb", Watchlist_accepts({ Type: "Series", ProviderIds: { imdb: "tt1" } }), true)
    eq(t, "episode never", Watchlist_accepts({ Type: "Episode", ProviderIds: { Tmdb: "1" } }), false)
    eq(t, "movie without ids", Watchlist_accepts({ Type: "Movie", ProviderIds: {} }), false)
    eq(t, "movie with empty ids", Watchlist_accepts({ Type: "Movie", ProviderIds: { Tmdb: "" } }), false)
    eq(t, "home video", Watchlist_accepts({ Type: "Video", ProviderIds: { Tmdb: "1" } }), false)
    eq(t, "invalid", Watchlist_accepts(invalid), false)
    ids = Watchlist_idsOfItem({ ProviderIds: { TMDB: "5", Tvdb: "6" } })
    eq(t, "ids tmdb", ids.tmdbId, "5")
    eq(t, "ids tvdb", ids.tvdbId, "6")
    eq(t, "ids imdb absent", ids.imdbId, "")
end sub

sub testBodies(t as object)
    b = Watchlist_bodyForItem({ Type: "Series", Name: "Severance", ProductionYear: 2022, ProviderIds: { Tvdb: "371980", Imdb: "tt11280740" } })
    eq(t, "item type", b.type, "Series")
    eq(t, "item title", b.title, "Severance")
    eq(t, "item year", b.year, 2022)
    eq(t, "item tvdb", b.tvdbId, "371980")
    eq(t, "item imdb", b.imdbId, "tt11280740")
    eq(t, "item no tmdb key", b.DoesExist("tmdbId"), false)
    eq(t, "item no poster key", b.DoesExist("posterUrl"), false)
    eq(t, "item no year when unknown", Watchlist_bodyForItem({ Type: "Movie", Name: "X", ProviderIds: { Tmdb: "1" } }).DoesExist("year"), false)
    s = Watchlist_bodyForSeerr({ kind: "tv", tmdbId: 95396, title: "Severance", year: 2022, posterPath: "/a.jpg", imdbId: "tt11280740", tvdbId: "371980" })
    eq(t, "seerr type", s.type, "Series")
    eq(t, "seerr tmdb as string", s.tmdbId, "95396")
    eq(t, "seerr poster", s.posterUrl, "https://image.tmdb.org/t/p/w500/a.jpg")
    eq(t, "seerr year", s.year, 2022)
    eq(t, "seerr tvdb", s.tvdbId, "371980")
    mv = Watchlist_bodyForSeerr({ kind: "movie", tmdbId: 7, title: "M", year: -1, posterPath: "", imdbId: "", tvdbId: "" })
    eq(t, "seerr movie type", mv.type, "Movie")
    eq(t, "seerr movie no poster", mv.DoesExist("posterUrl"), false)
    eq(t, "seerr movie no year", mv.DoesExist("year"), false)
    eq(t, "seerr movie no imdb", mv.DoesExist("imdbId"), false)
end sub

sub testContains(t as object)
    list = [{ tmdbId: "1", tvdbId: "", imdbId: "" }, { tmdbId: "", tvdbId: "", imdbId: "TT123" }]
    eq(t, "agrees on tmdb", Watchlist_contains(list, { tmdbId: "1", tvdbId: "9", imdbId: "" }), true)
    eq(t, "imdb ignores case", Watchlist_contains(list, { tmdbId: "", tvdbId: "", imdbId: "tt123" }), true)
    eq(t, "disjoint ids", Watchlist_contains(list, { tmdbId: "2", tvdbId: "3", imdbId: "tt4" }), false)
    eq(t, "empty never agrees", Watchlist_contains([{ tmdbId: "", tvdbId: "", imdbId: "" }], { tmdbId: "", tvdbId: "", imdbId: "" }), false)
    row = Watchlist_pickerRow({ entries: list }, { tmdbId: "1", tvdbId: "", imdbId: "" })
    eq(t, "picker row flag", row.isWatchlist, true)
    eq(t, "picker row name", row.name, "Watchlist")
    eq(t, "picker row count", row.count, 2)
    eq(t, "picker row already", row.already, true)
end sub

sub testTiles(t as object)
    on = Watchlist_tile(entry("a", "Movie", "x1", "1"), false)
    eq(t, "on server bright", on.dimmed, false)
    eq(t, "on server no pill", on.pill, "")
    eq(t, "on server item id", on.itemId, "x1")
    eq(t, "requested pill", Watchlist_tile(entry("b", "Movie", "", "2"), true).pill, "Requested")
    off = Watchlist_tile(entry("c", "Movie", "", "3"), false)
    eq(t, "missing dimmed", off.dimmed, true)
    eq(t, "missing pill", off.pill, "Not on server")
    eq(t, "tile title", off.title, "T c")
end sub

sub testRequestedKeys(t as object)
    entries = [entry("a", "Movie", "x", "1"), entry("b", "Series", "", "2"), entry("c", "Movie", "", ""), entry("d", "Series", "", "2"), entry("e", "Movie", "", "2")]
    targets = Watchlist_statusTargets(entries)
    eq(t, "only missing with tmdb, once each", targets.count(), 2)
    eq(t, "first target kind", targets[0].kind, "tv")
    eq(t, "first target id", targets[0].tmdbId, 2)
    eq(t, "movie and show with one id are two titles", targets[1].kind, "movie")
    eq(t, "seerr key", Watchlist_seerrKey(entries[1]), "tv-2")
    eq(t, "no key without tmdb", Watchlist_seerrKey(entries[2]), "")
    eq(t, "pending is requested", Watchlist_isRequested("pending"), true)
    eq(t, "coming is requested", Watchlist_isRequested("coming"), true)
    eq(t, "declined is not", Watchlist_isRequested("declined"), false)
    eq(t, "request is not", Watchlist_isRequested("request"), false)
    eq(t, "available is not", Watchlist_isRequested("available"), false)
end sub

sub testOnSelect(t as object)
    eq(t, "on server opens the item", Watchlist_onSelect(entry("a", "Movie", "x1", "1"), false).kind, "item")
    eq(t, "item id", Watchlist_onSelect(entry("a", "Movie", "x1", "1"), false).itemId, "x1")
    ' Request (on the Spotlight and the title page) opens Seerr's page.
    s = Watchlist_seerrTarget(entry("b", "Series", "", "42"))
    eq(t, "seerr kind for a series", s.kind, "tv")
    eq(t, "seerr tmdb id", s.tmdbId, 42)
    eq(t, "seerr title", s.title, "T b")
    eq(t, "no tmdb id: no seerr page", Watchlist_seerrTarget(entry("d", "Movie", "", "")), invalid)
end sub

sub testPlexCard(t as object)
    unlinked = { plex: invalid, cardDismissed: false }
    dismissed = { plex: invalid, cardDismissed: true }
    linked = { plex: { username: "alex", needsReconnect: false }, cardDismissed: false }
    paused = { plex: { username: "alex", needsReconnect: true }, cardDismissed: true }
    eq(t, "card when unlinked", Watchlist_showCard(unlinked), true)
    eq(t, "no card once dismissed", Watchlist_showCard(dismissed), false)
    eq(t, "no card when linked", Watchlist_showCard(linked), false)
    eq(t, "synced line", Watchlist_plexLine(linked), Chr(10003) + " Synced with Plex")
    eq(t, "paused line", Watchlist_plexLine(paused), "Plex sync is paused. Press * to reconnect.")
    eq(t, "no line unlinked", Watchlist_plexLine(unlinked), "")
    eq(t, "tile, unlinked", kinds(Watchlist_optionsMenu(unlinked, true)), "remove,connect")
    eq(t, "no tile, paused", kinds(Watchlist_optionsMenu(paused, false)), "reconnect,disconnect")
    eq(t, "no tile, linked", kinds(Watchlist_optionsMenu(linked, false)), "disconnect")
    menu = Watchlist_optionsMenu(paused, true)
    eq(t, "labels", menu[0].label + "|" + menu[1].label + "|" + menu[2].label, "Remove from Watchlist|Reconnect Plex|Disconnect Plex")
    eq(t, "connect label", Watchlist_optionsMenu(unlinked, false)[0].label, "Connect Plex")
end sub

sub testLinkOutcome(t as object)
    ok = Watchlist_linkOutcome(200, { username: "alex", needsReconnect: false })
    eq(t, "linked", ok.kind, "linked")
    eq(t, "linked name", ok.username, "alex")
    c = Watchlist_linkOutcome(409, { username: "sam", newUsername: "alex" })
    eq(t, "conflict", c.kind, "conflict")
    eq(t, "conflict current", c.username, "sam")
    eq(t, "conflict wanted", c.newUsername, "alex")
    eq(t, "conflict junk body", Watchlist_linkOutcome(409, invalid).newUsername, "")
    eq(t, "plex rejected the token", Watchlist_linkOutcome(422, invalid).kind, "rejected")
    ' 401 is the Jellyfin session, not Plex: never "Plex didn't accept that sign-in".
    eq(t, "401 is not a Plex rejection", Watchlist_linkOutcome(401, invalid).kind, "failed")
    eq(t, "no plugin", Watchlist_linkOutcome(404, invalid).kind, "unavailable")
    eq(t, "offline", Watchlist_linkOutcome(0, invalid).kind, "failed")
    ' 503 when the plugin can't reach plex.tv: not a rejected token.
    eq(t, "plex unreachable", Watchlist_linkOutcome(503, invalid).kind, "unreachable")
    eq(t, "any 5xx", Watchlist_linkOutcome(500, invalid).kind, "unreachable")
end sub

sub testAutoLink(t as object)
    eq(t, "no watchlist: skip", Watchlist_autoLinkStep({ available: false, plex: invalid }), "skip")
    eq(t, "unlinked: first", Watchlist_autoLinkStep({ available: true, plex: invalid }), "first")
    eq(t, "linked: refresh", Watchlist_autoLinkStep({ available: true, plex: { username: "x", needsReconnect: false } }), "refresh")
    p = Watchlist_replacePrompt("alex", "sam")
    eq(t, "prompt title", p.title, "Sync your Watchlist with Plex account alex instead?")
    eq(t, "prompt message", p.message, "It syncs with sam now.")
    eq(t, "prompt without a name", Watchlist_replacePrompt("", "sam").title, "Sync your Watchlist with this Plex account instead?")
    eq(t, "switch label", Watchlist_switchLabel("alex"), "Switch to alex")
    eq(t, "switch label without a name", Watchlist_switchLabel(""), "Switch Account")
end sub

sub testCover(t as object)
    eq(t, "card meta", Watchlist_cardMeta(3), "Private " + Chr(183) + " 3")
    five = [entry("a", "Movie", "x", "1"), entry("b", "Movie", "y", "2"), entry("c", "Movie", "z", "3"), entry("d", "Movie", "w", "4"), entry("e", "Movie", "v", "5")]
    eq(t, "the first three of five", Watchlist_coverSources(five).count(), 3)
    two = [entry("a", "Movie", "x", "1"), entry("b", "Movie", "y", "2")]
    eq(t, "two: a two-poster stack", Watchlist_coverSources(two).count(), 2)
    eq(t, "on the server: sharp", Watchlist_coverSources(two)[0].dimmed, false)
    poster = entry("p", "Movie", "", "1")
    poster.posterUrl = "https://image.tmdb.org/t/p/w500/p.jpg"
    bare = entry("q", "Movie", "", "2")
    c = Watchlist_coverSources([bare, poster])
    eq(t, "skips entries with neither", c.count(), 1)
    eq(t, "missing title's poster", c[0].posterUrl, poster.posterUrl)
    eq(t, "not on server: dimmed", c[0].dimmed, true)
    eq(t, "nothing drawable", Watchlist_coverSources([bare]).count(), 0)
end sub

sub testMetaLine(t as object)
    unlinked = { plex: invalid, cardDismissed: false }
    linked = { plex: { username: "alex", needsReconnect: false }, cardDismissed: false }
    eq(t, "one title", Watchlist_metaLine(1, unlinked), "1 title")
    eq(t, "many titles", Watchlist_metaLine(12, unlinked), "12 titles")
    eq(t, "empty", Watchlist_metaLine(0, unlinked), "")
    eq(t, "with the Plex line", Watchlist_metaLine(2, linked), "2 titles   " + Chr(183) + "   " + Chr(10003) + " Synced with Plex")
    eq(t, "empty but linked", Watchlist_metaLine(0, linked), Chr(10003) + " Synced with Plex")
end sub

sub testLinkErrors(t as object)
    ' Connect Plex reports every failure; a Requests sign-in's quiet auto-link
    ' doesn't, but a switch the person confirmed always does.
    eq(t, "connect: shown", Watchlist_showsLinkError("plexCheck", true), true)
    eq(t, "requests sign-in: quiet", Watchlist_showsLinkError("plexCheck", false), false)
    eq(t, "switch from Requests: shown", Watchlist_showsLinkError("watchlistReplace", false), true)
    eq(t, "switch from Connect Plex: shown", Watchlist_showsLinkError("watchlistReplace", true), true)
    eq(t, "rejected text", Watchlist_linkErrorText("rejected"), "Plex didn't accept that sign-in. Try again.")
    eq(t, "other text", Watchlist_linkErrorText("failed"), "Couldn't connect Plex. Check your connection.")
    eq(t, "unreachable text", Watchlist_linkErrorText("unreachable"), "Couldn't reach Plex. Try again.")
end sub

sub testItemBatches(t as object)
    ' A big Watchlist's library lookup goes in batches, so the /Items?Ids=
    ' request line stays well under a server's 8 KB limit.
    entries = []
    for i = 1 to 250
        entries.push(entry("e" + i.ToStr(), "Movie", "item" + i.ToStr(), ""))
    end for
    entries.push(entry("missing", "Movie", "", "9"))
    b = Watchlist_itemIdBatches(entries, 100)
    eq(t, "three batches", b.count(), 3)
    eq(t, "first batch", Left(b[0], 12), "item1,item2,")
    eq(t, "last batch ends with the last on-server id", Right(b[2], 7), "item250")
    eq(t, "missing titles left out", Instr(1, b[2], ",," ) = 0 and Instr(1, b[2], "missing") = 0, true)
    eq(t, "none on the server", Watchlist_itemIdBatches([entry("m", "Movie", "", "1")], 100).count(), 0)
end sub

sub testLinkResult(t as object)
    ' A Requests sign-in's auto-link never fails the sign-in: every failure
    ' comes back as nothing at all (no success flag, no error).
    for each kind in ["rejected", "failed", "unreachable", "unavailable"]
        eq(t, "auto " + kind + ": nothing", Watchlist_linkResult({ kind: kind }, true, "first").count(), 0)
        eq(t, "connect " + kind + ": the error", Watchlist_linkResult({ kind: kind }, false, "first").watchlistError, kind)
    end for
    eq(t, "auto first link: toast", Watchlist_linkResult({ kind: "linked" }, true, "first").watchlistLinked, true)
    eq(t, "auto refresh: quiet", Watchlist_linkResult({ kind: "linked" }, true, "refresh").watchlistLinked, false)
    ' Quiet, but the link did change (a paused sync is running again), so the
    ' Watchlist page and Settings > Plex must re-read.
    eq(t, "auto refresh: still a change", Watchlist_linkResult({ kind: "linked" }, true, "refresh").watchlistChanged, true)
    eq(t, "connect: a change", Watchlist_linkResult({ kind: "linked" }, false, "first").watchlistChanged, true)
    eq(t, "conflict: no change yet", Watchlist_linkResult({ kind: "conflict", username: "sam", newUsername: "alex" }, true, "refresh").DoesExist("watchlistChanged"), false)
    eq(t, "connect failure: no change", Watchlist_linkResult({ kind: "failed" }, false, "first").DoesExist("watchlistChanged"), false)
    eq(t, "connect: toast", Watchlist_linkResult({ kind: "linked" }, false, "first").watchlistLinked, true)
    c = Watchlist_linkResult({ kind: "conflict", username: "sam", newUsername: "alex" }, true, "refresh")
    eq(t, "conflict current", c.watchlistConflict.current, "sam")
    eq(t, "conflict wanted", c.watchlistConflict.wanted, "alex")
    eq(t, "conflict never carries success", c.DoesExist("success"), false)
end sub

sub testSettingsRow(t as object)
    ' Settings > Plex: a second way to the same link, hidden without the plugin.
    eq(t, "no plugin: hidden", Watchlist_settingsRow({ available: false, plex: invalid }).visible, false)
    un = Watchlist_settingsRow({ available: true, plex: invalid })
    eq(t, "unlinked shown", un.visible, true)
    eq(t, "row title", un.title, "Plex")
    eq(t, "unlinked value", un.value, "Not connected")
    eq(t, "the line", un.detail, "Keeps your Watchlist in sync with your Plex watchlist.")
    eq(t, "unlinked actions", kinds(un.actions), "connect")
    eq(t, "connect label", un.actions[0].label, "Connect Plex")
    ln = Watchlist_settingsRow({ available: true, plex: { username: "alex", needsReconnect: false } })
    eq(t, "linked value", ln.value, "Connected as alex")
    eq(t, "linked actions", kinds(ln.actions), "disconnect")
    eq(t, "disconnect label", ln.actions[0].label, "Disconnect")
    pz = Watchlist_settingsRow({ available: true, plex: { username: "alex", needsReconnect: true } })
    eq(t, "paused value", pz.value, "Connected as alex")
    eq(t, "paused actions", kinds(pz.actions), "reconnect,disconnect")
    eq(t, "reconnect label", pz.actions[0].label, "Reconnect Plex")
    eq(t, "linked without a name", Watchlist_settingsRow({ available: true, plex: { username: "", needsReconnect: false } }).value, "Connected")
end sub

sub testOptedOut(t as object)
    ' Someone who disconnected Plex is not linked again by a Requests sign-in.
    eq(t, "opted out read", Watchlist_fromResponse(200, { entries: [], plexOptedOut: true }).plexOptedOut, true)
    eq(t, "missing field is false", Watchlist_fromResponse(200, { entries: [] }).plexOptedOut, false)
    eq(t, "404 view not opted out", Watchlist_fromResponse(404, invalid).plexOptedOut, false)
    eq(t, "opted out: skip", Watchlist_autoLinkStep({ available: true, plex: invalid, plexOptedOut: true }), "skip")
    eq(t, "not opted out: first", Watchlist_autoLinkStep({ available: true, plex: invalid, plexOptedOut: false }), "first")
    eq(t, "older view without the field: first", Watchlist_autoLinkStep({ available: true, plex: invalid }), "first")
end sub

sub testCoverTags(t as object)
    ' The Lists card draws on-server posters with their image tag, so a
    ' replaced poster gets a new url instead of a stale cached copy.
    cover = [{ itemId: "a", posterUrl: "" }, { itemId: "", posterUrl: "https://image.tmdb.org/t/p/w500/p.jpg" }, { itemId: "b", posterUrl: "" }]
    items = { a: { Id: "a", ImageTags: { Primary: "tagA" } }, b: { Id: "b" } }
    tagged = Watchlist_tagCover(cover, items)
    eq(t, "on server: its tag", tagged[0].tag, "tagA")
    eq(t, "not on server: no tag", tagged[1].tag, "")
    eq(t, "item without tags: none", tagged[2].tag, "")
    eq(t, "no items at all", Watchlist_tagCover(cover, invalid)[0].tag, "")
    eq(t, "a missing title's poster stays dimmed", Watchlist_tagCover(cover, items)[1].dimmed, true)
    eq(t, "an on-server poster is sharp", Watchlist_tagCover(cover, items)[0].dimmed, false)
    eq(t, "ids to look up", Watchlist_coverItemIds(cover), "a,b")
    eq(t, "nothing to look up", Watchlist_coverItemIds([{ itemId: "", posterUrl: "x" }]), "")
end sub


' ---------- v2: + Add search ----------

function hitJson(title as string, itemId as dynamic, onWatchlist as boolean) as object
    return { type: "Movie", title: title, year: 2021, tmdbId: "438631", tvdbId: invalid, imdbId: "tt1160419", posterUrl: "https://image.tmdb.org/t/p/original/a.jpg", overview: "o", itemId: itemId, onWatchlist: onWatchlist, watchlistEntryId: invalid }
end function

sub testSearchReady(t as object)
    eq(t, "one letter waits", Watchlist_searchReady("d"), false)
    eq(t, "two letters search", Watchlist_searchReady("du"), true)
    eq(t, "spaces don't count", Watchlist_searchReady("  d  "), false)
    long = String(201, "a")
    eq(t, "over 200 is refused", Watchlist_searchReady(long), false)
end sub

sub testSearchResponse(t as object)
    eq(t, "404: no + Add", Watchlist_searchFromResponse(404, invalid).available, false)
    eq(t, "404 is not a failure", Watchlist_searchFromResponse(404, invalid).failed, false)
    eq(t, "500 fails", Watchlist_searchFromResponse(500, invalid).failed, true)
    data = { query: "dune", onServer: [hitJson("Dune", "abc", true)], notOnServer: [hitJson("Dune: Part Three", invalid, false), { type: "Episode", title: "x", tmdbId: "1" }, { type: "Movie", title: "", tmdbId: "2" }, { type: "Movie", title: "No ids" }] }
    r = Watchlist_searchFromResponse(200, data)
    eq(t, "query echoed", r.query, "dune")
    eq(t, "on server", r.onServer.count(), 1)
    eq(t, "bad hits dropped", r.notOnServer.count(), 1)
    h = r.onServer[0]
    eq(t, "hit item", h.itemId, "abc")
    eq(t, "null id reads empty", h.tvdbId, "")
    eq(t, "on watchlist", h.onWatchlist, true)
    eq(t, "numeric ids read as strings", Watchlist_searchFromResponse(200, { query: "q", onServer: [], notOnServer: [{ type: "Series", title: "S", tvdbId: 81189 }] }).notOnServer[0].tvdbId, "81189")
    eq(t, "missing groups read empty", Watchlist_searchFromResponse(200, { query: "q" }).onServer.count(), 0)
end sub

function rowKinds(rows as object) as string
    out = []
    for each r in rows
        out.push(r.kind)
    end for
    return joined(out)
end function

sub testSearchRows(t as object)
    r = Watchlist_searchFromResponse(200, { query: "dune", onServer: [hitJson("Dune", "abc", true)], notOnServer: [hitJson("Dune Two", invalid, false)] })
    rows = Watchlist_searchRows(r, {})
    eq(t, "two groups", rowKinds(rows), "header,hit,header,hit")
    eq(t, "first header", rows[0].text, "On your server")
    eq(t, "second header", rows[2].text, "Not on server")
    eq(t, "already on it", rows[1].added, true)
    eq(t, "not yet", rows[3].added, false)
    added = {}
    added[Watchlist_hitKey(r.notOnServer[0])] = true
    eq(t, "added on this screen", Watchlist_searchRows(r, added)[3].added, true)
    empty = Watchlist_searchFromResponse(200, { query: "zz", onServer: [], notOnServer: [] })
    eq(t, "empty groups say so", rowKinds(Watchlist_searchRows(empty, {})), "header,empty,header,empty")
    eq(t, "empty text", Watchlist_searchRows(empty, {})[1].text, "No results")
    eq(t, "hit line movie", Watchlist_hitLine({ type: "Movie", year: 2025 }), "2025 " + Chr(183) + " Movie")
    eq(t, "hit line show", Watchlist_hitLine({ type: "Series", year: -1 }), "Show")
    eq(t, "add label", Watchlist_addLabel(false), "+ Add")
    eq(t, "added label", Watchlist_addLabel(true), Chr(10003) + " Added")
end sub

sub testHitBody(t as object)
    h = Watchlist_searchFromResponse(200, { query: "d", onServer: [], notOnServer: [hitJson("Dune", invalid, false)] }).notOnServer[0]
    b = Watchlist_hitBody(h)
    eq(t, "type", b.type, "Movie")
    eq(t, "title", b.title, "Dune")
    eq(t, "year", b.year, 2021)
    eq(t, "tmdb", b.tmdbId, "438631")
    eq(t, "imdb", b.imdbId, "tt1160419")
    eq(t, "no empty tvdb", b.DoesExist("tvdbId"), false)
    eq(t, "poster", b.posterUrl, "https://image.tmdb.org/t/p/original/a.jpg")
    eq(t, "no overview in the body", b.DoesExist("overview"), false)
end sub

sub testHitOpen(t as object)
    r = Watchlist_searchFromResponse(200, { query: "d", onServer: [hitJson("Dune", "abc", false)], notOnServer: [hitJson("Dune 3", invalid, false)] })
    o = Watchlist_hitOpen(r.onServer[0])
    eq(t, "library title opens its page", o.kind, "item")
    eq(t, "with its id", o.item.Id, "abc")
    eq(t, "and type", o.item.Type, "Movie")
    eq(t, "missing title opens details", Watchlist_hitOpen(r.notOnServer[0]).kind, "details")
end sub

' ---------- v2: the title page for titles not on the server ----------

sub testDetailsQuery(t as object)
    eq(t, "every id", Watchlist_detailsQuery({ type: "Movie", tmdbId: "438631", tvdbId: "", imdbId: "tt1160419" }), "type=movie&tmdbId=438631&imdbId=tt1160419")
    eq(t, "series", Watchlist_detailsQuery({ type: "Series", tmdbId: "", tvdbId: "81189", imdbId: "" }), "type=series&tvdbId=81189")
end sub

sub testDetailsResponse(t as object)
    d = Watchlist_detailsFromResponse(200, { type: "Movie", title: "Dune", year: 2021, overview: "o", posterUrl: "p", backdropUrl: "b", runtimeMinutes: 155, officialRating: "PG-13", genres: ["Science Fiction", "Adventure"], communityRating: 7.8, source: "TMDB", tmdbId: "438631", imdbId: "tt1160419", onWatchlist: true, watchlistEntryId: "e1" })
    eq(t, "found", d.found, true)
    eq(t, "title", d.title, "Dune")
    eq(t, "runtime", d.runtimeMinutes, 155)
    eq(t, "missing tvdb", d.tvdbId, "")
    eq(t, "on watchlist", d.onWatchlist, true)
    eq(t, "entry id", d.entryId, "e1")
    eq(t, "not on the server", d.itemId, "")
    eq(t, "source line", Watchlist_detailsSource(d), "Details from TMDB")
    eq(t, "no source, no line", Watchlist_detailsSource({ source: "" }), "")
    nf = Watchlist_detailsFromResponse(404, invalid)
    eq(t, "404: not found", nf.found, false)
    eq(t, "404 is no failure", nf.failed, false)
    eq(t, "500 fails", Watchlist_detailsFromResponse(500, invalid).failed, true)
    eq(t, "the library has it", Watchlist_detailsFromResponse(200, { type: "Series", title: "S", itemId: "abc", onWatchlist: false }).itemId, "abc")
end sub

sub testDetailsMeta(t as object)
    dot = " " + Chr(183) + " "
    d = { type: "Movie", year: 2021, runtimeMinutes: 155, seasonCount: 0, officialRating: "PG-13", genres: ["Science Fiction", "Adventure", "Drama"], communityRating: 7.8 }
    eq(t, "movie line", Watchlist_detailsMeta(d), "2021" + dot + "2h 35m" + dot + "PG-13" + dot + "Science Fiction, Adventure" + dot + Chr(9733) + " 7.8")
    s = { type: "Series", year: 2017, runtimeMinutes: 0, seasonCount: 4, officialRating: "", genres: [], communityRating: 0 }
    eq(t, "series line", Watchlist_detailsMeta(s), "2017" + dot + "4 Seasons")
    eq(t, "one season", Watchlist_detailsMeta({ type: "Series", year: -1, runtimeMinutes: 0, seasonCount: 1, officialRating: "", genres: [], communityRating: 0 }), "1 Season")
end sub

sub testDetailsButtons(t as object)
    eq(t, "add, request", kinds(Watchlist_detailsButtons(false, true, false, true)), "toggle,request")
    eq(t, "add label", Watchlist_detailsButtons(false, true, false, true)[0].label, "Add to Watchlist")
    eq(t, "on watchlist label", Watchlist_detailsButtons(true, true, false, true)[0].label, Chr(10003) + " On Watchlist")
    eq(t, "requested", kinds(Watchlist_detailsButtons(true, true, true, true)), "toggle,requested")
    eq(t, "signed out", kinds(Watchlist_detailsButtons(true, false, false, true)), "toggle,signin")
    eq(t, "signin label", Watchlist_detailsButtons(true, false, false, true)[1].label, "Sign in to Requests")
    eq(t, "nothing Seerr can open", kinds(Watchlist_detailsButtons(false, true, false, false)), "toggle")
end sub

' ---------- v2: the Requests address set by the server ----------

sub testRequestsAddress(t as object)
    eq(t, "set", Watchlist_requestsAddress(200, { requestsUrl: "https://requests.example.com" }), "https://requests.example.com")
    eq(t, "trailing slash dropped", Watchlist_requestsAddress(200, { requestsUrl: "https://requests.example.com/seerr/" }), "https://requests.example.com/seerr")
    eq(t, "null", Watchlist_requestsAddress(200, { requestsUrl: invalid }), "")
    eq(t, "not http", Watchlist_requestsAddress(200, { requestsUrl: "ftp://x.example.com" }), "")
    eq(t, "older plugin", Watchlist_requestsAddress(404, invalid), "")
    eq(t, "failure", Watchlist_requestsAddress(500, invalid), "")
end sub

sub testEntryOpensDetails(t as object)
    ' A Watchlist title the server doesn't have opens its title page now,
    ' signed into Requests or not.
    missing = entry("m", "Movie", "", "12")
    eq(t, "signed in", Watchlist_onSelect(missing, true).kind, "details")
    eq(t, "signed out", Watchlist_onSelect(missing, false).kind, "details")
    eq(t, "carries the entry", Watchlist_onSelect(missing, false).entry.id, "m")
    eq(t, "no ids still opens it", Watchlist_onSelect(entry("n", "Movie", "", ""), false).kind, "details")
end sub

sub testTitleSources(t as object)
    e = entry("m", "Movie", "", "12")
    e.posterUrl = "https://image.tmdb.org/t/p/w500/p.jpg"
    src = Watchlist_entrySource(e)
    eq(t, "entry: on the watchlist", src.onWatchlist, true)
    eq(t, "entry: its id to remove", src.entryId, "m")
    eq(t, "entry: ids", src.tmdbId, "12")
    eq(t, "entry: poster", src.posterUrl, e.posterUrl)
    h = Watchlist_searchFromResponse(200, { query: "d", onServer: [], notOnServer: [hitJson("Dune", invalid, false)] }).notOnServer[0]
    hs = Watchlist_hitSource(h, false)
    eq(t, "hit: not on it", hs.onWatchlist, false)
    eq(t, "hit: no entry", hs.entryId, "")
    eq(t, "hit added on the search screen", Watchlist_hitSource(h, true).onWatchlist, true)
    eq(t, "empty text with + Add", Watchlist_emptyText(true), "Nothing on your Watchlist yet. Choose + Add to find something.")
    eq(t, "empty text without", Watchlist_emptyText(false), Watchlist_EMPTY_TEXT())
end sub
