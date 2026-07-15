# LLVM version API-migration deltas (15→16→17→18)

Concrete source-level API changes hit when porting seahorn/sea-dsa/llvm-seahorn
across LLVM versions. Reference for the next bump. Apply per-line from the error
log, NOT blanket seds (see llvm-seahorn-upstream-rebase-strategy.md for why).

[FACT] **15 → 16** (the bulk, ~115 errors in seahorn):
- `llvm::Optional`→`std::optional`; `.getValue()/.hasValue()`→`.value()/.has_value()`
  (PER-LINE — `ConstantInt::getValue` and seahorn's own Profiler/Evaluate getValue
  are valid and must NOT be rewritten); `llvm::None`/bare `None`→`std::nullopt`.
- `Attribute::InaccessibleMemOnly`→`B.addMemoryAttr(MemoryEffects::inaccessibleMemOnly())`
  (+`#include llvm/Support/ModRef.h`).
- `Intrinsic::flt_rounds`→`Intrinsic::get_rounding`.
- `ObjectSizeOpts::Mode::Exact`→`Mode::ExactSizeFromOffset`.
- `Function::getBasicBlockList` private → `for (bb : F)` / `F->insert(F->end(),BB)`.
- `BasicBlock::getInstList` private → `inst->eraseFromParent()` /
  `NewI->insertBefore(Loc)` / `I->getNextNode()`.
- `peelLoop(...)` gained a trailing `ValueToValueMapTy &VMap`.
- sea-dsa specifics: `AAResultBase` is non-template; `alias()` gained a trailing
  `const Instruction*`; `SimpleAAQueryInfo` needs an `AAResults&`;
  `CFLAliasAnalysisUtils.h` removed (inline `parentFunctionOfValue`).
- Link fixes: (1) llvm-seahorn dev16 removed legacy
  `createSeaInstructionCombiningPass` (new-PM only) → seahorn `createInstCombine()`
  falls back to stock `llvm::createInstructionCombiningPass()` (legacy PM can't
  host the new-PM SeaInstCombinePass; the legacy seapp pipeline loses Avoid*).
  (2) `IntrinsicLowering` (CodeGen, used by BvOpSem2) undefined for bin/seahorn
  until `llvm_config(seahorn ${LLVM_LINK_COMPONENTS})` is UNCOMMENTED in
  `tools/seahorn/CMakeLists.txt` (so LLVM libs link after libseahorn.a).
- CMake: `find_package(LLVM 16)` + `CMAKE_CXX_STANDARD 17` (was 14).

[FACT] **16 → 17** (tiny):
- CONFIRMED for sea-dsa (2026-07-09): the port shipped as exactly the first two
  bullets + the find_package bump — clean build vs 17.0.6, nothing new appeared;
  all gates baseline-locked vs dev16 (see journal 2026-07-09-seadsa-dev17-port).
- `llvm/ADT/Optional.h` REMOVED → replace include with `<optional>`.
- one missing direct `#include <set>` (was transitive) in CompleteCallGraph.hh.
- TargetParser reorg: `llvm/ADT/Triple.h`, `llvm/MC/SubtargetFeature.h`,
  `llvm/Support/Host.h` all → `llvm/TargetParser/`.
- `PassManagerBuilder.cpp` REMOVED upstream (drop it; seaopt's -O# is
  buildSeaPipeline now).
- InstCombine: `UndefMaskElem`→`PoisonMaskElem`, `getMinSignedBits`→
  `getSignificantBits`, `countPopulation`→`popcount`, `countTrailingZeros`→
  `countr_zero`; `+DL` arg on cannotBeNegativeZero/isKnownNeverNaN.
- LoopUnroll: `getUserCost`→`getInstructionCost`; `computeUnrollCount`/
  `computePeelCount` gained `AssumptionCache *AC`; `createSimpleLoopUnrollPass` gone.
- `StandardInstrumentations::registerCallbacks` takes `&MAM` not `&FAM`.
- seahorn additions (port shipped 2026-07-14, PR 588): dropped transitive
  includes — 9 files need direct `llvm/ADT/SmallString.h` (+ StringExtras.h
  for `SplitString`); missing-include errors CASCADE into bogus
  "no viable conversion" overload errors in the same TU — fix includes FIRST,
  re-diagnose after. `APInt::isOneValue/isNullValue`→`isOne/isZero`.
  `Type::getPointerElementType` REMOVED (typed ptrs gone): SimpleMemoryCheck
  dead branch deleted; SimplifyPointerLoops pointer-IV detection bails (see
  loose-ends — was assert-broken under opaque ptrs since 15 anyway).
  `Debugify.registerCallbacks(PIC, MAM)`. PGOOptions gained MemoryProfile+FS
  params. `initializeHardwareLoopsLegacyPass` rename. The sea python driver
  HARDCODES clang/llvm-link version names (py/sea/commands.py) — bump per
  version; build run/bin symlinks clang-N/llvm-link-N to the toolchain.

[FACT] **17 → 18**:
- StringRef `startswith/endswith`→`starts_with/ends_with`.
- `Type::getInt8PtrTy`/`IRBuilder::getInt8PtrTy` removed →
  `PointerType::getUnqual` / `IRBuilder::getPtrTy`.
- `ObjectSizeOffsetVisitor::compute` returns `SizeOffsetAPInt` (`.knownSize()`/`.Size`).
- `TypeSize::getFixedSize`→`getFixedValue`. `llvm::createAAEvalPass` removed.
- `CodeGenOpt::Level`→ scoped `CodeGenOptLevel` enum.
- LoopUnroll: ApproximateLoopSize folded into
  `UnrollCostEstimator(L,TTI,EphValues,BEInsns)`.
- CMake: `find_package(LLVM 18.1 ...)` (NOT 18 — 18 ships only as 18.1.x).
- CONFIRMED for all three repos (2026-07-14, ports merged): seahorn hit ~55
  starts_with/ends_with sites + ~85 getInt8PtrTy sites
  (`PointerType::getUnqual`/`IRBuilder::getPtrTy`), SizeOffsetAPInt/
  SizeOffsetValue (SimpleMemoryCheck, FatBufferBoundsCheck),
  `getConstantRange` explicit `UndefAllowed` arg, PromoteMemcpy dead
  typed-ptr branch deleted, legacy CallGraphPrinter init removed. sea-dsa:
  `createAAEvalPass` removal answered with a new-PM `SeaDsaAA` analysis
  (wrapper symmetry, seadsa registered ahead of BasicAA) instead of stubbing
  --sea-dsa-aa-eval out.
- **POINT-RELEASE SKEW**: InstCombine output depends on the LINKED LLVM libs
  (InstSimplify/ValueTracking), not just the forked sources — 18.1.3 vs
  18.1.8 fold differently. The sea_instcombine corpus and CI must use the
  SAME point release (CI now installs 18.1.8 from apt.llvm.org; noble's
  archive has 18.1.3). Applies to every future version bump.

## Why this matters

A new version port is mostly these tables + the 3-way merge mechanism. 16→17 and
17→18 are small; 15→16 was the big one. InstCombine deltas are absorbed by the
upstream rebase; these are the ones that hit seahorn/sea-dsa's own code.

## See also

- llvm-seahorn-upstream-rebase-strategy.md
- multi-llvm-version-branch-structure.md
