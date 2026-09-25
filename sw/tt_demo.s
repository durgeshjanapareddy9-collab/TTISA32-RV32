# TTISA-32 execution example from the spec, step by step.
# Run with +trace to see each instruction and the TT unit state.
# R1..R5 of the spec are mapped to s1..s5.
.include "test_macros.inc"
.include "tt.inc"

.text
start:
    li    s1, 5                    # R1 = 5
    li    s2, 3                    # R2 = 3

    CHECKPOINT                     # 1: CP0, state is saved
    add   s3, s1, s2               # 2: S1,  R3 = 8
    CHECKPOINT                     # 3: CP1, second state is saved
    sub   s4, s3, s1               # 4: S2,  R4 = 3
    REWIND                         # 5: CPU returns to CP1 (R4 back to 0)
    add   s5, s1, s2               # 6: S1', new execution continues from CP1

    CHECK 1, s3, 8
    CHECK 2, s4, 0
    CHECK 3, s5, 8
    j     pass

    TEST_END
