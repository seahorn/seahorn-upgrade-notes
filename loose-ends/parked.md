# Parked investigations

Backlog of started-but-not-pursued threads. Five-field format per entry.

(Resolved 2026-06-30: "why does dev15 keep the loop but dev16 fold it" — root cause
was a lost `--seaopt-enable-indvar=false` flag, not a pass-behavior difference;
LLVM-15 and LLVM-16 IndVarSimplify fold identically. Captured in
durable/seaopt-O-pipeline.md + journal/2026-06/2026-06-30-indvars-root-cause.md.)

(Resolved 2026-07-03: llvm-seahorn origin/dev16 — user directed the push;
force-with-lease of local dev16 (`8e7e6c6`: squash `fa74927` + realign/indvar
flag) over origin's `7748ee1`, exactly the action the parked note anticipated
(NOT reset-to-dev15). Verified first: `7748ee1`'s content fully contained in
the squash (NewPMDriver superseded; README byte-identical). local == origin ==
`8e7e6c6`. Note: `priyasiddharth/dev16` fork is now behind origin.)

(Resolved 2026-07-03: "enable IndVarSimplify for BMC flows" — implemented as
`--seaopt-enable-indvar` in seaopt (default off, gates LPM2) +
`Seaopt(enable_indvar=True)` on the bounded sea aliases
(`bpf`/`fpf`/`bnd-*`/`fpcf`/`spf`) via a dedicated `BndFeCmds` list. Validated:
opsem2 42/42, opsem 125, vcc 228/228 (vcc runs fpf → indvars exercised).
Uncommitted. Captured in
journal/2026-07/2026-07-03-indvar-tied-to-bounded-flows.md +
durable/seaopt-O-pipeline.md.)

