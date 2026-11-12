' Off-device tests for source/utils/SettingsSync.bs, run by tests/run.js
' against the transpiled module (out/source/utils/SettingsSync.brs). V1-V11
' are the shared vectors every Sashimi client runs (settings sync schema,
' WORK-106); the rest cover the Roku side: its registry strings, the
' subtitlesDefaultOn name, homeRowOrder <-> homeRows, and the Resume
' Threshold picker's default.

sub main()
    t = { passed: 0, failed: 0 }

    testVectors(t)
    testEntries(t)
    testValues(t)
    testStamps(t)
    testReconcile(t)
    testLayout(t)
    testBody(t)
    testResumePicker(t)

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

sub ok(t as object, name as string, cond as boolean)
    if cond
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name
    end if
end sub

' LongInteger stamps, so tests compare the way the app stores them.
function L(n as integer) as dynamic
    return SettingsSync_longOf(n)
end function

function entry(json as string, tt as string) as string
    return "{""v"":" + json + ",""t"":" + tt + "}"
end function

function stampStr(stamps as object, key as string) as string
    if not stamps.DoesExist(key) then return "none"
    return stamps[key].ToStr()
end function

function applied(r as object) as string
    out = []
    for each a in r.apply
        out.Push(a.local + "=" + type(a.value) + ":" + valueStr(a.value) + "@" + a.t.ToStr())
    end for
    return out.Join(",")
end function

function valueStr(v as dynamic) as string
    if type(v) = "roArray" then return "config"
    return v
end function

function writeKeys(r as object) as string
    keys = []
    for each k in r.writes
        keys.Push(k)
    end for
    keys.Sort()
    return keys.Join(",")
end function

' "id/on" per entry, for a layout or a homeRowOrder config.
function layoutStr(rows as object) as string
    out = []
    for each r in rows
        if r.DoesExist("kind")
            v = "on"
            if r.visible = false then v = "off"
            out.Push(r.id + "/" + v)
        else
            v = "on"
            if not r.on then v = "off"
            out.Push(r.id + "/" + v)
        end if
    end for
    return out.Join(" ")
end function

' A typical Roku homeRowOrder with the menu-only entries mixed in.
function rokuConfig() as object
    return [
        { id: "hero", kind: "hero", name: "Featured", visible: true }
        { id: "cw", kind: "cw", name: "Continue Watching", visible: true }
        { id: "fintv", kind: "fintv", name: "SashimiTV", visible: true, rail: true }
        { id: "requests", kind: "requests", name: "Requests", visible: true, rail: true }
        { id: "library_m", kind: "library", libraryId: "m", name: "Recently Added Movies", visible: true, rail: true }
        { id: "lists", kind: "lists", name: "Lists", rail: true }
        { id: "library_t", kind: "library", libraryId: "t", name: "Recently Added TV", visible: false, rail: false }
        { id: "list_p", kind: "list", listId: "p", name: "Your list: P", visible: true }
        { id: "watchlist", kind: "watchlist", name: "Watchlist", rail: true }
    ]
end function

' ---------- Shared vectors ----------

