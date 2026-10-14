' Off-device tests for source/utils/SkipPill.bs, run by tests/run.js against
' the transpiled module (out/source/utils/SkipPill.brs): the skip pill's
' label, its m:ss countdown and the purple fill's share of the segment.

sub main()
    t = { passed: 0, failed: 0 }

    testLabel(t)
    testFraction(t)
    testTimeLeft(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    same = false
    if type(actual) = type(expected)
        same = (actual = expected)
    else if (type(actual) = "Float" or type(actual) = "Double") and (type(expected) = "Float" or type(expected) = "Double" or type(expected) = "Integer")
        same = Abs(actual - expected) < 0.0001
    end if
    if same
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub

sub testLabel(t as object)
    eq(t, "intro", SkipPill_label("Introduction"), "Skip Intro")
    eq(t, "credits", SkipPill_label("Credits"), "Skip Credits")
    eq(t, "credits any case", SkipPill_label("credits"), "Skip Credits")
    eq(t, "recap", SkipPill_label("Recap"), "Skip Recap")
    eq(t, "preview", SkipPill_label("Preview"), "Skip Preview")
    eq(t, "unknown falls back to intro", SkipPill_label("Something"), "Skip Intro")
    eq(t, "invalid falls back to intro", SkipPill_label(invalid), "Skip Intro")
end sub

sub testFraction(t as object)
    ' A 6:40 -> 7:35 intro (400 s -> 455 s).
    eq(t, "at the start", SkipPill_fraction(400, 400, 455), 0.0)
    eq(t, "halfway", SkipPill_fraction(427.5, 400, 455), 0.5)
    eq(t, "at the end", SkipPill_fraction(455, 400, 455), 1.0)
    eq(t, "before the start clamps", SkipPill_fraction(390, 400, 455), 0.0)
    eq(t, "past the end clamps", SkipPill_fraction(470, 400, 455), 1.0)
    eq(t, "float position", SkipPill_fraction(411.0, 400.0, 455.0), 0.2)
    eq(t, "empty segment is full", SkipPill_fraction(400, 400, 400), 1.0)
    eq(t, "no position", SkipPill_fraction(invalid, 400, 455), 0.0)
end sub

sub testTimeLeft(t as object)
    eq(t, "55 s left", SkipPill_timeLeft(400, 455), "0:55")
    eq(t, "seconds are padded", SkipPill_timeLeft(450, 455), "0:05")
    eq(t, "rounds up a part second", SkipPill_timeLeft(454.2, 455), "0:01")
    eq(t, "a whole minute", SkipPill_timeLeft(0, 60), "1:00")
    eq(t, "over a minute", SkipPill_timeLeft(0, 84.5), "1:25")
    eq(t, "ten minutes", SkipPill_timeLeft(0, 600), "10:00")
    eq(t, "over", SkipPill_timeLeft(455, 455), "0:00")
    eq(t, "past the end", SkipPill_timeLeft(460, 455), "0:00")
    eq(t, "no position", SkipPill_timeLeft(invalid, 455), "0:00")
end sub
