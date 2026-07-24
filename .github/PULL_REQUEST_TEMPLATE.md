## What and why

<!-- What changes, and what problem it solves. Link the issue: Closes #123 -->

## How it was verified

<!--
There is no test suite, so this section is the safety net. What did you actually
run, and on what? e.g. "Sideloaded to a Roku Ultra, played a 4K HEVC movie with
subtitles on, scrubbed, backed out." Server-side checks against Jellyfin
/Sessions are worth mentioning too.
-->

## Checklist

- [ ] `npm run lint` is clean
- [ ] Sideloaded and manually exercised the affected screen
- [ ] `manifest` still has `bs_const=DEBUG=false`
- [ ] No logging of titles, tokens, or server URLs outside `#if DEBUG`
