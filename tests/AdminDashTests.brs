' Off-device tests for source/utils/AdminDash.bs, run by tests/run.js against
' the transpiled module (out/source/utils/AdminDash.brs). The admin dashboard
' draws everything it shows from these functions, and the badge truth table is
' shared word for word with the Apple and Android clients
' (plans/sashimi/2026-10-18-admin-dashboard-design.md, "Settled after review").

sub main()
    t = { passed: 0, failed: 0 }

    testTruthTable(t)
    testBadges(t)
    testReasonWords(t)
    testSourceFormat(t)
    testAdminGate(t)
    testRedaction(t)
    testStorage(t)
    testBitrate(t)
    testCounts(t)
    testActivity(t)
    testHealth(t)
    testTimes(t)
    testTitles(t)
    testDetails(t)
    testStateDot(t)
    testCardTitle(t)
    testCardPeople(t)
    testPercent(t)
    testResolutionPill(t)
    testVideoPill(t)
    testAudioPill(t)
    testRatePill(t)
    testSpeed(t)
    testModePill(t)
    testPills(t)
    testFooterReason(t)
    testLocalAddress(t)
    testWhere(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else if (type(actual) = "String" or type(actual) = "roString") and (type(expected) = "String" or type(expected) = "roString") and actual = expected
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

' A playing session as /Sessions returns it, with only the fields AdminDash reads.
function session(ti as dynamic, extra = {} as object) as object
    s = {
        Id: "s1", UserName: "mom", DeviceName: "Living Room Roku", Client: "Sashimi",
        SupportsRemoteControl: true,
        PlayState: { PositionTicks: 12440000000&, IsPaused: false, PlayMethod: "Transcode" },
        NowPlayingItem: {
            Name: "300", Type: "Movie", ProductionYear: 2006, RunTimeTicks: 70200000000&,
            Container: "mkv",
            MediaStreams: [
                { Type: "Video", Codec: "hevc", Width: 3840, Height: 2160, VideoRangeType: "DOVIWithHDR10", BitRate: 58000000, RealFrameRate: 23.976025, AverageFrameRate: 23.976025 },
                { Type: "Audio", Codec: "dts", Index: 1, IsDefault: true, BitRate: 1509000, Channels: 6 },
                { Type: "Audio", Codec: "ac3", Index: 2, IsDefault: false, BitRate: 640000, Channels: 2 }
            ]
        }
    }
    if ti <> invalid then s.TranscodingInfo = ti
    for each k in extra
        s[k] = extra[k]
    end for
    return s
end function

sub testTruthTable(t as object)
    ' Direct play: no TranscodingInfo at all.
    eq(t, "no TranscodingInfo", AdminDash_playMode(session(invalid)), "direct")
    ' Direct play: both direct, no burn-in (a container-only remux).
    eq(t, "remux", AdminDash_playMode(session({ IsVideoDirect: true, IsAudioDirect: true, TranscodeReasons: ["ContainerNotSupported"] })), "direct")
    ' Converting audio: video direct, audio not.
    eq(t, "audio only", AdminDash_playMode(session({ IsVideoDirect: true, IsAudioDirect: false, TranscodeReasons: ["AudioCodecNotSupported"] })), "audio")
    ' Converting video: video transcoded (audio either way).
    eq(t, "video + audio", AdminDash_playMode(session({ IsVideoDirect: false, IsAudioDirect: false, TranscodeReasons: ["VideoCodecNotSupported"] })), "video")
    eq(t, "video, audio copied", AdminDash_playMode(session({ IsVideoDirect: false, IsAudioDirect: true, TranscodeReasons: ["ContainerBitrateExceedsLimit"] })), "video")
    ' Burn-in is a video conversion even when the flags claim video is direct.
    eq(t, "burn-in", AdminDash_playMode(session({ IsVideoDirect: true, IsAudioDirect: true, TranscodeReasons: ["SubtitleCodecNotSupported"] })), "video")
    eq(t, "burn-in with audio", AdminDash_playMode(session({ IsVideoDirect: true, IsAudioDirect: false, TranscodeReasons: ["AudioCodecNotSupported", "SubtitleCodecNotSupported"] })), "video")
    ' HDR -> SDR tone-mapping is a video conversion.
    eq(t, "tone-mapping", AdminDash_playMode(session({ IsVideoDirect: true, IsAudioDirect: true, TranscodeReasons: ["VideoRangeTypeNotSupported"] })), "video")
    ' Missing flags are not "direct": a transcode the server did not describe
    ' must never read as Direct play.
    eq(t, "flags missing", AdminDash_playMode(session({ TranscodeReasons: [] })), "video")
    eq(t, "audio flag missing", AdminDash_playMode(session({ IsVideoDirect: true })), "audio")
    ' Reasons as a comma string (older servers) still find the burn-in.
    eq(t, "reasons as string", AdminDash_playMode(session({ IsVideoDirect: true, IsAudioDirect: true, TranscodeReasons: "ContainerNotSupported,SubtitleCodecNotSupported" })), "video")
    eq(t, "not a session", AdminDash_playMode(invalid), "direct")
end sub

sub testBadges(t as object)
    b = AdminDash_badge("direct")
    eq(t, "direct label", b.label, "Direct play")
    eq(t, "direct fg", b.fg, "#7BD389FF")
    eq(t, "direct bg", b.bg, "#1F3A2CFF")
    b = AdminDash_badge("audio")
    eq(t, "audio label", b.label, "Converting audio")
    eq(t, "audio fg", b.fg, "#8CC2FFFF")
    eq(t, "audio bg", b.bg, "#1E2E45FF")
    b = AdminDash_badge("video")
    eq(t, "video label", b.label, "Converting video")
    eq(t, "video fg", b.fg, "#F2B84BFF")
    eq(t, "video bg", b.bg, "#43341AFF")
end sub

sub testReasonWords(t as object)
    eq(t, "bitrate", AdminDash_reasonText("ContainerBitrateExceedsLimit"), "Bitrate cap")
    eq(t, "burn-in", AdminDash_reasonText("SubtitleCodecNotSupported"), "Subtitles burned in")
    eq(t, "hdr", AdminDash_reasonText("VideoRangeTypeNotSupported"), "HDR → SDR")
    eq(t, "resolution", AdminDash_reasonText("VideoResolutionNotSupported"), "Resolution too high")
    eq(t, "container", AdminDash_reasonText("ContainerNotSupported"), "Container not supported")
    eq(t, "channels", AdminDash_reasonText("AudioChannelsNotSupported"), "Too many audio channels")
    eq(t, "video codec", AdminDash_reasonText("VideoCodecNotSupported"), "Video format not supported")
    eq(t, "audio codec", AdminDash_reasonText("AudioCodecNotSupported"), "Audio format not supported")
    ' A reason this table has never heard of still reads as words, never as
    ' the raw enum name.
    eq(t, "unknown", AdminDash_reasonText("VideoWobbleNotSupported"), "Video wobble not supported")
    eq(t, "empty", AdminDash_reasonText(""), "")
end sub

sub testSourceFormat(t as object)
    eq(t, "4K DV", AdminDash_sourceFormat(session(invalid).NowPlayingItem), "4K Dolby Vision")
    item = { MediaStreams: [{ Type: "Video", Width: 1920, Height: 800, VideoRangeType: "SDR" }] }
    eq(t, "scope 1080p", AdminDash_sourceFormat(item), "1080p")
    item = { MediaStreams: [{ Type: "Video", Width: 3840, Height: 1600, VideoRangeType: "HDR10" }] }
    eq(t, "4K HDR10", AdminDash_sourceFormat(item), "4K HDR10")
    item = { MediaStreams: [{ Type: "Video", Width: 1280, Height: 720, VideoRangeType: "HDR10Plus" }] }
    eq(t, "720p HDR10+", AdminDash_sourceFormat(item), "720p HDR10+")
    item = { MediaStreams: [{ Type: "Video", Width: 720, Height: 480 }] }
    eq(t, "480p", AdminDash_sourceFormat(item), "480p")
    eq(t, "no streams", AdminDash_sourceFormat({}), "")
end sub

sub testAdminGate(t as object)
    ok(t, "admin", AdminDash_isAdministrator({ Policy: { IsAdministrator: true } }))
    ok(t, "not admin", not AdminDash_isAdministrator({ Policy: { IsAdministrator: false } }))
    ok(t, "no policy", not AdminDash_isAdministrator({ Name: "mom" }))
    ok(t, "string true is not a policy", not AdminDash_isAdministrator({ Policy: { IsAdministrator: "true" } }))
    ok(t, "no user", not AdminDash_isAdministrator(invalid))
    ok(t, "401 denied", AdminDash_isDenied(401))
    ok(t, "403 denied", AdminDash_isDenied(403))
    ok(t, "200 allowed", not AdminDash_isDenied(200))
    ok(t, "timeout is not a denial", not AdminDash_isDenied(0))
    ok(t, "500 is not a denial", not AdminDash_isDenied(500))
end sub

sub testRedaction(t as object)
    eq(t, "ipv4", AdminDash_redactIp("IP address: 185.220.101.4"), "IP address: 185.x.x.x")
    eq(t, "two ips", AdminDash_redactIp("10.0.0.1 then 72.14.3.99."), "10.x.x.x then 72.x.x.x.")
    eq(t, "ipv6", AdminDash_redactIp("from 2001:db8:85a3::8a2e:370:7334 today"), "from 2001:x:x:x today")
    eq(t, "mapped v4", AdminDash_redactIp("IP address: ::ffff:24.6.7.8"), "IP address: x:x:x:x")
    eq(t, "clock untouched", AdminDash_redactIp("at 12:30:45"), "at 12:30:45")
    eq(t, "text untouched", AdminDash_redactIp("mondo is playing 300 on Sashimi Roku"), "mondo is playing 300 on Sashimi Roku")
    eq(t, "not an ip", AdminDash_redactIp("version 1.2.3"), "version 1.2.3")
    eq(t, "out of range", AdminDash_redactIp("999.1.1.1"), "999.1.1.1")
    eq(t, "empty", AdminDash_redactIp(""), "")
end sub

sub testStorage(t as object)
    ok(t, "85 is fine", not AdminDash_isStorageWarning(85))
    ok(t, "85.1 warns", AdminDash_isStorageWarning(85.1))
    ok(t, "100 warns", AdminDash_isStorageWarning(100))
    ok(t, "0 fine", not AdminDash_isStorageWarning(0))
    pct = AdminDash_percentFull(75, 25)
    ok(t, "75% full", pct > 74.99 and pct < 75.01)
    ok(t, "unknown size", AdminDash_percentFull(0, 0) = -1)

    ' The live server's answer, shape and magnitudes (46 TB does not fit an
    ' Integer: the trap is truncating it).
    json = "{""ProgramDataFolder"":{""Path"":""/config"",""FreeSpace"":186508845056,""UsedSpace"":325600296960,""DeviceId"":""/config""},"
    json += """TranscodingTempFolder"":{""Path"":""/cache/transcodes"",""FreeSpace"":186508845056,""UsedSpace"":325600296960,""DeviceId"":""/cache""},"
    json += """Libraries"":[{""Name"":""Movies"",""Folders"":[{""Path"":""/media/movies"",""FreeSpace"":4641282834432,""UsedSpace"":44351753269248,""DeviceId"":""/media""},{""Path"":""/media/bt/movies"",""FreeSpace"":4641282834432,""UsedSpace"":44351753269248,""DeviceId"":""/media""}]},"
    json += "{""Name"":""TV"",""Folders"":[{""Path"":""/media/tv"",""FreeSpace"":4641282834432,""UsedSpace"":44351753269248,""DeviceId"":""/media""}]},"
    json += "{""Name"":""Collections"",""Folders"":[{""Path"":""/config/data/collections"",""FreeSpace"":186508845056,""UsedSpace"":325600296960,""DeviceId"":""/config""}]}]}"
    rows = AdminDash_storageRows(ParseJSON(json))
    eq(t, "rows: media once + cache", rows.count(), 2)
    if rows.count() = 2
        eq(t, "media label", rows[0].text, "Media storage")
        eq(t, "media value", rows[0].value, "4.6 TB free of 49 TB")
        eq(t, "media 90% warns", rows[0].color, "#F2B84BFF")
        eq(t, "cache label", rows[1].text, "Transcode cache")
        eq(t, "cache value", rows[1].value, "64% full")
        eq(t, "cache fine", rows[1].color, "#7BD389FF")
    end if
    ' Two media disks are each named by where they are mounted.
    json = "{""Libraries"":[{""Name"":""A"",""Folders"":[{""Path"":""/a/m"",""FreeSpace"":1000000000,""UsedSpace"":1000000000,""DeviceId"":""/a""}]},{""Name"":""B"",""Folders"":[{""Path"":""/b/m"",""FreeSpace"":500000000,""UsedSpace"":500000000,""DeviceId"":""/b""}]}]}"
    rows = AdminDash_storageRows(ParseJSON(json))
    eq(t, "two disks", rows.count(), 2)
    if rows.count() = 2
        eq(t, "disk a", rows[0].text, "Media storage (/a)")
        eq(t, "disk b value", rows[1].value, "500 MB free of 1.0 GB")
    end if
    eq(t, "no storage", AdminDash_storageRows(invalid).count(), 0)
end sub

sub testBitrate(t as object)
    ' Converting: the delivered bitrate.
    s = session({ IsVideoDirect: false, IsAudioDirect: true, Bitrate: 8000000 })
    eq(t, "transcode bitrate", AdminDash_formatBitrate(AdminDash_sessionBitrate(s)), "8 Mbps")
    eq(t, "one decimal under 10", AdminDash_formatBitrate(8460000), "8.5 Mbps")
    ' Direct: the file's video plus the audio track being played.
    s = session(invalid)
    eq(t, "direct bitrate", AdminDash_formatBitrate(AdminDash_sessionBitrate(s)), "60 Mbps")
    eq(t, "kbps", AdminDash_formatBitrate(720000), "720 kbps")
    eq(t, "61 Mbps", AdminDash_formatBitrate(61400000), "61 Mbps")
    eq(t, "nothing", AdminDash_formatBitrate(0), "")
    idle = { Id: "idle", UserName: "ozzy" }
    total = AdminDash_totalBitrate([session({ IsVideoDirect: false, Bitrate: 8000000 }), session(invalid), idle])
    eq(t, "total ignores idle", AdminDash_formatBitrate(total), "68 Mbps")
end sub

sub testCounts(t as object)
    idle = { Id: "idle", UserName: "ozzy" }
    list = [session(invalid), session({ IsVideoDirect: true, IsAudioDirect: false }), session({ IsVideoDirect: false }), idle]
    eq(t, "playing excludes idle", AdminDash_playing(list).count(), 3)
    c = AdminDash_counts(list)
    eq(t, "streaming", c.streaming, 3)
    eq(t, "converting", c.converting, 2)
    eq(t, "none", AdminDash_counts([]).streaming, 0)
    eq(t, "invalid list", AdminDash_playing(invalid).count(), 0)
    ' /Sessions answers most-recently-active first, so the order shuffles from
    ' one poll to the next; the cards keep a stable order (user, device, id)
    ' or a highlighted card would swap under the remote.
    a = session(invalid, { Id: "a", UserName: "ozzy", DeviceName: "Fire TV" })
    b = session(invalid, { Id: "b", UserName: "Mom", DeviceName: "Roku" })
    c = session(invalid, { Id: "c", UserName: "mom", DeviceName: "Apple TV" })
    sorted = AdminDash_playing([a, b, c])
    eq(t, "sorted 1", sorted[0].Id, "c")
    eq(t, "sorted 2", sorted[1].Id, "b")
    eq(t, "sorted 3", sorted[2].Id, "a")
    sorted = AdminDash_playing([c, a, b])
    eq(t, "same order from another poll", sorted[0].Id + sorted[1].Id + sorted[2].Id, "cba")
    eq(t, "index of id", AdminDash_indexOfId(sorted, "a"), 2)
    eq(t, "index of missing id", AdminDash_indexOfId(sorted, "zz"), -1)
end sub

sub testActivity(t as object)
    a = AdminDash_activityLine({ Name: "Failed login attempt from admin", Type: "AuthenticationFailed", Severity: "Error", ShortOverview: "IP address: 185.220.101.4" })
    eq(t, "failed text", a.text, "Failed sign-in for admin · 185.x.x.x")
    eq(t, "failed red", a.color, "#FF6B6BFF")
    a = AdminDash_activityLine({ Name: "ozzy is online from Fire TV", Type: "SessionStarted", Severity: "Information", ShortOverview: "IP address: 72.1.2.3" })
    eq(t, "session started keeps no ip", a.text, "ozzy is online from Fire TV")
    eq(t, "session blue", a.color, "#8CC2FFFF")
    a = AdminDash_activityLine({ Name: "mom is playing 300 on Sashimi Roku", Type: "VideoPlayback", Severity: "Information" })
    eq(t, "playback accent", a.color, "#BD3EEDFF")
    a = AdminDash_activityLine({ Name: "mom has finished playing 300 on Sashimi Roku", Type: "VideoPlaybackStopped", Severity: "Information" })
    eq(t, "stop grey", a.color, "#6B7684FF")
    a = AdminDash_activityLine({ Name: "Login from 10.1.2.3", Type: "Custom", Severity: "Warning" })
    eq(t, "ip in name", a.text, "Login from 10.x.x.x")
    eq(t, "warning amber", a.color, "#F2B84BFF")
    a = AdminDash_activityLine({ Name: "Something", Type: "Other", Severity: "Error" })
    eq(t, "error red", a.color, "#FF6B6BFF")
end sub

sub testHealth(t as object)
    now = AdminDash_isoSeconds("2026-10-18T20:00:00Z")
    tasks = [
        { Name: "Scan Media Library", Key: "RefreshLibrary", State: "Idle", IsHidden: false, LastExecutionResult: { Status: "Completed", EndTimeUtc: "2026-10-18T18:00:00.1234567Z" } },
        { Name: "Intro Skipper analysis", Key: "IS", State: "Idle", IsHidden: false, LastExecutionResult: { Status: "Failed", EndTimeUtc: "2026-10-18T19:00:00Z" } },
        { Name: "Hidden thing", Key: "H", State: "Idle", IsHidden: true, LastExecutionResult: { Status: "Failed", EndTimeUtc: "2026-10-18T19:00:00Z" } },
        { Name: "Cancelled by hand", Key: "C", State: "Idle", IsHidden: false, LastExecutionResult: { Status: "Cancelled", EndTimeUtc: "2026-10-18T19:00:00Z" } },
        { Name: "Aborted", Key: "A", State: "Idle", IsHidden: false, LastExecutionResult: { Status: "Aborted", EndTimeUtc: "2026-10-17T19:00:00Z" } }
    ]
    hw = [session({ IsVideoDirect: false, HardwareAccelerationType: "qsv" }), session(invalid)]
    rows = AdminDash_healthRows(tasks, { HardwareAccelerationType: "qsv" }, { HasPendingRestart: false }, hw, now)
    eq(t, "rows", rows.count(), 4)
    if rows.count() = 4
        eq(t, "scan", rows[0].text, "Library scan")
        eq(t, "scan value", rows[0].value, "OK · 2 h ago")
        eq(t, "scan green", rows[0].color, "#7BD389FF")
        eq(t, "failed task", rows[1].text, "Intro Skipper analysis")
        eq(t, "failed value", rows[1].value, "Failed · 1 h ago")
        eq(t, "failed red", rows[1].color, "#FF6B6BFF")
        eq(t, "aborted counts", rows[2].value, "Failed · 1 d ago")
        eq(t, "hw", rows[3].text, "Hardware transcoding (QSV)")
        eq(t, "hw value", rows[3].value, "In use · 1 stream")
    end if
    ' All good: one green line for the tasks, hardware ready, restart pending.
    tasks = [{ Name: "Scan Media Library", Key: "RefreshLibrary", State: "Running", IsHidden: false, LastExecutionResult: { Status: "Failed", EndTimeUtc: "2026-10-18T19:00:00Z" } }]
    rows = AdminDash_healthRows(tasks, { HardwareAccelerationType: "none" }, { HasPendingRestart: true }, [], now)
    eq(t, "rows 2", rows.count(), 4)
    if rows.count() = 4
        eq(t, "scan running", rows[0].value, "Running")
        eq(t, "tasks ok", rows[1].value, "All OK")
        eq(t, "hw off", rows[2].value, "Off")
        eq(t, "restart", rows[3].text, "Restart pending")
    end if
    rows = AdminDash_healthRows(invalid, invalid, invalid, invalid, now)
    eq(t, "nothing known", rows.count(), 0)
end sub

sub testTimes(t as object)
    eq(t, "now", AdminDash_relativeTime(30), "now")
    eq(t, "min", AdminDash_relativeTime(12 * 60 + 5), "12 min")
    eq(t, "hours", AdminDash_relativeTime(2 * 3600 + 100), "2 h")
    eq(t, "days", AdminDash_relativeTime(3 * 86400), "3 d")
    eq(t, "future clock skew", AdminDash_relativeTime(-40), "now")
    a = AdminDash_isoSeconds("2026-10-18T19:37:48.706744Z")
    b = AdminDash_isoSeconds("2026-10-18T19:36:48Z")
    eq(t, "iso diff", a - b, 60)
    eq(t, "bad iso", AdminDash_isoSeconds("nope"), 0)
    eq(t, "clock", AdminDash_clock(3490), "58:10")
    eq(t, "clock h", AdminDash_clock(5640), "1:34:00")
    eq(t, "clock line", AdminDash_clockLine(session(invalid)), "20:44 / 1:57:00")
    p = AdminDash_progress(session(invalid))
    ok(t, "progress", p > 0.177 and p < 0.178)
    ok(t, "progress no runtime", AdminDash_progress({ NowPlayingItem: {}, PlayState: {} }) = 0)
end sub

sub testTitles(t as object)
    tl = AdminDash_titleLines({ Type: "Episode", Name: "Mercy", SeriesName: "Vikings", ParentIndexNumber: 4, IndexNumber: 3 })
    eq(t, "episode title", tl.title, "Vikings")
    eq(t, "episode sub", tl.subtitle, "S4 E3 · Mercy")
    tl = AdminDash_titleLines({ Type: "Movie", Name: "300", ProductionYear: 2006 })
    eq(t, "movie title", tl.title, "300")
    eq(t, "movie sub", tl.subtitle, "2006")
    eq(t, "who", AdminDash_whoLine(session(invalid)), "mom · Living Room Roku")
    eq(t, "stop message", AdminDash_stopMessage(session(invalid)), "mom is watching 300 on Living Room Roku. It stops on their screen right away.")
end sub

sub testDetails(t as object)
    s = session({ IsVideoDirect: false, IsAudioDirect: false, VideoCodec: "h264", AudioCodec: "aac", Width: 1920, Height: 1080, Bitrate: 8000000, HardwareAccelerationType: "qsv", TranscodeReasons: ["ContainerBitrateExceedsLimit"] })
    s.RemoteEndPoint = "72.14.3.99"
    d = AdminDash_detailsText(s)
    ok(t, "details has user", Instr(1, d, "mom") > 0)
    ok(t, "details has source", Instr(1, d, "HEVC") > 0)
    ok(t, "details has delivery", Instr(1, d, "H.264") > 0)
    ok(t, "details has reason", Instr(1, d, "Bitrate cap") > 0)
    ok(t, "details redacts address", Instr(1, d, "72.x.x.x") > 0 and Instr(1, d, "72.14") = 0)
end sub

' ---------- The OpsDec-style card (design revision 2026-10-18) ----------

' Video re-encoded by QSV at 43.2 fps from a 23.976 fps source, bitrate cap.
function tcSession() as object
    return session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "h264", AudioCodec: "dts", Width: 1920, Height: 1080, Bitrate: 8000000, Framerate: 43.2, AudioChannels: 6, HardwareAccelerationType: "qsv", TranscodeReasons: ["ContainerBitrateExceedsLimit"] })
end function

' Video copied, DTS to AC3 at real time.
function audioSession() as object
    return session({ IsVideoDirect: true, IsAudioDirect: false, VideoCodec: "hevc", AudioCodec: "ac3", Width: 3840, Height: 2160, Bitrate: 58640000, Framerate: 23.976, AudioChannels: 6, HardwareAccelerationType: "qsv", TranscodeReasons: ["AudioCodecNotSupported"] })
end function

sub testStateDot(t as object)
    eq(t, "playing green", AdminDash_stateDot(session(invalid)), "#7BD389FF")
    s = session(invalid)
    s.PlayState.IsPaused = true
    eq(t, "paused amber", AdminDash_stateDot(s), "#F2B84BFF")
    s.PlayState = invalid
    eq(t, "no play state grey", AdminDash_stateDot(s), "#6B7684FF")
    s.PlayState = { PositionTicks: 0 }
    eq(t, "no pause flag grey", AdminDash_stateDot(s), "#6B7684FF")
    eq(t, "not a session grey", AdminDash_stateDot(invalid), "#6B7684FF")
end sub

sub testCardTitle(t as object)
    c = AdminDash_cardTitle({ Type: "Episode", Name: "Mercy", SeriesName: "Vikings", ParentIndexNumber: 4, IndexNumber: 3 })
    eq(t, "ep title", c.title, "Mercy")
    eq(t, "ep sub", c.sub, "Vikings")
    eq(t, "ep tag", c.ep, "S04E03")
    eq(t, "tag 3 digits", AdminDash_episodeTag({ Type: "Episode", ParentIndexNumber: 12, IndexNumber: 112 }), "S12E112")
    eq(t, "tag specials", AdminDash_episodeTag({ Type: "Episode", ParentIndexNumber: 0, IndexNumber: 2 }), "S00E02")
    eq(t, "tag no season", AdminDash_episodeTag({ Type: "Episode", IndexNumber: 7 }), "E07")
    eq(t, "tag nothing", AdminDash_episodeTag({ Type: "Episode" }), "")
    eq(t, "movie has no tag", AdminDash_episodeTag({ Type: "Movie", ParentIndexNumber: 1, IndexNumber: 1 }), "")
    c = AdminDash_cardTitle({ Type: "Movie", Name: "300", ProductionYear: 2006 })
    eq(t, "movie title", c.title, "300")
    eq(t, "movie sub", c.sub, "Movie · 2006")
    eq(t, "movie tag", c.ep, "")
    eq(t, "movie no year", AdminDash_cardTitle({ Type: "Movie", Name: "X" }).sub, "Movie")
    eq(t, "other type keeps year", AdminDash_cardTitle({ Type: "MusicVideo", Name: "Y", ProductionYear: 1999 }).sub, "1999")
    eq(t, "nothing", AdminDash_cardTitle(invalid).title, "")
end sub

sub testCardPeople(t as object)
    eq(t, "device line", AdminDash_deviceLine(session(invalid)), "Sashimi · Living Room Roku")
    eq(t, "device only", AdminDash_deviceLine({ DeviceName: "Pixel 8" }), "Pixel 8")
    eq(t, "client only", AdminDash_deviceLine({ Client: "Jellyfin Web" }), "Jellyfin Web")
    eq(t, "initial", AdminDash_initialOf("mom"), "M")
    eq(t, "no name", AdminDash_initialOf(""), "?")
    eq(t, "no name invalid", AdminDash_initialOf(invalid), "?")
end sub

sub testPercent(t as object)
    eq(t, "18%", AdminDash_percentText(session(invalid)), "18%")
    eq(t, "no runtime", AdminDash_percentText({ NowPlayingItem: {}, PlayState: {} }), "")
end sub

sub testResolutionPill(t as object)
    eq(t, "direct res", AdminDash_resolutionPill(session(invalid)), "4K")
    eq(t, "tc res", AdminDash_resolutionPill(tcSession()), "4K → 1080p")
    ' Video copied: the delivered size is the source, whatever the server says.
    eq(t, "audio res", AdminDash_resolutionPill(audioSession()), "4K")
    s = session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "h264", Width: 3840, Height: 2160 })
    eq(t, "same res no arrow", AdminDash_resolutionPill(s), "4K")
    s = session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "h264" })
    eq(t, "unknown output size", AdminDash_resolutionPill(s), "4K")
    eq(t, "no video", AdminDash_resolutionPill({ NowPlayingItem: { MediaStreams: [] } }), "")
end sub

sub testVideoPill(t as object)
    eq(t, "direct DV", AdminDash_videoPill(session(invalid)), "HEVC DV")
    ranges = [["HDR10", "HEVC HDR10"], ["HDR10Plus", "HEVC HDR10+"], ["HLG", "HEVC HLG"], ["DOVIWithSDR", "HEVC DV"], ["SDR", "HEVC"]]
    for each r in ranges
        s = session(invalid)
        s.NowPlayingItem.MediaStreams[0].VideoRangeType = r[0]
        eq(t, "range " + r[0], AdminDash_videoPill(s), r[1])
    end for
    eq(t, "tc codec", AdminDash_videoPill(tcSession()), "HEVC DV → H264")
    ' Tone-mapped in the same codec: the range is what changed.
    s = session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "hevc", TranscodeReasons: ["VideoRangeTypeNotSupported"] })
    eq(t, "tone map", AdminDash_videoPill(s), "HEVC DV → HEVC SDR")
    s = session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "h264", TranscodeReasons: ["VideoRangeTypeNotSupported"] })
    eq(t, "tone map + codec", AdminDash_videoPill(s), "HEVC DV → H264 SDR")
    ' Re-encoded at another bitrate in the same codec and range: no arrow.
    s = session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "hevc", TranscodeReasons: ["ContainerBitrateExceedsLimit"] })
    eq(t, "same codec", AdminDash_videoPill(s), "HEVC DV")
    eq(t, "audio copies video", AdminDash_videoPill(audioSession()), "HEVC DV")
    s = session(invalid)
    s.NowPlayingItem.MediaStreams[0].Codec = "h265"
    s.NowPlayingItem.MediaStreams[0].VideoRangeType = "SDR"
    eq(t, "h265 is HEVC", AdminDash_videoPill(s), "HEVC")
    eq(t, "no video", AdminDash_videoPill({ NowPlayingItem: { MediaStreams: [] } }), "")
