# Sashimi for Roku — working notes

A Roku (BrightScript / SceneGraph) client for Jellyfin. Sibling clients live in
`sashimi-apple` (tvOS/iOS) and `sashimi-android`; this repo is standalone but
aims for visual parity with the tvOS app.

## Commands

```bash
npm run lint      # bsc --create-package=false — real static analysis, no zip
npm run build     # bsc
npm run package   # build + copy to sashimi.zip
npm run dev       # package + sideload (needs ROKU_DEV_TARGET / ROKU_DEV_PASSWORD)
```

There is **no test suite**. `npm test` used to exist as a hardcoded pass and was
deleted rather than left implying coverage that doesn't exist. Don't re-add a
placeholder — if you add tests, make them real.

Always run `npm run lint` before committing. It must be clean.

## Dev device

The dev Roku is at `192.168.86.30`. Password is in the login keychain
(`security find-generic-password -s sashimi-roku-dev -a rokudev -w`).

```bash
# sideload
curl --digest -u "rokudev:$PW" -F mysubmit=Replace -F archive=@out/sashimi-roku.zip \
     http://192.168.86.30/plugin_install

# screenshot (graphics plane only — never captures video)
curl --digest -u "rokudev:$PW" -F mysubmit=Screenshot -F archive= -F passwd= \
     http://192.168.86.30/plugin_inspect >/dev/null
curl --digest -u "rokudev:$PW" http://192.168.86.30/pkgs/dev.jpg -o shot.jpg

# debug console (print output) — attach AFTER launching; a channel replace
# drops the connection
nc 192.168.86.30 8085
```

**ECP keypress works again** (it used to 403 on this device; re-verified
2026-07-31 with `POST /keypress/Down` → 200 and a visible focus move). You can
drive the UI remotely, but presses sent back-to-back are coalesced — pace them
~0.5s apart or only the first one or two land. Also useful: `POST
/launch/dev?contentId=…&mediaType=…` (deep links), `/query/active-app`,
`/query/device-info`.

Consequences worth internalising:
- Don't test sign-out on the dev box — it would strand it at a login screen
  someone has to type into. To reach the sign-in screen safely, use Settings →
  Servers → Add Server, which opens the same screen with Back as an escape.
- To verify something that normally needs a button press, drive it from an
  instrumented `#if DEBUG` build and read the result on port 8085. That's how
  the caption-mode work was verified (`SetCaptionsMode` from inside the app).
- Screenshots miss anything shorter than ~2s — the capture round-trip is slower
  than that. A 3s toast will usually not be caught. Use console prints.

Playback is best verified server-side via Jellyfin `/Sessions` (`NowPlayingItem`,
`PositionTicks`, `PlayMethod`) — the screenshot API cannot see the video plane,
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

**Subtitles are burned in server-side** (`SubtitleStreamIndex` + an Encode
profile). Roku's native HLS-VTT rendering silently fails; burn-in works for
every format (srt/ass/pgs) and QSV makes the re-encode cheap. This means a
subtitle change requires a stream restart, and Roku's own caption UI has no
native track to toggle — the app translates `GetCaptionsMode()` into a track
choice itself (`captionsMode()` / `applyCaptionsMode()` in `PlayerScreen.bs`).

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

## Jellyfin server (dev/family)

`http://192.168.86.151:9096`, Jellyfin 10.11.x on Unraid, QSV hardware
transcoding. Trickplay tile sheets are 6×6 at 320×180 → **1920×1080** per sheet;
do not raise the tile count, because 3200×1800 sheets exceed the 2048×2048 max
texture size on older Roku models.

Read trickplay geometry from the item's own `Trickplay` metadata rather than
assuming — it carries `Width`, `Height`, `TileWidth`, `TileHeight`,
`ThumbnailCount` and `Interval` per item.

## Conventions

- Comments explain **why**, especially where the code looks odd — most of the
  odd-looking code here is working around a platform trap listed above. Match
  the surrounding density; don't narrate what the code already says.
- Branch → PR → merge on green CI. Tag push is the real ship gate.
- Keep old API routes/behaviour working for already-deployed clients.
