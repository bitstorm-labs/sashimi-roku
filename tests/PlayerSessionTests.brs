' Off-device tests for source/utils/PlayerSession.bs, run by tests/run.js
' against the transpiled module (out/source/utils/PlayerSession.brs): which
' API answers a player that has already closed may still act on.

sub main()
    t = { passed: 0, failed: 0 }

    testPlaybackNeverRestartsAfterClose(t)
    testWatchStateWritesStillLand(t)

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

' Back during "Loading..." or "Lowering quality...", then the stream answer:
' it used to set the off-screen Video node playing and report a start the
' server never saw stopped. A channel's roll-over and flip answers lead to the
' same place through a new item.
sub testPlaybackNeverRestartsAfterClose(t as object)
    eq(t, "stream answer", PlayerSession_actsAfterClose("getPlaybackStream"), false)
    eq(t, "channel roll-over", PlayerSession_actsAfterClose("getChannelNowPlaying"), false)
    eq(t, "channel next item", PlayerSession_actsAfterClose("getItem"), false)
    eq(t, "station guide", PlayerSession_actsAfterClose("getGuide"), false)
    eq(t, "next-episode lookup", PlayerSession_actsAfterClose("getSiblingEpisodes"), false)
    eq(t, "intro segments", PlayerSession_actsAfterClose("getIntroSegments"), false)
    eq(t, "unknown action", PlayerSession_actsAfterClose("somethingNew"), false)
    eq(t, "no action", PlayerSession_actsAfterClose(invalid), false)
end sub

' The stop report and mark-played are queued as the player closes; their
' answers bump watchStateVersion so the detail screen underneath re-reads.
sub testWatchStateWritesStillLand(t as object)
    eq(t, "stop report", PlayerSession_actsAfterClose("reportStopped"), true)
    eq(t, "mark played", PlayerSession_actsAfterClose("markPlayed"), true)
end sub