end sub

sub testAudioPill(t as object)
    eq(t, "direct dts", AdminDash_audioPill(session(invalid)), "DTS 5.1")
    ' Same channel count either side: said once, after the arrow.
    eq(t, "dts to ac3", AdminDash_audioPill(audioSession()), "DTS → AC3 5.1")
    s = session({ IsVideoDirect: true, IsAudioDirect: false, AudioCodec: "aac", AudioChannels: 2 })
    eq(t, "downmix", AdminDash_audioPill(s), "DTS 5.1 → AAC 2.0")
    s = session({ IsVideoDirect: true, IsAudioDirect: false, AudioCodec: "aac" })
    eq(t, "output channels unknown", AdminDash_audioPill(s), "DTS 5.1 → AAC")
    ' Audio copied while the video converts: the source track as is.
    eq(t, "tc copies audio", AdminDash_audioPill(tcSession()), "DTS 5.1")
    ' The flag decides: a copied track is the source even if AudioCodec disagrees.
    s = session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "h264", AudioCodec: "aac", AudioChannels: 2 })
    eq(t, "flag wins", AdminDash_audioPill(s), "DTS 5.1")
    s = session(invalid)
    s.PlayState.AudioStreamIndex = 2
    eq(t, "selected track", AdminDash_audioPill(s), "AC3 2.0")
    labels = [[1, "1.0"], [2, "2.0"], [3, "2.1"], [6, "5.1"], [8, "7.1"], [4, "4ch"]]
    for each l in labels
        eq(t, "channels " + l[0].ToStr(), AdminDash_channelsLabel(l[0]), l[1])
    end for
    eq(t, "channels unknown", AdminDash_channelsLabel(invalid), "")
    s = session(invalid)
    s.NowPlayingItem.MediaStreams[1].Codec = "truehd"
    s.NowPlayingItem.MediaStreams[1].Channels = 8
    eq(t, "truehd", AdminDash_audioPill(s), "TRUEHD 7.1")
    eq(t, "no audio", AdminDash_audioPill({ NowPlayingItem: { MediaStreams: [] } }), "")
