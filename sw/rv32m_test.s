# RV32M self-checking test for the single-cycle core
# Each CHECK compares a register with the expected value; on a mismatch the
# program jumps to fail with the check number in gp (see test_macros.inc).
.include "test_macros.inc"

.text
start:
    li    a1, 7
    li    a2, -3
    li    a3, 0x80000000
    li    a4, 0xFFFFFFFF

    # ---------- Multiply ----------
    mul    t0, a1, a2
    CHECK  1, t0, -21
    mulh   t0, a1, a2              # -21 -> upper word all ones
    CHECK  2, t0, 0xFFFFFFFF
    mulh   t0, a3, a3              # (-2^31)^2 = 2^62
    CHECK  3, t0, 0x40000000
    mulhu  t0, a4, a4              # (2^32-1)^2
    CHECK  4, t0, 0xFFFFFFFE
    mulhsu t0, a4, a4              # -1 * (2^32-1)
    CHECK  5, t0, 0xFFFFFFFF
    mulhsu t0, a1, a4              # 7 * (2^32-1)
    CHECK  6, t0, 6
    li     t0, 12
    mul    t0, t0, t0              # rd == rs1 == rs2
    CHECK  7, t0, 144

    # ---------- Divide / remainder (truncate toward zero) ----------
    div    t0, a1, a2
    CHECK  8, t0, -2
    rem    t0, a1, a2
    CHECK  9, t0, 1
    neg    t1, a1
    li     t2, 3
    div    t0, t1, t2              # -7 / 3
    CHECK 10, t0, -2
    rem    t0, t1, t2              # -7 % 3
    CHECK 11, t0, -1
    li     t2, 2
    divu   t0, a4, t2
    CHECK 12, t0, 0x7FFFFFFF
    remu   t0, a4, t2
    CHECK 13, t0, 1

    # ---------- Divide by zero ----------
    div    t0, a1, zero
    CHECK 14, t0, 0xFFFFFFFF
    divu   t0, a1, zero
    CHECK 15, t0, 0xFFFFFFFF
    rem    t0, a2, zero
    CHECK 16, t0, -3
    remu   t0, a1, zero
    CHECK 17, t0, 7

    # ---------- Signed overflow ----------
    li     t2, -1
    div    t0, a3, t2
    CHECK 18, t0, 0x80000000
    rem    t0, a3, t2
    CHECK 19, t0, 0

    # ---------- Factorial 6! with a loop ----------
    li     t0, 1
    li     t1, 6
fact:
    mul    t0, t0, t1
    addi   t1, t1, -1
    bnez   t1, fact
    CHECK 20, t0, 720

    j     pass

    TEST_END
