# Privacy Policy for Sashimi

**Last updated: July 2026**

## Overview

Sashimi is a Roku channel for [Jellyfin](https://jellyfin.org) media servers. This policy explains exactly what Sashimi does with your data.

## Data Collection

**Sashimi does not collect, store, or transmit any personal data to the developer or to any third party.** There is no analytics, no telemetry, no crash reporting, and no advertising in this app.

### What Sashimi stores on your Roku

All of this lives in the Roku registry, a per-channel storage area on the device:

1. **Server connection details**
   - Your Jellyfin server URL
   - Your Jellyfin username
   - An authentication token issued by your server
   - The same details for each additional server you add, if you use more than one

2. **A device identifier** — a random, channel-scoped ID from Roku's `GetChannelClientId()`. It is not your Roku's serial number and it is not shared with anyone but your own Jellyfin server, which uses it to distinguish this device in its session list.

3. **Your preferences** — home screen row order, maximum bitrate, subtitle and playback settings, recent searches.

### How that data is protected

- The Roku registry is **sandboxed per channel** — no other Roku channel can read Sashimi's data.
- The registry is **not encrypted**. Anyone with developer access to your Roku device could read the stored values, including the authentication token.
- Signing out clears these values from the device and asks your Jellyfin server to revoke the token.

### Data transmission

Sashimi communicates with two things, both of which are yours:

1. **Your Jellyfin server** — all browsing, streaming, and playback progress goes directly from your Roku to the server you configured, and nowhere else.

2. **Your local network** — when you use "Discover Servers", Sashimi sends one UDP broadcast (`"Who is JellyfinServer?"` to port 7359, Jellyfin's standard discovery protocol) and listens briefly for replies. It contains no personal data and never leaves your network.

If you connect over `http://` rather than `https://`, that traffic — including your password at sign-in — is unencrypted on your network. Use HTTPS if your server is reachable from outside your home.

### Third-party content

The TMDb and Rotten Tomatoes logos shown next to ratings are bundled images. The ratings themselves come from your Jellyfin server. Sashimi makes **no network requests to TMDb, Rotten Tomatoes, or any other third party.**

## Your Jellyfin server

Your Jellyfin server has its own privacy practices, which Sashimi does not control. Refer to the Jellyfin documentation and your server administrator for how data is handled server-side.

## Children's privacy

Sashimi does not knowingly collect information from anyone, including children. Using the app requires a Jellyfin server, which is typically set up by an adult.

## Changes to this policy

This policy may be updated from time to time. Changes will be posted to this page and in the channel's listing.

## Contact

Questions or concerns: please open an issue on GitHub.

https://github.com/bitstorm-labs/sashimi-roku/issues

## Open Source

Sashimi is open source under the MIT license. You can read exactly what it does:

https://github.com/bitstorm-labs/sashimi-roku