end sub

sub testRatePill(t as object)
    eq(t, "direct rate", AdminDash_ratePill(session(invalid)), "60 Mbps")
    eq(t, "tc rate", AdminDash_ratePill(tcSession()), "60 → 8 Mbps")
    ' Video copied: the delivered rate, no arrow (it barely moves).
    eq(t, "audio rate", AdminDash_ratePill(audioSession()), "59 Mbps")
    s = session({ IsVideoDirect: false, IsAudioDirect: true, Bitrate: 720000 })
    eq(t, "units differ", AdminDash_ratePill(s), "60 Mbps → 720 kbps")
    s = session({ IsVideoDirect: false, IsAudioDirect: true, Bitrate: 8000000 })
    s.NowPlayingItem.MediaStreams = []
    eq(t, "source unknown", AdminDash_ratePill(s), "8 Mbps")
    s = session({ IsVideoDirect: false, IsAudioDirect: true, Bitrate: 59509000 })
    eq(t, "same rate", AdminDash_ratePill(s), "60 Mbps")
    eq(t, "nothing", AdminDash_ratePill({ NowPlayingItem: {} }), "")
end sub

sub testSpeed(t as object)
    eq(t, "1.8x", AdminDash_speed(tcSession()), "1.8x")
    eq(t, "1.0x", AdminDash_speed(audioSession()), "1.0x")
    s = tcSession()
    s.TranscodingInfo.Framerate = 100
    eq(t, "4.2x", AdminDash_speed(s), "4.2x")
    s.TranscodingInfo.Framerate = 12
    eq(t, "0.5x", AdminDash_speed(s), "0.5x")
    ' No source fps: RealFrameRate missing falls back to AverageFrameRate.
    s = tcSession()
    s.NowPlayingItem.MediaStreams[0].RealFrameRate = invalid
    s.NowPlayingItem.MediaStreams[0].AverageFrameRate = 24
    eq(t, "average fps", AdminDash_speed(s), "1.8x")
    s.NowPlayingItem.MediaStreams[0].AverageFrameRate = invalid
    eq(t, "no source fps", AdminDash_speed(s), "")
    s = tcSession()
    s.TranscodingInfo.Delete("Framerate")
    eq(t, "no framerate", AdminDash_speed(s), "")
    s.TranscodingInfo.Framerate = 0
    eq(t, "zero framerate", AdminDash_speed(s), "")
    eq(t, "direct", AdminDash_speed(session(invalid)), "")
