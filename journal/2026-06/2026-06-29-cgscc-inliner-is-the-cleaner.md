# The CGSCC inliner — not SROA/GVN — is what cleans push_back

[OBS 2026-06-29] `seaopt -O3` on the push_back pp input leaves 8 `@main` loads
where dev15 leaves 2 (input has 12). Bisecting against `default<O1>` (which also
reaches 2): flat scalar sequences all stall at 8, e.g.
`function(sroa,early-cse<memssa>,instcombine,mldst-motion,gvn,memcpyopt,dse,
instcombine,sroa,gvn,instcombine)` → 8; even `sroa<modify-cfg>`×3 → 12 (no
progress). But `function(mem2reg),cgscc(inline, function(sroa,...,gvn,instcombine))`
→ 2.

[OBS 2026-06-29] So the cleaner is the **CGSCC inliner**, not the scalar passes.
SeaHorn's PromoteMemcpy struct field-copies are opaque to SROA/GVN until the
inliner folds in residual callees and exposes the alloca; only then does SROA
scalarize and GVN forward. dev15's forked `PassManagerBuilder` ran `MPM.add(Inliner)`
before `addFunctionSimplificationPasses`; the dev16 transcription had dropped it
on the assumption "seapp already inlines." That single omission was the ~40×
slowdown.

[OBS 2026-06-29] Fix: wrap the function-simplification in
`ModuleInlinerWrapperPass` (+ `PostOrderFunctionAttrsPass`) in `buildSeaPipeline`
(`NewPMDriver.cpp`). push_back → 2 loads, 88s → 2.5s, dev15 parity.

## False lead

[OBS 2026-06-29] `-aa-pipeline='default,globals-aa'` appeared to give 0 loads,
which looked like "globals-aa is the fix." It was an artifact: `parseAAPipeline`
rejects `"default"` inside a comma list, seaopt errored, empty output counted as
"0 loads." globals-aa alone (`basic-aa,globals-aa`) gives a real 8. Lesson: when
a metric comes from parsing tool output, confirm the tool actually ran (non-empty,
exit 0) before trusting the number.

## Distilled to

../../durable/seaopt-O-pipeline.md (fact 1)
