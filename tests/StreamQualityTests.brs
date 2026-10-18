' Off-device tests for source/utils/StreamQuality.bs, run by tests/run.js
' against the transpiled module (out/source/utils/StreamQuality.brs) with the
' @rokucommunity/brs interpreter. Plain BrightScript: this file is not part of
' the channel package.

sub main()
    t = { passed: 0, failed: 0 }

    testTiers(t)
    testLabels(t)
    testWidths(t)
    testAutoCap(t)
    testStepDown(t)
    testSettingsCap(t)
    testLocalServer(t)
    testProbe(t)
    testVideoConditions(t)
    testAudioProfile(t)
    testRangeTypes(t)
    testTranscodeCodecs(t)
    testConnection(t)
    testSustainedKey(t)
    testSegments(t)
    testReencodes(t)
    testSustainedSamples(t)
    testWirelessCeiling(t)
    testCooldown(t)
    testSustainedUpgrade(t)

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

' The Apple client's tiers: 1080p 20, 720p 8, 480p 4, then the low-bandwidth
' 720p 2 Mbps, 480p 1 Mbps, 360p 720 kbps -- each with its width cap.
sub testTiers(t as object)
    tiers = StreamQuality_tiers()
    eq(t, "tier count", tiers.Count(), 6)
    want = [
        [20000000, 1920, "1080p"],
        [8000000, 1280, "720p"],
        [4000000, 854, "480p"],
        [2000000, 1280, "720p"],
        [1000000, 854, "480p"],
        [720000, 640, "360p"]
    ]
    if tiers.Count() <> 6 then return
    for i = 0 to 5
        n = "tier " + i.ToStr()
        eq(t, n + " bps", tiers[i].bps, want[i][0])
        eq(t, n + " width", tiers[i].width, want[i][1])
        eq(t, n + " name", tiers[i].name, want[i][2])
    end for
end sub

sub testLabels(t as object)
    dot = " " + Chr(183) + " "
    eq(t, "label 20M", StreamQuality_label(20000000), "1080p" + dot + "20 Mbps")
    eq(t, "label 2M", StreamQuality_label(2000000), "720p" + dot + "2 Mbps")
    eq(t, "label floor", StreamQuality_label(720000), "360p" + dot + "720 kbps")
    eq(t, "label non-tier", StreamQuality_label(80000000), "80 Mbps")
    eq(t, "bitrate 2.1M", StreamQuality_bitrateLabel(2125000), "2.1 Mbps")
    eq(t, "bitrate 14.6M", StreamQuality_bitrateLabel(14600000), "15 Mbps")
    eq(t, "bitrate 850k", StreamQuality_bitrateLabel(850000), "850 kbps")
end sub

sub testWidths(t as object)
    eq(t, "width auto", StreamQuality_widthForCap(0), 0)
    eq(t, "width 80M", StreamQuality_widthForCap(80000000), 0)
    eq(t, "width 20M", StreamQuality_widthForCap(20000000), 1920)
    eq(t, "width 8M", StreamQuality_widthForCap(8000000), 1280)
    eq(t, "width 4M", StreamQuality_widthForCap(4000000), 854)
    eq(t, "width 2M", StreamQuality_widthForCap(2000000), 1280)
    eq(t, "width 1M", StreamQuality_widthForCap(1000000), 854)
    eq(t, "width 720k", StreamQuality_widthForCap(720000), 640)
    ' Auto only narrows the picture once a re-encode is certain.
    eq(t, "auto width 20M", StreamQuality_autoMaxWidth(20000000), 0)
    eq(t, "auto width 4M", StreamQuality_autoMaxWidth(4000000), 0)
    eq(t, "auto width 2.1M", StreamQuality_autoMaxWidth(2125000), 1280)
    eq(t, "auto width 1M", StreamQuality_autoMaxWidth(1000000), 854)
    eq(t, "auto width floor", StreamQuality_autoMaxWidth(720000), 640)
end sub

sub testAutoCap(t as object)
    ' Unmeasured: conservative over the internet, high on the LAN.
    eq(t, "unmeasured remote", StreamQuality_autoCapBps(0, false), 4000000)
    eq(t, "unmeasured local", StreamQuality_autoCapBps(0, true), 20000000)
    ' Measured: 85%, wherever the server is.
    eq(t, "measured 10M", StreamQuality_autoCapBps(10000000, false), 8500000)
    eq(t, "measured 10M local", StreamQuality_autoCapBps(10000000, true), 8500000)
    ' A slow link is asked for what it can carry, not a 3 Mbps floor.
    eq(t, "measured 2.5M", StreamQuality_autoCapBps(2500000, false), 2125000)
    eq(t, "measured 1.2M", StreamQuality_autoCapBps(1200000, false), 1020000)
    eq(t, "floor", StreamQuality_autoCapBps(300000, false), 720000)
    eq(t, "ceiling", StreamQuality_autoCapBps(900000000, true), 100000000)
