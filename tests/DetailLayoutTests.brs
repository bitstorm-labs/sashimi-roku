' Off-device tests for source/utils/DetailLayout.bs, run by tests/run.js.
' The detail hero (backdrop image and hero trailer) fades out over its bottom
' 40%, so it must end above the rows: on the Season page it ran under the
' episode row and the trailer was cut off by the cards mid-fade (#253).

sub main()
    t = { passed: 0, failed: 0 }

    for each kind in ["Movie", "Series", "Season", "Episode", "Video"]
        for each yt in [false, true]
            r = DetailLayout_heroRegion(kind, yt)
            ok(t, kind + " hero ends above its rows", r.h + 24 <= DetailLayout_rowsTop(kind))
        end for
    end for

    ' The Season page's rows sit under its poster.
    eq(t, "season rows", DetailLayout_rowsTop("Season"), 480)
    eq(t, "season hero height", DetailLayout_heroRegion("Season", false).h, 456)
    eq(t, "season hero width", DetailLayout_heroRegion("Season", false).w, 1056)
    ' Everything else keeps its size.
    eq(t, "series rows", DetailLayout_rowsTop("Series"), 734)
    eq(t, "series hero", DetailLayout_heroRegion("Series", false).h, 648)
    eq(t, "series hero width", DetailLayout_heroRegion("Series", false).w, 1056)
    eq(t, "movie hero", DetailLayout_heroRegion("Movie", false).h, 648)
    eq(t, "YouTube channel banner is wider", DetailLayout_heroRegion("Series", true).w, 1152)
    eq(t, "a YouTube episode is not", DetailLayout_heroRegion("Episode", true).w, 1056)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub ok(t as object, name as string, cond as boolean)
    if cond
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name
    end if
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub
