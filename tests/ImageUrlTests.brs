' Off-device tests for source/utils/ImageUrl.bs, run by tests/run.js against
' the transpiled module (out/source/utils/ImageUrl.brs). A Jellyfin image url
' without &tag= never changes when the server replaces the image, so a cached
' copy of the old one keeps being shown; these pin that every builder carries
' the tag and that each tag is read off the right BaseItemDto field.

sub main()
    t = { passed: 0, failed: 0 }

    testBuilders(t)
    testWithTag(t)
    testOwnTags(t)
    testParentTags(t)
    testTagFor(t)

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

' The 100 S1:E1-shaped episode, as /Users/{id}/Items/{id} returns it.
function episode() as object
    return {
        Id: "ep1"
        Type: "Episode"
        SeriesId: "show"
        ImageTags: { Primary: "epPrimaryTag" }
        BackdropImageTags: []
        ParentBackdropItemId: "show"
        ParentBackdropImageTags: ["showBackdropTag"]
        ParentLogoItemId: "show"
        ParentLogoImageTag: "showLogoTag"
        ParentThumbItemId: "show"
        ParentThumbImageTag: "showThumbTag"
        SeriesPrimaryImageTag: "showPrimaryTag"
    }
end function

function series() as object
    return {
        Id: "show"
        Type: "Series"
        ImageTags: { Primary: "showPrimaryTag", Logo: "showLogoTag", Thumb: "showThumbTag", Banner: "showBannerTag" }
        BackdropImageTags: ["showBackdropTag", "secondBackdrop"]
    }
end function

sub testBuilders(t as object)
    eq(t, "primary carries the tag", ImageUrl_primaryAt("http://s", "ep1", 1280, "abc"), "http://s/Items/ep1/Images/Primary?maxWidth=1280&quality=90&tag=abc")
    eq(t, "no tag is a plain url", ImageUrl_primaryAt("http://s", "ep1", 480), "http://s/Items/ep1/Images/Primary?maxWidth=480&quality=90")
    eq(t, "empty tag is a plain url", ImageUrl_primaryAt("http://s", "ep1", 480, ""), "http://s/Items/ep1/Images/Primary?maxWidth=480&quality=90")
    eq(t, "backdrop type and tag", ImageUrl_imageAt("http://s", "show", "Backdrop", 1280, "bd"), "http://s/Items/show/Images/Backdrop?maxWidth=1280&quality=90&tag=bd")
    eq(t, "logo type", ImageUrl_imageAt("http://s", "show", "Logo", 1240, "lg"), "http://s/Items/show/Images/Logo?maxWidth=1240&quality=90&tag=lg")
    ' A new tag is a new url: the whole point.
    eq(t, "a replaced image gets a new url", ImageUrl_primaryAt("http://s", "ep1", 1280, "old") <> ImageUrl_primaryAt("http://s", "ep1", 1280, "new"), true)
end sub

sub testWithTag(t as object)
    eq(t, "appends to an existing query", ImageUrl_withTag("http://s/x?maxHeight=144", "t1"), "http://s/x?maxHeight=144&tag=t1")
    eq(t, "invalid tag", ImageUrl_withTag("http://s/x?a=1", invalid), "http://s/x?a=1")
    eq(t, "non-string tag", ImageUrl_withTag("http://s/x?a=1", 5), "http://s/x?a=1")
end sub

sub testOwnTags(t as object)
    eq(t, "episode primary", ImageUrl_primaryTag(episode()), "epPrimaryTag")
    eq(t, "series logo", ImageUrl_tagOf(series(), "Logo"), "showLogoTag")
    eq(t, "series banner", ImageUrl_tagOf(series(), "Banner"), "showBannerTag")
    eq(t, "missing type", ImageUrl_tagOf(episode(), "Logo"), "")
    ' /Images/Backdrop serves the FIRST backdrop.
    eq(t, "first backdrop", ImageUrl_backdropTag(series()), "showBackdropTag")
    eq(t, "no backdrops", ImageUrl_backdropTag(episode()), "")
    eq(t, "no ImageTags field", ImageUrl_primaryTag({ Id: "x" }), "")
    eq(t, "not an item", ImageUrl_primaryTag(invalid), "")
end sub

sub testParentTags(t as object)
    eq(t, "series backdrop of an episode", ImageUrl_parentBackdropTag(episode()), "showBackdropTag")
    eq(t, "series poster of an episode", ImageUrl_seriesPrimaryTag(episode()), "showPrimaryTag")
    eq(t, "series logo of an episode", ImageUrl_parentLogoTag(episode()), "showLogoTag")
    eq(t, "no parent backdrop", ImageUrl_parentBackdropTag(series()), "")
    eq(t, "no series poster", ImageUrl_seriesPrimaryTag(series()), "")
    eq(t, "empty parent backdrop list", ImageUrl_parentBackdropTag({ ParentBackdropImageTags: [] }), "")
end sub

sub testTagFor(t as object)
    ep = episode()
    eq(t, "own primary", ImageUrl_tagFor(ep, "ep1", "Primary"), "epPrimaryTag")
    eq(t, "own backdrop (none)", ImageUrl_tagFor(ep, "ep1", "Backdrop"), "")
    eq(t, "series backdrop", ImageUrl_tagFor(ep, "show", "Backdrop"), "showBackdropTag")
    eq(t, "series thumb", ImageUrl_tagFor(ep, "show", "Thumb"), "showThumbTag")
    eq(t, "series logo", ImageUrl_tagFor(ep, "show", "Logo"), "showLogoTag")
    eq(t, "series poster", ImageUrl_tagFor(ep, "show", "Primary"), "showPrimaryTag")
    ' The item names no tag for its season or the series' Art: untagged.
    eq(t, "season backdrop unknown", ImageUrl_tagFor(ep, "season1", "Backdrop"), "")
    eq(t, "series art unknown", ImageUrl_tagFor(ep, "show", "Art"), "")
    eq(t, "series item's own backdrop", ImageUrl_tagFor(series(), "show", "Backdrop"), "showBackdropTag")
    eq(t, "no id", ImageUrl_tagFor(ep, invalid, "Primary"), "")
end sub
