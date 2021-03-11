(*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "LICENSE" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 *)

(* ========================================================================= *)
(* Negation mod p_256, field characteristic for NIST P-256 curve.            *)
(* ========================================================================= *)

(**** print_literal_from_elf "X86/bignum_neg_p256.o";;
 ****)

let bignum_neg_p256_mc = define_assert_from_elf "bignum_neg_p256_mc" "X86/bignum_neg_p256.o"
[
  0x48; 0x8b; 0x06;        (* MOV (% rax) (Memop Quadword (%% (rsi,0))) *)
  0x48; 0x8b; 0x4e; 0x08;  (* MOV (% rcx) (Memop Quadword (%% (rsi,8))) *)
  0x49; 0x89; 0xc2;        (* MOV (% r10) (% rax) *)
  0x49; 0x09; 0xca;        (* OR (% r10) (% rcx) *)
  0x4c; 0x8b; 0x46; 0x10;  (* MOV (% r8) (Memop Quadword (%% (rsi,16))) *)
  0x4c; 0x8b; 0x4e; 0x18;  (* MOV (% r9) (Memop Quadword (%% (rsi,24))) *)
  0x4d; 0x89; 0xc3;        (* MOV (% r11) (% r8) *)
  0x4d; 0x09; 0xcb;        (* OR (% r11) (% r9) *)
  0x4d; 0x09; 0xd3;        (* OR (% r11) (% r10) *)
  0x49; 0xf7; 0xdb;        (* NEG (% r11) *)
  0x48; 0x19; 0xd2;        (* SBB (% rdx) (% rdx) *)
  0x41; 0xba; 0xff; 0xff; 0xff; 0xff;
                           (* MOV (% r10d) (Imm32 (word 4294967295)) *)
  0x49; 0xbb; 0x01; 0x00; 0x00; 0x00; 0xff; 0xff; 0xff; 0xff;
                           (* MOV (% r11) (Imm64 (word 18446744069414584321)) *)
  0x49; 0x21; 0xd2;        (* AND (% r10) (% rdx) *)
  0x49; 0x21; 0xd3;        (* AND (% r11) (% rdx) *)
  0x48; 0x29; 0xc2;        (* SUB (% rdx) (% rax) *)
  0xb8; 0x00; 0x00; 0x00; 0x00;
                           (* MOV (% eax) (Imm32 (word 0)) *)
  0x49; 0x19; 0xca;        (* SBB (% r10) (% rcx) *)
  0x4c; 0x19; 0xc0;        (* SBB (% rax) (% r8) *)
  0x4d; 0x19; 0xcb;        (* SBB (% r11) (% r9) *)
  0x48; 0x89; 0x17;        (* MOV (Memop Quadword (%% (rdi,0))) (% rdx) *)
  0x4c; 0x89; 0x57; 0x08;  (* MOV (Memop Quadword (%% (rdi,8))) (% r10) *)
  0x48; 0x89; 0x47; 0x10;  (* MOV (Memop Quadword (%% (rdi,16))) (% rax) *)
  0x4c; 0x89; 0x5f; 0x18;  (* MOV (Memop Quadword (%% (rdi,24))) (% r11) *)
  0xc3                     (* RET *)
];;

let BIGNUM_NEG_P256_EXEC = X86_MK_EXEC_RULE bignum_neg_p256_mc;;

(* ------------------------------------------------------------------------- *)
(* Proof.                                                                    *)
(* ------------------------------------------------------------------------- *)

let p_256 = new_definition `p_256 = 115792089210356248762697446949407573530086143415290314195533631308867097853951`;;

