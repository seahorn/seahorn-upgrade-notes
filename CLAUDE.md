# Project: SeaHorn dev16 upgrade (LLVM 16 + new PassManager)

These notes live in this directory (`seahorn-upgrade-notes/` at the workspace
root; the workspace `CLAUDE.md` points here via its "Notes at:" line).

The better-than-fish skill governs how to add and maintain notes — re-read its
SKILL.md for conventions (markers, tiers, supersede-on-correction, distillation).

Scope: porting SeaHorn from LLVM 15 (dev15) to LLVM 16 (dev16) — new-PM
migration of seapp/seaopt, sea-dsa port, opsem/verify-c-common parity. Out of
scope: one-off coding chores, transient PR/branch status.

## Three repos under upgrade

All three are git repos with a `dev16` branch (forked from `dev15`):

- seahorn      `~/seahorn/seahorn-upgrade/seahorn/`        (build: `build-dev16`)
- sea-dsa      `~/seahorn/seahorn-upgrade/sea-dsa/`        (build: `build-dev16`)
- llvm-seahorn `~/seahorn/seahorn-upgrade/llvm-seahorn/`   (SeaInstCombine, seaopt)

Toolchain: clang+llvm-16.0.4 at
`~/seahorn/toolchains/clang+llvm-16.0.4-x86_64-linux-gnu-ubuntu-22.04`.
Use ctest at `~/cmake-3.31.7-linux-x86_64/bin/ctest` (NOT the pip shim).

## Code locations to anchor citations

- seaopt -O# pipeline: `llvm-seahorn/tools/opt/NewPMDriver.cpp` (buildSeaPipeline)
- SeaInstCombine: `llvm-seahorn/lib/Transforms/InstCombine/`
- dev15 reference pipeline (legacy PM, now deleted on dev16):
  was `llvm-seahorn/lib/Transforms/IPO/PassManagerBuilder.cpp`
- seapp new-PM pipeline: `seahorn/tools/seapp/seapp.cc`
- sea-dsa new-PM analyses: `sea-dsa/include/seadsa/SeaDsaAnalysis.hh`
- opsem: `seahorn/lib/seahorn/BvOpSem2*.cpp`

## How to run the suites (parity gates)

- opsem2 (want 42/42): `ninja -C build-dev16 test-opsem2`
- opsem (want 125 PASS + xfail): `ninja -C build-dev16 test-opsem`
- verify-c-common (want 228/228): in `verify-c-common/build-dev16`, real ctest,
  `-j6 --timeout 600`. See empirical/ for current timings.

## Project-specific triggers

(none beyond the skill defaults yet — add here as they emerge)

## Active investigations

See `loose-ends/parked.md`. Quick view:

- clam malloc/free detection on LLVM 16 (carried over; clam compiled out)
- (resolved 07-03/07-06) indvars-for-BMC + avoid-bv-off-for-BMC: llvm-seahorn
  `8e7e6c6` (pushed to origin/dev16); seahorn `7dc45541` + `419bc407`
  (committed, not pushed)

## Last weekly digest

weekly/2026-W27.md (2026-06-27 → 2026-07-01: dev16 parity reached; seaopt -O#
root causes; BMC supported mode = df + coi + unify-assumes + gsa)
