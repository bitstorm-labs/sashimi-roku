' Off-device tests for source/utils/RailItems.bs, run by tests/run.js against
' the transpiled module (out/source/utils/RailItems.brs): which destinations
' the side menu lists and in what order, given the Home & Side Menu config.

sub main()
    t = { passed: 0, failed: 0 }

    testDefaults(t)
    testHiddenDrop(t)
    testAlwaysShown(t)
    testOrder(t)
    testNewAndStale(t)
    testIndependentOfHome(t)
    testWithFintv(t)
    testMarks(t)
    testToggle(t)
    testLists(t)
    testMenuFollowsRows(t)
    testRequestsRow(t)
    testDashboard(t)
    testEditorView(t)
    testHomeOrder(t)

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

function lib(id as string, visible as boolean, rail as dynamic) as object
    e = { id: "library_" + id, kind: "library", libraryId: id, name: "Recently Added " + id, visible: visible }
    if rail <> invalid then e.rail = rail
    return e
end function

function baseConfig() as object
    return [
        { id: "hero", kind: "hero", name: "Featured", visible: true },
        { id: "cw", kind: "cw", name: "Continue Watching", visible: true },
        { id: "fintv", kind: "fintv", name: "SashimiTV", visible: true, rail: true },
        lib("m", true, true),
        lib("tv", true, true),
        lib("yt", true, true)
    ]
end function

sub testDefaults(t as object)
    eq(t, "no config lists everything", joined(RailItems_ids(["m", "tv"], invalid)), "home,fintv,lib:m,lib:tv,lists,search,settings")
    eq(t, "empty config lists everything", joined(RailItems_ids(["m", "tv"], [])), "home,fintv,lib:m,lib:tv,lists,search,settings")
    ' Configs saved before the menu toggle have no `rail` field.
    old = [lib("m", true, invalid), lib("tv", false, invalid)]
    eq(t, "pre-toggle config shows all", joined(RailItems_ids(["m", "tv"], old)), "home,fintv,lib:m,lib:tv,lists,search,settings")
end sub