end sub

sub testModePill(t as object)
    eq(t, "direct", AdminDash_modeLabel(session(invalid)), "Direct Play")
    eq(t, "remux", AdminDash_modeLabel(session({ IsVideoDirect: true, IsAudioDirect: true, HardwareAccelerationType: "qsv", Framerate: 50, TranscodeReasons: ["ContainerNotSupported"] })), "Direct Play")
    eq(t, "audio", AdminDash_modeLabel(audioSession()), "Audio only · 1.0x")
    s = audioSession()
    s.TranscodingInfo.Delete("Framerate")
    eq(t, "audio no speed", AdminDash_modeLabel(s), "Audio only")
    eq(t, "tc", AdminDash_modeLabel(tcSession()), "TC 1.8x HW")
    s = tcSession()
    s.TranscodingInfo.HardwareAccelerationType = "none"
    eq(t, "tc software", AdminDash_modeLabel(s), "TC 1.8x")
    s.TranscodingInfo.Delete("HardwareAccelerationType")
    eq(t, "tc no hw field", AdminDash_modeLabel(s), "TC 1.8x")
    s = tcSession()
    s.TranscodingInfo.Delete("Framerate")
    eq(t, "tc no speed", AdminDash_modeLabel(s), "TC HW")
    ' The server names its configured accelerator on every TranscodingInfo,
    ' remuxes included (seen on the live server), so HW only means something
    ' when the picture is encoded.
    ok(t, "hw on tc", AdminDash_isHardware(tcSession()))
    ok(t, "no hw on audio", not AdminDash_isHardware(audioSession()))
    ok(t, "no hw on direct", not AdminDash_isHardware(session(invalid)))