sub testVectors(t as object)
    ' V1: remote newer -> apply, take its t, write nothing.
    r = SettingsSync_reconcile({ autoSkipIntro: "false" }, invalid, { autoSkipIntro: L(100) }, { autoSkipIntro: entry("true", "200") })
    eq(t, "V1 apply", applied(r), "autoSkipIntro=String:true@200")
    eq(t, "V1 stamp", stampStr(r.stamps, "autoSkipIntro"), "200")
    eq(t, "V1 no write", writeKeys(r), "")

    ' V2: local newer -> keep, write ours with our t.
    r = SettingsSync_reconcile({ autoSkipIntro: "false" }, invalid, { autoSkipIntro: L(300) }, { autoSkipIntro: entry("true", "200") })
    eq(t, "V2 no apply", applied(r), "")
    eq(t, "V2 write", r.writes.autoSkipIntro, "{""v"":false,""t"":300}")
    eq(t, "V2 stamp", stampStr(r.stamps, "autoSkipIntro"), "300")

    ' V3: equal -> nothing.
    r = SettingsSync_reconcile({ autoSkipIntro: "false" }, invalid, { autoSkipIntro: L(200) }, { autoSkipIntro: entry("true", "200") })
    eq(t, "V3 no apply", applied(r), "")
    eq(t, "V3 no write", writeKeys(r), "")

    ' V4: a resume value no platform offers is ignored; the stamp stays.
    r = SettingsSync_reconcile({ resumeThresholdSeconds: "30" }, invalid, { resumeThresholdSeconds: L(0) }, { resumeThresholdSeconds: entry("45", "500") })
    eq(t, "V4 ignored", applied(r), "")
    eq(t, "V4 stamp", stampStr(r.stamps, "resumeThresholdSeconds"), "0")
    eq(t, "V4 not overwritten", writeKeys(r), "")

    ' V5: an unknown shuffle mode is ignored.
    r = SettingsSync_reconcile({ tvShuffleMode: "randomEpisode" }, invalid, { tvShuffleMode: L(100) }, { tvShuffleMode: entry("""shuffleAll""", "500") })
    eq(t, "V5 ignored", applied(r), "")
    eq(t, "V5 stamp", stampStr(r.stamps, "tvShuffleMode"), "100")
    eq(t, "V5 no write", writeKeys(r), "")

    ' V6: every other CustomPrefs key survives a write.
    dto = { Id: "x", Client: "sashimi", CustomPrefs: { subscriptions: "[]", skipBackLength: "10000", futureKey: "kept" } }
    body = SettingsSync_prefsBody(dto, { autoSkipIntro: entry("true", "5") })
    eq(t, "V6 subscriptions", body.CustomPrefs.subscriptions, "[]")
    eq(t, "V6 skipBackLength", body.CustomPrefs.skipBackLength, "10000")
    eq(t, "V6 futureKey", body.CustomPrefs.futureKey, "kept")
    eq(t, "V6 ours", body.CustomPrefs.autoSkipIntro, "{""v"":true,""t"":5}")
    eq(t, "V6 schema", body.CustomPrefs.schema, "1")
    eq(t, "V6 read dto untouched", dto.CustomPrefs.DoesExist("autoSkipIntro"), false)

    ' V7: sync off -> no request, but the change is stamped now.
    now = SettingsSync_longOf("1762963200123")
    c = SettingsSync_recordChange({ autoSkipIntro: L(5) }, "autoSkipIntro", now, false)
    eq(t, "V7 no request", c.request, false)
    eq(t, "V7 stamp now", stampStr(c.stamps, "autoSkipIntro"), "1762963200123")
    eq(t, "V7 gate off", SettingsSync_shouldRequest(false, true), false)
    c = SettingsSync_recordChange({}, "autoSkipIntro", now, true)
    eq(t, "V7 on requests", c.request, true)
    eq(t, "V7 gate on", SettingsSync_shouldRequest(true, true), true)
    eq(t, "V7 gate signed out", SettingsSync_shouldRequest(true, false), false)

    ' V8: writing keeps a remote-only row (hero) in its remote place.
    config = [
        { id: "cw", kind: "cw", visible: true }
        { id: "library_a", kind: "library", libraryId: "a", visible: true }
    ]
    remote = [{ id: "continueWatching", on: true }, { id: "hero", on: true }, { id: "library:a", on: true }]
    eq(t, "V8 hero second", layoutStr(SettingsSync_layoutForWrite(config, remote)), "continueWatching/on hero/on library:a/on")

    ' V9: a local library the remote layout lacks stays after its local predecessor.
    config = [
        { id: "hero", kind: "hero", visible: true }
        { id: "cw", kind: "cw", visible: true }
        { id: "library_a", kind: "library", libraryId: "a", visible: true }
        { id: "library_new", kind: "library", libraryId: "new", visible: true }
        { id: "library_b", kind: "library", libraryId: "b", visible: true }
    ]
    remote = [{ id: "library:b", on: true }, { id: "hero", on: true }, { id: "continueWatching", on: false }, { id: "library:a", on: true }]
    eq(t, "V9 new library after a", layoutStr(SettingsSync_applyLayout(config, remote)), "library_b/on hero/on cw/off library_a/on library_new/on")

    ' V10: first run seeds explicit settings at 1, defaults get nothing.
    local = { autoSkipIntro: "true", showQualityBadges: "" }
    stamps = SettingsSync_seedStamps(local, invalid)
    eq(t, "V10 explicit seeded", stampStr(stamps, "autoSkipIntro"), "1")
    eq(t, "V10 default unseeded", stampStr(stamps, "showQualityBadges"), "none")
    r = SettingsSync_reconcile(local, invalid, stamps, {})
    eq(t, "V10 write", r.writes.autoSkipIntro, "{""v"":true,""t"":1}")
    eq(t, "V10 only explicit written", writeKeys(r), "autoSkipIntro")

    ' V11: unreadable JSON is ignored without a crash, and not overwritten.
    eq(t, "V11 decode", SettingsSync_decodeEntry("{not json"), invalid)
    r = SettingsSync_reconcile({ autoSkipIntro: "true" }, invalid, { autoSkipIntro: L(900) }, { autoSkipIntro: "{not json" })
    eq(t, "V11 no apply", applied(r), "")
    eq(t, "V11 no write", writeKeys(r), "")
