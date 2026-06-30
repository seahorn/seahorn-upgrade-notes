# Port llvm-seahorn by rebasing on upstream, not ad-hoc API porting

The rule for moving llvm-seahorn to a new LLVM version. (User directive,
2026-06; repeatedly validated through dev16/17/18.)

[FACT] llvm-seahorn is a fork of LLVM's own pass sources (InstCombine, the `opt`
driver, loop passes). To port to LLVM N: **first base the forked files on
UPSTREAM LLVM N, then transfer the seahorn delta from the previous dev branch on
top.** i.e. seahorn delta = `diff(dev{N-1} file, upstream-LLVM-{N-1} file)`,
re-applied onto pristine upstream-LLVM-N.

[FACT] Why not ad-hoc: blanket seds (Optional/None/getValue/getInstList) corrupt
InstCombine — it has enums named `None`, non-Optional `getValue()` methods,
static helpers without `Builder`. Rebasing onto clean upstream gets LLVM's own
fixes for free and isolates the real seahorn delta.

[FACT] Mechanism that works: per-file 3-way merge
`git merge-file --diff3 <ours=dev{N-1}:F> <base=llvm-{N-1}.src:F> <theirs=llvm-N.src:F>`.
Small InstCombine op-files auto-resolve via "take theirs (llvm-N) + perl
`(?<!Sea)\bInstCombinerImpl\b` → `SeaInstCombinerImpl`". Only
`InstructionCombining.cpp` needs care: keep-OURS for the seahorn *envelope*
(the `seaopt-instcombine-avoid-*` cl::opts, `SeaInstCombinePass` ctors, the
`combineInstructionsOverFunction` call with Avoid args, the deleted legacy pass);
take-theirs for new upstream functions/signatures. The Avoid* fold guards live in
the per-op files and survive the merge.

[FACT] InstCombine must TRACK stock (`sea(avoid off) == stock opt-N`); regenerate
its test corpus from LLVM-N's own `test/Transforms/InstCombine` each version
(user: "default tests follow upstream, don't port from the prior LLVM"). Loops /
SeaLoopUnroll are a TRUE seahorn fork and correctly stay frozen (taken from
dev{N-1}, API-ported only).

[FACT] Recurring link/runtime fixups when the fork overlaps libLLVM: `#if 0` any
base `InstCombiner::` method LLVM now provides (else multiple-definition);
`extern` (don't redefine) flags like `EnableInferAlignmentPass`; rename any
`cl::opt` whose string collides with an upstream one to `sea-ic-*` (else
"registered more than once" ABORT at startup).

## Why this matters

This is the difference between a 1-day port and a week of whack-a-mole. Every
version (16→17→18) confirmed it. Treat InstCombine and loop passes oppositely:
one tracks upstream, the other is a frozen fork.

## See also

- multi-llvm-version-branch-structure.md
- seapp-newpm-migration-patterns.md