end sub

sub testPills(t as object)
    p = AdminDash_pills(tcSession())
    eq(t, "five pills", p.count(), 5)
    if p.count() = 5
        eq(t, "pill 1", p[0].text, "4K → 1080p")
        eq(t, "pill 2", p[1].text, "HEVC DV → H264")
        eq(t, "pill 3", p[2].text, "DTS 5.1")
        eq(t, "pill 4", p[3].text, "60 → 8 Mbps")
        eq(t, "pill 5", p[4].text, "TC 1.8x HW")
        eq(t, "res colors", p[0].fg + p[0].bg, "#6CC6F0FF#15303FFF")
        eq(t, "video colors", p[1].fg + p[1].bg, "#B79CF5FF#2A2140FF")
        eq(t, "audio colors", p[2].fg + p[2].bg, "#F2C46BFF#3A2D12FF")
        eq(t, "rate colors", p[3].fg + p[3].bg, "#5FD3C4FF#123331FF")
        eq(t, "tc colors", p[4].fg + p[4].bg, "#F2B84BFF#43341AFF")
    end if
    p = AdminDash_pills(audioSession())
    if p.count() = 5 then eq(t, "audio mode colors", p[4].fg + p[4].bg, "#8CC2FFFF#1E2E45FF")
    p = AdminDash_pills(session(invalid))
    if p.count() = 5 then eq(t, "direct mode colors", p[4].text + p[4].fg, "Direct Play#7BD389FF")
    ' Nothing known about the file: only the play mode.
    p = AdminDash_pills({ NowPlayingItem: {} })
    eq(t, "bare pills", p.count(), 1)
    if p.count() = 1 then eq(t, "bare mode", p[0].text, "Direct Play")
