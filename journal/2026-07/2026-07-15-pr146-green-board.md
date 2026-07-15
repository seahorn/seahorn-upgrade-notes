# PR 146 fully green: 9/9 checks, cex-y2 unblacklisted, three stale configs woken

[OBS 2026-07-15] **verify-c-common PR #146 ended 9/9 green, zero failures** —
five commits, each unblocking one thing:
1. `735842c` image onto ghcr seahorn-llvm18:nightly (the original PR)
2. `521f583` vac: re-blacklist hash_table_eq (backedge at bound=4; blacklisted
   2021-2026, unblacklisted while the job was disabled)
3. `8d96964` cex-y2: **blacklist EMPTIED** — all 11 historical entries were
   the one const-array/lambda root cause fixed by seahorn #592
4. `1b58fc7` fuzz: codecov upload made non-fatal (see gotcha below)
5. `6bd5b45` cex: 18 pre-existing z3-performance stragglers blacklisted with
   provenance
The certified image carries LLVM 18 + the #592 yices fix + Shaobo's
foreign-node cleanup. cex-y2 ran all 228 tests unblacklisted and PASSED —
first time ever for that config.

[OBS 2026-07-15] **cex (plain z3) verdict — the THIRD stale-blacklist config
in a row** (after cex-y2 and vac): 16 tests exceed the 2000s timeout and 2
return `unknown` from z3 (hash_iter_begin2 in 0.8s, begin_done2 in 25s solve —
gives up, not wrong verdicts). Root: without `--horn-bmc-logic=QF_ABV`, z3
cannot close these proofs; the SAME tests pass in seconds under cex+smt-y2.
Pre-existing: dev16 sample times out identically. Treatment: blacklist with
in-file provenance; coverage retained via the unblacklisted cex-y2 config.

[FACT] **codecov on fork PRs**: GitHub withholds repository secrets from
`pull_request` runs originating in forks → codecov-action falls back to a
tokenless upload → aggressively rate-limited (429) → with
`fail_ci_if_error: true` a coverage hiccup fails the job. Treatment:
`fail_ci_if_error: false` (best-effort coverage; push-triggered runs with the
secret unaffected). Also: the action pinned at v2 is deprecated (v5 current),
and the vcc Dockerfile clones aws-c-common UNPINNED — both noted, not fixed.

[OBS 2026-07-15] **Ops flow that worked**: GHCR digest-change monitor caught
the nightly refresh (the tag is overwritten; watch the manifest digest, not
tag existence) → cosmetic amend-push re-fired PR CI against the new image →
per-check monitor reported the board as it filled. Nightly's own green run
also re-validated units_yices2 (the #592 regression test) in CI.

## Open ends

- Why z3-sans-QF_ABV diverges so hard from yices on these 18 proofs — and
  whether the cex job should simply pass QF_ABV — is unexplored (parked).
- Issues still to file: SimplifyPointerLoops pointer-IV, vac bound-4 harness
  precondition, aws-c-common pin, codecov action upgrade.

## See also

- journal/2026-07/2026-07-15-yices-constarray-fix.md (the fix this run certified)
- durable/seahorn-build-and-ci-gotchas.md (codecov fork-secrets added)
- loose-ends/parked.md (cex z3-performance entry)
