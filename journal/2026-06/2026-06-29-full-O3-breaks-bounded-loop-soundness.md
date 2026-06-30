# Full stock O3 flips a bounded-loop proof unsat→sat

[OBS 2026-06-29] Two different ways of giving seaopt the *genuine* LLVM-16 O3
pipeline (to fix the push_back slowdown) both fix push_back AND both break opsem2
`verifier_assert_unsat.03` (unsat → **sat**):
1. A verbatim fork of LLVM 16's `PassBuilderPipelines.cpp` copied into seaopt with
   `InstCombinePass`→`SeaInstCombinePass`. It shadow-links cleanly (the TU
   redefines the `PassBuilder::build*Pipeline` symbols, so the linker uses it over
   LLVM's object) — elegant, and push_back → 2 loads.
2. Build `default<O3>` then `printPipeline` → textual `instcombine`→`sea-instcombine`
   → `parsePassPipeline`. (Also blocked by `shouldPopulateClassToPassNames` gating
   the class→pass-name map, but even when worked around, same opsem2 break.)

[OBS 2026-06-29] Cause: full O3's loop passes (IndVarSimplify + LoopDeletion +
SimpleLoopUnswitch, plus constant-folding the `__VERIFIER_assume`-bounded loop)
erase the loop structure that SeaHorn's `-sea-loop-unroll` → `cut-loops` →
`--assert-on-backedge` machinery depends on. dev15 passes because its forked
pipeline is deliberately LIGHT on loops. Forcing `PTO.LoopUnrolling=false` was NOT
enough — it's the broader loop analysis, not just unrolling.

[HYP → promoted to FACT 2026-06-29] "Full stock O3 is fundamentally unusable as
SeaHorn's -O#, regardless of how faithfully InstCombine is swapped." Held across
both implementation routes; it's a soundness property of the loop passes vs
SeaHorn's bounded-loop encoding, not an artifact of either approach. → durable.

## Why this is the important finding

The naive framings ("make seaopt faster" → drop the inliner; "match stock O3" →
full O3) each trade one regression for another, and the O3 one is *soundness*
(wrong verdict), which no perf metric would catch — opsem2 did. The correct target
is "full scalar cleanup + light loops" = dev15's forked builder.

## Distilled to

../../durable/seaopt-O-pipeline.md (fact 3 + corollary)