end sub

sub testFooterReason(t as object)
    eq(t, "as is", AdminDash_footerReason(session(invalid)), "Plays as-is")
    eq(t, "remux", AdminDash_footerReason(session({ IsVideoDirect: true, IsAudioDirect: true, TranscodeReasons: ["ContainerNotSupported"] })), "Remux")
    eq(t, "audio", AdminDash_footerReason(audioSession()), "Audio format not supported")
    eq(t, "tc", AdminDash_footerReason(tcSession()), "Bitrate cap")
    s = session({ IsVideoDirect: false, IsAudioDirect: true, TranscodeReasons: ["VideoResolutionNotSupported", "SubtitleCodecNotSupported", "VideoResolutionNotSupported"] })
    eq(t, "all reasons once", AdminDash_footerReason(s), "Resolution too high · Subtitles burned in")
    eq(t, "no reasons", AdminDash_footerReason(session({ IsVideoDirect: false, IsAudioDirect: true })), "Converting")
end sub

sub testLocalAddress(t as object)
    locals = ["192.168.86.30", "10.0.0.5", "10.255.255.255", "172.16.0.1", "172.31.255.255", "127.0.0.1", "169.254.10.1", "::1", "fe80::1", "FE80::ABCD", "febf::1", "fd12:3456::1", "fc00::1", "::ffff:192.168.1.5", "[fe80::1]:8096", "192.168.1.5:54321", " 10.1.2.3 "]
    for each a in locals
        ok(t, "local " + a, AdminDash_isLocalAddress(a))
    end for
    ' CGNAT (100.64.0.0/10) is someone else's network, not this LAN.
    remotes = ["100.64.0.1", "100.127.255.255", "172.15.0.1", "172.32.0.1", "8.8.8.8", "192.169.0.1", "11.0.0.1", "fec0::1", "fe7f::1", "2001:db8::1", "::ffff:8.8.8.8", "::ffff:100.64.0.1", "999.168.1.1", "192.168.1", "localhost", "", "::"]
    for each a in remotes
        ok(t, "remote " + a, not AdminDash_isLocalAddress(a))
    end for
    ok(t, "invalid", not AdminDash_isLocalAddress(invalid))
end sub

sub testWhere(t as object)
    s = session(invalid)
    s.RemoteEndPoint = "192.168.86.30"
    eq(t, "local", AdminDash_whereLabel(s), "Local")
    s.RemoteEndPoint = "100.70.1.2"
    eq(t, "cgnat remote", AdminDash_whereLabel(s), "Remote")
    s.RemoteEndPoint = "72.14.3.99"
    eq(t, "remote", AdminDash_whereLabel(s), "Remote")
    s.RemoteEndPoint = ""
    eq(t, "unknown", AdminDash_whereLabel(s), "")
    s.Delete("RemoteEndPoint")
    eq(t, "missing", AdminDash_whereLabel(s), "")
end sub
