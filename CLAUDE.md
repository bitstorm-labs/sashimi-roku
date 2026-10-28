# Sashimi for Roku — working notes

A Roku (BrightScript / SceneGraph) client for Jellyfin. Sibling clients live in
`sashimi-apple` (tvOS/iOS) and `sashimi-android`; this repo is standalone but
aims for visual parity with the tvOS app. Public repo: no IPs, hostnames,
tokens or household names in docs, code comments or tests.

## Commands

```bash
npm run lint      # bsc --create-package=false — real static analysis, no zip
npm run build     # bsc
npm run package   # build + copy to sashimi.zip
npm run dev       # package + sideload (needs ROKU_DEV_TARGET / ROKU_DEV_PASSWORD)
```

`npm test` transpiles and then runs `tests/*Tests.brs` off-device with the
`@rokucommunity/brs` interpreter (`tests/run.js`). It covers **pure logic only**
— today `source/utils/StreamQuality.bs` (quality tiers, step-down ladder, probe
arithmetic, the device profile's audio codecs and channel cap, its HEVC
VideoRangeType list and HLS video codecs, and adaptive Auto: the Wi-Fi
ceiling, remembered link readings, the step-back-up decision) and `source/utils/Confirm.bs` (destructive-confirmation button
order: `StandardMessageDialog` focuses its first button, so Cancel goes first)
and `source/utils/NextEpisode.bs` (the end-of-episode Up Next screen: next
episode across seasons, countdown/Skip/Cancel state machine, screen text)
and `source/utils/HeroTrailer.bs` (the detail-screen hero trailer: whose
trailer a screen plays, movies to their end vs the series' 10-40 s clip,
the fade point, once-per-visit ownership, when a trailer that follows
the theme song readies its stream)
and `source/utils/ContinueWatching.bs` (the row's merge and order, the
plugin row, and Remove from Continue Watching: what a removal clears or
hides, the local hide list and when an entry goes stale, Home's options menu)
and `source/utils/ShowStatus.bs` (the show-status badge on series, season
and episode screens: the series' `Status` to Continuing / Ended / Upcoming,
nothing otherwise, drawn as the media chips' rounded rectangle) and
`source/utils/DetailActions.bs` (the detail action row, the More menu with
Go to Series / Go to Season N / admin-only Add to Channel, the season chip's
`*` menu) and `source/utils/SeasonPage.bs` (the Season page: next unwatched
episode to play or resume, E1 once all are watched, Mark Season Watched vs
Unwatched, the "Season N • X episodes • Y of X watched" line) and
`source/utils/DetailNav.bs` (a detail screen's Series button pops back to
that series when it is already on the stack, else reloads in place, so Back
never shows the same series twice) and `source/utils/DetailLayout.bs` (where a detail
screen's rows start, and the hero region that must end above them so its
bottom fade is never cut off) and `source/utils/Fades.bs` (the "Lightest" backdrop
fade: left 0-10% of the image's width, bottom 92-100% of its height; the
home hero sizes its fades from it, and `tests/fades.js` checks the detail
screen's baked `backdrop_feather.png` / `trailer_feather.png` against it) and `source/utils/SeriesMeta.bs` (the series meta line,
"1 Season" vs "7 Seasons") and `source/utils/ImageUrl.bs` (image urls
carry Jellyfin's `&tag=`, read off the right ImageTags / Parent*ImageTag
field, so a replaced image gets a new url instead of a cached stale copy)
and `source/utils/RowWindow.bs` (the leftmost visible card of a floatingFocus
episode row, where focus lands on entering it) and `source/utils/SkipPill.bs`
(the player's skip pill: label, m:ss left, the fill's share of the segment)
and `source/utils/AdminDash.bs` (the admin Dashboard: the play-mode
badge truth table shared with Apple/Android, plain-words transcode reasons,
the admin gate, IP redaction, the 85% storage warning, bitrate sums, health
and activity rows, the cards' stable order, and the OpsDec-style stream
card: state dot, SxxEyy, source → output pills, speed, HW, Local/Remote) and `source/utils/RemoteControl.bs`
(Jellyfin remote control: the /socket url, the capabilities body, server
messages to Stop / DisplayMessage / keep-alive / ignore, keep-alive timing,
reconnect backoff, the Roku OS 16 gate) and `source/utils/WatchState.bs`
(watched state: the `/UserPlayedItems` route with its legacy fallback, when a
detail screen coming back to the front is stale, and whether a re-read episode
list patches the row in place, rebuilds it, or is ignored) and
`source/utils/RailItems.bs` (Settings > Home & Side Menu: which destinations
the side menu lists and in what order, Home, Search and Settings always,
new libraries shown, stale ids ignored, the editor's two columns) and
`source/utils/SharedLists.bs` (shared lists: a list's creator from its
self-share, S1:E1 shown as its series, repeats once, the subscriptions codec
for DisplayPreferences `sashimi-lists`, "N new", subscribe/markSeen/prune, and
where a new subscription's Home row goes; same vectors as Apple and Android).
`SASHIMI_TEST_SUITE=<file> SASHIMI_TEST_MODULE=<brs>` runs one suite against a
mutant build, to prove a test fails on the code it is meant to catch. Nothing that touches a SceneGraph node, the registry or the network
can run there, so most of the app still has no coverage; don't add a test that
only pretends to exercise those. Two interpreter traps: it exits 0 on a script
error (the runner requires an explicit `ALL PASSED`), and a 10-digit integer
literal is not an Integer there.

Always run `npm run lint` and `npm test` before committing. Both must be clean.

## Claude Code helpers

`.claude/` holds this repo's automation (committed; `settings.local.json` is
personal and gitignored):

- **`/sideload`** — lint, package, push to the dev Roku, screenshot the result
- **`/ship`** — bump `build_version`, tag, and sign a `.pkg` for the beta channel
- A `PostToolUse` hook runs `npm run lint` after every `.bs`/`.xml` edit, so a
  syntax error surfaces at the edit instead of at commit time.

## Dev device

Set `ROKU_DEV_TARGET` (the dev Roku's address) and `ROKU_DEV_PASSWORD` in your
shell. Keep the password in your keychain, not in this repo.

```bash
# sideload
curl --digest -u "rokudev:$ROKU_DEV_PASSWORD" -F mysubmit=Replace -F archive=@out/sashimi-roku.zip \
     http://$ROKU_DEV_TARGET/plugin_install

# screenshot (graphics plane only, never captures video).
# passwd MUST carry the dev password: an empty field returns a 35-byte 404
# body that saves as a "blank screenshot", which reads as a black screen
# rather than a failed command.
curl --digest -u "rokudev:$ROKU_DEV_PASSWORD" -F mysubmit=Screenshot -F archive= -F passwd="$ROKU_DEV_PASSWORD" \
     http://$ROKU_DEV_TARGET/plugin_inspect >/dev/null
curl --digest -u "rokudev:$ROKU_DEV_PASSWORD" http://$ROKU_DEV_TARGET/pkgs/dev.jpg -o shot.jpg

# debug console (print output): attach AFTER launching, since a channel
# replace drops the connection. Use -d when backgrounding it: without it nc
# exits as soon as its stdin closes, which looks like "no output".
nc -d $ROKU_DEV_TARGET 8085
```

**ECP names the Options key `Info`.** `POST /keypress/Options` returns 200 and
does nothing, which looks exactly like the app ignoring the key. Use
`/keypress/Info` when driving the OSD remotely.

**ECP keypress drives the UI**, but presses sent back-to-back are coalesced:
pace them ~0.5s apart or only the first one or two land. Also useful:
`POST /launch/dev?contentId=...&mediaType=...` (deep links), `/query/active-app`,
`/query/device-info`.

- Don't test sign-out on the dev box: it strands the device at a login screen
  someone has to type into. To reach the sign-in screen safely, use Settings ->
  Servers -> Add Server, which opens the same screen with Back as an escape.
- To verify something that normally needs a button press, drive it from an
  instrumented `#if DEBUG` build and read the result on port 8085.
- Screenshots miss anything shorter than ~2s (the capture round-trip is slower).
  A 3s toast will usually not be caught. Use console prints.

Check what the dev Roku actually is before testing: this one is on Wi-Fi, runs
Roku OS 15 (so it cannot open the remote-control socket) and reports a 1080p SDR
display (`GetDisplayProperties`: no HDR10/HLG/DV), so every 4K file re-encodes
there for resolution (`VideoResolutionNotSupported`). To see an HEVC remux on
it, use a 1080p HEVC file with DTS/TrueHD audio. Its captions setting also
burns a subtitle into most deep-linked plays. `ECP /launch/dev?contentId=`
cold-starts the channel, so playback races the bandwidth probe and starts at
the unmeasured default; `POST /input?contentId=` deep-links into the running
channel instead. Port 8085 replays recent history on connect, so mark the log's
line count before acting on new output.

Playback is best verified server-side via Jellyfin `/Sessions` (`NowPlayingItem`,
`PositionTicks`, `PlayMethod`). The screenshot API cannot see the video plane,
so a "black" screenshot during playback is expected, not a bug.

## Debug builds

`manifest` carries `bs_const=DEBUG=false`. Flip to `true`, wrap prints in
`#if DEBUG` / `#end if`, and **always restore it to false** before committing.
Never log item titles, tokens, or server URLs outside a DEBUG guard — the
library is the user's personal media.

## Platform traps that have bitten this codebase

**`scaleToFit` centers the image inside its region.** Decorations anchored to
the region's edges (fade masks, gradients) therefore miss the image's real edge
and produce a hard seam. Fix: observe `loadStatus = "ready"` and read
`bitmapWidth`/`bitmapHeight` to find the actual fitted size, then position
relative to that. This caused three separate visual bugs (hero seam, backdrop
edges, detail thumbnails) before it was understood as one root cause.

**RowList / MarkupGrid recycle their item components.** Every branch of an
item's content handler must reset *every* field it might set — a missing `else`
leaves the previous item's artwork, opacity or scale on screen. If you write
`if x <> "" then node.uri = x`, you need the `else node.uri = ""`.

**Task fields coalesce same-tick writes.** Two requests assigned to a Task's
`request` field in the same tick means the first is silently lost. Screens that
issue more than one request use a serialized queue — see `enqueue()` /
`pumpQueue()` in `MediaDetailScreen.bs` and `PlayerScreen.bs`. Any screen doing
multiple requests needs the same pattern; direct `m.apiTask.request = …` writes
are only safe when a screen issues exactly one request at a time.

**Focus.** The player uses a *virtual* highlight (`m.zone` / `m.btnIdx` /
`m.menuIdx`) rather than real SceneGraph focus, because real focus produced
invisible-button traps twice. Don't "simplify" it back to real focus.

**One media player instance plays at a time.** A Video node started while
another Audio or Video node is playing fails at once with `errorMsg` "player:
only one playing instance supported" (`state = "error"`, verified on hardware). So the theme song must stop before the player opens a stream, and
the detail-screen hero trailer (`HeroTrailerPlayer`) waits for a theme to end
instead of playing muted under it as the Apple app does. A Video node outside
the focused screen never takes focus as long as nothing calls `setFocus` on it
and `enableUI` is false; it can be re-parented between screens while playing
(the hero trailer's series -> episode hand-off relies on this).

**SceneGraph colours are `#RRGGBBAA` — alpha LAST.** `#40FFFFFF` (Android's
"white at 25%") is opaque cyan here; write `#FFFFFF40`. The player's scrubber
track, "Finishes at" and subtitle lines rendered cyan for months this way.
`tests/colors.js` (part of `npm test`) fails on any 8-digit colour that only
makes sense alpha-first.

**A fully opaque Rectangle inside a MaskGroup draws unmasked** (seen on a
low-end Roku: the skip pill's purple fill poked out square past its capsule
at opacity 1.0, and was clipped at 0.99 and 0.55). Keep masked fills below
opacity 1.

**Subtitles are burned in server-side** (`SubtitleStreamIndex` + an Encode
profile). Roku's native HLS-VTT rendering silently fails; burn-in works for
every format (srt/ass/pgs) and QSV makes the re-encode cheap. This means a
subtitle change requires a stream restart, and Roku's own caption UI has no
native track to toggle — the app translates `GetCaptionsMode()` into a track
choice itself (`captionsMode()` / `applyCaptionsMode()` in `PlayerScreen.bs`).

**Jellyfin remote control needs Roku OS 16.** The dashboard's Stop and
Message arrive only over Jellyfin's `/socket` WebSocket (12.x has no polling
route), and remote viewers reach the server over https, so a client has to do
TLS -- which rules out a hand-rolled WebSocket on `roStreamSocket` (plain TCP).
`roWebSocket` (OS 16.0) does TLS, framing, masking and ping/pong natively.
On 15.x `CreateObject("roWebSocket")` still returns an object, but every
`Open()` fails with error 29 "WebSockets are not allowed", so
`RemoteControlTask` gates on `GetOSVersion().major >= 16` and does nothing on
older firmware. `Open()` with no wait returns false even when it will
succeed; the Opened/Closed/Error events decide. bsc 0.73.7 doesn't know the
component, hence the `bs:disable-next-line: 1129`. The dev Roku is on
15.x, so it can only exercise the dispatch path, not the socket.

## Certification

Public release is gated on Roku's certification criteria. Ones that have already
forced code changes:

- **3.2** home rendered within 15s; `AppLaunchComplete` beacon required. Roku
  defers the beacon to the next render pass, so signalling it early is safe —
  but never move it somewhere it might *not* fire (e.g. behind a successful
  library load), because a missing beacon is an automatic fail.
- **3.7** package under 4 MB.
- **4.4** the Options (`*`) key is reserved for Roku during playback. The app
  must never consume it, in any OSD zone.
- **4.7** trick-play thumbnails for content over 15 minutes. Jellyfin serves
  **no BIF**, so `HDBifUrl` is unusable — this needs a custom overlay drawing
  Jellyfin's JPEG tile sheets.
- **4.8** honour the Roku global caption settings.
- **4.10** bookmarks for content over 15 minutes, kept 30 days.
- **5.1 / 5.2** deep linking and Direct to Play. All `mediaType` values must
  begin playback immediately *except* `season`, which may show a springboard.
  `series` must resolve a "smart bookmark" (next unwatched episode). An invalid
  `contentId` must show an error and land on the home screen.

## Jellyfin server

Develop against Jellyfin 10.11.x with hardware transcoding (QSV). Trickplay tile
sheets are 6x6 at 320x180, which makes **1920x1080** per sheet. Do not raise the
tile count: 3200x1800 sheets exceed the 2048x2048 max texture size on older
Roku models.

Read trickplay geometry from the item's own `Trickplay` metadata rather than
assuming. It carries `Width`, `Height`, `TileWidth`, `TileHeight`,
`ThumbnailCount` and `Interval` per item.

## Fix what you find

If you come across a problem while working (a missing test, a red or flaky CI job, a
bug, dead code, a broken workflow), fix it as part of the work. Don't just mention
it in a summary and move on. If the fix doesn't belong in the current PR, open a
follow-up issue and do it next. Only hand something back when it truly needs the
user: credentials, a paid account, a product decision, or physical hardware. Say
exactly what's needed.

## Conventions

- Comments explain **why**, especially where the code looks odd — most of the
  odd-looking code here is working around a platform trap listed above. Match
  the surrounding density; don't narrate what the code already says.
- Branch -> PR -> merge on green CI. Tag push is the real ship gate: it builds the GitHub Release zip. The signed `.pkg` is made by `scripts/package-signed.sh` on a physical Roku and uploaded to the Roku developer portal by hand.
- Keep old API routes/behaviour working for already-deployed clients.