end sub

' ---------- Entries ----------

sub testEntries(t as object)
    e = SettingsSync_decodeEntry("{""v"":true,""t"":1762963200000}")
    eq(t, "decode v", e.v, true)
    eq(t, "decode 13-digit t", e.t.ToStr(), "1762963200000")
    eq(t, "decode t is LongInteger", type(e.t), "LongInteger")
    eq(t, "decode small t", SettingsSync_decodeEntry("{""v"":1,""t"":1}").t.ToStr(), "1")
    eq(t, "no t", SettingsSync_decodeEntry("{""v"":true}"), invalid)
    eq(t, "no v", SettingsSync_decodeEntry("{""t"":5}"), invalid)
    eq(t, "string t", SettingsSync_decodeEntry("{""v"":true,""t"":""5""}"), invalid)
    eq(t, "array", SettingsSync_decodeEntry("[1]"), invalid)
    eq(t, "not a string", SettingsSync_decodeEntry(5), invalid)
    eq(t, "raw t digits", SettingsSync_longFromRaw("{""v"":true,""t"":1762963200000}").ToStr(), "1762963200000")
    eq(t, "encode", SettingsSync_encodeEntry("""zoom""", SettingsSync_longOf("1762963200000")), "{""v"":""zoom"",""t"":1762963200000}")
    ' Round trip through the codec.
    raw = SettingsSync_encodeEntry(FormatJson([{ id: "hero", on: false }]), L(42))
    back = SettingsSync_decodeEntry(raw)
    eq(t, "round trip t", back.t.ToStr(), "42")
    eq(t, "round trip layout", layoutStr(SettingsSync_decodeLayout(back.v)), "hero/off")
end sub

' ---------- Values ----------

function specFor(key as string) as dynamic
    for each s in SettingsSync_specs()
        if s.key = key then return s
    end for
    return invalid
end function

