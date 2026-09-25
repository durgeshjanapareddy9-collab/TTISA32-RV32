# Self-checking test helpers for tb/sc_tb.v
#   gp (x3)  = number of the current check (reported on failure)
#   t6 (x31) = scratch, do not use it in tests
#   a0 (x10) = 1 at EBREAK means PASS

# CHECK num, reg, value : fail unless reg == value
.macro CHECK num, reg, val
    li   gp, \num
    li   t6, \val
    bne  \reg, t6, fail
.endm

# CHECKR num, reg_a, reg_b : fail unless reg_a == reg_b
.macro CHECKR num, ra, rb
    li   gp, \num
    bne  \ra, \rb, fail
.endm

# Place once at the end of every test program
.macro TEST_END
pass:
    li   a0, 1
    ebreak
fail:
    li   a0, 0xBAD
    ebreak
.endm
