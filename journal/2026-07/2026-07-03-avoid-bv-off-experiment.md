# avoid-bv off: nothing breaks, nothing meaningfully improves

[OBS 2026-07-03] A/B of SeaInstCombine's `--seaopt-instcombine-avoid-bv`
(InstructionCombining.cpp:179, default ON = suppress InstCombine folds that
introduce bit-vector reasoning). Method: flip `cl::init` to false, rebuild
seaopt, run all three suites, revert (same pattern as the indvars A/B).
State under test: dev16 + indvars-for-bounded-flows (llvm-seahorn `8e7e6c6`).

| suite | avoid-bv ON (baseline, same day/machine) | avoid-bv OFF |
|---|---|---|
| opsem2 | 42/42 | 42/42 |
| opsem | 125 + 1 xfail | 125 + 1 xfail |
| verify-c-common | 228/228, 413.1s wall | 228/228, 405.3s wall |
| — array_list_swap | 413.1s | 405.2s |
| — hash_table_remove | 108.3s | 113.3s |

[OBS 2026-07-03] Verdict: **no correctness impact anywhere**; the timing delta
(-2% wall, swap -8s, hash_remove +5s) is single-run -j6 noise territory — NOT
evidence of improvement (lesson from the indvars A/B: single -j6 runs misled
before; only isolated multi-run A/B counts). Flag verified live before trusting
the null result: `x % 4u` stays `urem` with ON, folds to `and i32 %x, 3` with
OFF (the udiv→lshr fold happens regardless — that one isn't guarded).

[HYP] The bv2 opsem already encodes everything as bitvectors, so the folds this
flag suppresses (masks/shift tricks) are no harder for the solver than what is
already there — which would explain the null result. Untested; an isolated
3-run A/B of the two long jobs would settle whether the small deltas are real.

## Decision + wiring (same day)

User call: turn avoid-bv OFF on the bounded (BMC) flows anyway (stock-LLVM
folds for BMC; the seaopt default stays ON for everything else). Implemented
as `Seaopt(..., avoid_bv=False)` on the same 8 bounded-alias instances as
enable_indvar (`py/sea/commands.py`); the stage emits
`--seaopt-instcombine-avoid-bv=false`. No llvm-seahorn change (flag existed).
Validated via the driver route: `fe` clean / `bnd-fe` both stages flagged;
opsem2 42/42, opsem 125 + 1 xfail, vcc 228/228 in 411.5s (swap 411.4s —
third run, consistent with 413/405: all noise-level). Uncommitted.

## Why noted

"avoid bv folds because they hurt the solver" is inherited dev14/dev15 lore;
this is the first dev16 measurement of it. The A/B's null result means the
bounded-flow flip is behavior-neutral today; the seaopt default stays ON so
unbounded flows and bare seaopt are untouched.
