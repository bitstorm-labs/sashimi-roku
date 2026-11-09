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
    testZones(t)
    testLinkOutcome(t)
    testAutoLink(t)
    testCover(t)

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
        plex: { username: "chad", needsReconnect: false }, cardDismissed: true,
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
    eq(t, "plex username", v.plex.username, "chad")
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
    linked = { plex: { username: "chad", needsReconnect: false }, cardDismissed: false }
    paused = { plex: { username: "chad", needsReconnect: true }, cardDismissed: true }
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

sub testZones(t as object)
    eq(t, "card first", Watchlist_firstZone(true, 0), "card")
    eq(t, "grid when no card", Watchlist_firstZone(false, 3), "grid")
    eq(t, "nothing focusable", Watchlist_firstZone(false, 0), "none")
end sub

sub testLinkOutcome(t as object)
    ok = Watchlist_linkOutcome(200, { username: "chad", needsReconnect: false })
    eq(t, "linked", ok.kind, "linked")
    eq(t, "linked name", ok.username, "chad")
    c = Watchlist_linkOutcome(409, { username: "mondo", newUsername: "chad" })
    eq(t, "conflict", c.kind, "conflict")
    eq(t, "conflict current", c.username, "mondo")
    eq(t, "conflict wanted", c.newUsername, "chad")
    eq(t, "conflict junk body", Watchlist_linkOutcome(409, invalid).newUsername, "")
    eq(t, "plex rejected the token", Watchlist_linkOutcome(422, invalid).kind, "rejected")
    ' 401 is the Jellyfin session, not Plex: never "Plex didn't accept that sign-in".
    eq(t, "401 is not a Plex rejection", Watchlist_linkOutcome(401, invalid).kind, "failed")
    eq(t, "no plugin", Watchlist_linkOutcome(404, invalid).kind, "unavailable")
    eq(t, "offline", Watchlist_linkOutcome(0, invalid).kind, "failed")
end sub

sub testAutoLink(t as object)
    eq(t, "no watchlist: skip", Watchlist_autoLinkStep({ available: false, plex: invalid }), "skip")
    eq(t, "unlinked: first", Watchlist_autoLinkStep({ available: true, plex: invalid }), "first")
    eq(t, "linked: refresh", Watchlist_autoLinkStep({ available: true, plex: { username: "x", needsReconnect: false } }), "refresh")
    p = Watchlist_replacePrompt("chad", "mondo")
    eq(t, "prompt title", p.title, "Sync your Watchlist with Plex account chad instead?")
    eq(t, "prompt message", p.message, "It syncs with mondo now.")
    eq(t, "prompt without a name", Watchlist_replacePrompt("", "mondo").title, "Sync your Watchlist with this Plex account instead?")
    eq(t, "switch label", Watchlist_switchLabel("chad"), "Switch to chad")
    eq(t, "switch label without a name", Watchlist_switchLabel(""), "Switch Account")
end sub

sub testCover(t as object)
    eq(t, "card meta", Watchlist_cardMeta(3), "Private " + Chr(183) + " 3")
    five = [entry("a", "Movie", "x", "1"), entry("b", "Movie", "y", "2"), entry("c", "Movie", "z", "3"), entry("d", "Movie", "w", "4"), entry("e", "Movie", "v", "5")]
    eq(t, "four of five", Watchlist_coverSources(five).count(), 4)
    two = [entry("a", "Movie", "x", "1"), entry("b", "Movie", "y", "2")]
    eq(t, "two: one", Watchlist_coverSources(two).count(), 1)
    poster = entry("p", "Movie", "", "1")
    poster.posterUrl = "https://image.tmdb.org/t/p/w500/p.jpg"
    bare = entry("q", "Movie", "", "2")
    c = Watchlist_coverSources([bare, poster])
    eq(t, "skips entries with neither", c.count(), 1)
    eq(t, "missing title's poster", c[0].posterUrl, poster.posterUrl)
    eq(t, "nothing drawable", Watchlist_coverSources([bare]).count(), 0)
end sub
