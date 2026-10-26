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

    ' The trailer's own rectangle (#257): a 16:9 trailer on a series whose
    ' backdrop fits to 1056x648 still gets a 16:9 box, not the backdrop's.
    b = DetailLayout_trailerBox(1056, 648, 16.0 / 9.0)
    eq(t, "16:9 trailer in a 1056x648 hero: width", b.w, 1056)
    eq(t, "16:9 trailer in a 1056x648 hero: height", b.h, 594)
    eq(t, "flush right", b.x, 864)
    b = DetailLayout_trailerBox(1056, 648, invalid)
    eq(t, "unknown aspect is 16:9", b.h, 594)
    ' The Season page's shorter hero: height-bound.
    b = DetailLayout_trailerBox(1056, 456, 16.0 / 9.0)
    eq(t, "season trailer width", b.w, 811)
    eq(t, "season trailer height", b.h, 456)
    eq(t, "season trailer flush right", b.x, 1109)
    ' Scope and 4:3 trailers keep their own shape.
    eq(t, "2.39:1 trailer", DetailLayout_trailerBox(1056, 648, 2.39).h, 442)
    b = DetailLayout_trailerBox(1056, 648, 4.0 / 3.0)
    eq(t, "4:3 trailer height", b.h, 648)
    eq(t, "4:3 trailer width", b.w, 864)

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
