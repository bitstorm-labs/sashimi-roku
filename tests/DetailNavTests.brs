' Off-device tests for source/utils/DetailNav.bs, run by tests/run.js. A
' detail screen's Series button pops back to that series when it is already
' on the stack, so Back never shows the same series twice (#246); otherwise
' the screen reloads as the series in place.

sub main()
    t = { passed: 0, failed: 0 }

    s = DetailNav_key("series1", "")
    ' Series -> (chip / Open Season) Season page -> Series: back to the series.
    eq(t, "season page over its series", DetailNav_popsTo([s, DetailNav_key("season1", "")], s), 1)
    ' Series -> episode -> Go to Series: the same.
    eq(t, "episode over its series", DetailNav_popsTo([s, DetailNav_key("ep1", "")], s), 1)
    ' Series -> episode -> Go to Season -> Series: both go, the series is on top.
    eq(t, "season over episode over series", DetailNav_popsTo([s, DetailNav_key("ep1", ""), DetailNav_key("season1", "")], s), 2)
    ' Home -> episode -> Go to Season -> Series: no series underneath, in place.
    eq(t, "no series underneath", DetailNav_popsTo(["", DetailNav_key("ep1", ""), DetailNav_key("season1", "")], s), 0)
    ' Another show's series underneath doesn't count.
    eq(t, "another series", DetailNav_popsTo([DetailNav_key("series2", ""), DetailNav_key("season1", "")], s), 0)
    ' The nearest copy wins.
    eq(t, "nearest", DetailNav_popsTo([s, "", s, DetailNav_key("season1", "")], s), 1)
    ' The asking screen itself is never a target.
    eq(t, "not itself", DetailNav_popsTo([s], s), 0)
    ' The same id on another saved server is another screen.
    eq(t, "other server", DetailNav_popsTo([DetailNav_key("series1", "srvB"), DetailNav_key("season1", "")], s), 0)
    eq(t, "unknown target", DetailNav_popsTo([s, ""], ""), 0)
    eq(t, "key", DetailNav_key("a", "b"), "a|b")
    eq(t, "no id, no key", DetailNav_key(invalid, ""), "")

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
