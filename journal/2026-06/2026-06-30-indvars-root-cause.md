# Root cause of the bounded-loop regression: IndVarSimplify + a lost flag

Supersedes the "soundness" framing in
./2026-06-29-full-O3-breaks-bounded-loop-soundness.md.

[OBS 2026-06-30] Captured every pipeline stage for `verifier_assert_unsat.03`
(`sea bpf --save-temps --temp-dir`) on both dev15 and dev16. **Current dev15 and
dev16 produce byte-identical `@main` at every stage** (incl. after the first
`-O3`: 3 blocks / 1 phi, loop survives) and both return `unsat`. So there is no
*current* divergence; the historical one was dev15 vs the *broken* (full-O3) dev16.

[OBS 2026-06-30] Bisected which pass folds the loop on the `pp.ms.bc`:
`function(loop-simplify,lcssa,loop(indvars))` → 0 phis (folded);
`loop-deletion`, `loop-unroll`, `simple-loop-unswitch` → loop survives. So the
single culprit is **IndVarSimplify**. `-replexitval=never` makes it survive → the
mechanism is **exit-value rewriting** (`rewriteLoopExitValues`).

[OBS 2026-06-30] The folded `@main` is: `%smax = llvm.smax.i32(%c, %limit)` with
both operands SYMBOLIC, plus the two `assume`s kept separate; `sassert(c==9)` →
`assume.not(smax==9)`. So LLVM computed the loop's *exact symbolic closed form*
`smax(c,limit)` (sound; needs no knowledge of the constants), deleted the loop,
and the `=10`/violation is the SMT solver's step, not LLVM's. The `sat` is the
TRUE verdict (`c` really ends at 10).

[OBS 2026-06-30] LLVM-15 vs LLVM-16 IndVarSimplify on the *same* input: **both
fold identically** (0 phis, same `smax`). So it is NOT a version/legacy-vs-new-PM
difference. dev15's `seaopt -O3` run plain ALSO folds it (0 phis); with
`--seaopt-enable-indvar=false` it survives (1 phi). The `sea` driver passes that
flag. → root cause: dev16's migration **dropped the flag**
(`seahorn/py/sea/commands.py:936`: "flag removed in dev16, nothing to disable").
The flag itself: `f4c57a5` (llvm-seahorn, Arie Gurfinkel, 2020, default ON).

[OBS 2026-06-30] Realigned `buildSeaPipeline` to dev15's actual disable: drop only
`IndVarSimplify` + `LoopIdiom`; keep `SimpleLoopUnswitch` / `LoopDeletion` /
unroller. Re-verified: loop survives `-O3` (1 phi), opsem2 42/42, opsem 125,
verify-c-common 228/228, push_back/front still ~2.5s. (The earlier fix dropped a
broader set + kept LoopIdiom — coincided only because indvars is the sole pass
that acts on this loop.)

## Lesson

When a verifier's verdict changes after an LLVM pipeline edit, "soundness" is the
wrong first reflex — capture the IR at each stage, bisect to the single pass, and
read the actual transform. Here the pass was sound (exact loop summary); the real
issue was that it removed the loop SeaHorn wanted to bound, and the regression was
a *lost feature flag*, not pass aggression.

## Distilled to

../../durable/seaopt-O-pipeline.md