sub testValues(t as object)
    b = specFor("autoSkipIntro")
    eq(t, "bool true", SettingsSync_localFromShared(b, true), "true")
    eq(t, "bool false", SettingsSync_localFromShared(b, false), "false")
    eq(t, "bool from string", SettingsSync_localFromShared(b, "true"), invalid)
    eq(t, "bool from int", SettingsSync_localFromShared(b, 1), invalid)
    eq(t, "bool out", SettingsSync_sharedJson(b, "true"), "true")
    eq(t, "bool out default", SettingsSync_sharedJson(specFor("autoPlayNextEpisode"), ""), "true")

    r = specFor("resumeThresholdSeconds")
    for each n in [0, 10, 30, 60, 120, 300, 600]
        eq(t, "resume " + n.ToStr(), SettingsSync_localFromShared(r, n), n.ToStr())
    end for
    eq(t, "resume 45", SettingsSync_localFromShared(r, 45), invalid)
    eq(t, "resume string", SettingsSync_localFromShared(r, "30"), invalid)
    eq(t, "resume out", SettingsSync_sharedJson(r, "10"), "10")
    eq(t, "resume out default", SettingsSync_sharedJson(r, ""), "30")

    lang = specFor("preferredAudioLanguage")
    eq(t, "lang fi", SettingsSync_localFromShared(lang, "fi"), "fi")
    eq(t, "lang default", SettingsSync_localFromShared(lang, ""), "")
    eq(t, "lang unknown", SettingsSync_localFromShared(lang, "xx"), invalid)
    eq(t, "lang count", SettingsSync_languageCodes().Count(), 19)
    eq(t, "lang out", SettingsSync_sharedJson(lang, "ja"), """ja""")
    eq(t, "lang out default", SettingsSync_sharedJson(lang, ""), """""")

    eq(t, "shuffle", SettingsSync_localFromShared(specFor("tvShuffleMode"), "randomShowNextEpisode"), "randomShowNextEpisode")
    eq(t, "view zoom", SettingsSync_localFromShared(specFor("defaultViewMode"), "zoom"), "zoom")
    eq(t, "view unknown", SettingsSync_localFromShared(specFor("defaultViewMode"), "fill"), invalid)

    ' Roku's own name for Subtitles; the wire uses the shared one.
    s = specFor("subtitlesEnabled")
    eq(t, "subtitles local name", s.local, "subtitlesDefaultOn")
    eq(t, "subtitles spec by local", SettingsSync_specForLocal("subtitlesDefaultOn").key, "subtitlesEnabled")
    r2 = SettingsSync_reconcile({ subtitlesDefaultOn: "false" }, invalid, {}, { subtitlesEnabled: entry("true", "7") })
    eq(t, "subtitles apply", applied(r2), "subtitlesDefaultOn=String:true@7")
    r2 = SettingsSync_reconcile({ subtitlesDefaultOn: "true" }, invalid, { subtitlesEnabled: L(9) }, {})
    eq(t, "subtitles write", r2.writes.subtitlesEnabled, "{""v"":true,""t"":9}")

    ' Never synced.
    eq(t, "bitrate not synced", SettingsSync_specForLocal("maxBitrateMbps"), invalid)
    eq(t, "theme songs not synced", SettingsSync_specForLocal("playThemeSongs"), invalid)
    eq(t, "toggle not synced", SettingsSync_specForLocal("settingsSyncEnabled"), invalid)
    eq(t, "side menu later", specFor("sideMenu"), invalid)
end sub

' ---------- Stamps ----------

sub testStamps(t as object)
    eq(t, "absent", SettingsSync_decodeStamps(""), invalid)
    eq(t, "corrupt", SettingsSync_decodeStamps("{nope"), invalid)
    s = SettingsSync_decodeStamps(SettingsSync_encodeStamps({ autoSkipIntro: SettingsSync_longOf("1762963200000"), homeRows: L(1) }))
    eq(t, "round trip big", stampStr(s, "autoSkipIntro"), "1762963200000")
    eq(t, "round trip 1", stampStr(s, "homeRows"), "1")
    eq(t, "empty map is not absent", type(SettingsSync_decodeStamps("{}")), "roAssociativeArray")

    ' A layout seeds only when it shows a choice.
    eq(t, "default layout unseeded", stampStr(SettingsSync_seedStamps({}, [{ id: "hero", kind: "hero" }, { id: "cw", kind: "cw", visible: true }]), "homeRows"), "none")
    eq(t, "hidden row seeds", stampStr(SettingsSync_seedStamps({}, rokuConfig()), "homeRows"), "1")
    moved = [{ id: "cw", kind: "cw" }, { id: "hero", kind: "hero" }]
    eq(t, "moved hero seeds", stampStr(SettingsSync_seedStamps({}, moved), "homeRows"), "1")
end sub

' ---------- Reconcile ----------

