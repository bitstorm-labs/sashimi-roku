# Security Policy

## Reporting a vulnerability

Please report security issues privately via
[GitHub Security Advisories](https://github.com/bitstorm-labs/sashimi-roku/security/advisories/new)
rather than opening a public issue.

Expect an acknowledgement within a week. Once a fix ships you'll be credited in
the release notes unless you'd rather not be.

## Scope

Sashimi is a client. It talks to *your* Jellyfin server and stores credentials
on *your* Roku. Things that are in scope:

- Credential handling — how the access token and server URL are stored and sent
- Anything that would leak your library contents, token, or server address to a
  third party
- Server discovery (the app broadcasts on your LAN to find Jellyfin)

Out of scope, because they are properties of the platform rather than bugs we
can fix:

- **The Roku registry is not encrypted.** It is sandboxed per channel, so other
  channels cannot read it, but anyone with developer access to the device can.
  This is documented in [PRIVACY.md](PRIVACY.md).
- **`http://` servers are cleartext.** If you connect to Jellyfin over plain
  HTTP, your token crosses the network in the clear. Use HTTPS for anything
  reachable outside your LAN.
- Vulnerabilities in Jellyfin itself — please report those to
  [the Jellyfin project](https://github.com/jellyfin/jellyfin/security).

## Supported versions

Only the latest released version receives fixes.
