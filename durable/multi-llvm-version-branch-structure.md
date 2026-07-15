# dev16/17/18 branch structure: pristine devN = dev{N-1} + upstream LLVM N

The branch model for the multi-version LLVM upgrade, and the git hygiene rules
learned the hard way.

[FACT] Each `devN` pristine import must be built **on `dev{N-1}`** (so it carries
the prior branch's CMakeLists / CXX standard / scaffolding), then swap in the
upstream-LLVM-N source for the ~25 imported files; the seahorn customizations
layer on top. An early wrong structure had `import16` and `import17` as siblings
both carrying dev14-era CMake — rebuilt so each pristine descends from the prior.
(User directive, 2026-06-26.)

[FACT] Two remotes on each component repo: `origin` = the shared seahorn org
(e.g. `seahorn/sea-dsa`, `seahorn/llvm-seahorn`); `priyasiddharth`/`fork` = the
user's fork. Convention used this session: push the *pristine* baseline to
`origin/devN`, push the customization stack to the user's fork, then open a PR
fork→origin. NOTE: this only applies cleanly when `origin/devN` does NOT already
exist — for llvm-seahorn, `origin/dev16` already had 17 commits of real port work
(see loose-ends/parked.md).

[FACT] `build-dev16/17/18` are out-of-source CMake/Ninja trees and must NEVER be
tracked. They are NOT gitignored by default in these repos — a bare `git add -A`
sweeps them into a commit, and a later branch reset then guts the build dir.
ALWAYS scope `git add` to explicit paths. sea-dsa now has a `.gitignore`
(`/build/`, `/build-*/`, committed in `823dd0c`); llvm-seahorn does not yet.

[FACT] dev15 provenance: dev15 was cut from dev14 at `57751d38` (2023-05-23) and
never forward-ported ~43 later dev14 commits (many opsem fixes: umin/umax, smin/
smax, partial-word memset, usub.sat, fshl/fshr, ...). Resolved by rebasing dev15's
opaque-ptr work onto dev14 head (branch `dev15-on-dev14`). Heuristic: when a dev15
failure looks like an unhandled intrinsic / removed API, check
`git log 57751d38..origin/dev14` first — the fix likely already exists in dev14.

[FACT] **sea-dsa dev17 (created 2026-07-09)**: cut FRESH from `origin/dev16`
head `384c63e` (includes ShadowMemNewPmPass) and pushed as new branch
`seahorn/sea-dsa:dev17`. The PREVIOUS local dev17 (2 llvm17 commits on a
pre-rebase dev16 lineage) was NOT rebased — its base predated real dev16
content (31 files of delta, rebase conflicted) — and survives as local
`dev17-pre-sync`. Precedent: when a devN branch's base is stale by more than
rebased twins, re-cut fresh from devN-1 head and cherry-pick the delta rather
than untangle the old lineage.

[FACT] **The devN wave pattern (validated twice in one day, dev17 and dev18,
2026-07-14)**: per repo, (1) push PRISTINE org devN = devN-1 head (llvm-seahorn
needed a FORCE-push both times — its org devN branches pre-existed at old
pre-newpm lineages, preserved locally as devN-pre-newpm); (2) port on the
fork; (3) PR fork:devN → org:devN shows only the version delta; (4) merge
order: sea-dsa + llvm-seahorn first (seahorn CI clones both BY BRANCH), then
buildpack image, then seahorn. seahorn's buildpack bootstrap commit can BE the
pristine-branch push (base born with the fixed workflow — dev18 did this,
avoiding dev17's separate fix-push). All merges produce twin SHAs; local
branches need post-wave realignment (still pending for dev17+dev18 as of
2026-07-15).

## Why this matters

The pristine-on-prior rule keeps each version's config inherited and the
seahorn-delta cleanly separable. The build-dir hygiene rule prevented (and twice
nearly caused) gutted build trees and bloated commits.

## See also

- llvm-seahorn-upstream-rebase-strategy.md
- ../loose-ends/parked.md (origin/dev16 reset decision)
