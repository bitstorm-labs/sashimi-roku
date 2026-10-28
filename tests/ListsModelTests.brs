' Off-device tests for source/utils/ListsModel.bs (with SharedLists.bs), run by
' tests/run.js. What the screens and the API task make of the server's answers
' for shared lists: cards from a list's visible entries, counts, the series
' anchor, the duplicate check, the subscriptions DisplayPreferences body, the
' 404 prune, creator names, the copy, and the Home rows a subscription adds.

sub main()
    t = { passed: 0, failed: 0 }

    testCards(t)
    testCountsIgnoreItemIds(t)
    testSeriesAnchor(t)
    testHasTitle(t)
    testPrefs(t)
    testMissing(t)
    testOwner(t)
    testCopy(t)
    testHomeRows(t)
    testMoves(t)
    testPicker(t)
    testDetailPage(t)

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
        s = s + v
    end for
    return s
end function

' What /Playlists/{id}/Items returns per entry, trimmed to what matters.
function movie(id as string) as object
    return { Id: id, Type: "Movie", Name: "Movie " + id, PlaylistItemId: "p" + id, ImageTags: { Primary: "t" + id } }
end function

function episode(id as string, series as string, season as integer, number as integer) as object
    return { Id: id, Type: "Episode", Name: "Ep " + id, SeriesId: series, SeriesName: "Show " + series, SeriesPrimaryImageTag: "st" + series, ParentIndexNumber: season, IndexNumber: number, PlaylistItemId: "p" + id }
end function

function cardIds(cards as object) as string
    out = []
    for each c in cards
        s = c.id
        if c.isSeries then s = s + "/series"
        out.push(s + "@" + c.index.ToStr())
    end for
    return joined(out)
end function

sub testCards(t as object)
    items = [episode("e1", "s1", 1, 1), movie("m1"), episode("e2", "s1", 1, 2), movie("m1"), episode("e5", "s1", 1, 1)]
    cards = ListsModel_cards(items)
    ' The FIRST entry stands for a repeated title, so its entry id is the one
    ' the owner tools move and remove.
    eq(t, "cards keep the first entry", cardIds(cards), "s1/series@0,m1@1,e2@2")
    eq(t, "card entry id", cards[1].entryId, "pm1")
    eq(t, "display ids", joined(ListsModel_displayIds(cards)), "s1,m1,e2")

    ' A series card opens and draws the series, from the episode's own fields.
    s = ListsModel_cardItem(cards[0])
    eq(t, "series card id", s.Id, "s1")
    eq(t, "series card type", s.Type, "Series")
    eq(t, "series card name", s.Name, "Show s1")
    eq(t, "series card poster tag", s.ImageTags.Primary, "sts1")
    eq(t, "movie card is the item", ListsModel_cardItem(cards[1]).Id, "m1")
    eq(t, "no items", ListsModel_cards(invalid).count(), 0)
end sub

' Review focus 3: PlaylistDto.ItemIds lists every entry, parental limits or
' not; /Items is filtered for the viewer. Counts come from /Items only.
sub testCountsIgnoreItemIds(t as object)
    playlist = { OpenAccess: true, Shares: [], ItemIds: ["m1", "m2"] }
    visible = [movie("m1")]
    eq(t, "count is the viewer's", ListsModel_visibleCount(visible), 1)
    eq(t, "count ignores the dto", ListsModel_listCount(playlist, visible), 1)
    eq(t, "new count from visible", ListsModel_newCountFor(visible, []), 1)
end sub

sub testSeriesAnchor(t as object)
    eps = [episode("x0", "s", 0, 1), episode("x22", "s", 2, 2), episode("x21", "s", 2, 1), { Id: "nonum", Type: "Episode" }]
    eq(t, "lowest season >= 1, lowest episode", ListsModel_seriesAnchor(eps).Id, "x21")
    eps.push(episode("x13", "s", 1, 3))
    eq(t, "season 1 wins", ListsModel_seriesAnchor(eps).Id, "x13")
    eq(t, "specials only: none", ListsModel_seriesAnchor([episode("x0", "s", 0, 1)]), invalid)
    eq(t, "nothing: none", ListsModel_seriesAnchor(invalid), invalid)
