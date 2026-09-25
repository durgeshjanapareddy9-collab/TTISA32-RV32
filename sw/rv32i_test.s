# RV32I self-checking test for the single-cycle core
.include "test_macros.inc"

.text
start:
    # ---------- LUI / ADDI / x0 ----------
    lui   t0, 0x12345
    CHECK 1, t0, 0x12345000
    addi  t0, t0, 0x678
    CHECK 2, t0, 0x12345678
    addi  t1, zero, -1
    CHECK 3, t1, 0xFFFFFFFF
    addi  zero, zero, 5            # writes to x0 are ignored
    CHECK 4, zero, 0

    # ---------- rd == rs1 (combinational-loop regression) ----------
    li    t0, 10
    addi  t0, t0, 1
    add   t0, t0, t0
    CHECK 5, t0, 22

    # ---------- AUIPC ----------
    jal   t1, 1f                   # t1 = address of the auipc below
1:  auipc t0, 0
    CHECKR 6, t0, t1
    jal   t1, 2f                   # t1 = address of the auipc below
2:  auipc t2, 1                    # pc + 0x1000
    li    t3, 0x1000
    add   t1, t1, t3
    CHECKR 7, t2, t1

    # ---------- OP-IMM ----------
    li    s1, -5
    slti  t0, s1, 1
    CHECK 8, t0, 1
    sltiu t0, s1, 1                # 0xFFFFFFFB < 1 unsigned? no
    CHECK 9, t0, 0
    li    t1, 0x0F0F
    xori  t0, t1, 0x0FF
    CHECK 10, t0, 0x0FF0
    ori   t0, t1, 0x0F0
    CHECK 11, t0, 0x0FFF
    andi  t0, t1, 0x0F0
    CHECK 12, t0, 0x0000
    li    t1, 0x80000001
    slli  t0, t1, 4
    CHECK 13, t0, 0x00000010
    srli  t0, t1, 4
    CHECK 14, t0, 0x08000000
    srai  t0, t1, 4
    CHECK 15, t0, 0xF8000000

    # ---------- OP (register-register) ----------
    li    s1, 100
    li    s2, 58
    add   t0, s1, s2
    CHECK 16, t0, 158
    sub   t0, s2, s1
    CHECK 17, t0, -42
    li    t2, 33                   # shifts use only rs2[4:0] -> 1
    li    t1, 0x80000000
    sll   t0, s2, t2
    CHECK 18, t0, 116
    srl   t0, t1, t2
    CHECK 19, t0, 0x40000000
    sra   t0, t1, t2
    CHECK 20, t0, 0xC0000000
    li    s3, -1
    slt   t0, s3, s1               # -1 < 100 signed
    CHECK 21, t0, 1
    sltu  t0, s3, s1               # 0xFFFFFFFF < 100 unsigned? no
    CHECK 22, t0, 0
    li    t1, 0xFF00FF00
    li    t2, 0x0FF00FF0
    xor   t0, t1, t2
    CHECK 23, t0, 0xF0F0F0F0
    or    t0, t1, t2
    CHECK 24, t0, 0xFFF0FFF0
    and   t0, t1, t2
    CHECK 25, t0, 0x0F000F00

    # ---------- Branches: taken ----------
    li    s1, -1
    li    s2, 1
    li    gp, 26
    beq   s1, s1, 1f
    j     fail
1:  li    gp, 27
    bne   s1, s2, 1f
    j     fail
1:  li    gp, 28
    blt   s1, s2, 1f               # -1 < 1 signed
    j     fail
1:  li    gp, 29
    bge   s2, s1, 1f
    j     fail
1:  li    gp, 30
    bltu  s2, s1, 1f               # 1 < 0xFFFFFFFF unsigned
    j     fail
1:  li    gp, 31
    bgeu  s1, s2, 1f
    j     fail
1:  li    gp, 32
    bge   s1, s1, 1f               # equal counts as >=
    j     fail
1:
    # ---------- Branches: not taken ----------
    li    gp, 33
    beq   s1, s2, fail
    li    gp, 34
    bne   s1, s1, fail
    li    gp, 35
    blt   s2, s1, fail
    li    gp, 36
    bge   s1, s2, fail
    li    gp, 37
    bltu  s1, s2, fail
    li    gp, 38
    bgeu  s2, s1, fail

    # ---------- Backward branch loop: sum 1..10 ----------
    li    t0, 0                    # sum
    li    t1, 1                    # i
    li    t2, 11
loop:
    add   t0, t0, t1
    addi  t1, t1, 1
    blt   t1, t2, loop
    CHECK 39, t0, 55

    # ---------- JAL / JALR ----------
    li    gp, 40
    jal   ra, jal_target
jal_ret:
    j     fail                     # jal must not fall through
jal_target:
    la    t1, jal_ret
    CHECKR 41, ra, t1

    la    t0, jalr_target
    addi  t0, t0, 1                # JALR clears bit 0 of the target
    li    gp, 42
    jalr  ra, 0(t0)
jalr_ret:
    j     fail
jalr_target:
    la    t1, jalr_ret
    CHECKR 43, ra, t1

    # jalr with rd == rs1
    la    t0, jalr2_target
    jalr  t0, 0(t0)
jalr2_ret:
    j     fail
jalr2_target:
    la    t1, jalr2_ret
    CHECKR 44, t0, t1

    # ---------- Loads / stores ----------
    li    s0, 0x100                # data base address
    li    t0, 0xDEADBEEF
    sw    t0, 0(s0)
    lw    t1, 0(s0)
    CHECK 45, t1, 0xDEADBEEF
    lb    t1, 0(s0)
    CHECK 46, t1, 0xFFFFFFEF
    lbu   t1, 0(s0)
    CHECK 47, t1, 0x000000EF
    lb    t1, 3(s0)
    CHECK 48, t1, 0xFFFFFFDE
    lbu   t1, 2(s0)
    CHECK 49, t1, 0x000000AD
    lh    t1, 0(s0)
    CHECK 50, t1, 0xFFFFBEEF
    lhu   t1, 2(s0)
    CHECK 51, t1, 0x0000DEAD
    lh    t1, 2(s0)
    CHECK 52, t1, 0xFFFFDEAD

    sw    zero, 4(s0)
    li    t0, 0xAA
    sb    t0, 5(s0)
    lw    t1, 4(s0)
    CHECK 53, t1, 0x0000AA00
    li    t0, 0x1234
    sh    t0, 6(s0)
    lw    t1, 4(s0)
    CHECK 54, t1, 0x1234AA00
    li    t0, 0x55
    sb    t0, 4(s0)
    lw    t1, 4(s0)
    CHECK 55, t1, 0x1234AA55

    # negative offset + load into its own base register
    addi  s1, s0, 8
    lw    s1, -8(s1)
    CHECK 56, s1, 0xDEADBEEF

    # load result used immediately by the next instruction
    lw    t1, 4(s0)
    addi  t1, t1, 1
    CHECK 57, t1, 0x1234AA56

    j     pass

    TEST_END