end sub

sub testStepDown(t as object)
    ' The whole ladder from the top tier.
    want = [8000000, 4000000, 2000000, 1000000, 720000, 0]
    cur = 20000000
    for i = 0 to 5
        cur = StreamQuality_nextStepDownBps(cur)
        eq(t, "ladder step " + i.ToStr(), cur, want[i])
        if cur = 0 then exit for
    end for
    ' From caps that are not tiers.
    eq(t, "step from 9.5M", StreamQuality_nextStepDownBps(9500000), 4000000)
    eq(t, "step from 100M", StreamQuality_nextStepDownBps(100000000), 20000000)
    eq(t, "step from 3M", StreamQuality_nextStepDownBps(3000000), 1000000)
    eq(t, "step from 1.2M", StreamQuality_nextStepDownBps(1200000), 720000)
    eq(t, "step at floor", StreamQuality_nextStepDownBps(720000), 0)
    eq(t, "step unknown", StreamQuality_nextStepDownBps(0), 0)
end sub

sub testSettingsCap(t as object)
    eq(t, "settings auto", StreamQuality_settingsCapBps("0"), 0)
    eq(t, "settings empty", StreamQuality_settingsCapBps(""), 0)
    eq(t, "settings 80", StreamQuality_settingsCapBps("80"), 80000000)
    eq(t, "settings 8", StreamQuality_settingsCapBps("8"), 8000000)
    eq(t, "settings 0.72", StreamQuality_settingsCapBps("0.72"), 720000)
    ' The retired "480p (3 Mbps)" option reads as the 4 Mbps tier.
    eq(t, "settings legacy 3", StreamQuality_settingsCapBps("3"), 4000000)
end sub

sub testLocalServer(t as object)
    eq(t, "lan ip", StreamQuality_isLocalServer("http://192.168.86.151:9096"), true)
    eq(t, "10.x", StreamQuality_isLocalServer("http://10.0.0.5:8096/"), true)
    eq(t, "172.16", StreamQuality_isLocalServer("https://172.20.1.1"), true)
    eq(t, "172.32", StreamQuality_isLocalServer("https://172.32.1.1"), false)
    eq(t, "loopback", StreamQuality_isLocalServer("http://127.0.0.1:8096"), true)
    eq(t, "mdns", StreamQuality_isLocalServer("http://popcorn.local:8096"), true)
    eq(t, "single label", StreamQuality_isLocalServer("http://popcorn:9096"), true)
    eq(t, "ipv6 link-local", StreamQuality_isLocalServer("http://[fe80::1]:8096"), true)
    eq(t, "public host", StreamQuality_isLocalServer("https://jellyfin.example.com"), false)
    eq(t, "public ip", StreamQuality_isLocalServer("http://8.8.8.8:8096"), false)
    eq(t, "tailscale", StreamQuality_isLocalServer("http://100.92.236.87:9096"), false)
    eq(t, "empty", StreamQuality_isLocalServer(""), false)
end sub

