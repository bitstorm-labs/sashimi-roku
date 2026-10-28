' Off-device tests for source/utils/SharedLists.bs, run by tests/run.js against
' the transpiled module (out/source/utils/SharedLists.brs). The vectors V1-V6
' are the ones every Sashimi client uses (shared lists plan, milestone 1), so a
' subscription written by one platform reads the same on the others.

sub main()
    t = { passed: 0, failed: 0 }

    testOwner(t)
    testDisplayEntries(t)
    testDecode(t)
    testNewCount(t)
    testEdits(t)
    testInsertionIndex(t)

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

function ep(id as string, series as dynamic, season as integer, episode as integer) as object
    return { itemId: id, type: "Episode", seriesId: series, season: season, episode: episode }
end function

function mv(id as string) as object
    return { itemId: id, type: "Movie" }
end function

' "id:seen1,seen2;id2:" so a whole subscription list compares in one line.
function subsStr(subs as object) as string
    out = ""
    for each s in subs
        if out <> "" then out = out + ";"
        out = out + s.id + ":" + s.seen.Join(",")
    end for
    return out
end function

function shownStr(shown as object) as string
    out = ""
    for each d in shown
        if out <> "" then out = out + "|"
        out = out + d.id
        if d.isSeries then out = out + "/series"
    end for
    return out
end function

sub testOwner(t as object)
    eq(t, "V1a", SharedLists_owner([{ UserId: "u1", CanEdit: false }, { UserId: "u2", CanEdit: true }, { UserId: "u3", CanEdit: true }]), "u2")
    eq(t, "V1b", SharedLists_owner([]), invalid)
    eq(t, "V1c", SharedLists_owner([{ UserId: "u1", CanEdit: false }]), invalid)
    ' The server's JSON, not ours: a missing Shares array or CanEdit is no owner.
    eq(t, "V1 no shares", SharedLists_owner(invalid), invalid)
    eq(t, "V1 no CanEdit", SharedLists_owner([{ UserId: "u1" }]), invalid)
end sub

sub testDisplayEntries(t as object)
    shown = SharedLists_displayEntries([ep("e1", "show1", 1, 1), mv("m1"), ep("e2", "show1", 1, 2), mv("m1"), ep("e3", "show2", 2, 1), ep("e4", invalid, 1, 1), ep("e5", "show1", 1, 1)])
    eq(t, "V2", shownStr(shown), "show1/series|m1|e2|e3|e4")
    ' An episode the server sent without numbers is itself, never a crash
    ' (comparing invalid to 1 is a type mismatch on device).
    eq(t, "V2 no numbers", shownStr(SharedLists_displayEntries([{ itemId: "e9", type: "Episode", seriesId: "s9" }])), "e9")
end sub

sub testDecode(t as object)
    eq(t, "V3a invalid", subsStr(SharedLists_decodeSubscriptions(invalid)), "")
    eq(t, "V3a empty", subsStr(SharedLists_decodeSubscriptions("")), "")
    eq(t, "V3a junk", subsStr(SharedLists_decodeSubscriptions("not json")), "")
    eq(t, "V3a object", subsStr(SharedLists_decodeSubscriptions("{}")), "")
    raw = "[{""id"":""a"",""seen"":[""x""]},{""seen"":[]},{""id"":""a"",""seen"":[]},{""id"":""b""}]"
    eq(t, "V3b", subsStr(SharedLists_decodeSubscriptions(raw)), "a:x;b:")
    subs = [{ id: "a", seen: ["x", "y"] }, { id: "b", seen: [] }]
    eq(t, "V3c", subsStr(SharedLists_decodeSubscriptions(SharedLists_encodeSubscriptions(subs))), "a:x,y;b:")
    ' Another client's encoder may write numbers or nulls where ids belong.
    eq(t, "V3 non-string ids dropped", subsStr(SharedLists_decodeSubscriptions("[{""id"":7,""seen"":[]},{""id"":""c"",""seen"":[""x"",3,null]}]")), "c:x")
end sub

sub testNewCount(t as object)
    eq(t, "V4a", SharedLists_newCount(["a", "b", "c"], ["b"]), 2)
    eq(t, "V4b", SharedLists_newCount(["a"], ["a", "z"]), 0)
end sub

sub testEdits(t as object)
    eq(t, "V5a", subsStr(SharedLists_subscribe([{ id: "a", seen: [] }], "b", ["x", "y"])), "a:;b:x,y")
    eq(t, "V5b", subsStr(SharedLists_subscribe([{ id: "a", seen: ["q"] }], "a", ["x"])), "a:q")
    eq(t, "V5c", subsStr(SharedLists_unsubscribe([{ id: "a", seen: [] }, { id: "b", seen: [] }], "a")), "b:")
    eq(t, "V5d", subsStr(SharedLists_markSeen([{ id: "a", seen: ["q"] }, { id: "b", seen: [] }], "a", ["x"])), "a:x;b:")
    eq(t, "V5e", subsStr(SharedLists_prune([{ id: "a", seen: [] }, { id: "b", seen: [] }, { id: "c", seen: [] }], ["a", "c"])), "b:")
end sub

sub testInsertionIndex(t as object)
    eq(t, "V6a", SharedLists_insertionIndex(["hero", "continueWatching", "lib1"], "continueWatching", "hero"), 2)
    eq(t, "V6b", SharedLists_insertionIndex(["lib1", "hero"], "continueWatching", "hero"), 2)
    eq(t, "V6c", SharedLists_insertionIndex(["lib1"], "continueWatching", "hero"), 0)
end sub
