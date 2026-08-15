---
description: Bump build_version, tag the release, and produce a signed .pkg for the channel store
argument-hint: "[patch|minor|major] (default: patch)"
---

Ship a release. Argument selects which version component to bump; default patch.

**Confirm with me before pushing the tag** — the tag is the real ship gate, not
the merge.

1. Make sure the tree is clean and on `main` with everything merged.

2. Bump the version in `manifest` (`major_version` / `minor_version` /
   `build_version` are separate lines — patch means `build_version`).

3. Verify `bs_const=DEBUG=false` in `manifest`. A debug build must never ship:
   it logs item titles and server URLs.

4. Lint must be clean:
   ```bash
   npm run lint
   ```

5. Commit the bump, push, and tag `vX.Y.Z`. The tag fires `build.yml`, which
   publishes a GitHub Release with the sideload zip attached.

6. Produce the signed channel package. This **requires the physical dev Roku** —
   Roku provides no offline signer, so CI can only ever build the unsigned zip:
   ```bash
   export ROKU_DEV_PASSWORD=$(security find-generic-password -s sashimi-roku-dev -a rokudev -w)
   bash scripts/package-signed.sh
   ```
   It writes `out/sashimi-signed-<version>.pkg`.

7. Send me the `.pkg` with SendUserFile and remind me the upload to
   developer.roku.com is manual — there's no API for it.