sub testHiddenDrop(t as object)
    c = baseConfig()
    c[4].rail = false
    eq(t, "hidden library drops", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,fintv,lib:m,lib:yt,lists,search,settings")
    c[2].rail = false
    eq(t, "hidden SashimiTV drops", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,lib:m,lib:yt,lists,search,settings")
end sub

sub testAlwaysShown(t as object)
    c = baseConfig()
    for each e in c
        e.rail = false
        e.visible = false
    end for
    c.push({ id: "lists", kind: "lists", name: "Lists", rail: false })
    c.push({ id: "home", kind: "home", rail: false })
    c.push({ id: "search", kind: "search", rail: false })
    c.push({ id: "settings", kind: "settings", rail: false })
    eq(t, "Home, Search, Settings can't drop", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,search,settings")
end sub

sub testOrder(t as object)
    c = baseConfig()
    ' Home row order: yt, m, tv.
    c = [c[0], c[1], c[2], c[5], c[3], c[4]]
    eq(t, "libraries follow the Home order", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,fintv,lib:yt,lib:m,lib:tv,lists,search,settings")
    ' SashimiTV dragged below the libraries moves in the menu too: the menu
    ' follows the Home rows exactly (it used to stay pinned under Home).
    c2 = [c[0], c[1], c[3], c[4], c[5], c[2]]
    eq(t, "SashimiTV follows its row", joined(RailItems_ids(["m", "tv", "yt"], c2)), "home,lib:yt,lib:m,lib:tv,fintv,lists,search,settings")
end sub

sub testNewAndStale(t as object)
    c = baseConfig()
    eq(t, "new library appended, visible", joined(RailItems_ids(["new", "m", "tv", "yt"], c)), "home,fintv,lib:m,lib:tv,lib:yt,lib:new,lists,search,settings")
    eq(t, "removed library ignored", joined(RailItems_ids(["m", "yt"], c)), "home,fintv,lib:m,lib:yt,lists,search,settings")
    c.push(lib("m", true, false))
    eq(t, "duplicate entry: first wins", joined(RailItems_ids(["m"], c)), "home,fintv,lib:m,lists,search,settings")
    junk = [invalid, { kind: 5 }, { kind: "library" }, { kind: "library", libraryId: 7 }, "x"]
    eq(t, "malformed entries ignored", joined(RailItems_ids(["m"], junk)), "home,fintv,lib:m,lists,search,settings")
end sub

sub testIndependentOfHome(t as object)
    c = baseConfig()
    c[3].visible = false
    eq(t, "hidden on Home, still in menu", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,fintv,lib:m,lib:tv,lib:yt,lists,search,settings")
    eq(t, "hidden on Home only: reachable", RailItems_onlyFromSearch(c[3]), false)
    c[3].rail = false
    eq(t, "hidden everywhere: footnote", RailItems_onlyFromSearch(c[3]), true)
    c[0].visible = false
    eq(t, "hero is never a destination", RailItems_onlyFromSearch(c[0]), false)
end sub

sub testWithFintv(t as object)
    c = [{ id: "hero", kind: "hero", visible: true }, { id: "cw", kind: "cw", visible: true }, lib("m", true, invalid)]
    r = RailItems_withFintv(c)
    eq(t, "added once", r.count(), 4)
    eq(t, "right after Continue Watching", r[2].kind, "fintv")
    eq(t, "defaults to shown", RailItems_inRail(r[2]) and RailItems_onHome(r[2]), true)
    eq(t, "idempotent", RailItems_withFintv(r).count(), 4)
    r2 = RailItems_withFintv([lib("m", true, invalid)])
    eq(t, "no cw: first", r2[0].kind, "fintv")
end sub

sub testMarks(t as object)
    c = baseConfig()
    mk = RailItems_marks(c[1])
    eq(t, "Continue Watching: menu column is a dash", mk.home + "/" + mk.rail, "on/none")
    c[3].visible = false
    mk = RailItems_marks(c[3])
    eq(t, "library hidden on Home", mk.home + "/" + mk.rail, "off/on")
    c[3].rail = false
    mk = RailItems_marks(c[3])
    eq(t, "library hidden everywhere", mk.home + "/" + mk.rail, "off/off")
end sub

sub testToggle(t as object)
    e = lib("m", true, invalid)
    e = RailItems_toggleRail(e)
    eq(t, "first toggle hides", e.rail, false)
    e = RailItems_toggleRail(e)
    eq(t, "second shows", e.rail, true)
    cw = RailItems_toggleRail({ id: "cw", kind: "cw", visible: true })
    eq(t, "not a destination: untouched", cw.rail = invalid, true)
end sub

' Shared lists: Lists is a side-menu destination with no Home row of its own.
' It follows the libraries, shows unless hidden, and the editor's Home column
' is a dash for it.
sub testLists(t as object)
    c = baseConfig()
    eq(t, "Lists after the libraries", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,fintv,lib:m,lib:tv,lib:yt,lists,search,settings")
    r = RailItems_withLists(c)
    eq(t, "Lists added once", r.count(), 7)
    eq(t, "at the end", r[6].kind, "lists")
    eq(t, "named", r[6].name, "Lists")
    eq(t, "idempotent", RailItems_withLists(r).count(), 7)
    eq(t, "a destination", RailItems_isDestination(r[6]), true)
    eq(t, "no Home row", RailItems_hasHomeRow(r[6]), false)
    eq(t, "not on Home", RailItems_onHome(r[6]), false)
    mk = RailItems_marks(r[6])
    eq(t, "Home column is a dash", mk.home + "/" + mk.rail, "none/on")
    r[6] = RailItems_toggleRail(r[6])
    eq(t, "hidden from the menu", joined(RailItems_ids(["m", "tv", "yt"], r)), "home,fintv,lib:m,lib:tv,lib:yt,search,settings")
    eq(t, "hidden Lists is no Search-only footnote", RailItems_onlyFromSearch(r[6]), false)
    e = RailItems_toggleHome(r[6])
    eq(t, "OK does nothing to Lists", e.visible = invalid, true)
    ' A subscribed list's Home row: a Home toggle, no menu column.
    row = { id: "list_a", kind: "list", listId: "a", name: "From M: A", visible: true }
    eq(t, "list row is not a destination", RailItems_isDestination(row), false)
    mk = RailItems_marks(row)
    eq(t, "list row marks", mk.home + "/" + mk.rail, "on/none")
    eq(t, "OK hides a list row", RailItems_toggleHome(row).visible, false)
end sub

' What the menu must be for a config: its destinations in the config's own
' order, less hidden and unavailable ones (Apple's "menu from a row order").
function expectedMenu(libraryIds as object, config as object, available as dynamic) as string
    present = {}
    for each id in libraryIds
        present[id] = true
    end for
    out = "home"
    for each c in config
        k = c.kind
        if k = "library"
            if present.DoesExist(c.libraryId) and c.rail <> false then out = out + ",lib:" + c.libraryId
        else if k = "fintv" or k = "lists" or k = "requests" or k = "dashboard"
            ok = c.rail <> false
            if k = "requests" or k = "dashboard" then ok = ok and available <> invalid and available[k] = true
            if ok then out = out + "," + k
        end if
    end for
    return out + ",search,settings"
end function

function fullConfig() as object
    c = baseConfig()
    c.push({ id: "lists", kind: "lists", name: "Lists", rail: true })
    c.push({ id: "dashboard", kind: "dashboard", name: "Dashboard", rail: true })
    return RailItems_withRequests(c)
end function

' Settings > Home & Side Menu is one list: moving any destination there moves
' it in the side menu, whatever it is (owner: "the rail order doesn't match
' the row order").
sub testMenuFollowsRows(t as object)
    all = { requests: true, dashboard: true }
    libs = ["m", "tv", "yt"]
    c = fullConfig()
    eq(t, "default menu", joined(RailItems_ids(libs, c, all)), "home,requests,fintv,lib:m,lib:tv,lib:yt,lists,dashboard,search,settings")
    eq(t, "default matches the rows", joined(RailItems_ids(libs, c, all)), expectedMenu(libs, c, all))
    ' Every single move of one entry to every other place.
    moves = 0
    mismatches = 0
    for src = 0 to c.count() - 1
        for dst = 0 to c.count() - 1
            mv = []
            for each e in c
                mv.push(e)
            end for
            e = mv[src]
            mv.Delete(src)
            mv2 = []
            for k = 0 to mv.count() - 1
                if k = dst then mv2.push(e)
                mv2.push(mv[k])
            end for
            if dst >= mv.count() then mv2.push(e)
            mv = mv2
            moves = moves + 1
            if joined(RailItems_ids(libs, mv, all)) <> expectedMenu(libs, mv, all) then mismatches = mismatches + 1
        end for
    end for
    eq(t, "every move: the menu keeps the rows' order", mismatches, 0)
    eq(t, "moves tried", moves, c.count() * c.count())
    ' Lists moved above the libraries.
    mv = [c[0], c[1], c[2], c[3], c[7], c[4], c[5], c[6], c[8]]
    eq(t, "Lists where it was put", joined(RailItems_ids(libs, mv, all)), "home,requests,fintv,lists,lib:m,lib:tv,lib:yt,dashboard,search,settings")
    ' The Dashboard moved to the top.
    mv = [c[8], c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7]]
    eq(t, "Dashboard where it was put", joined(RailItems_ids(libs, mv, all)), "home,dashboard,requests,fintv,lib:m,lib:tv,lib:yt,lists,search,settings")
end sub

sub testRequestsRow(t as object)
    c = [{ id: "hero", kind: "hero", visible: true }, { id: "cw", kind: "cw", visible: true }, { id: "fintv", kind: "fintv", visible: true, rail: true }, lib("m", true, invalid)]
    r = RailItems_withRequests(c)
    eq(t, "requests added once", r.count(), 5)
    eq(t, "right after Continue Watching", r[2].kind, "requests")
    eq(t, "nothing else moves", r[3].kind + "," + r[4].kind, "fintv,library")
    eq(t, "requests idempotent", RailItems_withRequests(r).count(), 5)
    eq(t, "no cw: first", RailItems_withRequests([lib("m", true, invalid)])[0].kind, "requests")
    eq(t, "a Home row", RailItems_hasHomeRow(r[2]), true)
    eq(t, "a destination", RailItems_isDestination(r[2]), true)
    mk = RailItems_marks(r[2])
    eq(t, "both columns", mk.home + "/" + mk.rail, "on/on")
    ' Hiding it on Home leaves the menu entry (the menu toggle is separate).
    r[2] = RailItems_toggleHome(r[2])
    eq(t, "hidden on Home, still in menu", joined(RailItems_ids(["m"], r, { requests: true })), "home,requests,fintv,lib:m,lists,search,settings")
    eq(t, "not on Home", RailItems_onHome(r[2]), false)
    ' Not signed in to Seerr: no entry, wherever it is saved.
    eq(t, "no Seerr account: absent", joined(RailItems_ids(["m"], r, { requests: false })), "home,fintv,lib:m,lists,search,settings")
    eq(t, "nothing available: absent", joined(RailItems_ids(["m"], r)), "home,fintv,lib:m,lists,search,settings")
    r[2] = RailItems_toggleRail(r[2])
    eq(t, "hidden from the menu", joined(RailItems_ids(["m"], r, { requests: true })), "home,fintv,lib:m,lists,search,settings")
    eq(t, "hidden everywhere: Search footnote", RailItems_note(r[2]), "Only reachable from Search")
    ' A config with no Requests entry yet still gets the menu entry.
    eq(t, "old config gains Requests", joined(RailItems_ids(["m"], c, { requests: true })), "home,requests,fintv,lib:m,lists,search,settings")
end sub

sub testDashboard(t as object)
    c = RailItems_withLists(baseConfig())
    r = RailItems_withDashboard(c)
    eq(t, "dashboard after Lists", r[r.count() - 1].kind, "dashboard")
    eq(t, "dashboard idempotent", RailItems_withDashboard(r).count(), r.count())
    r2 = RailItems_withDashboard([c[6], c[0]])
    eq(t, "straight after Lists", r2[1].kind, "dashboard")
    d = r[r.count() - 1]
    eq(t, "no Home row", RailItems_hasHomeRow(d), false)
    mk = RailItems_marks(d)
    eq(t, "Home column is a dash", mk.home + "/" + mk.rail, "none/on")
    eq(t, "admins only", joined(RailItems_ids(["m", "tv", "yt"], r, { dashboard: false })), "home,fintv,lib:m,lib:tv,lib:yt,lists,search,settings")
    eq(t, "admin sees it", joined(RailItems_ids(["m", "tv", "yt"], r, { dashboard: true })), "home,fintv,lib:m,lib:tv,lib:yt,lists,dashboard,search,settings")
    eq(t, "shown: no note", RailItems_note(d), "")
    d = RailItems_toggleRail(d)
    eq(t, "hidden: no other way in", RailItems_note(d), "Hidden: the Dashboard has no other way in")
    eq(t, "OK does nothing to the Dashboard", RailItems_toggleHome(d).visible = invalid, true)
end sub

' Signed out of Seerr / not an admin: the editor doesn't list those entries,
' and saving puts them back where they were.
sub testEditorView(t as object)
    c = fullConfig()
    v = RailItems_editorView(c, { requests: false, dashboard: false })
    names = []
    for each e in v.rows
        names.push(e.id)
    end for
    eq(t, "unavailable entries left out", joined(names), "hero,cw,fintv,library_m,library_tv,library_yt,lists")
    eq(t, "two kept aside", v.hidden.count(), 2)
    ' The user moves Lists to the top while signed out.
    rows = v.rows
    lists = rows[6]
    rows.Delete(6)
    rows.unshift(lists)
    back = RailItems_mergeHidden(rows, v.hidden)
    ids = []
    for each e in back
        ids.push(e.id)
    end for
    eq(t, "put back after what they followed", joined(ids), "lists,dashboard,hero,cw,requests,fintv,library_m,library_tv,library_yt")
    v2 = RailItems_editorView(c, { requests: true, dashboard: true })
    eq(t, "all available: everything listed", v2.rows.count(), c.count())
    eq(t, "nothing aside", v2.hidden.count(), 0)
end sub

sub testHomeOrder(t as object)
    c = fullConfig()
    ' Home draws its rows in the config's order: a SashimiTV row moved below
    ' the libraries is drawn there, and Requests sits after Continue Watching.
    mv = [c[0], c[1], c[2], c[4], c[5], c[3], c[6], c[7], c[8]]
    eq(t, "rows follow the config", joined(RailItems_homeOrder(mv, ["cw", "fintv", "library_m", "library_tv", "requests"])), "cw,requests,library_m,library_tv,fintv")
    eq(t, "unknown keys keep their place at the end", joined(RailItems_homeOrder(mv, ["x", "cw", "y"])), "cw,x,y")
    eq(t, "no config: unchanged", joined(RailItems_homeOrder(invalid, ["b", "a"])), "b,a")
    eq(t, "requests goes after cw", RailItems_rowPosition(c, "requests", ["cw", "fintv", "library_m"]), 1)
    eq(t, "nothing before it shown: first", RailItems_rowPosition(c, "requests", ["fintv"]), 0)
    eq(t, "not in config: last", RailItems_rowPosition(c, "nope", ["cw", "fintv"]), 2)
end sub
