---
description: Lint, package, and sideload to the dev Roku, then screenshot the result
---

Build the channel and push it to the dev Roku, then show me what's on screen.

```bash
cd "$CLAUDE_PROJECT_DIR"
PW=$(security find-generic-password -s sashimi-roku-dev -a rokudev -w)
DEVICE="${ROKU_DEV_TARGET:-192.168.86.30}"

npm run lint            # must be clean before packaging
npm run package

curl -s --digest -u "rokudev:$PW" \
     -F mysubmit=Replace -F archive=@out/sashimi-roku.zip \
     "http://$DEVICE/plugin_install" -o /dev/null -w "install HTTP %{http_code}\n"
```

Then wait for the channel to actually render before capturing — the app needs
~10s to reach Home and load library data, and a screenshot taken too early
just shows "Loading your library...":

```bash
sleep 11
curl -s --digest -u "rokudev:$PW" -F mysubmit=Screenshot -F archive= -F passwd= \
     "http://$DEVICE/plugin_inspect" >/dev/null
curl -s --digest -u "rokudev:$PW" "http://$DEVICE/pkgs/dev.jpg" -o /tmp/roku_shot.jpg
```

Read `/tmp/roku_shot.jpg` and describe what changed.

Notes:
- The screenshot API captures the **graphics plane only** — a black frame during
  playback is expected, not a bug. Verify playback server-side via Jellyfin
  `/Sessions` instead.
- If the download returns `Error 40x` instead of a JPEG, the dev channel isn't
  running; relaunch it before capturing.
- ECP keypress (`POST /keypress/Down`) is unreliable on this device — it has
  returned 404 for whole sessions. If you need a specific screen, ask me to
  navigate to it rather than assuming you can drive the remote.