end sub

sub testHasTitle(t as object)
    items = [episode("e1", "s1", 1, 1), movie("m1"), episode("e7", "s2", 2, 3)]
    eq(t, "movie already on", ListsModel_hasTitle(items, "m1", ""), true)
    eq(t, "movie not on", ListsModel_hasTitle(items, "m2", ""), false)
    ' A show whose S1:E1 is on the list is on the list, whatever its anchor id.
    eq(t, "series via its pilot", ListsModel_hasTitle(items, "other", "s1"), true)
    eq(t, "series via its anchor entry", ListsModel_hasTitle(items, "e7", "s2"), true)
    eq(t, "series not on", ListsModel_hasTitle(items, "e9", "s9"), false)
    ' Adding an episode that is its show's pilot checks the entry itself.
    eq(t, "pilot episode on", ListsModel_hasTitle(items, "e1", ""), true)
end sub

sub testPrefs(t as object)
    dto = { Id: "abc", Client: "sashimi", SortBy: "SortName", CustomPrefs: { other: "keep", subscriptions: "[]" } }
    body = ListsModel_prefsBody(dto, [{ id: "a", seen: ["x"] }])
    eq(t, "save keeps other keys", body.CustomPrefs.other, "keep")
    eq(t, "save keeps the dto", body.SortBy, "SortName")
    eq(t, "save writes subscriptions", joined([body.CustomPrefs.subscriptions]), "[{""id"":""a"",""seen"":[""x""]}]")
    eq(t, "save leaves the read copy alone", dto.CustomPrefs.subscriptions, "[]")
    eq(t, "reads back", ListsModel_subsFromPrefs(body)[0].seen[0], "x")
    ' A server that answered with no CustomPrefs still gets a whole body.
    bare = ListsModel_prefsBody({ Id: "abc" }, [])
    eq(t, "bare dto gains CustomPrefs", bare.CustomPrefs.subscriptions, "[]")
    eq(t, "nothing read: no subscriptions", ListsModel_subsFromPrefs(invalid).count(), 0)
    eq(t, "prefs path", ListsModel_prefsPath("u1"), "/DisplayPreferences/sashimi-lists?userId=u1&client=sashimi")
end sub

' Review focus 1: a 404 (deleted, or made private) prunes the subscription;
' anything else (a timeout, a 500) keeps it.
sub testMissing(t as object)
    eq(t, "404 is gone", ListsModel_isGone(404), true)
    eq(t, "timeout is not", ListsModel_isGone(0), false)
    eq(t, "500 is not", ListsModel_isGone(500), false)
    subs = [{ id: "a", seen: [] }, { id: "b", seen: [] }]
    eq(t, "404 prunes", ListsModel_afterLoad(subs, ["a"])[0].id, "b")
    eq(t, "404 prunes one", ListsModel_afterLoad(subs, ["a"]).count(), 1)
end sub

sub testOwner(t as object)
    users = { u1: "Marge", u2: "Robert" }
    o = ListsModel_owner({ Shares: [{ UserId: "u1", CanEdit: true }] }, users, "u2")
    eq(t, "owner name", o.name, "Marge")
    eq(t, "not mine", o.isMine, false)
    eq(t, "mine", ListsModel_owner({ Shares: [{ UserId: "u2", CanEdit: true }] }, users, "u2").isMine, true)
    ' Made outside Sashimi (no self-share), or its creator was deleted.
    eq(t, "no self-share", ListsModel_owner({ Shares: [] }, users, "u2").name, "")
    eq(t, "deleted creator", ListsModel_owner({ Shares: [{ UserId: "gone", CanEdit: true }] }, users, "u2").name, "")
    eq(t, "users map from /Users", ListsModel_userNames([{ Id: "u1", Name: "Marge" }, { Name: "no id" }]).u1, "Marge")
end sub