sub testProbe(t as object)
    eq(t, "rate 8MB in 4s", StreamQuality_probeRateBps(8000000, 4000), 16000000)
    eq(t, "rate nothing", StreamQuality_probeRateBps(0, 4000), 0)
    eq(t, "rate no time", StreamQuality_probeRateBps(8000000, 0), 0)
    eq(t, "rate capped", StreamQuality_probeRateBps(8000000, 1), 1000 * 1000000)

    ' Fast link: the follow-up is the full-size sample.
    eq(t, "follow-up fast", StreamQuality_probeFollowUpBytes(60000000, 33), 8000000)
    ' 2.5 Mbps link: about six seconds' worth, not 8 MB.
    eq(t, "follow-up 2.5M", StreamQuality_probeFollowUpBytes(2500000, 800), 1875000)
    ' A pilot that itself took 3 s+ is the measurement.
    eq(t, "follow-up slow pilot", StreamQuality_probeFollowUpBytes(500000, 4000), 0)
    eq(t, "follow-up floor", StreamQuality_probeFollowUpBytes(600000, 2900), 500000)

    ' A download that timed out still yields a number: bounded by what would
    ' have finished in time...
    eq(t, "timeout bound", StreamQuality_probeTimeoutEstimateBps(250000, 8000, 0), 250000)
    ' ...and by an earlier completed sample when that was lower.
    eq(t, "timeout earlier lower", StreamQuality_probeTimeoutEstimateBps(1875000, 12000, 900000), 900000)
    eq(t, "timeout earlier higher", StreamQuality_probeTimeoutEstimateBps(1875000, 12000, 2500000), 1250000)
    ' The old probe's own case: 8 MB not done in 20 s used to mean "unknown".
    eq(t, "timeout 8MB in 20s", StreamQuality_probeTimeoutEstimateBps(8000000, 20000, 0), 3200000)

    ' The audit's scenario end to end: a 2.5 Mbps remote link. The old probe
    ' (8 MB, 20 s wait) timed out, reported nothing, and Auto asked for
    ' 20 Mbps. Now the 250 KB pilot lands in 0.8 s...
    pilotBps = StreamQuality_probeRateBps(250000, 800)
    eq(t, "2.5M link pilot", pilotBps, 2500000)
    ' ...the sample is sized to about six seconds of it and completes...
    sampleBytes = StreamQuality_probeFollowUpBytes(pilotBps, 800)
    measured = StreamQuality_probeRateBps(sampleBytes, 6000)
    eq(t, "2.5M link measured", measured, 2500000)
    ' ...and Auto asks for what the link can carry.
    eq(t, "2.5M link auto cap", StreamQuality_autoCapBps(measured, false), 2125000)
    ' A 400 kbps link: the pilot alone takes 5 s and is the measurement.
    slowBps = StreamQuality_probeRateBps(250000, 5000)
    eq(t, "400k link no follow-up", StreamQuality_probeFollowUpBytes(slowBps, 5000), 0)
    eq(t, "400k link auto cap", StreamQuality_autoCapBps(slowBps, false), 720000)
    ' A link too slow for even the pilot still gets the floor, not 20 Mbps.
    eq(t, "dead-slow link auto cap", StreamQuality_autoCapBps(StreamQuality_probeTimeoutEstimateBps(250000, 8000, 0), false), 720000)
end sub

sub testVideoConditions(t as object)
    ' 4K output, no tier: unconstrained.
    eq(t, "uhd none", StreamQuality_videoConditions(true, 0).Count(), 0)
    ' HD output, no tier: the 1920x1080 limit, as before.
    hd = StreamQuality_videoConditions(false, 0)
    eq(t, "hd count", hd.Count(), 2)
    if hd.Count() = 2
        eq(t, "hd width", hd[0].Value, "1920")
        eq(t, "hd height prop", hd[1].Property, "Height")
        eq(t, "hd height", hd[1].Value, "1080")
    end if
    ' A tier's width reaches the profile on either kind of output.
    uhdTier = StreamQuality_videoConditions(true, 1280)
    eq(t, "uhd tier count", uhdTier.Count(), 1)
    if uhdTier.Count() = 1
        eq(t, "uhd tier prop", uhdTier[0].Property, "Width")
        eq(t, "uhd tier cond", uhdTier[0].Condition, "LessThanEqual")
        eq(t, "uhd tier width", uhdTier[0].Value, "1280")
        eq(t, "uhd tier required", uhdTier[0].IsRequired, true)
    end if
    hdTier = StreamQuality_videoConditions(false, 640)
    if hdTier.Count() > 0 then eq(t, "hd tier width", hdTier[0].Value, "640")
    eq(t, "hd tier count", hdTier.Count(), 2)
    ' A width wider than the output limit does not loosen it.
    wide = StreamQuality_videoConditions(false, 3840)
    if wide.Count() > 0 then eq(t, "hd wide width", wide[0].Value, "1920")
end sub

function audioCaps(ac3 as boolean, eac3 as boolean, aac6 as boolean, surround as boolean) as object
    return { ac3: ac3, eac3: eac3, aac6: aac6, hevc: false, surround: surround, uhd: false }
end function

