# Contributing

Thanks for taking a look. This is a BrightScript / SceneGraph channel for Roku,
talking to a Jellyfin server.

## Getting set up

```bash
npm install
npm run lint       # BrighterScript static analysis — must be clean
npm run package    # builds out/sashimi-roku.zip
```

To run it on hardware you need a Roku in developer mode:

```bash
export ROKU_DEV_TARGET=192.168.1.50
export ROKU_DEV_PASSWORD=yourdevpassword
npm run dev        # package + sideload
```

`nc <roku-ip> 8085` attaches to the debug console. Attach *after* sideloading —
replacing the channel drops the connection.

## Before you open a PR

- `npm run lint` is clean.
- You sideloaded it and the screen you touched still works. There is no test
  suite, so manual verification is the only safety net — please say in the PR
  what you actually exercised, and on what device.
- `manifest` still has `bs_const=DEBUG=false`. It's easy to leave this flipped.
- No `print` of item titles, tokens, or server URLs outside a `#if DEBUG` guard.
  The library is someone's personal media.

## Things worth knowing before you change rendering code

Some of the code looks odd on purpose. `CLAUDE.md` documents the platform traps
behind it — image scaling that silently centers, component recycling that keeps
the previous item's artwork, and Task fields that drop same-tick writes. Reading
that first will save you a confusing afternoon.

## Commit and PR style

Explain *why* in the commit body, not just what. If you worked around a platform
quirk, say which one — the next person will not be able to guess.

Small, focused PRs merge fastest. If you're planning something large, open an
issue first so we can agree on the shape.
