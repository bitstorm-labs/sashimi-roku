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
    s = Watchlist_onSelect(entry("b", "Series", "", "42"), true)
    eq(t, "missing and signed in: seerr page", s.kind, "seerr")
    eq(t, "seerr kind for a series", s.target.kind, "tv")
    eq(t, "seerr tmdb id", s.target.tmdbId, 42)
    eq(t, "seerr title", s.target.title, "T b")
    e = Watchlist_onSelect(entry("c", "Movie", "", "42"), false)
    eq(t, "seerr signed out: explain", e.kind, "explain")
    eq(t, "seerr signed out message", e.message, "Sign into Requests to ask for this.")
    eq(t, "explain title", e.title, "T c")
    n = Watchlist_onSelect(entry("d", "Movie", "", ""), true)
    eq(t, "no tmdb id: explain", n.kind, "explain")
    eq(t, "no tmdb id message", n.message, "Sashimi can't look this title up to request it.")
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

