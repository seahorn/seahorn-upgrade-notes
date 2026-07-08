# verify-c-common dev16 parity + timings

**Verified against:** seahorn dev16 + llvm-seahorn `fa74927` + sea-dsa `4c19864`,
LLVM 16.0.4 prebuilt toolchain
**Last verified:** 2026-07-07 (228/228 in 405s wall, clang-16 front end via the
fixed sea driver — earlier runs were silently front-ended by host clang-15 —
with indvars-on bounded flows; consistent with the 2026-07-03 413s run)
**Status:** wide-eval-confirmed (full 228-test suite, exit 0)

[EMP] dev16 verify-c-common is at **228/228** — full parity with the dev15
baseline. The full suite runs in ~420s wall (`array_list_swap` dominates at
~419s; that test is inherently slow, same on dev15). Run from
`verify-c-common/build-dev16` with the real ctest, `-j6 --timeout 600`, with the
LLVM-16 toolchain bin + `seahorn/build-dev16/run/bin` on PATH.

[EMP] Per-job timings, dev16 (after the seaopt -O# fix) vs dev15 — back to parity:

| job | dev16 before fix | dev16 now | dev15 |
|---|---:|---:|---:|
| array_list_push_back  | 88s | 2.5s | 2.3s |
| array_list_push_front | 90s | 2.5s | 2.2s |
| linked_list_swap      | 25s | 3.6s | 2.7s |
| string_new_from_string| 27s | 7.0s | 6.7s |
| array_list_swap       | ~344s | ~419s | ~420s |

The push_back/push_front ~40× slowdown was the seaopt -O# pipeline missing the
CGSCC inliner — see ../durable/seaopt-O-pipeline.md.

[EMP] Getting from 150/228 → 228/228 on dev16 required fixing the LLVM-16
`llvm.threadlocal.address` regression (NOT the new-PM work) — see
../journal/2026-06/2026-06-27-threadlocal-address-regression.md. Before that fix
dev16 gave 150/228 (78 regressions).

## Re-verify before relying

This is version-bound. Re-run the suite after any change to `buildSeaPipeline`,
SeaInstCombine, the seapp pipeline, or opsem. The timings especially are a
regression tripwire: if push_back creeps back toward ~88s, the inliner or scalar
cleanup dropped out of the -O# pipeline.

## See also

- ../durable/seaopt-O-pipeline.md
- ../durable/promotememcpy-opaque-ptr-port.md
