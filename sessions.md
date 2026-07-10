# Sessions log

Curated index of significant sessions. Newest first. Add an entry only when a
session produced notes, code, or decisions worth pointing back to.

## 2026-07-09
**Session:** ShadowMem new-PM port; PM perf A/B; PR 586 MERGED; lineage syncs
**Theme:** Ported ShadowMem to the new PM with wrapper symmetry (sea-dsa
   `2d264d8`: ShadowMemNewPmPass beside the legacy pass, DT/AC getters with
   FRESH-per-query trees, AllocSiteInfoAnalysis); seahorn `8a034427` wires it
   + fixes a latent double-hornify. Route equivalence PROVEN byte-identical
   (sea smt). Perf A/B: new PM == legacy PM (150 vs 149ms module, 2.2s suite,
   304 vs 301ms encode-only); binary +1MB (additive design).
**Milestone:** **seahorn PR 586 merged upstream** (origin/dev16 = 7c8a8f40,
   rebased twins). Local dev16 reset to origin; dev16-horn-newpm rebased on
   top (tip ede7a3ea, 17 commits, tree byte-identical, clean-FF PR ready).
   sea-dsa fork realigned to origin lineage (2d264d8) after a twin-commit
   merge conflict — same disease, same cure as the llvm15 episode.
**Status (updated 2026-07-09):** **PR 587 (new-PM migration) CI GREEN** and
   mergeable — sea-dsa's ShadowMem commit merged upstream first (384c63e,
   re-rebased SHAs again), then a cosmetic amend restarted CI (f2f98179).
   Both dev16 arcs — the LLVM-16 port (#586) and the new-PM migration
   (#587) — are now upstream or upstream-ready.
**PR 587 trail:** opened from fork:dev16 (message rewritten for outside
   reviewers per user ask). CI round 1: lint+format FAILED → 657-line
   clang-format fixpoint (style commit) + 3 header rewords via filter-branch
   (incl. git's default Revert header — no type, uppercase). Round 2: test
   FAILED — sea-dsa dependency missing on org branch (CI clones by branch);
   user merged sea-dsa dev16, cosmetic amend restarted CI → ALL GREEN.
**Next-session pickup:** merge PR 587; delete backup branches
   (dev16-pre-rebase/-pre-reorder/-pre-sync, horn-newpm-pre-sync);
   check origin/copilot/fix-lint-failure branch (unreviewed automation?);
   formats artifacts still undecided; simple/05 + solve/04 investigation.

## 2026-07-08 (horn-newpm arc)
**Session:** horn/BMC + CHC new-PM migration, kickoff to completion
**Theme:** Migrated the seahorn driver to the new PassManager in 17 gated
   commits on `dev16-horn-newpm`: transform prefix (A1-A4), opsem Pass-seam
   retirements (Bv2OpSem, BvOpSem, UfoOpSem family — all ctor-only CanFail
   pulls), five seahorn new-PM analyses, BmcPassNew (mono BMC end to end),
   explicit CHC orchestration (hornify/write/solve/cex/houdini/pred-abs),
   --oll dumps. Every batch gated on opsem2/opsem (+vcc 228/228 for the big
   ones; CHC on baseline-locked simple/solve: 2 pre-existing dev16 failures).
**Critical corrections (user):**
- "the wrappers were there in dev14/dev15 — a design choice, don't change
  it": cancelled the dead-class deletion sweep (E2) and REVERTED the E1 file
  deletion; the migration stays additive; the retained legacy pass library
  is intentional, which also re-answers the PR +/- asymmetry question.
**Key findings:** Pass-conduit accessors segfault standalone (getSBI);
   ShadowMem pinned to its consumers' PM (addRequired); UnifyAssumes needs
   lazy DT/AC; CHC baseline failures (simple/05, solve/04) pre-exist dev16.
**Status:** task complete; branch local-only, 17 commits, ready to push/PR.
**Next-session pickup:** optional sea-dsa ShadowMem new-PM port; the two
   pre-existing CHC failures; PR sequencing after seahorn#586 merges.

## 2026-07-07
**Session:** seahorn dev16 rebased onto current dev15; PR branches finalized
**Theme:** The dev16→origin PR showed ~22 llvm15-titled commits: dev16 forked
   from dev15 at `42f7f824` BEFORE the llvm15-port commits landed on
   origin/dev15 as rebased twins (same patches, different SHAs), so both lines
   carried copies git cannot deduplicate. Fixed by rebasing dev16 onto the
   real dev15 tip.
**Key outputs:**
- `git rebase --onto origin/dev15 42f7f824 dev16 --empty=drop`: 18 twins
  auto-dropped/skipped, b84660f7 (early CI commit) skipped as content-subsumed
  by dev15's ccache redesign, 35 genuine LLVM16 commits replayed clean, 3 tiny
  llvm15-titled residue commits survived (~7 lines; their dev15 twins were
  later modified on dev15, so re-applying restores what dev16 had).
- Verification: tree diff pre- vs post-rebase = ONLY CI/docker files (the
  ccache work dev16 lacked); zero source-code difference. opsem2 42/42,
  opsem 125 + 1 xfail re-run as smoke.
- Pushes: origin/dev16 moved 42f7f824 → 2503bdd8 (= dev15 tip, the PR base);
  fork dev16 force-pushed 419bc407 → b14e7323 (rebased head). PR range now
  37 commits, clean fast-forward, based on current dev15.
- Local backup branch `dev16-pre-rebase` (= 419bc407) kept.
**Later same day:** PR **seahorn/seahorn#586** opened (via browser). Dropped 3
   residual llvm15-titled commits (netted to exactly zero — verified empty
   diff). Fixed both red CI jobs: clang-format (1703-line clang-format-diff-15
   delta → applied to fixpoint, `style:` commit, 55 files) and commitlint
   (15/35 messages: 14 headers >72, 1 sentence-case subject → reworded headers
   via filter-branch, bodies+trees untouched). Diagnosed via the PUBLIC
   check-runs/annotations API (no gh auth needed). Final head `cddd06f2`
   (35 commits). Rules distilled to durable/seahorn-build-and-ci-gotchas.md;
   trail in journal/2026-07/2026-07-07-pr586-and-ci-fixes.md.
**Later (dev16 CI):** wired build/test CI for dev16 per user ask: workflow
   triggers on dev16, jammy-llvm16 buildpack image (LLVM_VERSION arg, toolchain
   from apt.llvm.org incl. llvm-16-dev), build_seahorn.sh LLVM_VERSION env,
   CMakeLists clones sea-dsa/llvm-seahorn -b dev16 (was dev15 — real bug).
   Validated by SIMULATING CI LOCALLY (docker build of the image + full
   build_seahorn.sh run in it) before any dispatch: caught (1) missing
   libzstd-dev, (2) zstd::libzstd_shared never defined because seahorn's
   global ".a"-first CMAKE_FIND_LIBRARY_SUFFIXES makes LLVM's Findzstd take
   its static-only branch — fixed with a scoped shared-first re-find after
   LLVM_CMAKE_DIR joins the module path. Full sim green (doctest units,
   package). Commits a3e684c5, c7debae4, 915bebbe. REMAINING: one-time
   "Buildpack deps" workflow dispatch on branch dev16 to publish
   ghcr jammy-llvm16, then re-run the PR CI job.
**2026-07-08:** PR 586 CI fully GREEN (user-confirmed) after the mcfuzz saga:
   issue_44 XPASS→runner-fail→UNRESOLVED across three lit-marker attempts;
   final fix = rename to .disabled (out of lit discovery — the only portable
   disable). Lesson: XFAIL/UNSUPPORTED/REQUIRES semantics differ across lit
   versions; pip lit reports unmet REQUIRES as UNRESOLVED (suite-failing).
   issue_44 parked in loose-ends as a real opsem imprecision (correct verdict
   unsat; sub-word undef propagation in aggregate copies). Also fixed en route:
   sea driver clang-16/llvm-link-16 search (4840427a — local suites had been
   silently clang-15 front-ended!), string.h for clang-16 implicit-decl error
   (4ab6505c), vcc re-validated 228/228 @ 405s with the true clang-16 front end.
   horn-newpm branch: batch A1 committed (b360b165), suites green.
**Status:** PR 586 GREEN and mergeable; dev16 CI operational end to end.
**Next-session pickup:** confirm PR 586 CI green + merge; delete
   `dev16-pre-rebase` after merge; formats artifacts (.clp/.mcmt Jun 27
   regeneration) still uncommitted-undecided.

## 2026-07-03
**Session:** IndVarSimplify tied to bounded (BMC) sea flows
**Theme:** Implemented the indvars-for-BMC decision: restored dev15's
   `--seaopt-enable-indvar` in seaopt (default OFF, gating IndVarSimplify in
   `buildSeaPipeline` LPM2), and enabled it from the sea driver on the bounded
   aliases only (`bpf`/`fpf`/`bnd-*`/`fpcf`/`spf`) via `Seaopt(enable_indvar=True)`
   on a fresh `BndFeCmds` stage list. Unbounded flows and bare seaopt unchanged.
**Key outputs:**
- code: llvm-seahorn `NewPMDriver.cpp` (flag + gate); seahorn
  `py/sea/commands.py` (constructor param + bounded-alias rewiring). UNCOMMITTED.
- journal/2026-07/: 2026-07-03-indvar-tied-to-bounded-flows (incl. the failed
  `hasattr` detection: SeqCmd stages parse separate namespaces — per-instance
  constructor config is the only mechanism)
- durable/seaopt-O-pipeline.md fact updated (gated, not omitted); parked.md
  indvars entry resolved; empirical vcc note re-stamped (2026-07-03, 413s).
**Validation:** opsem2 42/42, opsem 125 + 1 xfail, verify-c-common 228/228
   (vcc runs fpf → indvars-on exercised end-to-end).
**Also:** confirmed local sea-dsa dev16 == origin/dev16 in content (SHAs differ:
   re-committed Jul 3 under gmail identity; local reset to origin pending).
   A/B'd `--seaopt-instcombine-avoid-bv` off: no correctness impact, timing
   noise-level (journal/2026-07/2026-07-03-avoid-bv-off-experiment.md); then
   per user call wired avoid_bv=False into the same bounded aliases
   (vcc 228/228 in 411.5s via the driver route). llvm-seahorn committed as
   `8e7e6c6` (realign + indvar flag) and force-with-lease pushed to
   origin/dev16; seahorn side committed 2026-07-06 as `7dc45541` (indvar
   tie-in + geometric/gsa test) and `419bc407` (avoid-bv tie-in), split per
   user request.
**Status:** complete + validated; only the notes repo remains uncommitted.
**Next-session pickup:** loose-ends/parked.md — llvm-seahorn origin/dev16 reset;
   optional: commit the indvar tie-in + the opsem2 gsa RUN-line change together.

## 2026-07-01
**Session:** BMC opsem supported mode = df + coi + unify-assumes + gsa
**Theme:** A geometric (non-summarizable) `verifier_assert_unsat.03` returned the
   wrong verdict because its RUN line ran only 3 of the 4 flags of the supported
   BMC (opsem) VC-gen mode — it was missing `--horn-gsa`. The supported mode is
   df + coi + unify-assumes + gsa together; gsa makes a phi's gate an explicit
   operand so the dataflow/coi slice handles gated (multi-pred) merges. Fix = run
   the full mode. Version-independent (dev15 == dev16).
**Key outputs:**
- durable/: **bmc-opsem-supported-mode** (new — the 4-flag fact); seaopt-O-pipeline
  (indvars cross-link updated: indvars-ON is a live option under the full BMC mode)
- journal/2026-06/: 2026-06-30-unify-assumes-slicing-spurious-sat (scrubbed to the
  fact; notes the investigation's earlier wrong "COI bug" framings)
- repro/: bmc-opsem-mode-demo.ll (full mode = correct; drop gsa = wrong)
- code: `test/opsem2/verifier_assert_unsat.03.c` RUN line += `--horn-gsa`
  (was silently failing; **opsem2 42/42** re-verified). UNCOMMITTED.
**Critical corrections (user reframings this session):**
- "coi without unify is unsupported" — killed a wrong "COI is unsound standalone"
  pivot.
- "try unify + dataflow + gsa" — surfaced gsa as the missing flag.
- "the supported mode is df + coi + unify-assumes + gsa; that is durable" — the
  final, correct framing: it is one 4-flag mode, not a bug; scrubbed the notes to it.
**Status:** complete + validated (opsem2 42/42); test change uncommitted.
**Next-session pickup:** optional — enable IndVarSimplify globally in
   `buildSeaPipeline` (with the full BMC mode) + re-run opsem/vcc; see parked.md.

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
