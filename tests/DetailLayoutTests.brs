' Off-device tests for source/utils/DetailLayout.bs, run by tests/run.js.
' Every detail page uses the Spotlight list page's backdrop (owner,
' 2026-11-11): full-bleed across the right ~2/3, fading left and bottom, the
' rows over the faded lower part.

sub main()
    t = { passed: 0, failed: 0 }

    r = DetailLayout_spotlight()
    eq(t, "flush right", r.x + r.w, 1920)
    eq(t, "the Spotlight list page's region", r.x, 560)
    eq(t, "16:9", r.h, 765)
    ok(t, "covers the right two-thirds or more", r.w * 3 >= 1920 * 2)
    for each kind in ["Movie", "Series", "Season", "Episode", "Video"]
        top = DetailLayout_rowsTop(kind)
        f = DetailLayout_fades(r)
        ' The rows sit over the faded part, not under a hard edge or beside
        ' the picture.
        ok(t, kind + ": rows start inside the picture", top < r.h)
        ok(t, kind + ": rows start below where the fade begins", top > f.bottom.y)
    end for
    eq(t, "season rows", DetailLayout_rowsTop("Season"), 480)
    eq(t, "series rows", DetailLayout_rowsTop("Series"), 734)

    ' The fades are the list page's: 720 of 1360 on the left, the lower 400 of 765.
    f = DetailLayout_fades(r)
    eq(t, "left fade width", f.left.w, 720)
    eq(t, "left fade x", f.left.x, 560)
    eq(t, "left fade height", f.left.h, 765)
    eq(t, "bottom fade y", f.bottom.y, 365)
    eq(t, "bottom fade height", f.bottom.h, 400)
    eq(t, "bottom fade width", f.bottom.w, 1360)
    ' Scaled to a smaller box (a scope trailer), still ending at its edges.
    b = DetailLayout_trailerBox(1360, 765, 2.39)
    f = DetailLayout_fades(b)
    eq(t, "scope box bottom fade ends at its bottom", f.bottom.y + f.bottom.h, b.h)
    eq(t, "scope box left fade starts at its left", f.left.x, b.x)

    ' Backdrops fill the region; a channel banner is fitted.
    eq(t, "16:9 backdrop fills", DetailLayout_artBox(16.0 / 9.0).h, 765)
    eq(t, "unknown aspect fills", DetailLayout_artBox(invalid).w, 1360)
    eq(t, "a 2:1 backdrop still fills", DetailLayout_artBox(2.0).h, 765)
    b = DetailLayout_artBox(6.2)
    eq(t, "banner: full width", b.w, 1360)
    eq(t, "banner: its own height", b.h, 219)
    eq(t, "banner: flush right", b.x, 560)

    ' The trailer's own rectangle (#257), fitted into the region.
    b = DetailLayout_trailerBox(1360, 765, 16.0 / 9.0)
    eq(t, "16:9 trailer: width", b.w, 1360)
    eq(t, "16:9 trailer: height", b.h, 765)
    eq(t, "16:9 trailer: flush right", b.x, 560)
    eq(t, "unknown aspect is 16:9", DetailLayout_trailerBox(1360, 765, invalid).h, 765)
    eq(t, "2.39:1 trailer", DetailLayout_trailerBox(1360, 765, 2.39).h, 569)
    b = DetailLayout_trailerBox(1360, 765, 4.0 / 3.0)
    eq(t, "4:3 trailer height", b.h, 765)
    eq(t, "4:3 trailer width", b.w, 1020)
    eq(t, "4:3 trailer flush right", b.x, 900)

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
