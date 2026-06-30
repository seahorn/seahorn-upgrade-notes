# Parked investigations

Backlog of started-but-not-pursued threads. Five-field format per entry.

## llvm-seahorn origin/dev16: pristine reset vs. preserve shared work
**Status:** parked 2026-06-30
**Context:** Asked to create a "pristine" `seahorn/llvm-seahorn:dev16` from
   `dev15` (mirroring the sea-dsa workflow). But unlike sea-dsa, `origin/dev16`
   on the shared seahorn org ALREADY exists with 17 commits of real LLVM-16
   port work (SeaInstCombine, FakeLatchExit, loop-extract, new-PM passes). Only
   `7748ee1` differs from local `dev16`, and its content is already folded into
   the squashed `fa74927`. So a reset-to-dev15 would discard shared upstream work.
**Why parked:** Destructive on a shared repo + contradicts how it was described
   ("pristine" implies empty); needs a human decision, not an autonomous force-push.
**To resume:** Confirm intent. Likely the right action is NOT reset-to-dev15 but
   a force-with-lease of local `fa74927` over `origin/dev16` (same safe squash
   already pushed to `priyasiddharth/dev16`). Verify no PR is backed by the branch.
**Effort estimate:** ~10 min once intent confirmed.
**References:** durable/multi-llvm-version-branch-structure.md

## clam: malloc/free not recognized at -O0 on LLVM 15
**Status:** parked (carried over from dev15 work)
**Context:** clam does not recognize malloc/free at -O0 on LLVM 15 — the
   allockind attribute changed how the allocator functions are marked, so clam's
   detection misses them. Deferred during the dev15 push; clam is built OFF
   (`WITH_CLAM=OFF`) on dev16 (clam not ported to LLVM 16).
**Why parked:** Not on the critical path for the dev16 upgrade (clam compiled out).
**To resume:** When porting clam to LLVM 16, update its alloc/free detection to
   read the `allockind` attribute rather than the older marking.
**Effort estimate:** unknown (~half-day once clam build is up on 16).
**References:** durable/seahorn-build-and-ci-gotchas.md
