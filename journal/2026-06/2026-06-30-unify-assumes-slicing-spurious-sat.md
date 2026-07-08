# A surviving-loop opsem2 test needed the full BMC mode (missing `--horn-gsa`)

[OBS 2026-06-30..07-01] `opsem2/verifier_assert_unsat.03.c` was rewritten to a
**geometric** loop `c*=2` (non-summarizable, so it survives BMC regardless of
IndVarSimplify). Under its shipped RUN line
(`--horn-unify-assumes --horn-vcgen-only-dataflow --horn-bmc-coi`, **no gsa**) it
returned spurious `sat` and silently failed.

[OBS] Root cause: that RUN line ran only three of the four flags of the supported
BMC (opsem) VC-gen mode. The supported mode is **df + coi + unify-assumes + gsa**
together; `--horn-gsa` is what lets the dataflow/coi slice keep the gate of a
multi-predecessor merge (the surviving loop's γ). Missing it, the merge gate is
dropped and a false arm is reached → spurious `sat`.

[OBS] Fix: add `--horn-gsa` to the RUN line (the full supported mode). Verified
end-to-end via `sea bpf … --bmc=opsem`: without gsa → `sat` (FileCheck fails); with
gsa → `Error: assertion failed … backedge!!` + `unsat` (passes). **opsem2 42/42.**
Version-independent: reproduces + fixes identically on dev15 (`build-dev15`,
LLVM 15.0.7) and dev16. Minimal 3-block illustration: `../../repro/bmc-opsem-mode-demo.ll`.

[OBS] So this test no longer forces IndVarSimplify off: being non-summarizable it
passes with indvars ON or OFF, as long as BMC runs the full mode.

Note: the investigation took several wrong turns (framing it as a COI "soundness
bug," blaming individual flags) before landing on the simple fact — it is not a bug,
it is a four-flag mode and the RUN line was missing one. The mechanism detail (gsa
materializes the phi gate as a data operand) is real but secondary to that fact.

## Distilled to

../../durable/bmc-opsem-supported-mode.md

## See also

- ../../repro/bmc-opsem-mode-demo.ll
- ../../durable/seaopt-O-pipeline.md
- ./2026-06-30-indvars-root-cause.md
