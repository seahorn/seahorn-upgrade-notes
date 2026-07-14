# sea-dsa dev17: fresh branch, LLVM-17 port, gates all baseline-locked

[OBS 2026-07-09] **Fresh dev17 cut and ported in one sitting.** The old local
dev17 (2 llvm17 commits on a pre-rebase dev16 lineage, 31 files of real delta
below them) was abandoned in place: a `rebase --onto` attempt conflicted, user
called for a fresh branch instead. `dev17` = `origin/dev16` head `384c63e`
(includes ShadowMemNewPmPass); old work preserved on local `dev17-pre-sync`.
Pushed as NEW branch `seahorn/sea-dsa:dev17` (direct org push user-directed).

[OBS 2026-07-09] **The 16→17 delta for sea-dsa is exactly the two known
items** from durable/llvm-version-api-deltas.md — nothing new appeared:
- `build(llvm17): require LLVM 17` (find_package bump), cherry-picked clean.
- `fix(llvm17): drop removed Optional.h include and add missing <set>` —
  cherry-pick conflicted on 3 of 6 files because dev16's later
  `style(headers)` commit (`023b523`) had already converted them; resolution
  = take HEAD, pick shrank to 3 files. Post-pick sweep: zero
  `llvm/ADT/Optional.h` includes remain anywhere.
Clean Release build against clang+llvm-17.0.6 toolchain (reused the
already-configured `build-dev17`), zero errors.

[OBS 2026-07-09] **Gate results — every failure pre-exists on dev16:**
- **lit suite**: 30/52 pass; the 22 failures are an IDENTICAL set on the
  dev16 binary (same suite, same env). Pre-existing, not a 17 regression.
- **Graph isomorphism (the strong gate)**: all 63 `.mem.dot`/callgraph
  outputs emitted by dev16 vs dev17 binaries are label-isomorphic per the
  repo's own `tests/check_graphs.py both`. 63/63.
- **units_sea_dsa** (doctest, EXCLUDE_FROM_ALL target): 7/8; the failure
  `FirstPrimT.LL_reverse` (FieldTypeTests.cpp:89) fails IDENTICALLY on a
  dev16 baseline built in a throwaway worktree with the LLVM-16 toolchain.
  Opaque-pointer-era behavior: `GetFirstPrimitiveTy` on a self-referential
  struct `{ptr, ptr}` walks into the first field and returns `ptr`, test
  expects the struct itself. Pre-existing since opaque pointers.

[OBS 2026-07-09] **The lit suite was environmentally broken and lying about
failure counts**: `pygraphviz` was missing, so `check_graphs.py` crashed
(exit 2) and 46/52 "failed" on BOTH dev16 and dev17. After
`pip install --user --break-system-packages pygraphviz`, real results
emerged: 22 genuine (pre-existing) failures. Corollary caught in the same
sweep: an earlier grep-for-"isomorphic" pass check matched the word inside
the *traceback* ("in isomorphic", "is_isomorphic") and reported bogus 63/63
OK — verify the checker's success string verbatim before trusting a loop.

[OBS 2026-07-09] **seadsa dot output is nondeterministic run-to-run even for
one binary** (heap addresses as `Node0x…` IDs *and* unstable emission order —
normalizing addresses to first-appearance ordinals still left 40/63
differing; a same-binary two-run control proved nondeterminism). Byte- or
normalized-diff is a dead end for graph comparison; `check_graphs.py`
(networkx labeled isomorphism) is the intended and correct gate.

## Open ends

- The 22 pre-existing lit failures + 1 unit failure are candidate cleanup
  work (stale expectations vs real opaque-ptr regressions — undiagnosed).
- Local dev17 is 2 ahead of origin/dev17; not pushed (as of save).

## See also

- durable/llvm-version-api-deltas.md (16→17 table, now confirmed for sea-dsa)
- durable/multi-llvm-version-branch-structure.md (dev17 branch facts)
- durable/seahorn-build-and-ci-gotchas.md (pygraphviz + dot nondeterminism)