sub testAudioProfile(t as object)
    ' The remote viewer whose every episode froze at 2 s: a 5.1 output that
    ' takes AC3 but not E-AC3 or six-channel AAC. E-AC3 5.1 sources must be
    ' streamed as AC3, never 5.1 AAC, and AAC is held to stereo.
    a = StreamQuality_audioProfile(audioCaps(true, false, false, true))
    eq(t, "ac3 5.1 stream", a.stream, "ac3,aac")
    eq(t, "ac3 5.1 channels", a.channels, "6")
    eq(t, "ac3 5.1 direct", a.direct, "aac,mp3,ac3")
    eq(t, "ac3 5.1 aac profile", a.profiles.Count(), 1)
    if a.profiles.Count() = 1
        p = a.profiles[0]
        eq(t, "aac profile type", p.Type, "VideoAudio")
        eq(t, "aac profile codec", p.Codec, "aac")
        eq(t, "aac profile prop", p.Conditions[0].Property, "AudioChannels")
        eq(t, "aac profile cond", p.Conditions[0].Condition, "LessThanEqual")
        eq(t, "aac profile value", p.Conditions[0].Value, "2")
    end if
    ' Both Dolby codecs: both ahead of AAC.
    both = StreamQuality_audioProfile(audioCaps(true, true, false, true))
    eq(t, "dolby stream", both.stream, "ac3,eac3,aac")
    eq(t, "dolby direct", both.direct, "aac,mp3,ac3,eac3")
    ' A device that decodes six-channel AAC keeps it, with no stereo cap.
    aac = StreamQuality_audioProfile(audioCaps(false, false, true, true))
    eq(t, "aac6 stream", aac.stream, "aac")
    eq(t, "aac6 channels", aac.channels, "6")
    eq(t, "aac6 no profile", aac.profiles.Count(), 0)
    ' Surround output but nothing that carries it: stereo AAC.
    none = StreamQuality_audioProfile(audioCaps(false, false, false, true))
    eq(t, "no surround codec channels", none.channels, "2")
    eq(t, "no surround codec stream", none.stream, "aac")
    eq(t, "no surround codec profile", none.profiles.Count(), 1)
    ' Stereo output: stereo whatever the device decodes, AAC first.
    tv = StreamQuality_audioProfile(audioCaps(true, false, true, false))
    eq(t, "stereo channels", tv.channels, "2")
    eq(t, "stereo stream", tv.stream, "aac,ac3")
    eq(t, "stereo aac profile", tv.profiles.Count(), 1)
end sub

' Dolby Vision with a base layer must be listed, or Jellyfin re-encodes 54
' 4K films (DOVIWithHDR10 MKVs such as Moonrise Kingdom) instead of copying
' them. Bare DOVI only for a Dolby Vision display.
sub testRangeTypes(t as object)
    plain = StreamQuality_hevcRangeTypes(false)
    eq(t, "range types no dv", plain, "SDR|HDR10|HDR10Plus|HLG|DOVIWithHDR10|DOVIWithHDR10Plus|DOVIWithHLG|DOVIWithSDR")
    eq(t, "range types dv", StreamQuality_hevcRangeTypes(true), plain + "|DOVI")
    parts = plain.Split("|")
    bare = false
    for each p in parts
        if p = "DOVI" then bare = true
    end for
    eq(t, "no bare DOVI without dv display", bare, false)
    rp = StreamQuality_videoRangeProfile(false)
    eq(t, "range profile type", rp.Type, "Video")
    eq(t, "range profile codec", rp.Codec, "hevc")
    eq(t, "range profile cond", rp.Conditions[0].Condition, "EqualsAny")
    eq(t, "range profile prop", rp.Conditions[0].Property, "VideoRangeType")
    eq(t, "range profile value", rp.Conditions[0].Value, plain)
    eq(t, "range profile not required", rp.Conditions[0].IsRequired, false)
end sub

sub testTranscodeCodecs(t as object)
    ' H.264 first (re-encode target), HEVC copyable after it.
    eq(t, "hevc device", StreamQuality_transcodeVideoCodecs(true), "h264,hevc")
    eq(t, "no hevc device", StreamQuality_transcodeVideoCodecs(false), "h264")
end sub

sub testConnection(t as object)
    eq(t, "wired", StreamQuality_isWiredConnection("WiredConnection"), true)
    eq(t, "wifi", StreamQuality_isWiredConnection("WiFiConnection"), false)
    eq(t, "offline", StreamQuality_isWiredConnection(""), false)
end sub

