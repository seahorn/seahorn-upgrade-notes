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

## Why this matters

None of these are discoverable from the code; each produces a confusing failure
(broken cmake, "targets already defined", silent usage-dump exit, green-locally/
red-in-CI). This note is the checklist.