sub testCopy(t as object)
    eq(t, "row title", ListsModel_rowTitle("Christmas Movies", "Marge"), "From Marge: Christmas Movies")
    eq(t, "orphan row title", ListsModel_rowTitle("Christmas Movies", ""), "Christmas Movies")
    eq(t, "row title with new", ListsModel_rowTitleWithNew("From Marge: X", 3), "From Marge: X  " + Chr(8226) + "  3 new")
    eq(t, "row title nothing new", ListsModel_rowTitleWithNew("From Marge: X", 0), "From Marge: X")
    eq(t, "titles", ListsModel_titles(1), "1 title")
    eq(t, "titles plural", ListsModel_titles(12), "12 titles")
    eq(t, "own card", ListsModel_cardMeta(true, true, "", 12), "Public " + Chr(183) + " 12 titles")
    eq(t, "own private card", ListsModel_cardMeta(true, false, "", 5), "Private " + Chr(183) + " 5 titles")
    eq(t, "other card", ListsModel_cardMeta(false, true, "Marge", 18), "Marge " + Chr(183) + " 18 titles")
    eq(t, "orphan card", ListsModel_cardMeta(false, true, "", 2), "Shared list " + Chr(183) + " 2 titles")
    eq(t, "byline", ListsModel_byline(false, "Marge"), "A list by Marge")
    eq(t, "own byline", ListsModel_byline(true, "Marge"), "Your list")
    eq(t, "orphan byline", ListsModel_byline(false, ""), "Shared list")
    eq(t, "subscriber line", ListsModel_detailLine(false, true, true, 18, 3), "18 titles " + Chr(183) + " 3 new since you last looked")
    eq(t, "subscriber line nothing new", ListsModel_detailLine(false, true, true, 18, 0), "18 titles")
    eq(t, "owner line public", ListsModel_detailLine(true, true, false, 12, 0), "12 titles " + Chr(183) + " Public: everyone on the server can see and subscribe")
    eq(t, "owner line private", ListsModel_detailLine(true, false, false, 1, 0), "1 title " + Chr(183) + " Private: only you can see it")
    eq(t, "initial", ListsModel_initial("marge"), "M")
    eq(t, "initial of nothing", ListsModel_initial(""), "?")
end sub

function cfgIds(cfg as object) as string
    out = []
    for each c in cfg
        out.push(c.id)
    end for
    return joined(out)
end function

sub testHomeRows(t as object)
    base = [
        { id: "hero", kind: "hero", name: "Featured", visible: true },
        { id: "cw", kind: "cw", name: "Continue Watching", visible: true },
        { id: "fintv", kind: "fintv", name: "SashimiTV", visible: true },
        { id: "library_m", kind: "library", libraryId: "m", name: "Recently Added Movies", visible: true }
    ]
    rows = [{ id: "a", title: "From Marge: A" }]
    cfg = ListsModel_withListRows(base, rows)
    eq(t, "new subscription goes after Continue Watching", cfgIds(cfg), "hero,cw,list_a,fintv,library_m")
    eq(t, "its kind", cfg[2].kind, "list")
    eq(t, "its list id", cfg[2].listId, "a")
    eq(t, "shown on Home", cfg[2].visible, true)

    ' Moved and hidden in Settings: stays where it was put, stays hidden, and
    ' a renamed list takes its new name.
    moved = [base[0], base[1], base[2], base[3], { id: "list_a", kind: "list", listId: "a", name: "old", visible: false }]
    cfg = ListsModel_withListRows(moved, [{ id: "a", title: "From Marge: A2" }, { id: "b", title: "B" }])
    eq(t, "existing row keeps its place; next new one after CW", cfgIds(cfg), "hero,cw,list_b,fintv,library_m,list_a")
    eq(t, "hidden stays hidden", cfg[5].visible, false)
    eq(t, "renamed", cfg[5].name, "From Marge: A2")

    ' Unsubscribed (here or on another device): the row goes.
    cfg = ListsModel_withListRows(moved, [])
    eq(t, "unsubscribed row dropped", cfgIds(cfg), "hero,cw,fintv,library_m")
    eq(t, "unchanged config is equal", ListsModel_sameConfig(base, ListsModel_withListRows(base, [])), true)

    ' Where a list row goes among the rows actually on screen: after the
    ' nearest config entry before it that is shown, else first.
    cfg = [base[0], base[1], { id: "list_a", kind: "list", listId: "a" }, base[2], base[3], { id: "list_b", kind: "list", listId: "b" }]
    eq(t, "after CW", ListsModel_rowPosition(cfg, "list_a", ["cw", "fintv", "library_m"]), 1)
    eq(t, "after the last library", ListsModel_rowPosition(cfg, "list_b", ["cw", "fintv", "library_m"]), 3)
    eq(t, "no CW on screen: first", ListsModel_rowPosition(cfg, "list_a", ["fintv", "library_m"]), 0)
    eq(t, "after a list row already placed", ListsModel_rowPosition([base[1], { id: "list_a", kind: "list" }, { id: "list_b", kind: "list" }], "list_b", ["cw", "list_a"]), 2)
