' Off-device tests for source/utils/Fades.bs, run by tests/run.js. The
' "Lightest" backdrop fade (#255): left 0 -> 10% of the image's width,
' bottom 92% -> 100% of its height.

sub main()
    t = { passed: 0, failed: 0 }

    eq(t, "left fade of a 1056-wide detail backdrop", Fades_leftWidth(1056), 106)
    eq(t, "left fade of a 910-wide home hero", Fades_leftWidth(910), 91)
    eq(t, "bottom fade of a 594-tall detail backdrop", Fades_bottomHeight(594), 48)
    eq(t, "bottom fade of the 512-tall home hero", Fades_bottomHeight(512), 41)
    eq(t, "no image, no left fade", Fades_leftWidth(0), 0)
    eq(t, "no image, no bottom fade", Fades_bottomHeight(-5), 0)

    ' The home hero's 1274x512 region: a 16:9 backdrop fits by height and
    ' only moves right; 2.39:1 art fits by width and must move UP to the top
    ' edge, not float mid-banner with a hard top line.
    eq(t, "16:9 hero moves right only", pair(Fades_flushShift(1274, 512, 910, 512)), "182,0")
    eq(t, "wide hero is flush to the top", pair(Fades_flushShift(1274, 512, 1274, 433)), "0,-39")
    eq(t, "banner art is flush to the top", pair(Fades_flushShift(1274, 512, 1274, 236)), "0,-138")
    eq(t, "unknown size stays put", pair(Fades_flushShift(1274, 512, 0, 0)), "0,0")

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

function pair(v as object) as string
    return v[0].ToStr() + "," + v[1].ToStr()
end function

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub
