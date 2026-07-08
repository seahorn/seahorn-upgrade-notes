# PR 586 (dev16 → seahorn) opened; history cleaned; CI lint/format fixed

[OBS 2026-07-07] The dev16 upstream PR is live: seahorn/seahorn#586,
`priyasiddharth:dev16` → `seahorn:dev16`. Getting it clean took three rounds
of history surgery, all content-preserving (verified by tree-diff each time):

1. **Rebase onto real dev15.** The PR initially showed ~22 llvm15-titled
   commits: dev16 forked from dev15 at `42f7f824` *before* the llvm15-port
   commits landed on origin/dev15 as rebased twins (same patch, different
   SHA), so both lines carried copies. `git rebase --onto origin/dev15
   42f7f824 dev16 --empty=drop`: 18 twins dropped, one early CI commit
   skipped (content subsumed by dev15's ccache redesign), 35 genuine commits
   replayed conflict-free. Tree diff vs pre-rebase = only CI/docker files
   (dev15's ccache work, inherited for free). origin/dev16 moved to the
   dev15 tip `2503bdd8`.
2. **Dropped 3 residual llvm15-titled commits.** They netted to exactly
   zero (`git diff base third-commit` was EMPTY — +7 lines then -7); a
   second `rebase --onto` removed them. 34 commits, no llvm15 titles.
3. **CI fixes (both jobs red).**
   - clang-format: 1703-line `clang-format-diff-15` delta over the PR diff;
     applied with `-i` to fixpoint (2 passes), committed as `style:` (55
     files). Build + opsem2 42/42 re-verified.
   - commitlint: 15/35 messages failed — 14 headers >72 chars, 1
     sentence-case subject. Reworded headers only via
     `git filter-branch --msg-filter` (bodies verbatim); tree verified
     byte-identical before force-push.

[OBS 2026-07-07] Diagnosis without gh auth: the GitHub **public REST API**
serves PR check-runs AND their annotations unauthenticated
(`/repos/.../commits/<sha>/check-runs`, `<check-run-url>/annotations`) — the
commitlint annotation contained the exact per-commit rule failures. gh token
had expired; never needed it.

[OBS 2026-07-07] PR message drafted (bullet-form) in
`$CLAUDE_JOB_DIR/tmp/pr-message.md`; final head `cddd06f2` (35 commits:
34 port + 1 style).

## Distilled to

../../durable/seahorn-build-and-ci-gotchas.md (commitlint rule set +
clang-format-15 check recipe)

## See also

- ./2026-07-03-indvar-tied-to-bounded-flows.md
- ../../durable/multi-llvm-version-branch-structure.md

## Addendum: dev16 CI enablement (same day, second wave)

[OBS 2026-07-07] After publishing jammy-llvm16 and moving the CI infra to the
base branch, the first real CI run failed at opsem2 while opsem passed — the
.ll-vs-.c signature that exposed the stale clang-15 search list in the sea
driver (see gotchas note). Fixes, each validated in the local container before
pushing: `4840427a` (clang-16/llvm-link-16 search), `4ab6505c` (string.h in
ownsem/unique_unsat.02 — clang-16 implicit-decl error), `2a56cc52` (un-XFAIL
mcfuzz/issue_44: historically both bv-opsems answered sat; on dev16 it
deterministically answers unsat — plausibly the bounded-flow IndVarSimplify —
and the XPASS failed the suite).

[OBS 2026-07-07] Local re-validation with the clang-16 front end (the local
suites had been silently clang-15-front-ended all along): opsem2 42/42,
opsem 125+1, vcc 228/228 in 405s — parity holds under the real front end.

[FACT] Debug loop that worked: GitHub jobs API is public per-step
(`/actions/jobs/<id>` — no auth), job LOGS are not (403); reproduce instead in
the local image (`docker run -v repo:/seahorn -v fixed-file:/path:ro`) — every
CI failure this day was reproduced and fixed locally before re-pushing.
