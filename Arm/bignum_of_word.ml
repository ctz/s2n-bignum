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
(* Conversion of a single word (digit) to a bignum.                          *)
(* ========================================================================= *)

let bignum_of_word_mc =
  define_assert_from_elf "bignum_of_word_mc" "Arm/bignum_of_word.o"
[
  0xb40000e0;       (* arm_CBZ X0 (word 28) *)
  0xf9000022;       (* arm_STR X2 X1 (Immediate_Offset (word 0)) *)
  0xf1000400;       (* arm_SUBS X0 X0 (rvalue (word 1)) *)
  0x54000080;       (* arm_BEQ (word 16) *)
  0xf820783f;       (* arm_STR XZR X1 (Shiftreg_Offset X0 3) *)
  0xf1000400;       (* arm_SUBS X0 X0 (rvalue (word 1)) *)
  0x54ffffc1;       (* arm_BNE (word 2097144) *)
  0xd65f03c0        (* arm_RET X30 *)
];;

let BIGNUM_OF_WORD_EXEC = ARM_MK_EXEC_RULE bignum_of_word_mc;;

(* ------------------------------------------------------------------------- *)
(* Correctness proof.                                                        *)
(* ------------------------------------------------------------------------- *)

let BIGNUM_OF_WORD_CORRECT = prove
 (`!k z n pc.
        nonoverlapping (word pc,0x20) (z,8 * val k)
        ==> ensures arm
             (\s. aligned_bytes_loaded s (word pc) bignum_of_word_mc /\
                  read PC s = word pc /\
                  C_ARGUMENTS [k; z; n] s)
             (\s. read PC s = word (pc + 0x1c) /\
                  bignum_from_memory (z,val k) s =
                  val n MOD (2 EXP (64 * val k)))
         (MAYCHANGE [PC; X0; X2] ,, MAYCHANGE SOME_FLAGS ,,
          MAYCHANGE [memory :> bignum(z,val k)])`,
  W64_GEN_TAC `k:num` THEN X_GEN_TAC `z:int64` THEN
  W64_GEN_TAC `n:num` THEN X_GEN_TAC `pc:num` THEN
  REWRITE_TAC[NONOVERLAPPING_CLAUSES] THEN
  REWRITE_TAC[C_ARGUMENTS; C_RETURN; SOME_FLAGS] THEN DISCH_TAC THEN

  ASM_CASES_TAC `k = 0` THENL
   [ASM_REWRITE_TAC[BIGNUM_FROM_MEMORY_TRIVIAL] THEN
    ARM_SIM_TAC BIGNUM_OF_WORD_EXEC [1] THEN
    REWRITE_TAC[MULT_CLAUSES; EXP; MOD_1];
    ALL_TAC] THEN

  ASM_CASES_TAC `k = 1` THENL
   [ARM_SIM_TAC BIGNUM_OF_WORD_EXEC (1--4) THEN
    REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES] THEN
    ASM_SIMP_TAC[BIGNUM_FROM_MEMORY_SING; MULT_CLAUSES; MOD_LT];
    ALL_TAC] THEN

  FIRST_ASSUM(MP_TAC o MATCH_MP (ONCE_REWRITE_RULE[IMP_CONJ]
        NONOVERLAPPING_IMP_SMALL_2)) THEN
  ANTS_TAC THENL [SIMPLE_ARITH_TAC; DISCH_TAC] THEN

  ENSURES_WHILE_PADOWN_TAC `k:num` `1` `pc + 0x10` `pc + 0x18`
   `\i s. (read X1 s = z /\
           read X0 s = word(i - 1) /\
           read (memory :> bytes64 z) s = word n /\
           bignum_from_memory(word_add z (word(8 * i)),k - i) s = 0) /\
          (read ZF s <=> i = 1)` THEN
  ASM_REWRITE_TAC[] THEN REPEAT CONJ_TAC THENL
   [ASM_REWRITE_TAC[ARITH_RULE `1 < k <=> ~(k = 0) /\ ~(k = 1)`];
    MP_TAC(ISPECL [`word k:int64`; `word 1:int64`] VAL_WORD_SUB_EQ_0) THEN
    ASM_REWRITE_TAC[VAL_WORD_1] THEN DISCH_TAC THEN
    ARM_SIM_TAC BIGNUM_OF_WORD_EXEC (1--4) THEN
    REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES] THEN
    ASM_SIMP_TAC[BIGNUM_FROM_MEMORY_TRIVIAL; WORD_SUB; LE_1];
    X_GEN_TAC `i:num` THEN STRIP_TAC THEN
    VAL_INT64_TAC `i:num` THEN REWRITE_TAC[ADD_SUB] THEN
    ARM_SIM_TAC BIGNUM_OF_WORD_EXEC (1--2) THEN
    ASM_SIMP_TAC[WORD_SUB; LE_1; VAL_WORD_1] THEN
    REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES] THEN
    ONCE_REWRITE_TAC[BIGNUM_FROM_MEMORY_EXPAND] THEN
    ASM_REWRITE_TAC[VAL_WORD_0; ADD_CLAUSES; SUB_EQ_0; GSYM NOT_LT] THEN
    REWRITE_TAC[WORD_RULE
     `word_add (word_add z (word (8 * i))) (word 8) =
      word_add z (word (8 * (i + 1)))`] THEN
    REWRITE_TAC[ARITH_RULE `k - i - 1 = k - (i + 1)`] THEN
    ASM_REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES; MULT_CLAUSES];
    REPEAT STRIP_TAC THEN ARM_SIM_TAC BIGNUM_OF_WORD_EXEC [1];
    ARM_SIM_TAC BIGNUM_OF_WORD_EXEC [1] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[MULT_CLAUSES]) THEN
    REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES] THEN
    ONCE_REWRITE_TAC[BIGNUM_FROM_MEMORY_EXPAND] THEN
    ASM_REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES; ADD_CLAUSES; MULT_CLAUSES] THEN
    CONV_TAC SYM_CONV THEN MATCH_MP_TAC MOD_LT THEN
    TRANS_TAC LTE_TRANS `2 EXP 64` THEN ASM_REWRITE_TAC[LE_EXP] THEN
    UNDISCH_TAC `~(k = 0)` THEN ARITH_TAC]);;

let BIGNUM_OF_WORD_SUBROUTINE_CORRECT = prove
 (`!k z n pc returnaddress.
        nonoverlapping (word pc,0x20) (z,8 * val k)
        ==> ensures arm
             (\s. aligned_bytes_loaded s (word pc) bignum_of_word_mc /\
                  read PC s = word pc /\
                  read X30 s = returnaddress /\
                  C_ARGUMENTS [k; z; n] s)
             (\s. read PC s = returnaddress /\
                  bignum_from_memory (z,val k) s =
                  val n MOD (2 EXP (64 * val k)))
             (MAYCHANGE [PC; X0; X2] ,, MAYCHANGE SOME_FLAGS ,,
              MAYCHANGE [memory :> bignum(z,val k)])`,
  ARM_ADD_RETURN_NOSTACK_TAC BIGNUM_OF_WORD_EXEC BIGNUM_OF_WORD_CORRECT);;