sub testSustainedKey(t as object)
    eq(t, "key wireless", StreamQuality_sustainedKey("http://192.168.86.151:9096", false), "http://192.168.86.151:9096|wireless")
    eq(t, "key wired", StreamQuality_sustainedKey("http://192.168.86.151:9096", true), "http://192.168.86.151:9096|wired")
    eq(t, "key case + slash", StreamQuality_sustainedKey("HTTPS://Jelly.Example.com/jf/", false), "https://jelly.example.com/jf|wireless")
    eq(t, "key same server", StreamQuality_sustainedKey("http://popcorn:9096/", true), StreamQuality_sustainedKey("http://POPCORN:9096", true))
end sub

sub testSegments(t as object)
    w = { bytes: 0, ms: 0 }
    ' 2 MB segments at 1 s each: nothing until 16 MB, then 16 Mbps.
    for i = 1 to 7
        eq(t, "segment " + i.ToStr() + " no reading", StreamQuality_addSegment(w, 2000000, 1000), 0)
    end for
    eq(t, "segment 8 reading", StreamQuality_addSegment(w, 2000000, 1000), 16000000)
    eq(t, "window reset bytes", w.bytes, 0)
    eq(t, "window reset ms", w.ms, 0)
    ' A short burst of fast segments is not a reading on its own.
    eq(t, "burst under 16MB", StreamQuality_addSegment(w, 4000000, 100), 0)
    eq(t, "bad segment ignored", StreamQuality_addSegment(w, 0, 100), 0)
    eq(t, "bad segment keeps window", w.bytes, 4000000)
end sub

sub testSustainedSamples(t as object)
    s = []
    for each bps in [90000000, 40000000, 120000000, 80000000, 70000000]
        s = StreamQuality_addSustainedSample(s, bps)
    end for
    eq(t, "five kept", s.Count(), 5)
    ' The lowest, not the average.
    eq(t, "sustained lowest", StreamQuality_sustainedBps(s), 40000000)
    ' A sixth pushes the oldest out; the slow one stays until it ages out.
    s = StreamQuality_addSustainedSample(s, 100000000)
    eq(t, "still five", s.Count(), 5)
    eq(t, "oldest dropped", s[0], 40000000)
    s = StreamQuality_addSustainedSample(s, 100000000)
    eq(t, "slow reading aged out", StreamQuality_sustainedBps(s), 70000000)
    eq(t, "none remembered", StreamQuality_sustainedBps([]), 0)
    eq(t, "nothing stored", StreamQuality_sustainedBps(invalid), 0)
    ' Registry JSON: doubles and junk.
    j = ParseJSON("[30000000.0, ""x"", 50000000]")
    eq(t, "json samples", StreamQuality_sustainedBps(j), 30000000)
    eq(t, "json kept", StreamQuality_addSustainedSample(j, 0).Count(), 2)
    eq(t, "zero reading not kept", StreamQuality_addSustainedSample([], 0).Count(), 0)
end sub

sub testWirelessCeiling(t as object)
    ' Nothing remembered: the old smooth-4K clamp.
    eq(t, "wifi unremembered", StreamQuality_wirelessCeilingBps(85000000, 0), 24000000)
    eq(t, "wifi unremembered slow cap", StreamQuality_wirelessCeilingBps(4000000, 0), 4000000)
    ' Remembered: half the sustained rate, under the cap.
    eq(t, "wifi half sustained", StreamQuality_wirelessCeilingBps(85000000, 120000000), 60000000)
    eq(t, "wifi capped", StreamQuality_wirelessCeilingBps(30000000, 120000000), 30000000)
    ' A link that proved 100 Mbps copies a 44 Mbps 4K source on Wi-Fi.
    eq(t, "wifi link cap", StreamQuality_linkCapBps(85000000, false, 100000000), 50000000)
    eq(t, "wifi link cap unremembered", StreamQuality_linkCapBps(85000000, false, 0), 24000000)
    ' Ethernet carries what it measured.
    eq(t, "wired link cap", StreamQuality_linkCapBps(85000000, true, 10000000), 85000000)
end sub

sub testCooldown(t as object)
    eq(t, "cooldown 0", StreamQuality_adaptiveCooldownSecs(0), 120)
    eq(t, "cooldown 1", StreamQuality_adaptiveCooldownSecs(1), 240)
    eq(t, "cooldown 3", StreamQuality_adaptiveCooldownSecs(3), 960)
    eq(t, "cooldown capped 32x", StreamQuality_adaptiveCooldownSecs(9), 3840)
    eq(t, "cooldown negative", StreamQuality_adaptiveCooldownSecs(-2), 120)
