# Enabling clam exposed a dangling sea-dsa result: ShadowMem must preserve DsaInfoAnalysis

Source: sea-dsa PR #189 (`fix-shadowmem-preserve-dsainfo` → `dev16`) and its
review thread, plus seahorn PR #596 (`fix-crab-new-pm-bmc` → `dev16`), both
opened/reviewed 2026-08-08…08-11.

[OBS 2026-08-11] **`ShadowMemNewPmPass::run` returned
`PreservedAnalyses::none()` while handing out an object that holds a reference
into `DsaInfoAnalysis::Result`.** The pass moves the constructed `ShadowMem`
into `*m_keep` for downstream consumers, but `ShadowMem` stores the underlying
`seadsa::GlobalAnalysis` **by reference**, and that `GlobalAnalysis` is owned by
the cached `DsaInfoAnalysis::Result`. `none()` tells the `ModuleAnalysisManager`
to free that result the moment the pass returns → every later
`ShadowMem::getDsaAnalysis()` is a use-after-free. Fix (whole diff, in
`lib/seadsa/ShadowMem.cc` at the end of `ShadowMemNewPmPass::run`):

```cpp
auto PA = llvm::PreservedAnalyses::none();
PA.preserve<DsaInfoAnalysis>();
return PA;
```

This also restores legacy-PM semantics, where the `DsaAnalysis` pass outlived
the instrumentation and consumers saw the same pre-instrumentation graphs.

[OBS 2026-08-11] **The bug was latent for the whole dev16 cycle because nothing
consumed `getDsaAnalysis()` after the pass.** It surfaced only once seahorn was
built with `WITH_CLAM=ON` (seahorn PR #596): `Bv2OpSem::initCrabAnalysis` became
the first real post-pass consumer, and `test/crab`'s `crab_is_deref` and
`crab_rng_1` crashed. `WITH_CLAM=OFF` compiles the call sites out entirely — so
the dev16 "green" board never exercised this path. Same shape as the stale-
blacklist/disabled-job findings on verify-c-common PR #146: a disabled consumer
hides a real defect indefinitely.

[OBS 2026-08-11] **Design clarification from the review (caballa, answering
priyasiddharth/agurfinkel): sea-dsa has two different consumer channels, and
only one of them goes through the IR.**
- sea-dsa → **seahorn**: communication is *through the IR* (shadow-memory
  instrumentation). Preserving sea-dsa data structures is not the design.
- sea-dsa → **clam** (linked as a library inside seahorn): communication is
  *through the data structures*. Clam calls
  `seadsa::ContextSensitiveGlobalAnalysis` /
  `seadsa::ContextInsensitiveGlobalAnalysis` directly — no pass manager
  involved on that edge.

So preserving `DsaInfoAnalysis` does not contradict the IR-based design; it
serves the second, deliberately different channel. With that answer,
priyasiddharth agreed with preserving and agurfinkel approved the PR.

[OBS 2026-08-11] **Review outcomes to carry forward** (both requested in the
threads, both agreed to):
- The fix must be **ported to `dev17` and `dev18`** (caballa, PR #189
  description comment). The three branches are pristine forks of one another,
  so it is a cherry-pick, but nothing ports it automatically.
- **verify-c-common needs a clam-ON entry in its CI matrix** (priyasiddharth),
  so the sea-dsa + clam + seahorn path is actually exercised — `is_deref` is
  the suspected user of that path. Assigned to priyasiddharth ("Please do the
  update").
- On seahorn PR #596, priyasiddharth requested changes against making clam a
  *required* dependency (it complicates future LLVM upgrades) and proposed a
  graded rollout: keep `WITH_CLAM=OFF` for the primary CI runs, add separate
  nightlies with and without clam. agurfinkel backed it; caballa reverted the
  CI portion so clam stays optional.

[OBS 2026-08-11] **Also from PR #596, worth remembering as dev16 facts:** clam's
clone target moved dev15 → dev16 (clam *is* now ported to LLVM 16, which
partially unblocks the long-parked clam alloc-detection item); `test/crab` went
4/7 → 7/7; the other latent bug was a null-pointer deref in
`Bv2OpSem::initCrabAnalysis` (fixed by passing ShadowMem explicitly); and the
lit config used to crash outright when the `sea_inc` binary was missing.

## Open ends

- Ports to dev17/dev18 and the clam-ON verify-c-common matrix entry — both
  tracked in `loose-ends/parked.md`.
- Unknown whether any *other* new-PM pass in the tree returns `none()` while
  publishing an object that borrows from a cached result. The pattern is worth
  a sweep, not just a point fix.

## See also

- durable/sea-dsa-newpm-analyses.md (distilled: the result-lifetime contract)
- durable/seahorn-build-and-ci-gotchas.md (WITH_CLAM build flag)
- loose-ends/parked.md (clam malloc/free detection on LLVM 16)