## verify-c-common cex+y2: 13 fat-mem tests die on yices lambda terms
**Status:** FIXED 2026-07-15 (same session, user chose core fix over
   blacklist): seahorn commit `fix(smt): expand const-array selects for yices
   instead of lambdas` on fork branch dev18-yices-constarray, PR pending.
   Root cause: yices marshals const-array as yices_lambda (yices2#271) but
   contexts reject lambdas; tracking-mem zero-inits metadata with
   const-arrays, and since opaque ptrs the select(store/ite...(const-array))
   shapes survive simplification into the asserted formula. Fix = pre-encode
   rewrite in yices_solver_impl::add pushing selects through store/ite
   skeletons that bottom out in const-array (select-over-store axiom; DAG
   memoized; havoc'd memories untouched). Gates: 13/13 fixed, cex-y2 217/217,
   the 11 HISTORICALLY BLACKLISTED same-cause tests now 11/11 (blacklist can
   shrink to empty once a fixed nightly publishes), y2 228/228, opsem2 42/42,
   opsem 125+1. Earlier verdict (kept for the record): pre-existing since
   dev15, NOT a dev18 regression. Bisect by line (same test, same cex-y2 flags):
   dev14 image 13/13 PASS; dev15, dev16, dev17, dev18 local builds ALL fail
   with the identical yices lambda error, crashing at ENCODE time
   (SolverBmcEngine::encode) — the lambda is emitted by the opsem encoding,
   solver version irrelevant. Introduced in the dev14->dev15 port
   (LLVM 15 / opaque-pointer era). Prime suspect: symbolic memcpy under
   opaque pointers — sizes that were concrete under typed pointers stay
   symbolic and the encoding falls back to a lambda past
   --horn-array-sym-memcpy-unroll-count, despite --horn-bv2-lambdas=false
   (which gates memory representation, not this fallback). Unblock for
   PR #146: add the 13 tests to blacklist.cex-y2.txt (documented known
   failure) + file an issue.
**Context:** on verify-c-common PR #146 (CI image moved to the dev18 nightly),
   the re-enabled `--cex --horn-bmc-solver=smt-y2` matrix config fails 13
   tests — ALL `*2_unsat_test` (fat/extra-widemem/tracking-mem variants) —
   with `LLVM ERROR: yices_solver_impl::add: yices_assert_formula failed:
   the context does not support lambda terms`, despite
   `--horn-bv2-lambdas=false`. The non-cex y2 config passes 228/228, so the
   lambda term enters via the --cex extras (hexdump/tracking-mem path).
   CRITICAL CONFOUND: this CI job had been DISABLED and was only just
   re-enabled — the cex-y2 blacklist may simply be stale, i.e. pre-existing
   failure, not a dev18 regression.
**To resume:** (1) read the dev14-image baseline verdict below; (2) if
   pre-existing → extend blacklist.cex-y2.txt with the 13 tests + file an
   issue; if dev18 regression → bisect the encoding: what emits a lambda
   under --cex + tracking-mem/extra-widemem when --horn-bv2-lambdas=false
   (suspects: hexdump memory dumps, symbolic memcpy fallback past
   --horn-array-sym-memcpy-unroll-count).
**Effort estimate:** blacklist route ~1h; regression route ~1-2 days (opsem).
**References:** journal/2026-07/2026-07-14-dev17-dev18-waves.md; PR #146 CI
   run; local logs vcc-dev18-y2b.log (non-cex y2 228/228).

## SimplifyPointerLoops: pointer-IV detection disabled (needs opaque-ptr port)
**Status:** parked 2026-07-14 (user flagged: might still be important — file a
   GitHub issue on seahorn/seahorn; draft ready at the session tmp
   issue-simplify-pointer-loops.md, gh token was stale at the time)
**Context:** the dev17 port made `isPointerInductionVariable` bail out
   unconditionally: LLVM 17 removed `Type::getPointerElementType`, which the
   pass used for element size (SCEV byte-step -> element stride). No observable
   change: under opaque pointers (default since 15/16) the old code asserted at
   the same spot, so seapp `--simplify-pointer-loops` has been broken since the
   LLVM 15 era. The pass rewrites strided pointer loops into index loops —
   valuable preprocessing for verification back-ends.
**To resume:** recover the element type from the IV's increment GEP
   (`getSourceElementType()` of the latch GEP, as LLVM's own loop passes do
   under opaque pointers) or from access types at the IV's load/store sites;
   the deleted stride logic is at the dev16 branch tip of
   lib/Transforms/Scalar/SimplifyPointerLoops.cc.
**Effort estimate:** ~0.5-1 day + a lit test that the rewrite fires.
**References:** journal/2026-07 (dev17 seahorn port); seahorn PR #588 commit
   `fix(llvm17): port sources to LLVM 17 API removals`.

## clam: malloc/free not recognized at -O0 on LLVM 15
**Status:** parked (carried over from dev15 work)
**Context:** clam does not recognize malloc/free at -O0 on LLVM 15 — the
   allockind attribute changed how the allocator functions are marked, so clam's
   detection misses them. Deferred during the dev15 push; clam is built OFF
   (`WITH_CLAM=OFF`) on dev16 (clam not ported to LLVM 16).
**Why parked:** Not on the critical path for the dev16 upgrade (clam compiled out).
**To resume:** When porting clam to LLVM 16, update its alloc/free detection to
   read the `allockind` attribute rather than the older marking.
**Effort estimate:** unknown (~half-day once clam build is up on 16).
**References:** durable/seahorn-build-and-ci-gotchas.md

## opsem imprecision: partially-uninitialized bitfield structs (mcfuzz issue_44)
**Status:** parked 2026-07-08 (test disabled: test/mcfuzz/issue_44.c.disabled)
**Context:** Correct verdict is unsat. Reasoning: i.a = 2 is a load-modify-write
   that concretely sets the LOW 16 bits of the bitfield's storage unit; undef
   occupies only the never-written high bits and .b, which do not flow into the
   i.a != 2 comparison; by-value copies preserve written bits, so the error is
   unreachable. Corroborated by LLVM -O3 folding the branch away (a sat verdict
   would make that a miscompile) and by MCFuzz's differential report adjudicating
   SeaHorn's sat as the false alarm. A sat verdict requires losing WRITTEN
   sub-word bits while copying a partially-undef storage unit -- imprecision,
   not a defensible model of uninitialized memory. (File is seahorn-local
   issue_44.c, derived from MCFuzz upstream tracker issue 46.) Both
   bv-opsems historically gave spurious sat (hence XFAIL); on dev16 the verdict
   is ENVIRONMENT-DEPENDENT (unsat in local jammy-llvm16 container, fail on the
   CI runner) — likely sub-word undef propagation during aggregate copies in
   BvOpSem2's memory model. XFAIL/pass/UNSUPPORTED/REQUIRES all unstable across
   lit versions (pip lit reports unmet REQUIRES as UNRESOLVED), so the file is
   renamed out of lit discovery.
**To resume:** fix low-16-bit preservation across struct copies with undef high
   bits; re-enable by renaming back; verdict must be unsat in ALL 4 RUN configs.
**Effort estimate:** ~1-2 days (opsem memory model).
**References:** journal/2026-07/2026-07-07-pr586-and-ci-fixes.md
