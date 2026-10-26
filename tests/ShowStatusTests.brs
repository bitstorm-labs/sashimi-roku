' Off-device tests for source/utils/ShowStatus.bs, run by tests/run.js against
' the transpiled module (out/source/utils/ShowStatus.brs). The series detail
' screen draws a status pill from what ShowStatus_badge returns: a label and a
' colour for the three values Jellyfin sends, nothing for anything else, and
' nothing at all off a Series, Season or Episode.

sub main()
    t = { passed: 0, failed: 0 }

    testKnownStatuses(t)
    testUnknownStatuses(t)
    testTvOnly(t)

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

sub isNone(t as object, name as string, b as dynamic)
    if b = invalid
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected no badge, got "; b.label
    end if
end sub

sub isBadge(t as object, name as string, b as dynamic, label as string, color as string)
    if b = invalid
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected a "; label; " badge, got none"
        return
    end if
    eq(t, name + " label", b.label, label)
    eq(t, name + " colour", b.color, color)
    ' A rounded rectangle like the media chips beside it, not a capsule (#246).
    eq(t, name + " shape", b.bg, "pkg:/images/badge_r6.9.png")
end sub

sub testKnownStatuses(t as object)
    isBadge(t, "Continuing", ShowStatus_badge("Series", "Continuing"), "Continuing", "#3FBF7FFF")
    isBadge(t, "Ended", ShowStatus_badge("Series", "Ended"), "Ended", "#B8B6C4FF")
    ' Jellyfin's enum name is not the word the pill shows.
    isBadge(t, "Unreleased", ShowStatus_badge("Series", "Unreleased"), "Upcoming", "#5CADE6FF")
    ' Case and stray whitespace don't change the answer.
    isBadge(t, "lower-case", ShowStatus_badge("Series", "continuing"), "Continuing", "#3FBF7FFF")
    isBadge(t, "padded", ShowStatus_badge("Series", " Ended "), "Ended", "#B8B6C4FF")
end sub

sub testUnknownStatuses(t as object)
    isNone(t, "missing", ShowStatus_badge("Series", invalid))
    isNone(t, "empty", ShowStatus_badge("Series", ""))
    isNone(t, "unknown value", ShowStatus_badge("Series", "Cancelled"))
    isNone(t, "label not accepted as input", ShowStatus_badge("Series", "Upcoming"))
    isNone(t, "non-string", ShowStatus_badge("Series", 1))
end sub

sub testTvOnly(t as object)
    ' Seasons and episodes show their series' status (the caller passes it).
    isBadge(t, "Season shows its series' status", ShowStatus_badge("Season", "Ended"), "Ended", "#B8B6C4FF")
    isBadge(t, "Episode shows its series' status", ShowStatus_badge("Episode", "Continuing"), "Continuing", "#3FBF7FFF")
    isBadge(t, "Episode of an upcoming show", ShowStatus_badge("Episode", "Unreleased"), "Upcoming", "#5CADE6FF")
    isNone(t, "Episode, series status unknown", ShowStatus_badge("Episode", invalid))
    isNone(t, "Season, series status unknown", ShowStatus_badge("Season", ""))
    for each kind in ["Movie", "BoxSet", "Video", ""]
        isNone(t, kind + " gets no badge", ShowStatus_badge(kind, "Continuing"))
    end for
    isNone(t, "no item type", ShowStatus_badge(invalid, "Continuing"))
end sub
