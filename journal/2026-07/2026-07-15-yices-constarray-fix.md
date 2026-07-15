# yices const-array fix: root-caused, fixed, unit-tested, merged (PR 592)

[OBS 2026-07-15] **The cex+y2 lambda crash is fixed at the core** (user chose
core fix over blacklisting). Full debugging trail, in order:

1. **Flag bisect** on the failing formula: cex extras irrelevant —
   `--horn-bv2-tracking-mem=true` alone flips the crash (z3 solves the same
   formula fine).
2. **gdb breakpoint on `yices_lambda`**: provenance =
   `MarshalYices.cc` CONST_ARRAY case → `yices_lambda` (comment cites
   yices2#271) inside `SolverBmcEngine::encode`.
3. **Env-gated dump** (`SEA_DEBUG_DUMP_CONST_ARRAY`, added permanently):
   offending assertions are
   `select(store(const-array(0), p, 1), q) = 1` and
   `select(ite(c, store(const-array(0), p, 1), const-array(0)), q)` — the
   tracking-mem metadata reads (zero-initialized metadata memory, stores at
   symbolic addresses).

[FACT] **Why yices rejects it, precisely**: yices's term API can only express
const-array as a lambda, and CONTEXTS reject lambda terms at assert. Subtle:
a DIRECT `select(const-array, i)` beta-reduces inside yices (harmless — which
is why the old units const-array test and dev14 never crashed), but a lambda
under `yices_update` (= store) survives into the assertion and kills it.

[FACT] **The fix** (seahorn PR 592, MERGED 2026-07-15): in
`yices_solver_impl::add`, pre-encode rewrite — every select whose array
argument's store/ite skeleton bottoms out in a const-array is pushed through:
select-over-store → index-equality ite; select-over-ite distributes;
const-array leaf → default value; plain leaves keep plain selects. DAG-
memoized; havoc'd memories untouched. `lib/seahorn/Smt/Yices2SolverImpl.cc`.

[OBS 2026-07-15] **Gates**: the 13 failing vcc tests 13/13; full cex-y2
217/217; **the 11 tests blacklisted for this same root cause (comments in
blacklist.cex-y2.txt cite yices2#271; some failing since LLVM 14) now pass
11/11** — blacklist can shrink to empty once a post-fix nightly publishes;
y2 228/228; opsem2 42/42; opsem 125+1. (3 transient y2 fails during gating =
racing ninja install mid-suite; serial rerun + clean full run green.)

[OBS 2026-07-15] **Regression test** (`units/units_yices2.cpp`,
yices2-const-array-store-select.test): builds the exact shapes as Exprs,
checks VERDICTS (unsat + a sat positive control + the ite variant).
Validated bidirectionally: fails (aborts) with the fix reverted, 6/6 with it.
Learned along the way: (a) the existing const-array unit case never caught
this because direct selects beta-reduce (see FACT above); (b) synthetic
opsem2 .c tests could NOT reproduce — simple programs' metadata selects fold
away; the crash needs the full fat-pointer vcc pipeline shape — so the
pipeline-level test was dropped (it passed even unfixed = worthless);
(c) `docker/build_seahorn.sh` already builds AND RUNS units_z3/units_yices2/
units_type_checker in the CI build step, so units regressions gate CI for free.

[OBS 2026-07-15] **vac config verdict** (fork agent):
`hash_table_eq_unsat_test` fails with `assertion failed (sat)
hash_table.c:754 backedge!!` — the `--assert-on-backedge=true --bound=4`
vacuity harness finds a surviving loop backedge; identical on dev16/17/18;
z3-based, unrelated to yices. Pre-existing, exposed by re-enabling the
long-disabled vac CI job (same pattern as cex-y2). Recommendation: blacklist
with comment + file an issue on the unroll bound. Watch: vac job runtime is
dominated by array_list_swap (619s in CI).

[OBS 2026-07-15] **Shaobo He's foreign-node cleanup ported to dev18**:
sea-dsa PR #179 (3 commits: clean up foreign nodes in CS top-down
propagation, compress before cleanup, avoid copying reachable nodes) merged
to dev14 by user; cherry-picked clean onto origin/dev18 as
`dev18-cs-foreign-node-cleanup`, content verified twin-identical to the
merged dev14 commits. Gates: sea-dsa lit at the exact 22-failure baseline,
units 10/11 (known), seahorn opsem2 42/42; vcc 228/228. Pushed DIRECTLY to
seahorn/sea-dsa:dev18 (user-authorized, fast-forward to b6835bd) — no PR;
the same content is upstream on dev14 via PR #179.

## See also

- durable/yices-bridge-gotchas.md (distilled)
- loose-ends/parked.md (cex-y2 FIXED+merged; vac backedge parked)
- journal/2026-07/2026-07-14-dev17-dev18-waves.md