end sub

function upgradeCtx() as object
    ' Wi-Fi, Auto held a 44 Mbps 4K source to 24 Mbps; the link now has
    ' proven 100 Mbps sustained.
    return {
        isAuto: true, isWired: false, isTranscoding: true, isBusy: false,
        autoCap: 85000000, activeCap: 24000000, sourceBps: 44000000, sustainedBps: 100000000,
        secondsSinceRecovery: -1, secondsSinceQualityChange: -1, failedUpgrades: 0
    }
end function

sub testSustainedUpgrade(t as object)
    eq(t, "upgrade now", StreamQuality_sustainedUpgrade(upgradeCtx()), 0)
    ' Never over a quality the viewer picked.
    c = upgradeCtx() : c.isAuto = false
    eq(t, "viewer pick", StreamQuality_sustainedUpgrade(c), -1)
    ' Nothing held down: direct play, or a cap that already covers the source.
    c = upgradeCtx() : c.isTranscoding = false
    eq(t, "not transcoding", StreamQuality_sustainedUpgrade(c), -1)
    c = upgradeCtx() : c.activeCap = 50000000
    eq(t, "cap covers source", StreamQuality_sustainedUpgrade(c), -1)
    c = upgradeCtx() : c.sustainedBps = 0
    eq(t, "nothing remembered", StreamQuality_sustainedUpgrade(c), -1)
    ' Wi-Fi ceiling 30 Mbps: under the source and under 2x 24 Mbps.
    c = upgradeCtx() : c.sustainedBps = 60000000
    eq(t, "not enough", StreamQuality_sustainedUpgrade(c), -1)
    ' A stall step-down to 4 Mbps: 2x the cap is enough, short of the source.
    c = upgradeCtx() : c.activeCap = 4000000 : c.sustainedBps = 20000000
    eq(t, "double the step-down", StreamQuality_sustainedUpgrade(c), 0)
    c = upgradeCtx() : c.activeCap = 8000000 : c.sustainedBps = 30000000
    eq(t, "short of double", StreamQuality_sustainedUpgrade(c), -1)
    ' Wired: the ceiling is the sustained rate itself, under the Auto cap.
    c = upgradeCtx() : c.isWired = true : c.activeCap = 8000000 : c.sustainedBps = 30000000
    eq(t, "wired double", StreamQuality_sustainedUpgrade(c), 0)
    c = upgradeCtx() : c.isWired = true : c.autoCap = 12000000 : c.activeCap = 8000000 : c.sustainedBps = 90000000
    eq(t, "wired auto cap limits", StreamQuality_sustainedUpgrade(c), -1)
    ' Timing: busy, a fresh rebuffer, and the cooldown.
    c = upgradeCtx() : c.isBusy = true
    eq(t, "busy waits", StreamQuality_sustainedUpgrade(c), 15)
    c = upgradeCtx() : c.secondsSinceRecovery = 5
    eq(t, "recovery quiet", StreamQuality_sustainedUpgrade(c), 10)
    c = upgradeCtx() : c.secondsSinceQualityChange = 100
    eq(t, "cooldown wait", StreamQuality_sustainedUpgrade(c), 20)
    c = upgradeCtx() : c.secondsSinceQualityChange = 130
    eq(t, "cooldown over", StreamQuality_sustainedUpgrade(c), 0)
    c = upgradeCtx() : c.secondsSinceQualityChange = 130 : c.failedUpgrades = 1
    eq(t, "cooldown doubled", StreamQuality_sustainedUpgrade(c), 110)
end sub

' Only a remux's readings measure the link; a re-encode's are the encoder's.
sub testReencodes(t as object)
    eq(t, "audio only", StreamQuality_reencodesVideo("AudioCodecNotSupported"), false)
    eq(t, "remux after direct play refused", StreamQuality_reencodesVideo("DirectPlayError"), false)
    eq(t, "over the cap", StreamQuality_reencodesVideo("AudioCodecNotSupported,ContainerBitrateExceedsLimit"), true)
    eq(t, "url-encoded", StreamQuality_reencodesVideo("AudioCodecNotSupported%2CContainerBitrateExceedsLimit"), true)
    eq(t, "codec", StreamQuality_reencodesVideo("VideoCodecNotSupported"), true)
    eq(t, "range", StreamQuality_reencodesVideo("VideoRangeTypeNotSupported"), true)
    eq(t, "nothing", StreamQuality_reencodesVideo(""), false)
end sub
