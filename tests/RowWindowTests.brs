' Off-device tests for source/utils/RowWindow.bs, run by tests/run.js against
' the transpiled module (out/source/utils/RowWindow.brs). Focus entering an
' episode row lands on the leftmost card on screen; these pin how that card is
' worked out for a floatingFocus row (the detail screen's episode row: 1800px
' wide, 240px cards, 30px apart, so 6 whole cards and a cut-off 7th).

sub main()
    t = { passed: 0, failed: 0 }

    testVisibleCount(t)
    testFollow(t)
    testEntry(t)
    testScenario(t)

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

sub testVisibleCount(t as object)
    eq(t, "episode row: 6 whole cards", RowWindow_visibleCount(1800, 240, 30), 6)
    eq(t, "exact fit counts", RowWindow_visibleCount(1050, 240, 30), 4)
    eq(t, "one pixel short drops a card", RowWindow_visibleCount(1049, 240, 30), 3)
    eq(t, "never below one", RowWindow_visibleCount(100, 240, 30), 1)
end sub

sub testFollow(t as object)
    ' Inside the window: no scroll.
    eq(t, "S5:E5 (index 4) needs no scroll", RowWindow_follow(0, 4, 6), 0)
    eq(t, "last whole card needs no scroll", RowWindow_follow(0, 5, 6), 0)
    ' Past the right edge: scroll just far enough.
    eq(t, "the cut-off 7th scrolls one", RowWindow_follow(0, 6, 6), 1)
    eq(t, "a jump to index 9 shows 4..9", RowWindow_follow(0, 9, 6), 4)
    ' Past the left edge: that card becomes the leftmost.
    eq(t, "moving left off the window", RowWindow_follow(4, 3, 6), 3)
    eq(t, "moving within the window", RowWindow_follow(4, 7, 6), 4)
end sub

sub testEntry(t as object)
    eq(t, "lands on the leftmost visible", RowWindow_entry(4, 12), 4)
    eq(t, "clamped to the last card", RowWindow_entry(9, 3), 2)
    eq(t, "empty row", RowWindow_entry(2, 0), 0)
    eq(t, "negative start", RowWindow_entry(-1, 5), 0)
end sub

' S1:E10 of a 16-episode season: the row opens scrolled to show the current
' card (index 9), the user wanders right and back, then re-enters.
sub testScenario(t as object)
    v = RowWindow_visibleCount(1800, 240, 30)
    s = RowWindow_follow(0, 9, v)
    eq(t, "opens showing the current episode", s, 4)
    eq(t, "enters on the leftmost, not the current", RowWindow_entry(s, 16), 4)
    for i = 5 to 12
        s = RowWindow_follow(s, i, v)
    end for
    eq(t, "walking right scrolls", s, 7)
    for i = 11 to 8 step -1
        s = RowWindow_follow(s, i, v)
    end for
    eq(t, "walking back inside the window keeps it", s, 7)
    eq(t, "re-entering lands on the leftmost again", RowWindow_entry(s, 16), 7)
end sub
