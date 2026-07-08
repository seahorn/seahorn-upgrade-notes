; Illustration: the supported BMC (opsem) VC-gen mode is FOUR flags together --
;     --horn-vcgen-only-dataflow=true --horn-bmc-coi=true
;     --horn-unify-assumes=true       --horn-gsa
; Run the full mode -> correct. Drop --horn-gsa (a partial, unsupported mode) and a
; surviving multi-predecessor loop returns a wrong verdict. See
; ../durable/bmc-opsem-supported-mode.md.
; ---------------------------------------------------------------------------
; This @main has a multi-predecessor merge: `%m` at @verifier.error is gated on the
; loop guard `g = (c<limit)`. GSA makes that gate an explicit operand so the
; dataflow/coi slice keeps it; without GSA the slice drops it and picks the wrong
; arm. TRUE answer = UNSAT (seahorn.fail is unreachable: the entry->error edge needs
; !(2<20) and the body edge is killed by assume.not(!(4<20))).
;
; Observed (dev15 build-dev15/bin/seahorn LLVM 15.0.7; identical dev16), base flags
;   --horn-bmc --horn-bv2 --horn-solve -horn-inter-proc -horn-sem-lvl=mem \
;   --horn-step=large --horn-bmc-engine=mono --sea-dsa=ci \
;   --horn-shadow-mem-alloc-is-def --keep-shadows=true --lower-gv-init-struct=false \
;   --horn-unify-assumes=true :
;
;   full mode  (df + coi + unify + gsa) .................... unsat  (CORRECT)
;   full mode minus --horn-gsa ............................ SAT    (WRONG)
;
; opsem2's RUN lines historically set df+coi+unify but not gsa; the affine tests
; don't expose it (single-predecessor error block, no gated merge). A surviving
; multi-predecessor loop (e.g. IndVarSimplify left ON) does.

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

declare void @seahorn.fn.enter()
declare i32 @nd_int()
declare void @verifier.assume(i1)
declare void @verifier.assume.not(i1)
declare void @seahorn.fail()

define dso_local i32 @main() local_unnamed_addr {
entry:
  call void @seahorn.fn.enter()
  %c = call i32 @nd_int()
  %limit = call i32 @nd_int()
  %ec = icmp eq i32 %c, 2
  call void @verifier.assume(i1 %ec)
  %el = icmp eq i32 %limit, 20
  call void @verifier.assume(i1 %el)
  %g = icmp slt i32 %c, %limit                    ; <-- gamma gate; only user is the br below
  br i1 %g, label %body, label %verifier.error

body:                                             ; preds = %entry
  %c2 = mul nsw i32 %c, 2
  %bg = icmp slt i32 %c2, %limit
  call void @verifier.assume.not(i1 %bg)          ; prunes the body edge only
  br label %verifier.error

verifier.error:                                   ; preds = %body, %entry
  %m = phi i32 [ %c, %entry ], [ %c2, %body ]     ; gamma( g, c, c2 )
  %chk = icmp sgt i32 %m, 19
  call void @verifier.assume.not(i1 %chk)
  call void @seahorn.fail()
  ret i32 42
}
