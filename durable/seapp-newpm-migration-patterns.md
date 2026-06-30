# seapp new-PM migration: the seven porting patterns

seapp's entire preprocessing pipeline was migrated off the legacy PassManager to
the new PM on dev16, and the legacy bridge deleted (~50 passes across 3 repos).

[FACT] `SeaPassManagerWrapper` in `seahorn/tools/seapp/seapp.cc` now holds only a
`ModulePassManager` + ordered steps: module passes added directly, function
passes via `createModuleToFunctionPassAdaptor`, SeaInstCombine as a flushed step.
No `m_legacy` / `flushLegacy` / `legacy::PassManager`. `--verify-after-all` is a
native `llvm::VerifierPass` after each pass. Each ported pass keeps its legacy
pass; the new-PM class is declared in `include/seahorn/SeaNewPmPasses.hh` (or
`SeaNewPmLoopPasses.hh`) and defined alongside the legacy one.

[FACT] The seven porting patterns (pick by inspecting each pass's `getAnalysis`):
1. **No-dep** → instantiation trick: new-PM `run()` does `LegacyClass().runOnX(...)`.
2. **Analysis-dep** → split a `runImpl(...)` taking the analyses; legacy supplies
   `getAnalysis<>`, new-PM supplies from FAM proxy / `LoopStandardAnalysisResults`.
3. **Stateless helper** (e.g. SeaBuiltinsInfo) → local instance.
4. **Optional CallGraph** (guarded uses) → drop (`nullptr`); new PM recomputes.
5. **Per-function/lazy TLI** → `function_ref<TLI(const Function&)>` member.
6. **sea-dsa-coupled** (Devirt, CrabLowerIsDeref, SimpleMemoryCheck) → build LOCAL
   `AllocWrapInfo(&tliWP)`/`DsaLibFuncInfo`/`CallGraph`/`LocalDsaInfo` with a local
   `TargetLibraryInfoWrapperPass{Triple(M.getTargetTriple())}` — the ImmutablePasses
   are constructible, so no deep analysis-manager port needed.
7. **Legacy LoopPass** → new-PM loop pass + `createFunctionToLoopPassAdaptor`.

[FACT] LLVM 16 has no new-PM `StripDeadDebugInfo`, so seahorn reimplements
`SeaStripDeadDebugInfoPass`. CanFail gets `runImpl(M, CallGraph&)`; MixedSemantics
uses local CanFail+SBI.

## Why this matters

These patterns are the reusable recipe for the dev17/dev18 ports and for any
remaining legacy pass. Pattern 6 (local ImmutablePass instances) is the escape
hatch that avoided a full sea-dsa analysis-manager port in seapp.

## See also

- sea-dsa-newpm-analyses.md
- seaopt-O-pipeline.md
- llvm-seahorn-upstream-rebase-strategy.md