sub testReconcile(t as object)
    ' A key the server has never seen, with a local stamp, is written.
    r = SettingsSync_reconcile({ use24HourTime: "true" }, invalid, { use24HourTime: L(50) }, {})
    eq(t, "missing remote written", r.writes.use24HourTime, "{""v"":true,""t"":50}")
    ' No stamp and no remote: nothing either way.
    r = SettingsSync_reconcile({ use24HourTime: "true" }, invalid, {}, {})
    eq(t, "unstamped not written", writeKeys(r), "")
    ' A fresh device takes every value it has no stamp for.
    r = SettingsSync_reconcile({}, invalid, {}, { autoSkipCredits: entry("true", "1"), defaultViewMode: entry("""stretch""", "3") })
    eq(t, "fresh apply", applied(r), "autoSkipCredits=String:true@1,defaultViewMode=String:stretch@3")
    ' Unrelated and null CustomPrefs keys are left alone.
    r = SettingsSync_reconcile({}, invalid, {}, { tvhome: invalid, subscriptions: "[]", schema: "2" })
    eq(t, "foreign keys", applied(r) + "|" + writeKeys(r), "|")
    ' Unreadable prefs read as empty.
    r = SettingsSync_reconcile({}, invalid, { autoSkipIntro: L(3) }, invalid)
    eq(t, "invalid prefs", writeKeys(r), "autoSkipIntro")
    ' Newer remote but invalid value, older local: neither apply nor write.
    r = SettingsSync_reconcile({ autoSkipIntro: "true" }, invalid, { autoSkipIntro: L(3) }, { autoSkipIntro: entry("""yes""", "9") })
    eq(t, "invalid newer remote", applied(r) + "|" + writeKeys(r), "|")
    ' Older remote with an invalid value: ours is newer, so it is written.
    r = SettingsSync_reconcile({ autoSkipIntro: "true" }, invalid, { autoSkipIntro: L(30) }, { autoSkipIntro: entry("""yes""", "9") })
    eq(t, "invalid older remote", writeKeys(r), "autoSkipIntro")

    ' homeRows: applied into homeRowOrder.
    config = rokuConfig()
    layout = "[{""id"":""library:t"",""on"":true},{""id"":""hero"",""on"":true},{""id"":""continueWatching"",""on"":false},{""id"":""future:x"",""on"":true}]"
    r = SettingsSync_reconcile({}, config, { homeRows: L(1) }, { homeRows: entry(layout, "500") })
    eq(t, "layout applied", applied(r), "homeRowOrder=roArray:config@500")
    eq(t, "layout applied rows", layoutStr(r.apply[0].value), "library_t/on list_p/on hero/on cw/off fintv/on lists/on requests/on library_m/on watchlist/on")
    eq(t, "layout stamp", stampStr(r.stamps, "homeRows"), "500")
    ' Not applied before Home has a config to apply it to.
    r = SettingsSync_reconcile({}, invalid, {}, { homeRows: entry(layout, "500") })
    eq(t, "layout waits for Home", applied(r) + "|" + stampStr(r.stamps, "homeRows"), "|none")
    ' homeRows written with remote-only ids carried through.
    r = SettingsSync_reconcile({}, config, { homeRows: L(900) }, { homeRows: entry(layout, "500") })
    w = SettingsSync_decodeEntry(r.writes.homeRows)
    eq(t, "layout write t", w.t.ToStr(), "900")
    eq(t, "layout write rows", layoutStr(SettingsSync_decodeLayout(w.v)), "hero/on continueWatching/on future:x/on fintv/on requests/on library:m/on library:t/off list:p/on")
    ' A non-array layout is ignored.
    r = SettingsSync_reconcile({}, config, { homeRows: L(1) }, { homeRows: entry("{""a"":1}", "500") })
    eq(t, "layout not array", applied(r) + "|" + writeKeys(r), "|")
end sub

' ---------- Layout ----------