let BIGNUM_NEG_P256_CORRECT = time prove
 (`!z x n pc.
        nonoverlapping (word pc,0x5b) (z,8 * 4)
        ==> ensures x86
             (\s. bytes_loaded s (word pc) bignum_neg_p256_mc /\
                  read RIP s = word pc /\
                  C_ARGUMENTS [z; x] s /\
                  bignum_from_memory (x,4) s = n)
             (\s. read RIP s = word (pc + 0x5a) /\
                  (n <= p_256
                   ==> bignum_from_memory (z,4) s = (p_256 - n) MOD p_256))
          (MAYCHANGE [RIP; RAX; RCX; RDX; R8; R9; R10; R11] ,,
           MAYCHANGE SOME_FLAGS ,,
           MAYCHANGE [memory :> bignum(z,4)])`,
  MAP_EVERY X_GEN_TAC [`z:int64`; `x:int64`; `n:num`; `pc:num`] THEN
  REWRITE_TAC[C_ARGUMENTS; C_RETURN; SOME_FLAGS; NONOVERLAPPING_CLAUSES] THEN
  DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES] THEN ENSURES_INIT_TAC "s0" THEN
  BIGNUM_DIGITIZE_TAC "n_" `read (memory :> bytes (x,8 * 4)) s0` THEN

  X86_ACCSTEPS_TAC BIGNUM_NEG_P256_EXEC [16;18;19;20] (1--24) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
  CONV_TAC(LAND_CONV BIGNUM_EXPAND_CONV) THEN
  ASM_REWRITE_TAC[] THEN DISCARD_STATE_TAC "s24" THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN
  MATCH_MP_TAC EQUAL_FROM_CONGRUENT_REAL THEN
  MAP_EVERY EXISTS_TAC [`256`; `&0:real`] THEN
  CONJ_TAC THENL [BOUNDER_TAC; ALL_TAC] THEN CONJ_TAC THENL
   [UNDISCH_TAC `n <= p_256` THEN
    REWRITE_TAC[REAL_OF_NUM_CLAUSES; p_256] THEN ARITH_TAC;
    ALL_TAC] THEN
  CONJ_TAC THENL [REAL_INTEGER_TAC; ALL_TAC] THEN

  SUBGOAL_THEN `(p_256 - n) MOD p_256 = if n = 0 then 0 else p_256 - n`
  SUBST1_TAC THENL
   [COND_CASES_TAC THEN ASM_REWRITE_TAC[SUB_0; MOD_REFL] THEN
    MATCH_MP_TAC MOD_LT THEN ASM_ARITH_TAC;
    ONCE_REWRITE_TAC[COND_RAND]] THEN
  ASM_SIMP_TAC[GSYM REAL_OF_NUM_SUB] THEN EXPAND_TAC "n" THEN
  REWRITE_TAC[ADD_EQ_0; MULT_EQ_0; EXP_EQ_0; ARITH_EQ] THEN
  ACCUMULATOR_POP_ASSUM_LIST(MP_TAC o end_itlist CONJ o DESUM_RULE) THEN
  REWRITE_TAC[WORD_AND_MASK; COND_SWAP; WORD_OR_EQ_0; VAL_EQ_0] THEN
  REWRITE_TAC[CONJ_ACI] THEN COND_CASES_TAC THEN
  ASM_REWRITE_TAC[p_256; GSYM REAL_OF_NUM_CLAUSES; BITVAL_CLAUSES] THEN
  CONV_TAC WORD_REDUCE_CONV THEN
  DISCH_THEN(fun th -> REWRITE_TAC[th]) THEN REAL_INTEGER_TAC);;

let BIGNUM_NEG_P256_SUBROUTINE_CORRECT = time prove
 (`!z x n pc stackpointer returnaddress.
        ALL (nonoverlapping (z,8 * 4)) [(word pc,0x5b); (stackpointer,8)]
        ==> ensures x86
             (\s. bytes_loaded s (word pc) bignum_neg_p256_mc /\
                  read RIP s = word pc /\
                  read RSP s = stackpointer /\
                  read (memory :> bytes64 stackpointer) s = returnaddress /\
                  C_ARGUMENTS [z; x] s /\
                  bignum_from_memory (x,4) s = n)
             (\s. read RIP s = returnaddress /\
                  read RSP s = word_add stackpointer (word 8) /\
                  (n <= p_256
                   ==> bignum_from_memory (z,4) s = (p_256 - n) MOD p_256))
          (MAYCHANGE [RIP; RSP; RAX; RCX; RDX; R8; R9; R10; R11] ,,
           MAYCHANGE SOME_FLAGS ,,
           MAYCHANGE [memory :> bignum(z,4)])`,
  X86_ADD_RETURN_NOSTACK_TAC BIGNUM_NEG_P256_EXEC
      BIGNUM_NEG_P256_CORRECT);;
