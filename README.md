# seahorn-upgrade-notes

Notes to help guide AI in performing
[seahorn](https://github.com/seahorn/seahorn),
[llvm-seahorn](https://github.com/seahorn/llvm-seahorn), and
[sea-dsa](https://github.com/seahorn/sea-dsa) upgrades across LLVM major
versions.

---

## Table of Contents

1. [Upgrade overview](#upgrade-overview)
2. [Branch conventions](#branch-conventions)
3. [Upgrade checklist (generic)](#upgrade-checklist-generic)
4. [LLVM 14 -> 15 upgrade guide](#llvm-14--15-upgrade-guide)
   - [sea-dsa](#sea-dsa-llvm-14--15)
   - [llvm-seahorn](#llvm-seahorn-llvm-14--15)
   - [seahorn](#seahorn-llvm-14--15)
5. [Known limitations and open issues after LLVM 15 port](#known-limitations-and-open-issues-after-llvm-15-port)
6. [How llvm-seahorn source files map to upstream LLVM](#how-llvm-seahorn-source-files-map-to-upstream-llvm)
7. [Testing](#testing)

---

## Upgrade overview

SeaHorn, llvm-seahorn, and sea-dsa are tightly coupled to a specific LLVM major
version.  Each new LLVM major release typically requires

* CMake version guards updated
* C++ API migrations (especially when LLVM deprecates or removes APIs)
* Source file rebases against the new LLVM release for files forked directly
  from the LLVM source tree

The three repos must always be upgraded together and kept on matching `devN`
branches.

---

## Branch conventions

| Repo | Branch name | LLVM version |
|------|------------|--------------|
| seahorn | `devN` / `main` | LLVM N |
| llvm-seahorn | `devN` | LLVM N |
| sea-dsa | `devN` / `main` | LLVM N |

`main` in seahorn and sea-dsa tracks the current stable port.
`llvm-seahorn` has no `main`; always use the explicit `devN` branch.

Clam/crab-llvm follows the same `devN` convention but lags behind;
see [the Clam note](#clam--crab-llvm-is-not-always-ported-in-lock-step).

---

## Upgrade checklist (generic)

When upgrading from LLVM N to LLVM N+1, work in this order:

1. **sea-dsa first** – it has no dependency on llvm-seahorn or seahorn.
2. **llvm-seahorn second** – it depends only on LLVM itself (it is a set of
   forked LLVM passes).
3. **seahorn last** – it depends on both sea-dsa and llvm-seahorn.

For each repo:

- [ ] Create branch `devN+1` from `devN` (or `main`).
- [ ] Update `CMakeLists.txt`: change `find_package(LLVM N)` to
      `find_package(LLVM N+1)`.
- [ ] Update version number (e.g. `SeaHorn_VERSION_MAJOR` in seahorn).
- [ ] Apply all C++ API changes listed in the relevant section below.
- [ ] Re-run the LLVM 3-way merge for any files forked from the LLVM tree (see
      [How llvm-seahorn source files map to upstream LLVM](#how-llvm-seahorn-source-files-map-to-upstream-llvm)).
- [ ] Update the Docker / CI scripts to pull the correct LLVM version.
- [ ] Run all lit / ctest suites and fix failures.
- [ ] Mark tests that exercise features blocked by known limitations as
      `XFAIL` with a reference to the tracking issue.
- [ ] Update the seahorn `CMakeLists.txt` `extra` target to clone the new
      `devN+1` branches of llvm-seahorn and sea-dsa.

---

## LLVM 14 -> 15 upgrade guide

LLVM 15 is the first release to **enable opaque pointers by default**.
This is the dominant change; almost every API migration in this section
is a consequence of typed pointers being gone.

Reference commits:
- seahorn `dev15` branch: https://github.com/seahorn/seahorn/tree/dev15
- llvm-seahorn `dev15` branch: https://github.com/seahorn/llvm-seahorn/tree/dev15
- sea-dsa `dev15` branch: https://github.com/seahorn/sea-dsa/tree/dev15

### sea-dsa (LLVM 14 -> 15)

**Key reference commit:** `8248b6b` ("LLVM 15 Port")
and follow-up commits on the `dev15` branch.

#### CMake

```cmake
# Before (dev14)
find_package (LLVM 14.0 CONFIG)

# After (dev15)
find_package (LLVM 15.0 CONFIG)
```

#### `getPointerElementType()` is gone

LLVM 15 removes the ability to query the pointee type from a pointer type.
Every call to `ptr->getPointerElementType()` is a compile error.
Replace as follows:

| Old pattern | Replacement |
|-------------|-------------|
| `GV->getType()->getElementType()` (GlobalVariable) | `GV->getValueType()` |
| `ptr->getType()->getPointerElementType()` when ptr is an `AllocaInst` | `AI->getAllocatedType()` |
| `retVal->getType()->getPointerElementType()` in `DsaLibFuncInfo` | Pass the type explicitly: `builder.CreateLoad(F.getReturnType(), retVal)` |
| `IsOmnipotentPtr`: checked `Ty->getPointerElementType()->isIntegerTy(8)` | Return `false` conservatively; cannot determine pointee type |
| `FieldType::elemOf()` | Method removed; callers must obtain the element type another way |
| `GetInnermostTypeImpl`: traversed through pointer via `getPointerElementType()` | Stop traversal when a pointer type is encountered |

**Files changed:** `include/seadsa/FieldType.hh`, `lib/seadsa/FieldType.cc`,
`lib/seadsa/Cloner.cc`, `lib/seadsa/DsaLibFuncInfo.cc`,
`lib/seadsa/ShadowMem.cc`

#### `RemovePtrToInt` pattern change

The LLVM 15 IR for the store-of-ptrtoint pattern no longer has an intermediate
`bitcast`.  Instead the store goes directly to a GEP result:

```llvm
; LLVM 14 (typed pointers)
%20 = ptrtoint %struct.Entry* %m to i32
%22 = getelementptr inbounds %struct.Entry, %struct.Entry* %G, i32 0, i32 1
%23 = bitcast %struct.Entry** %22 to i32*
store i32 %20, i32* %23

; LLVM 15 (opaque pointers)
%20 = ptrtoint ptr %m to i32
%22 = getelementptr inbounds %struct.Entry, ptr %G, i32 0, i32 1
store i32 %20, ptr %22
```

Update `RemovePtrToInt.cc` to match on a GEP instead of a bitcast as the store
pointer operand, and simplify the new-store creation.

**File changed:** `lib/seadsa/RemovePtrToInt.cc`

#### Global function-pointer initializer (regression / XFAIL)

`GlobalBuilder::visitGlobalInit()` used to detect when a global constant
was a function pointer by calling `getElementType()->isFunctionTy()`.
This is not possible under opaque pointers.
The code block that linked function-pointer globals into the points-to graph
has been **commented out** in dev15.

**Consequence:** a function pointer set by a global or static initializer is
not linked into the sea-dsa graph.  An indirect call through such a pointer
is left unresolved in the complete call graph.
Tracked as **sea-dsa issue 176**.

**File changed:** `lib/seadsa/DsaLocal.cc` (`GlobalBuilder::visitGlobalInit`)

---

### llvm-seahorn (LLVM 14 -> 15)

llvm-seahorn forks several LLVM passes directly from the LLVM source tree and
applies SeaHorn-specific patches on top.  The upgrade process is a **3-way
merge**: take the upstream LLVM 15 version of each forked file and re-apply the
SeaHorn delta.

**Key reference commits:**
- `fac072f` / `e577b8c` – import LLVM 15 sources
- `1fdc36b` – loops adapt
- `d1b71a0` – instcombine adapt
- `e73ca04` – re-add Avoid* guards lost in merge
- `389a98a` – opt/PassManagerBuilder adapt + link-clash fixes

#### CMake

```cmake
# Before (dev14)
find_package (LLVM 5.0 REQUIRED CONFIG NO_DEFAULT_PATH)

# After (dev15)
cmake_minimum_required(VERSION 3.10.2)
project(Llvm-SeaHorn)
set(CMAKE_CXX_STANDARD 17)   # LLVM 15 headers require C++17
# ...
find_package (LLVM 15 REQUIRED CONFIG)
```

The top-level `CMakeLists.txt` gains a proper `project()` declaration and bumps
the required C++ standard from 14 to 17 (LLVM 15 headers require C++17).

#### InstCombine

The upstream `InstCombineAndOrXor.cpp` was heavily restructured in LLVM 15
(the `foldAndOrOfICmps` region was refactored).  After the 3-way merge:

1. Re-apply the **`AvoidUnsignedICmp`** guard inside
   `foldAndOrOfICmpsUsingRanges` so that signed comparisons are not silently
   turned into unsigned ones.

2. Re-apply the **`AvoidBv`** guard inside the
   `(icmp eq A,0) & (icmp eq B,0)` -> `icmp eq (A|B),0` fold.

3. **Duplicate symbol fix**: `foldAndOrOfICmpEqZeroAndICmp` must be made
   `static` to avoid multiply-defined symbol errors when linking against the
   stock `libLLVMInstCombine`.

4. **Duplicate `cl::opt` fix**: all `instcombine-*` command-line options
   defined in SeaHorn's InstCombine must be renamed with a `sea-` prefix
   (e.g. `sea-instcombine-max-iterations`) because the stock
   `libLLVMInstCombine` registers the same names at runtime.

5. **Remove duplicate helper**: `InstCombiner::getFlippedStrictnessPredicateAndConstant`
   is now provided by the LLVM base class; remove the SeaHorn copy.

**Files changed:** `lib/Transforms/InstCombine/InstCombineAndOrXor.cpp`,
`lib/Transforms/InstCombine/InstCombineCompares.cpp`,
`lib/Transforms/InstCombine/InstructionCombining.cpp`,
`lib/Transforms/InstCombine/InstCombineNegator.cpp`

#### Loops (IndVarSimplify, LoopRotation, LoopUnroll)

| Change | Detail |
|--------|--------|
| `isSafeToExpand(expr, L)` | Now a member of `SCEVExpander`; call `Expander.isSafeToExpand(expr)` |
| `simplifyInstruction(I, DL, TLI, DT, AC)` | Now takes a `SimplifyQuery`; construct one from the available analyses |
| `ApproximateLoopSize` return type | Returns `InstructionCost` (not a plain integer) in LLVM 15 |
| `LoopUnroll.cc` source origin | Forks `lib/Transforms/Scalar/LoopUnrollPass.cpp`, **not** `Utils/LoopUnroll.cpp` |
| Missing transitive includes | Add `ScalarEvolutionExpressions.h`, `LoopInfo.h`, `InstructionSimplify.h` |
| libPolly | `Extensions.cmake` / Polly static lib often absent in Ubuntu packages; drop the Polly extension from the opt CMakeLists |

**Files changed:** `lib/Transforms/Loops/IndVarSimplify.cc`,
`lib/Transforms/Loops/LoopRotation.cc`,
`lib/Transforms/Loops/LoopUnroll.cc`,
`lib/Transforms/Loops/LoopUnrollPass.cc`,
`lib/Transforms/Loops/SeaSCEVUtils.cc`

#### PassManagerBuilder

```cpp
// Before: global variables (clash with stock libLLVMIPO / seaopt)
extern cl::opt<bool> EnableGVNHoist;

// After: static, renamed
static cl::opt<bool> SeaOptEnableGVNHoist("sea-opt-enable-gvn-hoist", ...);
```

Make `EnableGVNHoist`, `EnableGVNSink`, `EnableHotColdSplit`, and
`PreInlineThreshold` **static** and rename them with a `sea-opt-` prefix.
Drop the `LLVMPassManagerBuilder` C API (removed in LLVM 15).

**File changed:** `lib/Transforms/IPO/PassManagerBuilder.cpp`

#### `seaopt` / opt tool

1. The old `createWholeProgramDevirtPass()` API was removed in LLVM 15.
   Drop its use from the `opt` tool (SeaHorn's own devirt pass handles
   this).

2. Plugin loading API in `tools/opt/NewPMDriver.cpp` changed between 14 and 15;
   apply the LLVM 15 calling convention.

3. `PassPrinters` (removed upstream in LLVM 15) are kept in SeaHorn's fork.

**Files changed:** `tools/opt/opt.cpp`, `tools/opt/NewPMDriver.cpp`

#### `InstNondet` / `FakeLatchExit`

`replaceFnBodyWithND` must be guarded for both opaque pointers (no pointee
type on the argument) and void-return functions (do not emit a return value for
`void` functions):

```cpp
// Before: assumed typed pointer
auto *Ty = F.getReturnType()->getPointerElementType();

// After: use the return type directly
auto *Ty = F.getReturnType();
if (Ty->isVoidTy()) { builder.CreateRetVoid(); return; }
```

**Files changed:** `lib/Transforms/Loops/FakeLatchExit.cc`,
`lib/Transforms/InstNondet/`

---

### seahorn (LLVM 14 -> 15)

**Key reference commits** (all on the `dev15` branch of seahorn):

| Commit message | What it fixes |
|----------------|---------------|
| `build(llvm15): configure seahorn for llvm 15` | CMake + Python toolchain |
| `fix(llvm15): add missing includes` | Headers no longer transitively included |
| `fix(llvm15): use getValueType for globals/unique scalars` | Opaque pointer migration |
| `fix(llvm15): use AllocaInst::getAllocatedType` | Opaque pointer migration |
| `fix(llvm15): use getAlign().value() for load/store alignment` | Removed API |
| `fix(llvm15): use getFreedOperand instead of removed isFreeCall` | Removed API |
| `fix(llvm15): key devirt alias sets by function type` | Opaque pointer migration |
| `fix(llvm15): guard ClassHierarchyAnalysis devirt under opaque pointers` | Opaque pointer migration (partial workaround) |
| `fix(llvm15): port SimpleMemoryCheck to opaque pointers` | Opaque pointer migration |
| `fix(llvm15): port counterexample generators to opaque pointers` | Opaque pointer migration |
| `build(llvm15): guard clam/crab code behind HAVE_CLAM` | Clam not yet ported |
| `build(llvm15): add WITH_CLAM option; build CI image without Clam` | Build without Clam |
| `feat(scalar): gate struct-memcpy lowering behind --horn-promote-memcpy` | Opaque pointer memcpy |

#### CMake

```cmake
# 1. Bump version
set(SeaHorn_VERSION_MAJOR 15)

# 2. Subproject branches
add_custom_target(llvm-seahorn-git
  ${GIT_EXECUTABLE} clone ${SEAHORN_LLVM_REPO} ... -b dev15)
add_custom_target(sea-dsa-git
  ${GIT_EXECUTABLE} clone ${SEA_DSA_REPO} ... -b dev15)

# 3. Ubuntu 22.04 LLVM 15 package exposes zstd targets; pull them first
find_package(zstd QUIET)
find_package(LLVM 15 CONFIG)
```

#### Missing headers (LLVM 15 stopped transitively including these)

Add explicit `#include` directives where missing:

| Header | Files that need it added |
|--------|--------------------------|
| `llvm/IR/Constants.h` | `BvOpSem.cc`, `BvOpSem2.cc` |
| `llvm/Analysis/LoopInfo.h` | `BackedgeCutter.cc`, `CutLoops.cc`, `LoopPeeler.cc` |
| `llvm/Support/CommandLine.h` | `PromoteVerifierCalls.cc` |
| `llvm/IR/InstrTypes.h` or `<list>` | Various files using `CallBase` |
| `llvm/Analysis/MemoryBuiltins.h` | `MarkInternalSpecialFunctions.cc` |
| `llvm/Support/Houdini.hh` (internal) | `Houdini.hh`, `ShadowMemDsa.hh` |

#### `getPointerElementType()` migration

| Old call | File | Replacement |
|----------|------|-------------|
| `alloca->getType()->getElementType()` | `BvOpSem2.cc`, `BvOpSem2Allocators.cc` | `AI->getAllocatedType()` |
| `GV->getType()->getElementType()` | `KleeInternalize.cc`, `LowerGvInitializers.cc`, `MemSimulator.cc`, `BvOpSem.cc`, `BvOpSem2.cc` | `GV->getValueType()` |
| `ptrOp->getType()->getPointerElementType()` in store SMC | `SimpleMemoryCheck.cc` | Use stored value type: `SI->getValueOperand()->getType()` |
| `ptr->getType()->getPointerElementType()` for CEX return size | `BvOpSem*.cc` cex generators | Return size 0 (unsized fallback) for pointer returns |
| `fnPtr->getType()->getPointerElementType()` for devirt alias sets | `DevirtFunctions.cc` | `CB.getFunctionType()` / `F.getFunctionType()` |
| `thisPtr->getType()->getPointerElementType()` for CHA class type | `DevirtFunctions.cc` | Guard with `isOpaquePointerTy()`; skip CHA resolution |

#### Removed LLVM APIs

| Removed API | Replacement |
|-------------|-------------|
| `Instruction::getAlignment()` | `getAlign().value()` |
| `llvm::isFreeCall(CS, TLI)` | `llvm::getFreedOperand(CB, TLI)` from `MemoryBuiltins.h` |
| `llvm::createWholeProgramDevirtPass()` | Removed; SeaHorn's own devirt pass (`DevirtFunctions`) is used instead |

#### Clam / Crab not yet ported to LLVM 15

Wrap all Clam/Crab usage in `#ifdef HAVE_CLAM` guards:

```cpp
// lib/Analysis/CrabAnalysis.cc
#ifdef HAVE_CLAM
  // ... all crab analysis code
#endif

// lib/seahorn/BvOpSem2.cc, BvOpSem2Allocators.cc
#ifdef HAVE_CLAM
  // crab range inference members and calls
#endif
```

Add a CMake option to opt out entirely:

```cmake
option(WITH_CLAM "Build with Clam/Crab support" ON)
if (WITH_CLAM AND IS_DIRECTORY ${CMAKE_SOURCE_DIR}/clam ...)
  add_subdirectory(${CMAKE_SOURCE_DIR}/clam)
  set(HAVE_CLAM TRUE)
elseif(WITH_CLAM)
  message(WARNING "No Clam found ...")
else()
  message(STATUS "Clam/Crab support disabled (WITH_CLAM=OFF)")
endif()
```

Build the CI image with `-DWITH_CLAM=OFF` until Clam is ported.

#### CHA devirt under opaque pointers (partial fix)

`DevirtFunctions.cc` `resolveVirtualCall` recovered the `this` class type via
`getPointerElementType()`.  Under LLVM 15 this crashes.  Guard the class-type
path:

```cpp
// In resolveVirtualCall / matchVirtualSignature:
auto *CallTy = CB.getFunctionType();  // use this instead
// guard the class-type recovery path:
if (!ThisArg->getType()->isOpaquePointerTy()) {
  // old typed-pointer path (dead on LLVM 15)
  ...
} else {
  // under opaque pointers we cannot recover the class type; return false
  return false;
}
```

CHA resolves **no** virtual calls on LLVM 15 until the devirt is reworked to
use vtable structure metadata.  Tracked as **seahorn issue 581**.

#### `PromoteMemcpy` (struct memcpy lowering)

Under opaque pointers, lowering `memcpy` of a whole struct to field-wise
loads/stores requires recovering the struct type from a GEP that indexes the
exact pointer passed to `memcpy` (the only remaining type hint).  This
lowering is gated behind a new flag `--horn-promote-memcpy` (default off;
`verify-c-common` opts in).

The `sea` Python wrapper forwards `--horn-promote-memcpy` to `seapp` and drops
it from the seahorn-stage argument list.

**File changed:** `lib/Transforms/Scalar/PromoteMemcpy.cc`, `py/sea/commands.py`

#### Python toolchain

```python
# Before (dev14)
which(['clang-mp-14', 'clang-14', 'clang'])
which(['llvm-link-mp-14', 'llvm-link-14', 'llvm-link'])

# After (dev15)
which(['clang-mp-15', 'clang-15', 'clang'])
which(['llvm-link-mp-15', 'llvm-link-15', 'llvm-link'])
```

**File changed:** `py/sea/commands.py`

---

## Known limitations and open issues after LLVM 15 port

### Clam / crab-llvm is not always ported in lock-step

Clam (crab-llvm) is the abstract-interpretation back-end.  It is a large,
independent project that may lag behind the main LLVM version.  SeaHorn's
LLVM 15 port (`dev15`) was shipped **without Clam**.

- Build seahorn with `-DWITH_CLAM=OFF` until Clam's `dev15` branch exists.
- The following features are unavailable without Clam:
  - Abstract-interpretation invariant inference (`--crab`)
  - Path-based BMC (`--bmc=path`)
  - Crab range injection into Spacer

### CHA virtual-call devirtualization (seahorn issue 581)

Class Hierarchy Analysis cannot recover the `this` class type under opaque
pointers.  All CHA virtual-call resolutions are skipped on LLVM 15.
Tests `devirt_cha_*.cpp` are marked `XFAIL`.

Resolution requires reworking CHA to use LLVM's vtable structure metadata
instead of `getPointerElementType`.

### sea-dsa global function-pointer initializer (sea-dsa issue 176)

A function pointer set by a global or `static` initializer is not linked into
the sea-dsa points-to graph on LLVM 15.  Indirect calls through such pointers
are left unresolved in the complete call graph.
Test `devirt_08.c` (sea-dsa devirt path) is marked `XFAIL`.

Resolution requires inferring function-pointer types from uses (e.g., checking
whether a pointer is ever called as a function) rather than from the pointee
type.

### sea-dsa precision loss for omnipotent pointers

`IsOmnipotentPtr` now always returns `false` because the pointee type is
unavailable.  This may reduce sea-dsa precision for `i8*`-heavy code (e.g.,
`void*` in C programs).

---

## How llvm-seahorn source files map to upstream LLVM

llvm-seahorn forks files directly from the LLVM source tree and applies
SeaHorn-specific patches.  For each upgrade, retrieve the corresponding LLVM
N+1 source file and perform a 3-way merge (common ancestor = LLVM N version
used in the previous devN branch):

| llvm-seahorn file | Upstream LLVM file |
|-------------------|--------------------|
| `lib/Transforms/InstCombine/InstCombineAndOrXor.cpp` | `llvm/lib/Transforms/InstCombine/InstCombineAndOrXor.cpp` |
| `lib/Transforms/InstCombine/InstCombineCompares.cpp` | `llvm/lib/Transforms/InstCombine/InstCombineCompares.cpp` |
| `lib/Transforms/InstCombine/InstructionCombining.cpp` | `llvm/lib/Transforms/InstCombine/InstructionCombining.cpp` |
| `lib/Transforms/InstCombine/InstCombineNegator.cpp` | `llvm/lib/Transforms/InstCombine/InstCombineNegator.cpp` |
| `lib/Transforms/Loops/IndVarSimplify.cc` | `llvm/lib/Transforms/Scalar/IndVarSimplify.cpp` |
| `lib/Transforms/Loops/LoopRotation.cc` | `llvm/lib/Transforms/Scalar/LoopRotate.cpp` |
| `lib/Transforms/Loops/LoopUnroll.cc` | `llvm/lib/Transforms/Scalar/LoopUnrollPass.cpp` |
| `lib/Transforms/IPO/PassManagerBuilder.cpp` | `llvm/lib/Transforms/IPO/PassManagerBuilder.cpp` |
| `tools/opt/opt.cpp` | `llvm/tools/opt/opt.cpp` |
| `tools/opt/NewPMDriver.cpp` | `llvm/tools/opt/NewPMDriver.cpp` |

**Merge strategy:**

```
git diff llvm-N llvm-(N+1) -- <upstream file>   # upstream delta
git diff devN-base devN-head -- <seahorn fork>  # SeaHorn delta
```

Apply the upstream delta to the SeaHorn fork, resolving conflicts by
preserving SeaHorn intent (e.g., `AvoidUnsignedICmp`, `AvoidBv` guards) on
top of the new LLVM structure.

Common merge pitfalls:
- SeaHorn guards inserted into the middle of a function may be displaced when
  upstream restructures that function; verify each guard is still in the right
  place after the merge.
- New `cl::opt` variables added by LLVM upstream may clash at runtime with
  the stock `libLLVMInstCombine`; make SeaHorn additions `static` and rename
  with a `sea-` prefix.
- New upstream helper functions may duplicate SeaHorn additions; remove the
  SeaHorn copy.

---

## Testing

### seahorn

```bash
cd build
cmake --build . --target install    # must install before running tests
cmake --build . --target test-all   # full suite
# or individual suites:
cmake --build . --target test-opsem
cmake --build . --target test-opsem2
cmake --build . --target test-devirt
```

Tests blocked by known LLVM 15 limitations are marked `XFAIL` with a comment
referencing the tracking issue.

### llvm-seahorn

```bash
cd build
cmake --build . --target install
lit test/sea_transforms/         # sea_transforms corpus
```

The sea_transforms corpus includes:
- `pipeline_o2.ll` – full SeaHorn `-O2` pipeline smoke test (drives
  sea-instcombine and sea-loops)
- Avoid* corpus – non-vacuity guard for SeaHorn instcombine flags

### sea-dsa

```bash
cd build
cmake --build . --target install
cmake --build . --target test      # lit tests
cmake --build . --target units     # unit tests
```
