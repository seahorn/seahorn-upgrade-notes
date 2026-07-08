# IndVarSimplify tied to the bounded (BMC) sea flows

[OBS 2026-07-03] Implemented the "indvars on for BMC paths" decision as a
flag + driver tie-in, replacing the compile-time omission:

- **llvm-seahorn** `tools/opt/NewPMDriver.cpp`: restored dev15's
  `--seaopt-enable-indvar` (same name, **opposite default: off**), gating
  `IndVarSimplifyPass()` in LPM2 of `buildSeaPipeline`. Bare `seaopt -O#`
  behaves exactly as before (loop survives). LoopIdiom stays hard-omitted —
  no flag (scope deliberately reduced to the one pass we care about).
- **seahorn** `py/sea/commands.py`: `Seaopt(enable_indvar=True)` constructor
  param; the bounded aliases (`bpf`, `fpf`, `bnd-fe`, `bnd-smt`, `fpcf`,
  `spf`) get a fresh `BndFeCmds` front-end list with it set. Unbounded flows
  (`fe`, `smt`, `pf`, `ndc`, `smc`) untouched. User-facing `--enable-indvar`
  still forces it anywhere.

[OBS 2026-07-03] First detection attempt FAILED and is worth remembering:
`hasattr(args, 'assert_backedge')` (an option only CutLoops defines) never
fires because `SeqCmd.run` calls each stage's `main(argv)` — **each stage
re-parses its own namespace**; stages never see sibling stages' options. So
run-time "am I in a bounded pipeline" sniffing is impossible in the sea
driver; per-instance constructor config is the mechanism (same pattern as
`Seahorn(solve=True)`). Corollary: the bounded aliases must NOT reuse
`FrontEnd.cmds` (its Seaopt instance is shared with smt/pf — the setting
would leak); they need fresh instances.

[OBS 2026-07-03] Validation, all green:
- flag mechanics: default → affine loop survives (1 phi); `=true` → folded
  (0 phi, `smax`);
- driver: `sea fe` emits no flag; `sea bnd-fe` passes `=true` to **both** its
  seaopt stages (pre-unroll fe-opt is the one that folds; post-cut opt is
  acyclic/no-op);
- suites: opsem2 **42/42** (geometric test 03 passes — non-summarizable +
  gsa), opsem **125 + 1 xfail**, verify-c-common **228/228** (413s wall;
  vcc runs `fpf` = bounded, so indvars-on is exercised for real).

Uncommitted in both repos (commit-when-asked).

## Distilled to

../../durable/seaopt-O-pipeline.md (updated fact) and
../../durable/bmc-opsem-supported-mode.md (consequence now implemented)

## See also

- ../2026-06/2026-06-30-indvars-root-cause.md
- ../2026-06/2026-06-30-unify-assumes-slicing-spurious-sat.md
