' Off-device tests for the detail page's audio-language chip (#271), in
' source/utils/LanguagePrefs.bs. The chip names the language that will play
' (the preferred language when a track has it, else the default track, else
' the first) and "+N" other audio languages. Real case: Love is Blind S11E09
' defaulted to a Portuguese dub with English as the second track.

sub main()
    t = { passed: 0, failed: 0 }
    dubbed = [aud(1, "por", true), aud(2, "eng", false)]

    eq(t, "preferred present wins over default", LanguagePrefs_audioChipLabel(dubbed, "en"), "English  +1")
    eq(t, "preferred absent falls back to default", LanguagePrefs_audioChipLabel(dubbed, "de"), "Portuguese  +1")
    eq(t, "no preference uses default", LanguagePrefs_audioChipLabel(dubbed, ""), "Portuguese  +1")
    eq(t, "no default flag uses first", LanguagePrefs_audioChipLabel([aud(1, "fra", false), aud(2, "eng", false)], ""), "French  +1")
    eq(t, "639-1 tags match", LanguagePrefs_audioChipLabel([aud(1, "pt", true), aud(2, "en", false)], "en"), "English  +1")
    many = [aud(1, "eng", true), aud(2, "eng", false), aud(3, "en", false), aud(4, "fra", false), aud(5, "fre", false), aud(6, "spa", false), aud(7, invalid, false)]
    eq(t, "+N counts distinct languages", LanguagePrefs_audioChipLabel(many, ""), "English  +2")
    eq(t, "single language has no +N", LanguagePrefs_audioChipLabel([aud(1, "eng", true), aud(2, "eng", false)], "en"), "English")
    eq(t, "no tagged track, no chip", LanguagePrefs_audioChipLabel([aud(1, invalid, true), aud(2, "", false)], "en"), "")
    eq(t, "no tracks, no chip", LanguagePrefs_audioChipLabel([], ""), "")
    eq(t, "untagged playing track, no chip", LanguagePrefs_audioChipLabel([aud(1, invalid, true), aud(2, "jpn", false)], ""), "")
    eq(t, "preferred present beats untagged default", LanguagePrefs_audioChipLabel([aud(1, invalid, true), aud(2, "jpn", false)], "ja"), "Japanese")
    eq(t, "unknown code shows upper-cased", LanguagePrefs_audioChipLabel([aud(1, "tlh", true)], ""), "TLH")

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

function aud(index as integer, language as dynamic, isDefault as boolean) as object
    return { index: index, language: language, isDefault: isDefault }
end function

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    if type(actual) = type(expected) and actual = expected
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected '"; expected; "' got '"; actual; "'"
    end if
end sub
