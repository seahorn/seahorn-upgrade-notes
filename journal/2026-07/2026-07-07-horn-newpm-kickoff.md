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

## Progress (2026-07-08, cont.): batches B + C1

[OBS] Batch B (29c07677): UnifyAssumes ported with LAZY DT/AC getters (legacy
fetched them AFTER mutating, for the final PromoteMemToReg — pre-fetching via
FAM would hand mem2reg a stale domtree); EvalBranchSentinel ported (function
wrapper, explicit SBI). vcc 228/228.

[FACT] The ShadowMem slice CANNOT interleave out of the tail legacy PM:
BmcPass and HornifyModule addRequired<ShadowMemPass>, so ShadowMem must be
scheduled in the same legacy manager as its consumers (a sandwich attempt
crashed legacy schedulePass; reverted, re-gated green). The whole
ShadowMem..EvalBranchSentinel slice moves only when the tail consumes shadow
memory via an analysis.

[OBS] Batch C1 (f4c66797): first seahorn new-PM analyses — CanFailAnalysis
(CallGraph from MAM), TopologicalOrderAnalysis, CutPointGraphAnalysis
(composes over TopologicalOrderAnalysis via FAM), DsaInfoAnalysis idiom
(Result = unique_ptr<legacy state-holder> + runImpl). KEY: BmcPass does NOT
consume HornifyModule (only HornCex/HornSolver/HornWrite/Houdini/LoadCrab/
PredicateAbstraction do, all CHC-side) — so the BMC tail needs only these
three + stock FAM analyses + NameValues + ShadowMem + optional GateAnalysis.
Next (C2): BmcPassNew consuming via MAM, ShadowMem object handed from the
legacy run (keep raw pass ptr), then the BMC path is fully new-PM.

## Progress (2026-07-08, cont.): batch C2a + C2b — opsem seam + full analysis set

[OBS] C2a (21d858c7): retired the Pass& seam in Bv2OpSem. Blast radius was
tiny: 5 m_pass sites — ctor pulls (CanFail ifAvailable + a WRITE-ONLY
m_tliWrapper, deleted), per-function LVI (now a std::function getter; the
LVI cache stores LazyValueInfo* not the wrapper), clam-gated ShadowMem/TLI
(compiled out on dev16; nullable Pass* + assert). Legacy ctor = adapter; new
ctor takes CanFail* + LVI getter → FAM-ready. Gated opsem2/opsem/vcc 228/228.

[OBS] C2b (1bed7079): runImpl in ControlDependenceAnalysisPass + GateAnalysisPass;
ControlDependenceAnalysisWrapper + GateAnalysisWrapper module analyses (FAM
proxy for per-F DT/PDT). The new-PM BmcPass analysis set is now COMPLETE:
CanFail/TopoOrder/CutPointGraph/CDA/GateAnalysis + stock TLI/LVI/DT.

[FACT] BmcPass consumption map (for C2c): GateAnalysis (main, if HornGSA),
CutPointGraph(F), CanFail (ifAvailable → opsem), TLI(F) only for cex-gen,
ShadowMem OBJECT only in the clam-stubbed path engine (dev16: dead) — but
ShadowMem INSTRUMENTATION must still run before BMC (legacy pre-step is fine;
BmcPassNew need not require the pass). Next (C2c): BmcPass::runImpl over
getters + BmcPassNew + driver BMC route = legacy{SeaBuiltins,ShadowMem} →
MPM{UnifyAssumes?, CanReadUndef, EvalBranchSentinel?, NameValues, BmcPassNew}.
