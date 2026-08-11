# sea-dsa new-PM analyses: construct / cache / read / invalidate

How sea-dsa's analyses are shaped under the new PassManager, and how that maps to
the legacy model.

[FACT] sea-dsa exposes three cached new-PM module analyses (LLVM
`AnalysisInfoMixin`) in `sea-dsa/include/seadsa/SeaDsaAnalysis.hh`:
`AllocWrapInfoAnalysis`, `DsaLibFuncInfoAnalysis`, `DsaInfoAnalysis`. The
`ModuleAnalysisManager` computes and caches each per module and shares it with
every `getResult<>` consumer. `DsaInfoAnalysis::run` *composes* the other two by
pulling them back out of the MAM (`MAM.getResult<AllocWrapInfoAnalysis>()` etc.)
rather than rebuilding — so the expensive points-to analysis runs once.

[FACT] The four analysis-manager verbs all existed in the legacy PM, just
pass-centric: **construct** = declare `addRequired<A>()` in `getAnalysisUsage`
(the PM schedules it) then `getAnalysis<A>()`; **cache/share** = the PM caches a
scheduled analysis (ImmutablePass is the extreme — `AllocWrapInfo`/
`DsaLibFuncInfo` were ImmutablePasses, which is why they port to plain local
instances); **read-if-cached** = `getAnalysisIfAvailable<A>()` (≙ new-PM
`getCachedResult`); **invalidate** = the *mutating* pass declares
`setPreservesAll/CFG/addPreserved<>` and the PM drops the rest.

[FACT] The genuinely-new part of the new PM is **first-class, per-result
invalidation decoupled from the producing pass**: each Result implements
`invalidate(IRUnit, PA, Invalidator)` (sea-dsa's do the canonical
`PAC.preserved() || PAC.preservedSet<AllAnalysesOn<Module>>()`), plus robust
cross-IR-unit access via proxies (`ModuleAnalysisManagerFunctionProxy`,
`OuterAnalysisManagerProxy`). This replaced the legacy accident where a *module*
analysis survived into a *function* pipeline only "so long as the first function
pass doesn't invalidate it" — the exact fragile GlobalsAA-stays-alive behavior
dev15's `PassManagerBuilder.cpp` relied on.

[FACT] **A pass's preserved set is a lifetime contract, not just a freshness
hint.** `PreservedAnalyses::none()` frees the cached results *immediately*, so
any object the pass publishes that borrows from a result becomes dangling. This
bit `ShadowMemNewPmPass::run`: it moves the constructed `ShadowMem` into
`*m_keep`, `ShadowMem` holds the `seadsa::GlobalAnalysis` **by reference**, and
that `GlobalAnalysis` is owned by `DsaInfoAnalysis::Result` — so `none()` made
every later `ShadowMem::getDsaAnalysis()` a use-after-free. Fix = return
`PA.preserve<DsaInfoAnalysis>()` on top of `none()` (sea-dsa PR #189, in
`lib/seadsa/ShadowMem.cc`); this also matches the legacy PM, where the
`DsaAnalysis` pass outlived the instrumentation. Rule: if a new-PM pass hands
out anything that borrows from a cached result, it must preserve that analysis.

[FACT] **sea-dsa has two consumer channels, and only one runs through the IR.**
sea-dsa → **seahorn** communicates *through the IR* (shadow-memory
instrumentation) — preserving sea-dsa data structures is explicitly not that
design. sea-dsa → **clam** (linked as a library inside seahorn) communicates
*through the data structures*: clam calls
`seadsa::ContextSensitiveGlobalAnalysis` / `ContextInsensitiveGlobalAnalysis`
directly, with no pass manager on that edge. That second channel is why result
lifetime matters at all, and why preserving `DsaInfoAnalysis` does not
contradict the IR-based design. (caballa/agurfinkel, sea-dsa PR #189 review.)

[FACT] sea-dsa's TLI is threaded as a `seadsa::TargetLibraryInfoGetter`
(`std::function`, in `include/seadsa/TargetLibraryInfoGetter.hh`) everywhere
instead of the legacy `TargetLibraryInfoWrapperPass`. Legacy passes adapt via
`mkTLIGetter(wrapper)`; new-PM analyses source it from the FAM's
`TargetLibraryAnalysis`. → committed in `sea-dsa` `4c19864`.

## Why this matters

When porting a sea-dsa consumer, pick the construct/cache pattern by what the
analysis needs (ImmutablePass → local instance; scheduled analysis → getResult
from MAM). The only thing without a clean legacy analog is invalidation — design
the `invalidate` per Result rather than relying on a mutating pass's preserved
set. And when a pass publishes state (an out-parameter, a `unique_ptr` moved to
a consumer), audit what that state *borrows*: under the legacy PM a scheduled
analysis outlived the pipeline by accident, under the new PM it is freed on the
preserved set you return.

## See also

- seapp-newpm-migration-patterns.md
- ../journal/2026-08/2026-08-11-shadowmem-preserves-dsainfo.md (the UAF that
  established the lifetime-contract fact; clam is the consumer that exposed it)
- ../sea-dsa is at ~/seahorn/seahorn-upgrade/sea-dsa (branch dev16)
