# TTISA-32 self-checking test for the single-cycle core (4 checkpoint slots)
# R1..R5 of the spec example are mapped to s1..s5 (x3 is used as gp by CHECK).
.include "test_macros.inc"
.include "tt.inc"

.text
start:
    li    s0, 0x200                # data area (memory is NOT rolled back)
    li    s1, 5
    li    s2, 3

    # ---------- Spec execution example ----------
    CHECKPOINT                     # CP0 (slot 0)
    add   s3, s1, s2               # S1 : s3 = 8
    CHECKPOINT                     # CP1 (slot 1)
    sub   s4, s3, s1               # S2 : s4 = 3
    REWIND                         # back to CP1: s4 undone, s3 kept
    CHECK 1, s4, 0
    CHECK 2, s3, 8
    add   s5, s1, s2               # S1': new execution from CP1
    CHECK 3, s5, 8

    # ---------- Two REWINDs: CP1 first, then CP0 ----------
    REWIND                         # instructions ran since CP1 -> CP1
    REWIND                         # already at CP1 -> CP0
    CHECK 4, s3, 0
    CHECK 5, s5, 0
    CHECK 6, s1, 5

    # ---------- FORWARD ----------
    FORWARD                        # CP0 -> CP1
    CHECK 7, s3, 8
    CHECK 8, s4, 0
    li    s6, 77
    FORWARD                        # CP1 is newest -> no-op
    CHECK 9, s6, 77

    # ---------- SNAPSHOT / RESTORE with handles ----------
    li    s7, 111
    SNAPSHOT a1                    # slot 2
    CHECK 10, a1, 2
    sw    a1, 0(s0)                # keep handles in memory
    li    s7, 222
    SNAPSHOT a2                    # slot 3
    CHECK 11, a2, 3
    sw    a2, 4(s0)
    li    s7, 333

    lw    t0, 0(s0)
    RESTORE t0                     # -> slot 2
    CHECK 12, s7, 111
    CHECK 13, a2, 0                # a2 had not been written yet at slot 2
    lw    t0, 4(s0)
    RESTORE t0                     # -> slot 3 (restores do not discard history)
    CHECK 14, s7, 222
    CHECK 15, a1, 2

    # ---------- Overflow: all 4 slots used, pos = 3 ----------
    SNAPSHOT a3
    CHECK 16, a3, 0xFFFFFFFF
    li    s8, 5
    CHECKPOINT                     # dropped as well
    REWIND                         # -> slot 3, which has s8 = 0
    CHECK 17, s8, 0
    CHECK 18, s7, 222

    # ---------- New checkpoint after going back discards the future ----------
    li    t0, 0
    RESTORE t0                     # -> CP0
    CHECK 19, s3, 0
    li    s9, 9
    SNAPSHOT a4                    # slot 1 again; slots 2,3 discarded
    CHECK 20, a4, 1
    li    s10, 42
    li    t0, 3
    RESTORE t0                     # slot 3 no longer valid -> no-op
    CHECK 21, s10, 42
    FORWARD                        # slot 1 is newest -> no-op
    CHECK 22, s10, 42
    li    t0, -1
    RESTORE t0                     # invalid handle -> no-op
    CHECK 23, s10, 42
    li    s9, 0
    REWIND                         # -> slot 1
    CHECK 24, s9, 9
    CHECK 25, s10, 0

    # ---------- Memory is not rolled back ----------
    lw    t0, 0(s0)
    CHECK 26, t0, 2

    j     pass

    TEST_END
