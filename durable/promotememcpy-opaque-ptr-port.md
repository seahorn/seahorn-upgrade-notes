# PromoteMalloc / PromoteMemcpy under opaque pointers

How seapp's two `@main` FunctionPasses were ported off `getPointerElementType()`,
and why PromoteMemcpy is a performance (not correctness) pass. Directly relevant
to the seaopt -O# inliner finding — these are the struct field-copies the inliner
makes scalarizable.

[FACT] Under LLVM-15+ opaque pointers, `Type::getPointerElementType()` aborts.
Two seapp passes crashed on it (212/228 SIGSEGV originally):
- `lib/Transforms/Scalar/PromoteMalloc.cc` — fixed by allocating
  `i8 × CI.getOperand(0)` directly (`Type::getInt8Ty`); malloc/new always
  returned `i8*`, so the element type was always `i8`.
- `lib/Transforms/Scalar/PromoteMemcpy.cc` — `simplifyMemCpy` rewritten to
  recover the copied `StructType` via `recoverStructType()`, then emit a recursive
  typed field-wise copy via `emitFieldwiseCopy()` using explicit GEP source-element
  types.

[FACT] PromoteMemcpy is NOT needed for correctness — `BvOpSem2::executeMemCpyInst`
handles a raw memcpy, so the pass bails safely when the type can't be recovered.
It is a big PERFORMANCE win: disabling it makes memcpy-heavy jobs 30–100× slower
(`byte_buf_eq` 2.3s → >2000s timeout). The struct type buys size + field layout +
per-field pointer-ness (emitting `load ptr` vs `load iN`, for easier alias
analysis); the copy itself only needs the byte size.

[FACT] `recoverStructType` was reduced to **Tier-1 only** (GEP on the exact
memcpy SSA pointer; else bail) because the size-only and slot-match fallbacks were
unsound (a different equal-width struct could be picked, mistyping pointer
fields). The whole pass is behind `--horn-promote-memcpy` (default OFF);
verify-c-common turns it on via `seahorn/sea_base.yaml`. Flag threading needs both
the Seapp forward AND a Seahorn-stage swallow (see
seahorn-build-and-ci-gotchas.md, sea fpf routing).

## Why this matters

These field-copies are exactly what `seaopt -O#`'s CGSCC inliner + SROA later
scalarize (see seaopt-O-pipeline.md). Understanding the producer explains why the
inliner is load-bearing downstream, and why the pass must stay sound-only.

## See also

- seaopt-O-pipeline.md
- seahorn-build-and-ci-gotchas.md
