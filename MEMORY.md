# MEMORY — principles for merging upstream

This repo is a **thin, structural subset** of [lzell/AIProxySwift](https://github.com/lzell/AIProxySwift):
we re-scope and re-structure upstream — we don't re-implement it. Behavior should track upstream;
our delta is *what we remove* and *where things live*, not *how things work*. Keeping that delta
small and structural is what keeps each upstream merge cheap. These principles say how.

## Invariants — preserve these through every merge

**1. No hosted-proxy backend. Direct (BYOK) only.**
Everything that exists to talk to the aiproxy.pro backend stays deleted: every
`*ProxiedService.swift`, plus DeviceCheck, AnonymousAccount, certificate pinning, receipt
validation, remote logging, `RuntimeInfo`, keychain/storage. When upstream adds a provider or
edits a service, take only its **Direct** half and leave the proxied half deleted (it shows up
as a `modify/delete` conflict → `git rm`). The public surface is BYOK: the caller brings a key
and talks to the provider directly.

**2. Realtime & audio live in a separate, Apple-only target.**
The package is two products:
- `AIProxy` — Foundation-only **core**, must keep building cross-platform (incl. Linux). This is
  the reason the fork exists (it feeds the cross-platform daemon).
- `AIProxyRealtime` — Apple-only (AVFoundation/AudioToolbox/CoreAudio): OpenAI Realtime + audio
  capture/playback; depends on `AIProxy`.

So never let an audio-framework import land in `AIProxy`, and keep realtime/audio sources and
tests under `Sources/AIProxyRealtime/` + `Tests/AIProxyRealtimeTests/`. Upstream keeps all of
this in one target, so re-separating it is a standing part of every merge.

## Decision principle — when in doubt, follow upstream

**Prefer upstream's implementation wherever it's close to something we changed.** Our fork is a
scope/structure transformation, not a behavioral one — so when upstream's work overlaps our edits
(same file, same feature, same type), resolve toward *upstream's* shape and re-apply our
structural change (delete / move / re-scope) on top. Don't let our version "win" on behavior.

Why: the closer we stay to upstream's behavior, the smaller our delta and the cheaper the next
merge. Re-implementing or pinning things upstream owns is how a fork rots into an unmergeable
divergence. State it as a split: **upstream owns behavior, we own structure.**

Corollaries:
- **Adapt consumers to upstream, don't revert the SDK.** If an upstream API change breaks the app
  (a field becomes optional, a signature changes), fix the consumer to match upstream rather than
  patching the SDK back to the old shape.
- **Keep our delta structural.** If you're tempted to change *how* something works — rather than
  *whether* it's included or *where* it lives — stop and reconsider: that's behavioral divergence
  every future merge will pay for.

## Mechanics

Merge on a throwaway branch so the real branch stays clean until verified; trust git's rename
detection to carry upstream's edits onto our moved files; then confirm the invariants survived.

```sh
git fetch upstream --tags
git switch multiplatform-subset && git switch -c merge-upstream-$(date +%Y-%m)
git merge --no-edit upstream/main      # resolve per the principles above
```

Remotes/branches: `origin` = our fork (work publishes to **`origin/main`** — there is no remote
`multiplatform-subset`), `upstream` = lzell/AIProxySwift; local `multiplatform-subset` tracks
`origin/main`.

### Verify the invariants held — a clean auto-merge can still violate them

```sh
# Invariant 2 — nothing realtime/audio resurfaced in the core, and no audio import leaked in:
git status -s | grep -iE 'Sources/AIProxy/(Audio|Microphone|OpenAI/OpenAIRealtime)'
git grep -lnE '^import (AVFoundation|AudioToolbox|CoreAudio)' -- 'Sources/AIProxy/**' | grep -v AIProxyRealtime

# Invariant 2 — a NEW upstream test for a moved type lands in the wrong target (it has no rename
# to follow). Relocate to Tests/AIProxyRealtimeTests/ with `import AIProxy` + `@testable import AIProxyRealtime`:
git grep -lnE 'OpenAIRealtime|MicrophonePCM|AudioPCMPlayer|RealtimeAudioUtils|AudioController' -- 'Tests/AIProxyTests/**'

# Invariant 1 — no kept code still references a stripped backend symbol (comments/log strings OK):
git grep -nE 'ProxiedService|AnonymousAccount|DeviceCheck|CertificatePinning|ReceiptValidation|RemoteLoggerService|RuntimeInfo|AIProxyKeychain|AIProxyStorage' -- 'Sources/**/*.swift'
```

### Build-verify through the consumer, then finalize

The real proof is the consumer, not just `swift build`/`swift test`. KeepTalking uses a local
`path:` dep and **KeepTalkingApp links `AIProxyRealtime` directly**, so build
`KeepTalking.xcworkspace` with the fork checked out on the merge branch.

```sh
git switch multiplatform-subset && git merge --ff-only merge-upstream-$(date +%Y-%m)
git branch -d merge-upstream-$(date +%Y-%m) && git push   # → origin/main
```
