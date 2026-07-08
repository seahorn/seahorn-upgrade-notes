# seaopt -O# is a curated new-PM pipeline (not stock default<O#>)

How SeaHorn's `seaopt -O#` is built on dev16, and the two things that make it work.

[FACT] `seaopt -O#` is built by `buildSeaPipeline` in
`llvm-seahorn/tools/opt/NewPMDriver.cpp` — a new-PassManager transcription of
dev15's forked legacy `PassManagerBuilder`, NOT LLVM's stock `default<O#>`.
Structure: module setup (InferAttrs → IPSCCP → CalledValueProp → GlobalOpt →
mem2reg → DeadArgElim → SeaInstCombine/simplifycfg) → **CGSCC inliner**
(`ModuleInlinerWrapperPass`) wrapping the full `addFunctionSimplificationPasses`
scalar cleanup → light late cleanup → GlobalDCE/ConstantMerge. Stock
`InstCombinePass` is replaced by `llvm_seahorn::SeaInstCombinePass()` throughout.
→ committed in `llvm-seahorn` `fa74927` (refactor(newpm): sea -O# pipeline).

[FACT] **The CGSCC inliner is load-bearing for *cleanup*, not just inlining.**
SeaHorn's PromoteMemcpy emits struct field-copies (store fields to a dst alloca,
load them back). SROA/GVN/MemCpyOpt/DSE alone do NOTHING to them — the structs
only become scalarizable AFTER the inliner folds in residual callees. dev15 ran
`MPM.add(Inliner)` before the function passes; dropping it ("seapp already
inlines") made `array_list_push_back/push_front` ~40× slower (88s vs dev15 2.3s).
Bisect proof: `-passes='function(sroa,...,gvn,instcombine)'` left all 12 `@main`
loads; `-passes='function(mem2reg),cgscc(inline, function(...))'` → 2 loads.
(globals-aa was a red herring: a `parseAAPipeline("default,globals-aa")` error
gave empty output mis-counted as "0 loads".)

[FACT] **The -O# stage treats two loop passes specially: `LoopIdiomRecognize` is
hard-omitted; `IndVarSimplify` is gated by `--seaopt-enable-indvar` (default OFF —
dev15's flag name, opposite default).** Everything else dev15 ran stays
(`LoopInstSimplify`, `LoopSimplifyCFG`, `LICM`, `LoopRotate`, `SimpleLoopUnswitch`,
`LoopDeletion`, the unroller). The `sea` driver enables indvars on the **bounded
(BMC) aliases** (`bpf`/`fpf`/`bnd-*`/`fpcf`/`spf` — via `Seaopt(enable_indvar=True)`
on a dedicated `BndFeCmds` stage list in `py/sea/commands.py`): the early fold of a
summarizable assume-bounded loop is sound, and a surviving loop is handled by the
BMC VC-gen mode (see bmc-opsem-supported-mode.md). The same bounded instances
also pass `--seaopt-instcombine-avoid-bv=false` (stock-LLVM InstCombine folds for
BMC; A/B'd behavior-neutral 2026-07-03, journal entry). Unbounded flows
(`smt`/`pf`/…) and bare `seaopt -O#` keep indvars off and avoid-bv on. History:
dev15's `f4c57a5` (2020, Arie
Gurfinkel) had both flags default ON with the driver forcing both off for all
flows; dev16 first re-implemented that by omission, then (2026-07-03) restored the
indvar flag with the bounded-flow tie-in. [validated: opsem2 42/42, opsem 125,
vcc 228/228 — vcc runs fpf, so indvars-on is exercised]

[FACT] **`IndVarSimplify` is the single load-bearing one** (bisection: adding just
`indvars` to the loop folds it; `LoopDeletion` / `SimpleLoopUnswitch` / `loop-unroll`
each leave it). Mechanism = its **exit-value rewriting** (`rewriteLoopExitValues`,
gated by `-replexitval`): for `c=2; while(c<limit) c++;` SCEV proves the loop's exit
value of `c` is the closed form `smax(c,limit)` — a *sound, exact* summary, true for
all inputs (it does NOT consult the `assume`; both operands stay symbolic). It
replaces the post-loop use of `c` with `llvm.smax(c,limit)` and deletes the now-dead
induction phi → the loop dissolves to straight-line code. `sassert(c==9)` becomes
`assert(smax(c,limit)==9)`, which the **SMT solver** (not LLVM) evaluates under
`c==2, limit==10` to false → `sat`.

[FACT] **This is NOT unsoundness — the folded `sat` is the *true* verdict.** The
loop runs `c` from 2 to 10, so `sassert(c==9)` genuinely fails. The `unsat` that
opsem2 `verifier_assert_unsat.03` expects is the *bounded* answer: with the loop
intact, SeaHorn unrolls to a small bound, the post-loop assert is unreached, and
the `--assert-on-backedge` adequacy assert fires ("bound too small") — that
`Error: assertion failed (backedge) / unsat` pair is exactly what the test checks.
The real reason to disable `IndVarSimplify` is that it **summarizes away the loop
that SeaHorn's own `-sea-loop-unroll` / `cut-loops` (`CutLoops.cc`,
`BackedgeCutter.cc`) stage is meant to bound** — it takes loop-bounding away from
SeaHorn — *not* because it gives a wrong answer.

[FACT] Root cause of the dev16 regression (CLOSED): a **lost feature flag**, not a
pass-behavior difference. LLVM-15 and LLVM-16 `IndVarSimplify` fold this loop
identically (verified: both → `smax`, 0 phis). dev15's `seaopt -O3` also folds it
when run plain; dev15 only avoids it because the `sea` driver passes
`--seaopt-enable-indvar=false`. The dev16 migration dropped that flag from seaopt
(`seahorn/py/sea/commands.py:936` now reads *"flag removed in dev16, nothing to
disable"*), so indvars ran and folded the loop → `sat`. The fix restores the
disable by omitting the pass.

[FACT] Corollary: full stock `default<O3>` is unusable as SeaHorn's -O# — it runs
`IndVarSimplify`, which summarizes bounded loops away. Tested two faithful-O3
routes (verbatim shadow-link fork of `PassBuilderPipelines.cpp`;
build-then-print→swap→reparse); both fold the loop identically, both rejected.
NOTE: seaopt -O3 unrolling *marked* loops is intended (`CutLoops.cc:1-16`:
"the actual unrolling is done by some optimization pass… seaopt -O3 does the
trick"), so this is NOT "-O3 must not touch loops" — it is specifically "don't let
`IndVarSimplify` summarize unmarked `assume`-bounded loops."

## Correction (2026-06-30)

An earlier draft called this a **soundness** regression and explained it as "keep
the -O# stage LIGHT on loops because SeaHorn does the unrolling" / "trip-count-
exploiting passes fold the loop." All three were wrong: (1) the fold is *sound* —
`sat` is the true verdict; (2) seaopt -O3 unrolling is by design; (3) the culprit
is `IndVarSimplify` exit-value rewriting *specifically*, and the root cause is a
lost flag, not a legacy-vs-new-PM pass difference. The first fix was also
over-broad (dropped IndVarSimplify + LoopDeletion + SimpleLoopUnswitch + unroll,
kept LoopIdiom); it was realigned to dev15's actual two-flag disable
(IndVarSimplify + LoopIdiom off; the rest on).

## Why this matters

The seaopt pipeline is the per-job optimizer feeding BMC. "Make it faster" and
"make it match stock O3" are traps: the first invites dropping the inliner (40×
regression); the second runs `IndVarSimplify`, which summarizes SeaHorn's bounded
loops away (a *correct* verdict on the program, but it bypasses SeaHorn's
loop-bounding machinery). The correct target = dev15's effective -O3: full scalar
cleanup + the inliner, with `IndVarSimplify` and `LoopIdiom` disabled.

## See also

- ../empirical/verify-c-common-dev16-parity-and-timings.md
- ../journal/2026-06/2026-06-29-cgscc-inliner-is-the-cleaner.md
- ../journal/2026-06/2026-06-30-indvars-root-cause.md
- bmc-opsem-supported-mode.md — the path to keep indvars ON: a surviving bounded loop
  becomes a BMC gated merge, handled by the full supported BMC mode
  (df + coi + unify-assumes + gsa). Validated on `verifier_assert_unsat.03`
  (geometric); disabling indvars is one option, keeping it on under the full BMC mode
  is the other.
- ../journal/2026-06/2026-06-30-unify-assumes-slicing-spurious-sat.md (full trail)
- ../journal/2026-06/2026-06-29-full-O3-breaks-bounded-loop-soundness.md (superseded)
- promotememcpy-opaque-ptr-port.md
- seapp-newpm-migration-patterns.md
