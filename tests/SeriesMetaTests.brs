' Off-device tests for source/utils/SeriesMeta.bs, run by tests/run.js against
' the transpiled module (out/source/utils/SeriesMeta.brs). The series meta
' line once read "1 Seasons" for a one-season show.

sub main()
    t = { passed: 0, failed: 0 }

    testSeasonCount(t)
    testLine(t)

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

sub testSeasonCount(t as object)
    eq(t, "one season is singular", SeriesMeta_seasons(1), "1 Season")
    eq(t, "two seasons", SeriesMeta_seasons(2), "2 Seasons")
    eq(t, "seven seasons", SeriesMeta_seasons(7), "7 Seasons")
    eq(t, "zero says nothing", SeriesMeta_seasons(0), "")
    eq(t, "negative says nothing", SeriesMeta_seasons(-1), "")
    eq(t, "unknown says nothing", SeriesMeta_seasons(invalid), "")
    eq(t, "a string count says nothing", SeriesMeta_seasons("3"), "")
end sub

sub testLine(t as object)
    dot = " " + Chr(8226) + " "
    eq(t, "year and one season", SeriesMeta_line(2018, 1), "2018" + dot + "1 Season")
    eq(t, "year and seasons", SeriesMeta_line(2014, 7), "2014" + dot + "7 Seasons")
    eq(t, "no year", SeriesMeta_line(invalid, 1), "1 Season")
    eq(t, "no seasons", SeriesMeta_line(2022, 0), "2022")
    eq(t, "nothing", SeriesMeta_line(invalid, invalid), "")
end sub
