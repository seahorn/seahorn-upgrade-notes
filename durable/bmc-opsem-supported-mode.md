# Supported BMC (opsem) VC-gen mode = df + coi + unify-assumes + gsa

[FACT] SeaHorn's supported bounded-model-checking (opsem) VC-gen mode is these
**four flags used together**:

    --horn-vcgen-only-dataflow=true
    --horn-bmc-coi=true
    --horn-unify-assumes=true
    --horn-gsa

They are one mode, not four independent switches — a proper subset is unsupported
and can return a wrong verdict. `--horn-gsa` (Gated SSA) is the piece that makes a
phi's **gate** an explicit data operand, so the dataflow/coi slicing keeps the
branch conditions guarding multi-predecessor merges. Run slicing (df/coi) without
gsa and a program with a surviving multi-predecessor loop (a gated merge) can return
spurious `sat`. (devirt runs the same mode plus `--horn-vcgen-use-ite`.)

[FACT] The opsem2 default RUN line historically set only **three** of the four
(df + coi + unify, no gsa), so a non-summarizable / surviving-loop test silently
returned the wrong answer. Fix = run the full mode (add `--horn-gsa`). Verified:
`opsem2/verifier_assert_unsat.03.c` (geometric `c*=2` loop that survives BMC) fails
without gsa, passes with; **opsem2 42/42**. Version-independent (dev15 == dev16).
Minimal illustration: ../repro/bmc-opsem-mode-demo.ll.

[FACT] Consequence for the `-O#` pipeline (seaopt-O-pipeline.md): a bounded loop
MAY be left to survive into BMC (e.g. IndVarSimplify ON) as long as BMC runs the
full supported mode — the surviving loop becomes a gated merge that gsa handles. So
"disable IndVarSimplify" and "keep it on + run the full BMC mode" are both valid;
loop-bounding is not lost either way.

## Why this matters

The four flags look independent but are one mode. The trap is turning on slicing
(`--horn-bmc-coi` / `--horn-vcgen-only-dataflow`) for speed without also enabling
`--horn-gsa` (and `--horn-unify-assumes`): the slice then drops merge gates and can
flip a true `unsat` to `sat` silently. Always run the four together.

## See also

- ../repro/bmc-opsem-mode-demo.ll (full-mode = correct; drop gsa = wrong)
- ../journal/2026-06/2026-06-30-unify-assumes-slicing-spurious-sat.md
- seaopt-O-pipeline.md
