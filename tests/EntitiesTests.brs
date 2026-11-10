' Off-device tests for source/utils/Entities.bs, run by tests/run.js. Some
' metadata reaches Jellyfin with HTML character references left in (seen on
' device: Maxine &#34;Max&#34; Gibson, Terry&#39;s), which every overview
' drew as written.

sub main()
    t = { passed: 0, failed: 0 }

    testDecode(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected '"; expected; "' got '"; actual; "'"
    end if
end sub

sub testDecode(t as object)
    eq(t, "decimal", Entities_decode("Maxine &#34;Max&#34; Gibson"), "Maxine " + Chr(34) + "Max" + Chr(34) + " Gibson")
    eq(t, "apostrophe", Entities_decode("Terry&#39;s classmates"), "Terry's classmates")
    eq(t, "hex", Entities_decode("caf&#xE9;"), "caf" + Chr(233))
    eq(t, "named", Entities_decode("Tom &amp; Jerry &quot;live&quot; &lt;3 &gt; &apos;s&apos;"), "Tom & Jerry " + Chr(34) + "live" + Chr(34) + " <3 > 's'")
    eq(t, "nbsp", Entities_decode("a&nbsp;b"), "a b")
    eq(t, "an & on its own stays", Entities_decode("Fast & Furious"), "Fast & Furious")
    eq(t, "unknown name stays", Entities_decode("&bogus; x"), "&bogus; x")
    eq(t, "unterminated stays", Entities_decode("&#34 x"), "&#34 x")
    eq(t, "amp is decoded once", Entities_decode("&amp;#39;"), "&#39;")
    eq(t, "nothing to do", Entities_decode("plain text"), "plain text")
    eq(t, "empty", Entities_decode(""), "")
    eq(t, "not a string", Entities_decode(invalid), "")
end sub
