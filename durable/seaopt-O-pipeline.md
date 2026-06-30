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

[FACT] **Keep the -O# stage LIGHT on loops** — rotate + LICM only.
`IndVarSimplify`, `LoopDeletion`, `SimpleLoopUnswitch`, and loop unrolling are
deliberately dropped. Their new-PM forms fold SeaHorn's `__VERIFIER_assume`-
bounded loops before `-sea-loop-unroll`/`cut-loops`/`--assert-on-backedge` run,
flipping bounded-loop proofs **unsat→sat** (opsem2 `verifier_assert_unsat.03`) —
a SOUNDNESS regression. SeaHorn drives unrolling itself.

[FACT] Corollary: full stock `default<O3>` is unusable as SeaHorn's -O#, by
either route tested — (a) a verbatim shadow-link fork of LLVM 16's
`PassBuilderPipelines.cpp` with InstCombine→SeaInstCombine, or (b) build
`default<O3>` then print→swap→reparse the pipeline string. Both fix push_back but
both break opsem2 the same way (the loops fact above). Both rejected.

## Why this matters

The seaopt pipeline is the per-job optimizer feeding BMC. "Make it faster" and
"make it match stock O3" are traps: the first invites dropping the inliner (40×
regression), the second invites full O3 (soundness break). The only correct
target is "full scalar cleanup + light loops," which is exactly dev15's forked
builder — so transcribe that, don't reinvent.

## See also

- ../empirical/verify-c-common-dev16-parity-and-timings.md
- ../journal/2026-06/2026-06-29-cgscc-inliner-is-the-cleaner.md
- ../journal/2026-06/2026-06-29-full-O3-breaks-bounded-loop-soundness.md
- promotememcpy-opaque-ptr-port.md
- seapp-newpm-migration-patterns.md
