' Off-device tests for source/utils/Confirm.bs, run by tests/run.js against the
' transpiled module (out/source/utils/Confirm.brs). StandardMessageDialog
' focuses its first button, so "Cancel first, and the action is the index that
' confirms" is the whole safety property of every destructive confirmation.

sub main()
    t = { passed: 0, failed: 0 }

    testButtonOrder(t)
    testConfirmIndex(t)
    testRemoveServerCopy(t)

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

sub testButtonOrder(t as object)
    for each action in ["Sign Out", "Remove", "Mark Season Watched", "Mark Season Unwatched", "Delete Channel"]
        b = Confirm_buttons(action)
        eq(t, action + " count", b.Count(), 2)
        if b.Count() = 2
            ' The default-focused button must be the harmless one.
            eq(t, action + " default is Cancel", b[0], "Cancel")
            eq(t, action + " second is the action", b[1], action)
        end if
    end for
end sub

sub testConfirmIndex(t as object)
    b = Confirm_buttons("Sign Out")
    ' Whatever index the action lands at is the one that confirms, and the
    ' default-focused index never does.
    for i = 0 to b.Count() - 1
        eq(t, "index " + i.ToStr() + " confirms iff it is the action", Confirm_isConfirmed(i), (b[i] = "Sign Out"))
    end for
    eq(t, "default focus does not confirm", Confirm_isConfirmed(0), false)
    eq(t, "invalid does not confirm", Confirm_isConfirmed(invalid), false)
    eq(t, "out of range does not confirm", Confirm_isConfirmed(2), false)
    eq(t, "negative does not confirm", Confirm_isConfirmed(-1), false)
    eq(t, "string does not confirm", Confirm_isConfirmed("1"), false)
end sub

sub testRemoveServerCopy(t as object)
    eq(t, "title names the server", Confirm_removeServerTitle("jellyfin.example.com"), "Remove jellyfin.example.com?")
    eq(t, "title without a name", Confirm_removeServerTitle(""), "Remove this server?")
    ' The only server: removing it signs out, and the dialog must say so.
    eq(t, "only server warns of sign-out", Instr(1, Confirm_removeServerMessage(true, true), "signed out") > 0, true)
    eq(t, "active server warns of switch", Instr(1, Confirm_removeServerMessage(false, true), "switch") > 0, true)
    eq(t, "inactive server mentions neither", Instr(1, Confirm_removeServerMessage(false, false), "signed out") = 0 and Instr(1, Confirm_removeServerMessage(false, false), "switch") = 0, true)
end sub