sub testLayout(t as object)
    config = rokuConfig()
    eq(t, "to shared", layoutStr(SettingsSync_localLayout(config)), "hero/on continueWatching/on fintv/on requests/on library:m/on library:t/off list:p/on")
    eq(t, "missing visible is on", layoutStr(SettingsSync_localLayout([{ id: "cw", kind: "cw" }])), "continueWatching/on")
    eq(t, "menu-only has no id", SettingsSync_sharedId({ id: "dashboard", kind: "dashboard" }), "")
    eq(t, "library id", SettingsSync_sharedId({ id: "library_x", kind: "library", libraryId: "x" }), "library:x")
    eq(t, "list id", SettingsSync_sharedId({ id: "list_y", kind: "list", listId: "y" }), "list:y")
    eq(t, "broken entry", SettingsSync_sharedId({ kind: "library" }), "")

    ' Shared -> Roku: order, on flags, menu-only entries keep their slots and
    ' their rail flags; ids this device lacks are skipped.
    remote = SettingsSync_decodeLayout([
        { id: "list:p", on: false }
        { id: "requests", on: true }
        { id: "library:gone", on: true }
        { id: "hero", on: true }
        { id: "continueWatching", on: true }
        { id: "fintv", on: false }
        { id: "library:t", on: true }
        { id: "library:m", on: true }
    ])
    out = SettingsSync_applyLayout(config, remote)
    eq(t, "apply order", layoutStr(out), "list_p/off requests/on hero/on cw/on fintv/off lists/on library_t/on library_m/on watchlist/on")
    eq(t, "menu-only slot", out[5].id + "," + out[8].id, "lists,watchlist")
    eq(t, "rail kept", out[6].rail, false)
    eq(t, "library fields kept", out[6].libraryId + "|" + out[6].name, "t|Recently Added TV")
    eq(t, "input untouched", config[0].id + "," + config[6].visible.ToStr(), "hero,false")
    ' Roku -> shared -> Roku round trip is the identity.
    eq(t, "round trip", layoutStr(SettingsSync_applyLayout(config, SettingsSync_localLayout(config))), layoutStr(config))

    ' Rows the layout doesn't name, at the very start, keep leading.
    cfg = [{ id: "library_n", kind: "library", libraryId: "n" }, { id: "hero", kind: "hero" }, { id: "cw", kind: "cw" }]
    eq(t, "unnamed first", layoutStr(SettingsSync_applyLayout(cfg, [{ id: "continueWatching", on: true }, { id: "hero", on: false }])), "library_n/on cw/on hero/off")

    ' Malformed entries dropped; repeated ids keep their first.
    d = SettingsSync_decodeLayout([{ id: "hero", on: "yes" }, { on: true }, 5, { id: "cw", on: true }, { id: "cw", on: false }])
    eq(t, "decode drops bad", layoutStr(d), "cw/on")
    eq(t, "decode non-array", SettingsSync_decodeLayout("x"), invalid)

    ' Writing: unknown ids at the front stay at the front.
    w = SettingsSync_layoutForWrite([{ id: "cw", kind: "cw" }], [{ id: "x:1", on: true }, { id: "x:2", on: false }, { id: "continueWatching", on: true }])
    eq(t, "write leading unknown", layoutStr(w), "x:1/on x:2/off continueWatching/on")
end sub

' ---------- Body ----------

sub testBody(t as object)
    body = SettingsSync_prefsBody(invalid, {})
    eq(t, "body client", body.Client, "sashimi")
    eq(t, "body schema", body.CustomPrefs.schema, "1")
    eq(t, "path", SettingsSync_prefsPath("u1"), "/DisplayPreferences/sashimi-settings?userId=u1&client=sashimi")
    eq(t, "custom prefs", SettingsSync_customPrefsOf({ CustomPrefs: { a: "1" } }).a, "1")
    eq(t, "custom prefs missing", SettingsSync_customPrefsOf({}), invalid)
end sub

' ---------- Resume Threshold picker ----------

sub testResumePicker(t as object)
    opts = SettingsSync_resumeOptions()
    values = []
    for each o in opts
        values.Push(o.value)
    end for
    eq(t, "resume options", values.Join(","), "0,10,30,60,120,300,600")
    eq(t, "10 seconds label", opts[1].label, "10 seconds")
    ' Nothing stored: the picker shows what playback uses (30 s).
    eq(t, "resume default", SettingsSync_defaultValue("resumeThresholdSeconds"), "30")
    i = SettingsSync_optionIndex(opts, "", SettingsSync_defaultValue("resumeThresholdSeconds"))
    eq(t, "unset picker shows 30", opts[i].label, "30 seconds")
    eq(t, "stored wins", opts[SettingsSync_optionIndex(opts, "0", "30")].label, "Always resume")
    eq(t, "unknown stored", SettingsSync_optionIndex(opts, "45", "30"), 0)
    eq(t, "other defaults", SettingsSync_defaultValue("autoPlayNextEpisode") + "," + SettingsSync_defaultValue("showQualityBadges") + "," + SettingsSync_defaultValue("defaultViewMode"), "true,true,normal")
end sub
