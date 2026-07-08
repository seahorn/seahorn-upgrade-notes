# Build / CLI / CI gotchas (toolchain, flag routing, commitlint)

A grab-bag of source-grounded gotchas that each cost real time. Keep loading this
when configuring builds, adding seapp flags, or writing commit messages.

[FACT] **ctest/cmake shim.** The `ctest`/`cmake` first on PATH (`~/.local/bin/`)
are broken pip wrappers (`ModuleNotFoundError: No module named 'cmake'`). Use the
real ones at `~/cmake-3.31.7-linux-x86_64/bin/` — prepend that dir
to PATH before any ctest/cmake invocation.

[FACT] **zstd shim.** Prebuilt-LLVM `LLVMExports` references
`zstd::libzstd_shared`, but `find_package(zstd)` doesn't locate the host config
under the prebuilt clang → configure sea-dsa/llvm-seahorn with
`-DCMAKE_PROJECT_INCLUDE_BEFORE=<toolchains>/zstd_shim.cmake` (pre-defines the
imported target from `/usr/lib/x86_64-linux-gnu/libzstd.so`). EXCEPTION: the
`seahorn` repo calls `find_package(zstd)` itself and finds the system config, so
adding the shim there CONFLICTS ("targets already defined") — no shim for seahorn.

[FACT] **find_package LLVM 18 needs major.minor.** apt's LLVMConfigVersion needs
`major.minor` and LLVM 18 ships only as 18.1.x → `find_package(LLVM 18.1 REQUIRED
CONFIG)`, not `LLVM 18`.

[FACT] **sea fpf flag routing.** `sea fpf`/`SeqCmd` parse the top-level command
with a limited parser; every other flag lands in `extra` and is handed to EVERY
stage. `Seahorn.run` forwards leftover `extra` filtered by `_is_seahorn_opt` =
name starts with `horn-`/`crab`/`sea-opsem`. So any unrecognized `--horn-*` flag
LEAKS to the seahorn binary, which prints usage and exits non-zero. A new
seapp-only `--horn-*` flag must EITHER define a matching (no-op) `cl::opt` in the
seahorn binary, OR be added to the Seahorn stage parser in
`py/sea/commands.py` so `parse_known_args` consumes it. (A `cl::opt` in a static
lib only registers in a binary that pulls that `.o` in.)

[FACT] **commitlint #NNN.** seahorn CI lints commits with an OLD
`wagoid/commitlint-github-action@v1.6.0` that parses an `#NNN` issue ref in a
commit BODY as a footer and fails `footer-leading-blank` (blocks the PR). A newer
local `npx commitlint` does NOT reproduce this — don't trust a clean local run.
Never put `#NNN` (e.g. `seahorn#581`) in a commit body; write `issue 581` or a
full URL. Headers ≤72 chars.

[FACT] **commitlint full rule set (verified on PR 586, 2026-07-07).** The old
action enforces: header ≤ **72** chars (not config-conventional's modern 100);
**subject must start lowercase** (`subject-case` rejects sentence-case — so
`refactor(seapp): SimpleMemoryCheck consumes …` fails; reword to
`use the cached … in SimpleMemoryCheck`); body lines ≤ 100. Local pre-push
audit that matches CI: check `%s` length, first-subject-char case, and body
line lengths over `origin/<base>..HEAD` — 15/35 dev16 commits failed on first
push. Bulk fix: `git filter-branch -f --msg-filter` with a header-mapping
script (bodies untouched), then force-with-lease.

[FACT] **clang-format CI** (`check-formatting.yml`): the check is
`git diff <base> -U0 -- '**/*.cpp' '**/*.cc' '**/*.h' '**/*.hh' |
clang-format-diff-15 -p1` must output nothing — i.e. only the PR's *changed
lines* must be clang-format-15-clean, with **clang-format-15 specifically**
(other versions format differently; `/usr/bin/clang-format-diff-15` exists
locally). Fix = same command with `-i`, run to a fixpoint (a second pass can
expose new reflow), rebuild, commit as `style: …`.

[FACT] **The sea driver hardcodes the clang version it searches** —
`py/sea/commands.py` `which(['clang-mp-<N>', 'clang-<N>', 'clang'])` (plus
`llvm-link-<N>`). Two consequences on dev16 (found via PR 586 CI, 2026-07-07):
(1) in the jammy-llvm16 container, the stale clang-15 list made every source
(.c) flow die with "clang not found" — .ll-based suites (opsem) pass while
.c-based ones (opsem2/mcfuzz/smc/cex) fail wholesale, a distinctive signature;
(2) locally, host `/usr/bin/clang-15` matched the old list, so ALL local
validation had silently used a clang-15 front end while seahorn itself was
built with LLVM 16. After fixing the list to clang-16, local lit runs need
`clang-16`/`llvm-link-16` on lit's PATH (lit only prepends `run/bin`; symlink
the toolchain binaries into `build-dev16/run/bin`). Re-validated with the
clang-16 front end: opsem2 42/42, opsem 125+1, vcc 228/228 (405s).

[FACT] **clang-16 makes implicit function declarations a hard error** (C99+):
tests calling `memset` etc. without `<string.h>` fail to COMPILE on dev16
(e.g. opsem2 `ownsem/unique_unsat.02.c`). Sweep pattern: grep mem*/str* users
without the include across all CI-run suites.

## Why this matters

None of these are discoverable from the code; each produces a confusing failure
(broken cmake, "targets already defined", silent usage-dump exit, green-locally/
red-in-CI). This note is the checklist.
