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

## MILESTONE (2026-07-08): mono BMC runs through the new PM (batch C2c)

[OBS] C2c (c899734e): BmcPass refactored onto std::function analysis getters
+ shared processModule; BmcPassNew wires them from MAM/FAM (CanFailAnalysis,
CutPointGraphAnalysis, GateAnalysisWrapper, stock TLI/LVI); opsems built via
the explicit-analyses ctors (BvOpSem v1 mini-seam: its Pass& was ctor-only).
Driver: mono-BMC (no --oll/--mem-dot) = legacy{SeaBuiltins, ShadowMem} →
MPM{UnifyAssumes?, CanReadUndef, EvalBranchSentinel?, NameValues, BmcPassNew}.
Path engine + dump flows fall back to the untouched legacy tail.

[OBS] Gates all green THROUGH THE NEW ROUTE: opsem2 42/42, opsem 125+1,
verify-c-common 228/228. Batch B's ports (UnifyAssumesNewPass etc.) are now
live consumers, closing the boundary finding.

Remaining: CHC tail (HornifyModule-as-analysis, 6 solver-side consumers);
sea-dsa ShadowMem new-PM port (lifts the last legacy pre-step); batch E
(delete legacy tail + dead-legacy-class sweep, ~75 classes).

## CHC tail kickoff (2026-07-08): gates + step 1

[FACT] CHC QA gates: test-simple (10) + test-solve (6), both `sea pf` end to
end (prefix → ShadowMem → HornifyModule → HornSolver). Baseline: simple 9/10,
solve 5/6; the two failures (simple/05_recursive_sat, solve/04_unsat)
REPRODUCE ON THE dev16 BASE — pre-existing, not branch-caused (A/B'd with a
dev16 rebuild). Gate = "pass/fail set unchanged". pred-abs discovers ZERO
tests (empty suite). Follow-up someday: did those two fail on dev15?

[OBS] CHC step 1 (ce47a5a7): the whole LegacyOperationalSemantics family
(UfoOpSem, MemUfoOpSem, FMapUfoOpSem, ClpOpSem) had Pass& ONLY for a ctor
CanFail lookup (same as BvOpSem). Now ctor takes const CanFail*; creators:
HornifyModule passes m_canFail, HornCex pulls CanFail itself. Family is now
Pass-free constructible.

Remaining CHC map (CHC-2): HornifyModule getter-ization (its own pulls:
CanFail ifAvailable, ShadowMem+CompleteCallGraph ifAvailable under
InterProcMem modes, CallGraph @314, per-F CutPointGraph @426 which is a
scheduling-only discarded call) + HornifyModuleWrapper module analysis
(needs ShadowMem handoff — register an external-object analysis capturing
the pointer from the legacy pre-step) + consumers via runImpl(hm,...):
HornWrite(hm), HornSolver(hm) (+its printCex paths getAnalysis sites @254,
305), HornCex(hm, solver-result) — or explicit driver orchestration for the
run-once tail (leaning explicit). Houdini/PredAbs/LoadCrab: legacy fallback
via route predicate, like path-bmc.

## MILESTONE (2026-07-08): CHC tail on the new PM (CHC-2)

[OBS] CHC-2 (710ac614): HornifyModule split (legacy wiring / shared
processModule + cpg/cg getters + setCanFail); HornWrite/HornSolver runImpl;
driver routes plain pf/smt through the shared MPM then EXPLICIT orchestration
(hornify → write → solve as plain objects — the kickoff's "run-once tail
needs no PM" option, realized). Fallback to legacy tail for Cex, Houdini,
PredAbs, Crab, MemDot, --oll, inter-proc-mem (exported hornInterMemEnabled).

[FACT] Standalone-object hazard: Pass-CONDUIT ACCESSORS (methods on a legacy
pass that call getAnalysis for callers, e.g. HornifyModule::getSBI,
HornifyFunction's m_smp ctor fetch) segfault on a standalone object (null
resolver). Grep 'getAnalysis' in the class HEADER, not just runOnModule,
before instantiating any legacy pass outside a PM. getSBI now returns an
owned stateless SeaBuiltinsInfo; the m_smp fetch was write-only and dropped.

[OBS] Gates: simple 9/10 + solve 5/6 IDENTICAL to dev16 baseline through the
new route; opsem2 42/42; opsem 125+1; vcc 228/228. Both pipelines (BMC and
CHC) now run on the new PM. Remaining for batch E: Cex flow, sea-dsa
ShadowMem port, legacy-tail deletion + dead-class sweep.

## Batch E underway (2026-07-08): E1 dead-file deletion; E2 worklist

[OBS] E1 (fb72b50c): -999 lines. Deleted zero-consumer legacy pass files:
ApiAnalysisPass, CanAccessMemory, BufferBoundsCheck trio (NOT the live
FatBufferBoundsCheck), LoopUnhoist, WeakTopologicalOrderPass (pass only —
the header-only WTO used by HornClauseDBWto stays!), StaticTaint. Audit
method: factory CALLS (declarations excluded, namespace-qualified `new`
included) + addRequired/getAnalysis refs across lib/tools/units. Gates:
opsem2 42/42, opsem 125+1, simple/solve baseline.

[OBS] E2 worklist — 37 more zero-consumer LEGACY WRAPPERS inside files
shared with new-PM twins (delete wrapper class + factory + INITIALIZE +
Passes.hh decl; keep runImpl/new-PM code): AbstractMemory, CHAPass,
DebugVerifier, DevirtualizeFunctions, DummyExitBlock, DummyMainFunction,
EnumVerifierCalls, ExternalizeAddressTakenFunctions, ExternalizeFunctions,
GeneratePartialFn, KillUnusedNondet, KillVarArgFn, KleeInternalize,
LowerArithIntrinsics, LowerAssert, LowerCstExpr, LowerGvInitializers,
MarkFnEntry, MarkInternalConstructOrDestructInline, MixedSemantics,
NondetInit, NullCheck, OneAssumePerBlock, PromoteBoolLoads, PromoteMalloc,
PromoteMemcpy, PromoteSeahornAssume, ReduceToReturnPaths, RenameNondet,
SimplifyPointerLoops, SliceFunctions, StripLifetime,
StripUselessDeclarations, SymbolizeConstantLoopBounds, UnfoldLoopForDsa,
WrapMem (+LowerIsDeref-family recheck). Caveats: initializeXPass calls in
seapp.cc/seahorn.cpp Registry blocks must go too (link errors are the
auditor); INITIALIZE_PASS_DEPENDENCY of retained passes may pin some.
After E2: the driver's legacy-tail deletion still awaits HornCex +
sea-dsa ShadowMem ports.
