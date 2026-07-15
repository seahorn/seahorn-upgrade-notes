# The yices bridge: const-arrays, lambdas, and how to debug it

What the seahorn↔yices2 solver bridge can and cannot encode, learned while
fixing the tracking-mem crash (PR 592, 2026-07-15).

[FACT] **yices contexts reject lambda terms**, and `yices_lambda` is the only
way the term API can express a const-array (`MarshalYices.cc`, cites
yices2#271). The failure is positional, not syntactic:
- `select(const-array v, i)` — SAFE: yices beta-reduces it at term build.
- const-array under `yices_update` (a store) or as a naked array value in an
  assertion — FATAL: `yices_assert_formula failed: the context does not
  support lambda terms` via `report_fatal_error` (process aborts).

[FACT] **Where const-arrays come from in BMC formulas**: the array memory
repr's `FilledMemory` (`OpSemMemRepr.hh`) — used by tracking-mem
(`--horn-bv2-tracking-mem`) to ZERO-INITIALIZE its five metadata memories.
Reads of metadata at symbolic addresses yield
`select(store/ite...(const-array(0)), q)` shapes. Since opaque pointers
(LLVM 15) these survive simplification (`--horn-bv2-simplify` does not push
selects through stores), so they reach the solver. z3 accepts lambdas — only
yices configs die. `--horn-bv2-lambdas` is IRRELEVANT here (it selects the
memory representation, not the zero-init or the marshalling).

[FACT] **The fix in place**: `yices_solver_impl::add` rewrites before
encoding — selects whose store/ite skeleton bottoms out in a const-array are
expanded (select-over-store → index-equality ite, select-over-ite
distributes, const leaf → default value); DAG-memoized; ordinary havoc'd
memories untouched. If a const-array survives in any OTHER position, yices
still aborts — extend the rewrite, and use the debug aid below to see the
shape.

[FACT] **Debug aid**: `SEA_DEBUG_DUMP_CONST_ARRAY=1` makes the yices bridge
print every assertion still containing a const-array after the rewrite.
Alternative provenance tool: `gdb -batch -ex "break yices_lambda" -ex run
-ex bt` on the seahorn invocation.

[FACT] **Regression coverage**: `units/units_yices2.cpp`
(yices2-const-array-store-select.test) checks verdicts for the store and ite
shapes. Units run in CI automatically — `docker/build_seahorn.sh` builds and
EXECUTES units_z3/units_yices2/units_type_checker in the build step.

[FACT] **Pipeline-level repro needs the full fat-pointer vcc shape**: simple
opsem2-style C programs cannot reproduce (concrete/foldable metadata
addresses; same-pointer select-over-store cancels structurally). Don't waste
time synthesizing small .c repros for solver-bridge bugs — unit-test at the
Expr/solver level instead.

## Why this matters

Any future encoding change that lets a const-array reach the yices bridge in
a new position (array equality, nested ite, memcpy fallback) will abort the
solver, not return unknown. The rewrite + dump + unit test triangle localizes
such failures in minutes instead of a day of pipeline bisecting.

## See also

- journal/2026-07/2026-07-15-yices-constarray-fix.md (the debugging trail)
- durable/llvm-version-api-deltas.md (why the shapes appeared at LLVM 15)
