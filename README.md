# Sashimi for Roku

<p align="center">
  <img src="images/logo.png" alt="Sashimi Logo" width="160">
</p>

<p align="center">
  <strong>A native Jellyfin client for Roku</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#development">Development</a> •
  <a href="#packaging--release">Packaging &amp; Release</a> •
  <a href="#contributing">Contributing</a>
</p>

---

Sashimi is a Roku channel for [Jellyfin](https://jellyfin.org/) media servers,
written in BrightScript and SceneGraph. It's the Roku member of the Sashimi
family — the [Apple TV / iPhone / iPad client](https://github.com/bitstorm-labs/sashimi-apple)
lives in a separate repo and aims for feature parity.

## Features

- **Plex-style pullout sidebar** — a collapsed icon rail that expands over the
  content when focused (Home, libraries, Search, Settings, account)
- Browse and stream movies, TV shows, and YouTube-style libraries (Pinchflat)
- **Continue Watching** with playback progress reported back to Jellyfin
- **Shuffle** — play one random item from a Movies/TV library or a single show
- **Trailer button** — plays a local trailer inline when one exists
  (`LocalTrailerCount > 0`, e.g. downloaded by [Trailarr](https://github.com/nandyalu/trailarr))
- **Quality badges** (4K / HD / SD) on cover art, with a toggle
- **Stream bitrate** shown on the playback overlay
- Audio / subtitle track selection, including subtitle burn-in for formats the
  Roku can't render natively
- Multi-server aware — switch servers from the account row (library refreshes)
- **Deep linking** via ECP (`supports_input_launch`) — movies and episodes
  autoplay; other content opens its detail screen
- A–Z jump bar for large libraries

## Requirements

- A Roku device (or the Roku OS emulator) on OS 11+
- A Jellyfin server (local or remote)
- [Node.js](https://nodejs.org/) 18+ for the build toolchain
  ([BrighterScript](https://github.com/rokucommunity/brighterscript) + [roku-deploy](https://github.com/rokucommunity/roku-deploy))
- **Developer Mode** enabled on the Roku (for sideloading) — see
  [Roku's guide](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md)

## Development

```bash
# Install the toolchain
npm install

# Type-check / lint (BrighterScript static analysis)
npm run lint

# Build the channel zip (out/sashimi-roku.zip) and copy to sashimi.zip
npm run package

# Sideload to a dev device (set env first)
export ROKU_DEV_TARGET=192.168.x.x     # your Roku's IP
export ROKU_DEV_PASSWORD=xxxx          # Developer Mode password
npm run deploy

# Build + sideload in one step
npm run dev
```

> **Note:** `npm run lint` only refreshes `out/sashimi-roku.zip`. Always run
> `npm run package` before deploying/signing so `sashimi.zip` reflects your
> latest changes.

The debug console (BrightScript `print` output) is available over telnet on
port **8085** while the channel runs on the device.

### Project Structure

```
sashimi-roku/
├── source/            # App entry point (Main)
├── components/
│   ├── MainScene.*    # Root scene + navigation
│   ├── screens/       # Home, detail, library, player, search, settings
│   ├── widgets/       # Sidebar, reusable SceneGraph widgets
│   └── tasks/         # JellyfinApi (REST) + other background tasks
├── images/            # Logo, channel icons, splash, misc art
├── fonts/             # Bundled Roboto family
├── locale/            # Localized strings
├── manifest           # Channel metadata + version (major/minor/build)
└── scripts/           # package-signed.sh (on-device signing)
```

## Packaging & Release

Roku channels must be **signed on a physical device** — there's no offline
signer. GitHub Actions builds the unsigned zip artifact; producing a signed,
uploadable `.pkg` is a local step:

```bash
# Bump the version in `manifest` (build_version) first, then:
bash scripts/package-signed.sh        # build → sideload → sign on device
# → out/sashimi-signed-<version>.pkg
```

The signed package is uploaded manually at
[developer.roku.com](https://developer.roku.com/) → your channel →
**Package Upload** (beta channel). The home-screen channel icon ships inside
the package (`mm_icon_focus_hd/sd` in the manifest); the Channel Store listing
art (poster, screenshots) is only required for public certification.

## Contributing

1. Create a feature branch: `git checkout -b feat/my-feature`
2. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   `git commit -m "feat: add new feature"`
3. Run `npm run lint` and `npm run package`, then sideload and test on a device
4. Open a Pull Request (CI runs BrighterScript static analysis)

## License

Licensed under the terms in the [LICENSE](LICENSE) file.

## Acknowledgments

- [Jellyfin](https://jellyfin.org/) — the free software media system
- [RokuCommunity](https://github.com/rokucommunity) — BrighterScript & roku-deploy
