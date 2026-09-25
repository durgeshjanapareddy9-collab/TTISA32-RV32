# TTISA-32 mnemonics (custom-0 opcode 0001011 = 0x0B, funct7 = 0, rs2 = x0)
#   .insn r opcode, funct3, funct7, rd, rs1, rs2

.macro CHECKPOINT
    .insn r 0x0B, 0, 0, x0, x0, x0
.endm

.macro SNAPSHOT rd
    .insn r 0x0B, 1, 0, \rd, x0, x0
.endm

.macro RESTORE rs1
    .insn r 0x0B, 2, 0, x0, \rs1, x0
.endm

.macro REWIND
    .insn r 0x0B, 3, 0, x0, x0, x0
.endm

.macro FORWARD
    .insn r 0x0B, 4, 0, x0, x0, x0
.endm
