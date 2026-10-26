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
    eq(t, "no config lists everything", joined(RailItems_ids(["m", "tv"], invalid)), "home,fintv,lib:m,lib:tv,search,settings")
    eq(t, "empty config lists everything", joined(RailItems_ids(["m", "tv"], [])), "home,fintv,lib:m,lib:tv,search,settings")
    ' Configs saved before the menu toggle have no `rail` field.
    old = [lib("m", true, invalid), lib("tv", false, invalid)]
    eq(t, "pre-toggle config shows all", joined(RailItems_ids(["m", "tv"], old)), "home,fintv,lib:m,lib:tv,search,settings")
end sub

sub testHiddenDrop(t as object)
    c = baseConfig()
    c[4].rail = false
    eq(t, "hidden library drops", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,fintv,lib:m,lib:yt,search,settings")
    c[2].rail = false
    eq(t, "hidden SashimiTV drops", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,lib:m,lib:yt,search,settings")
end sub

sub testAlwaysShown(t as object)
    c = baseConfig()
    for each e in c
        e.rail = false
        e.visible = false
    end for
    c.push({ id: "home", kind: "home", rail: false })
    c.push({ id: "search", kind: "search", rail: false })
    c.push({ id: "settings", kind: "settings", rail: false })
    eq(t, "Home, Search, Settings can't drop", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,search,settings")
end sub

sub testOrder(t as object)
    c = baseConfig()
    ' Home row order: yt, m, tv.
    c = [c[0], c[1], c[2], c[5], c[3], c[4]]
    eq(t, "libraries follow the Home order", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,fintv,lib:yt,lib:m,lib:tv,search,settings")
    ' SashimiTV dragged below the libraries still sits under Home.
    c2 = [c[0], c[1], c[3], c[4], c[5], c[2]]
    eq(t, "SashimiTV stays under Home", joined(RailItems_ids(["m", "tv", "yt"], c2)), "home,fintv,lib:yt,lib:m,lib:tv,search,settings")
end sub

sub testNewAndStale(t as object)
    c = baseConfig()
    eq(t, "new library appended, visible", joined(RailItems_ids(["new", "m", "tv", "yt"], c)), "home,fintv,lib:m,lib:tv,lib:yt,lib:new,search,settings")
    eq(t, "removed library ignored", joined(RailItems_ids(["m", "yt"], c)), "home,fintv,lib:m,lib:yt,search,settings")
    c.push(lib("m", true, false))
    eq(t, "duplicate entry: first wins", joined(RailItems_ids(["m"], c)), "home,fintv,lib:m,search,settings")
    junk = [invalid, { kind: 5 }, { kind: "library" }, { kind: "library", libraryId: 7 }, "x"]
    eq(t, "malformed entries ignored", joined(RailItems_ids(["m"], junk)), "home,fintv,lib:m,search,settings")
end sub

sub testIndependentOfHome(t as object)
    c = baseConfig()
    c[3].visible = false
    eq(t, "hidden on Home, still in menu", joined(RailItems_ids(["m", "tv", "yt"], c)), "home,fintv,lib:m,lib:tv,lib:yt,search,settings")
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