end sub

sub testMoves(t as object)
    cards = ListsModel_cards([movie("a"), movie("b"), movie("b"), movie("c")])
    ' Indices are the server's entry positions (the duplicate b sits at 2).
    eq(t, "move first", ListsModel_moveIndex(cards, 2, "first"), 0)
    eq(t, "move earlier", ListsModel_moveIndex(cards, 2, "earlier"), 1)
    eq(t, "move later", ListsModel_moveIndex(cards, 0, "later"), 1)
    eq(t, "move last", ListsModel_moveIndex(cards, 0, "last"), 3)
    eq(t, "already first", ListsModel_moveIndex(cards, 0, "earlier"), -1)
    eq(t, "already last", ListsModel_moveIndex(cards, 2, "last"), -1)
end sub

sub testPicker(t as object)
    lists = [{ name: "Date Night", isPublic: true, count: 12, already: false }, { name: "Holiday", isPublic: false, count: 1, already: true }]
    eq(t, "picker labels", joined(ListsModel_pickerLabels(lists)), "Date Night  " + Chr(183) + "  Public " + Chr(183) + " 12,Holiday  " + Chr(183) + "  Already on this list,+ New List" + Chr(8230))
    eq(t, "picker title", ListsModel_pickerTitle("Klaus"), "Add " + Chr(8220) + "Klaus" + Chr(8221) + " to" + Chr(8230))
    eq(t, "public toggle label", ListsModel_publicLabel(false), "Public: Off")
    eq(t, "added", ListsModel_addedMessage("Holiday", false), "Added to Holiday")
    eq(t, "already", ListsModel_addedMessage("Holiday", true), "Already on Holiday")
    eq(t, "can add a movie", ListsModel_canAdd("Movie"), true)
    eq(t, "can add a series", ListsModel_canAdd("Series"), true)
    eq(t, "can add an episode", ListsModel_canAdd("Episode"), true)
    eq(t, "not a season", ListsModel_canAdd("Season"), false)
    eq(t, "not a person", ListsModel_canAdd("Person"), false)
end sub

function kindsOf(defs as object) as string
    out = []
    for each d in defs
        out.push(d.kind)
    end for
    return joined(out)
end function

sub testDetailPage(t as object)
    eq(t, "subscriber row", kindsOf(ListsModel_detailButtons(false, false, true)), "subscribe,shuffle")
    b = ListsModel_detailButtons(false, true, true)
    eq(t, "subscribed row", kindsOf(b), "unsubscribe,shuffle")
    eq(t, "subscribed label", b[0].label, Chr(10003) + " Subscribed")
    eq(t, "owner row", kindsOf(ListsModel_detailButtons(true, false, true)), "subscribe,shuffle,edit")
    eq(t, "empty list: no shuffle", kindsOf(ListsModel_detailButtons(true, false, false)), "subscribe,edit")
    eq(t, "edit menu public", kindsOf(ListsModel_editMenu(true, true)), "rename,private,reorder,remove,delete")
    eq(t, "edit menu private empty", kindsOf(ListsModel_editMenu(false, false)), "rename,public,delete")
    eq(t, "move menu", kindsOf(ListsModel_moveMenu()), "first,earlier,later,last")
    eq(t, "no mode, no hint", ListsModel_modeHint(""), "")
end sub
