# LLVM-16 llvm.threadlocal.address broke 78 verify-c-common proofs

[OBS 2026-06-27] On dev16, verify-c-common dropped to **150/228** (78
regressions). Root cause is the LLVM-15→16 upgrade, NOT the new-PM migration:
clang-16 emits the new `llvm.threadlocal.address` intrinsic for every
`thread_local` access (clang-15 emits none). SeaHorn's opsem has no visitor for
it, so reads of aws-c-common's thread-local `tl_last_error` (in
`seahorn/lib/error_override.c`) became nondet and flipped error-code proofs
unsat→sat. The intrinsic survives preprocessing into the BMC regardless of seapp
passes.

[OBS 2026-06-27] Fix: `seahorn/lib/Transforms/Scalar/LowerThreadLocalAddress.cc`
— a new-PM FunctionPass `seahorn::LowerThreadLocalAddressPass` that replaces each
`call @llvm.threadlocal.address(@g)` with `@g` (sound for SeaHorn's
single-threaded BMC). Wired first in seapp's pipeline. Result: 228/228.

## How found

Bisected the 78 failures to thread-local reads; confirmed clang-16 vs clang-15
IR diff shows the intrinsic is new in 16. The "not the new-PM work" point matters
— it isolated a clang-version regression from the (separately green) pipeline
migration.

## Distilled to

../../empirical/verify-c-common-dev16-parity-and-timings.md
