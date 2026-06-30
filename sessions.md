# Sessions log

Curated index of significant sessions. Newest first. Add an entry only when a
session produced notes, code, or decisions worth pointing back to.

## 2026-06-30
**Session:** seaopt -O# pipeline + dev16 PR/notes bootstrap
**Theme:** Fixed the dev16 seaopt -O# performance regression, committed/pushed the
   seahorn + sea-dsa + llvm-seahorn dev16 work, opened sea-dsa PR #177, and
   bootstrapped this notes directory (seeded from the session + prior memory).
**Key outputs:**
- durable/: seaopt-O-pipeline, sea-dsa-newpm-analyses, seapp-newpm-migration-
  patterns, llvm-seahorn-upstream-rebase-strategy, multi-llvm-version-branch-
  structure, seahorn-build-and-ci-gotchas, promotememcpy-opaque-ptr-port
- empirical/: verify-c-common-dev16-parity-and-timings (228/228; push_back 88s→2.5s)
- journal/2026-06/: threadlocal-address-regression (06-27), cgscc-inliner-is-the-
  cleaner (06-29), full-O3-breaks-bounded-loop-soundness (06-29)
- code: llvm-seahorn `fa74927` (dev15-faithful -O# pipeline + drop legacy
  PassManagerBuilder); sea-dsa `db979fd` (Copilot header-hygiene fixes) on PR #177
**Critical corrections (user reframings this session):**
- "run dev15's passes" instead of reconstructing from stock O3 — led directly to
  the CGSCC-inliner finding (the dev15 forked builder is the known-good target).
- "read the cl::opt defaults from the registry" instead of hardcoding 31 knob
  defaults — dissolved the divergence hazard in the (later-abandoned) O3 fork.
- Paused the llvm-seahorn origin/dev16 force-push: the shared branch already has
  17 commits of real work; "pristine reset" would discard them.
**Status:** complete (pipeline fix shipped + validated; notes bootstrapped)
**Next-session pickup:** loose-ends/parked.md — llvm-seahorn origin/dev16 reset
   decision (needs human call); clam alloc detection on LLVM 16.
