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
    testReasonLine(t)
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
                { Type: "Video", Codec: "hevc", Width: 3840, Height: 2160, VideoRangeType: "DOVIWithHDR10", BitRate: 58000000 },
                { Type: "Audio", Codec: "dts", Index: 1, IsDefault: true, BitRate: 1509000 },
                { Type: "Audio", Codec: "ac3", Index: 2, IsDefault: false, BitRate: 640000 }
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

sub testReasonLine(t as object)
    eq(t, "direct: nothing", AdminDash_reasonLine(session(invalid)), "")
    eq(t, "remux", AdminDash_reasonLine(session({ IsVideoDirect: true, IsAudioDirect: true, TranscodeReasons: ["ContainerNotSupported"] })), "Remux")
    ' Audio: the codec change in place of "Audio format not supported".
    eq(t, "audio", AdminDash_reasonLine(session({ IsVideoDirect: true, IsAudioDirect: false, AudioCodec: "ac3", TranscodeReasons: ["AudioCodecNotSupported"] })), "Video copied · DTS → AC3")
    ' The mockup's line: bitrate cap, then the resolution change.
    eq(t, "bitrate cap", AdminDash_reasonLine(session({ IsVideoDirect: false, IsAudioDirect: true, VideoCodec: "h264", Width: 1920, Height: 1080, TranscodeReasons: ["ContainerBitrateExceedsLimit"] })), "Bitrate cap · 4K → 1080p")
    ' Every reason is listed, in plain words, and the resolution change is
    ' named by the reason that caused it instead of being repeated.
    line = AdminDash_reasonLine(session({ IsVideoDirect: false, IsAudioDirect: false, VideoCodec: "h264", AudioCodec: "aac", Width: 1920, Height: 1080, TranscodeReasons: ["VideoResolutionNotSupported", "AudioCodecNotSupported", "SubtitleCodecNotSupported"] }))
    eq(t, "all reasons", line, "4K → 1080p · DTS → AAC · Subtitles burned in")
    ' Unknown codecs fall back to the words.
    s = session({ IsVideoDirect: true, IsAudioDirect: false, TranscodeReasons: ["AudioCodecNotSupported"] })
    eq(t, "no target codec", AdminDash_reasonLine(s), "Video copied · Audio format not supported")
    ' The audio track being played (PlayState.AudioStreamIndex) is the source.
    s = session({ IsVideoDirect: true, IsAudioDirect: false, AudioCodec: "aac", TranscodeReasons: ["AudioCodecNotSupported"] })
    s.PlayState.AudioStreamIndex = 2
    eq(t, "selected audio", AdminDash_reasonLine(s), "Video copied · AC3 → AAC")
    eq(t, "duplicate reasons", AdminDash_reasonLine(session({ IsVideoDirect: false, IsAudioDirect: true, TranscodeReasons: ["ContainerBitrateExceedsLimit", "ContainerBitrateExceedsLimit"] })), "Bitrate cap")
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
    eq(t, "detail line", AdminDash_detailLine(s), "4K Dolby Vision · Bitrate cap · 4K → 1080p")
    eq(t, "direct detail", AdminDash_detailLine(session(invalid)), "4K Dolby Vision")
end sub
