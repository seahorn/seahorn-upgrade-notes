# Kickoff: migrate the horn/BMC driver (tools/seahorn) to the new PM

[OBS 2026-07-07] Branch **`dev16-horn-newpm`** created off dev16 (local only).
Task: move `tools/seahorn/seahorn.cpp`'s legacy PassManager (50 pass-adds,
line ~278-481) to the new PM, then delete the ~75 retained legacy pass
classes (the +/- asymmetry flagged in PR 586 review).

## Pipeline map (from the survey)

Split point = `HornifyModule` (seahorn.cpp:406).

**Transform prefix (lines 307-401, ~30 adds) — batch A, mostly mechanical:**
new-PM twins exist in SeaNewPmPasses.hh (43 classes) for nearly everything:
SeaRemoveUnreachableBlocks, PromoteMalloc, PromoteVerifierCalls, LowerIsDeref,
LowerConstantExprs, LowerGvInitializers, NondetInit,
LowerArithWithOverflowIntrinsics, DeadNondetElim, CanReadUndef, NameValues,
MarkInternalInline, BranchSentinel(Eval?)... Stock LLVM ones (Internalize,
GlobalDCE, AlwaysInliner, mem2reg, DCE, LowerSwitch, UnifyFunctionExitNodes,
ModuleInliner) all have new-PM versions. **To check/port:** GeneratePartialFn,
StripLifetime, OneAssumePerBlock, UnifyAssumes, SymbolizeConstantLoopBounds
(seapp batch 8 — twin may exist), SeaAnnotation2Metadata (llvm-seahorn),
seadsa ShadowMem + RemovePtrToInt + StripShadowMem + DsaPrinter (sea-dsa new-PM
faces; RemovePtrToInt/StripShadowMem exist per seapp batch 9).

**Horn/BMC tail (post-406) — batches C/D, the real design work:**
- `HornifyModule` → ModuleAnalysis (9 getAnalysis consumers); result =
  HornClauseDB + expr context. Precedent: sea-dsa DsaInfoAnalysis on the MAM.
- `CutPointGraph` (4 consumers), `GateAnalysisPass` → FunctionAnalyses.
- `HornSolver` → `HornCex` verdict chain; `BmcPass(out, Solve)` ctor args fine.
- TLI via FAM proxy (solved pattern); LazyValueInfo/CallGraph stock.
- Design decision pending: full new-PM tail vs hybrid (new-PM prefix +
  explicit driver orchestration for the run-once tail). Leaning hybrid —
  the tail is linear and side-effecting; a PM adds ceremony, not value.

## Batch plan (each gated on opsem2/opsem, vcc for big ones)

A. prefix via new-PM MPM before the legacy PM (hybrid bridge, like seapp);
B. remaining utility passes incl. ShadowMem boundary;
C. CutPointGraph/GateAnalysis analyses;
D. HornifyModule analysis + tail consumers;
E. delete legacy PM from seahorn.cpp; then the dead-legacy-class sweep
   (audit from 2026-07-07: 9+ classes already have zero consumers).

## Why every increment is testable

opsem/opsem2/vcc all exercise the `seahorn` binary (the horn stage), so each
batch gets the full existing gates — same rhythm as the seapp migration.

## Progress (2026-07-08): transform prefix fully migrated

[OBS] Batches A1-A4 on `dev16-horn-newpm` (6daf6307, 2a538b7f, ab0cc662,
b5ce654e), each gated opsem2 42/42 + opsem 125+1; A2-A4 also vcc 228/228
(391-404s). The ENTIRE transform prefix now runs through the driver MPM;
ported en route with the shared-runImpl pattern: GeneratePartialFn,
StripLifetime, OneAssumePerBlock. Legacy inliner → ModuleInlinerWrapperPass
(gated clean). Legacy PM remaining: SeaBuiltinsWrapper → ShadowMem →
UnifyAssumes? → CanReadUndef → EvalBranchSentinel? → horn tail.
Next: batch B = ShadowMem boundary (sea-dsa new-PM face) + UnifyAssumes port
(needs DT/AC via FAM proxy for its final PromoteMemToReg) + CanReadUndef
(twin exists); then HornifyModule-as-ModuleAnalysis (batch C/D).
