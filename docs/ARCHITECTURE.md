# RV32IM + TTISA-32 Single-Cycle Processor

A single-cycle RV32IM core extended with the TTISA-32 time-travel instructions.
Every instruction, including the time-travel ones, completes in one clock (CPI = 1).

See the [README](../README.md) for the file layout and how to run the tests.
The original instruction table is in [TTISA32_spec.pdf](TTISA32_spec.pdf).

## Datapath

```
                    +---------+      +--------------+
 PC --> IMEM -----> | decoder |----->| control_unit |---> control signals
  ^                 | imm_gen |      +--------------+
  |                 +---------+
  |                  rs1 rs2 rd imm
  |                      v
  |  +----------------------+ rs1/rs2 +-------------+ alu_result +------+
  |  | tt_regfile x1..x31   |-------->| ALU         |----------->| DMEM |--> load data
  |  |                      |-------->| muldiv_comb |--> mul/div +------+
  |  |                      |
  |  |  regs_flat    ------------->  +---------+
  |  |  restore_data <-------------  | tt_unit |--> snap_id
  |  +----------------------+        +---------+
  |             ^
  |             wb_data = load | mul/div | PC+4 | snap_id | ALU
  |
  next PC = PC+4 | PC+imm_b (taken branch) | PC+imm_j (JAL) | (rs1+imm) & ~1 (JALR)
```

## TTISA-32 encoding

All TT instructions use the RISC-V **custom-0** opcode `0001011`, with `funct7 = 0` and `rs2 = x0`.

| Instruction | funct3 | rs1 | rd | Hex (fields = 0) |
|---|---|---|---|---|
| `CHECKPOINT`  | 000 | 0 | 0 | `0000000B` |
| `SNAPSHOT rd` | 001 | 0 | rd | `0000100B \| rd<<7` |
| `RESTORE rs1` | 010 | rs1 | 0 | `0000200B \| rs1<<15` |
| `REWIND`      | 011 | 0 | 0 | `0000300B` |
| `FORWARD`     | 100 | 0 | 0 | `0000400B` |

Any other `funct3`, or a nonzero `funct7`, executes as a NOP.

## TTISA-32 semantics

**What a checkpoint holds:** registers x1..x31. The PC and data memory are *not* saved or restored.
After every TT instruction the PC advances to PC+4, so execution continues after the
REWIND/FORWARD/RESTORE rather than jumping back (as in the spec's execution example).
Because memory is not rolled back, a program can use it to carry values across
time travel, for example to keep snapshot handles.

**Timeline state** (in `tt_unit`, 4 slots by default):

- `count`: number of valid checkpoints. Valid IDs are `0 .. count-1`.
- `pos`: the checkpoint the CPU is currently at or after.
- `at_cp`: 1 while the registers still equal checkpoint `pos`. It is cleared by any non-TT instruction.
- `overflow`: sticky, set when a save finds no free slot.

| Instruction | Effect |
|---|---|
| `CHECKPOINT` | Save into slot `s = (count == 0) ? 0 : pos + 1`, then `pos = s` and `count = s + 1`. Checkpoints after `pos` are discarded, like browser history. If `s == SLOTS`, nothing is saved and `overflow` is set. |
| `SNAPSHOT rd` | Same as CHECKPOINT, and `rd = s` (`0xFFFFFFFF` on overflow). The saved image is the state *before* `rd` is written. |
| `RESTORE rs1` | If `rs1 < count`, restore slot `rs1` and set `pos = rs1`. Otherwise it is a no-op. Restores never discard history. |
| `REWIND` | Restore the previous checkpoint: slot `pos` if instructions have run since the last checkpoint/restore, otherwise slot `pos-1`. No-op when there is no earlier checkpoint. |
| `FORWARD` | Restore slot `pos+1` if it is valid, otherwise no-op. |

Spec example, with R1..R5 mapped to s1..s5:

```
CHECKPOINT        CP0 saved (slot 0)
ADD  s3, s1, s2   S1
CHECKPOINT        CP1 saved (slot 1)
SUB  s4, s3, s1   S2
REWIND            instructions ran since CP1 -> restore CP1 (s4 back to 0, s3 kept)
ADD  s5, s1, s2   S1' continues from CP1
```

A second REWIND right after the first one would go to CP0. A FORWARD after that would return to CP1.

## How it works in one cycle

- `tt_regfile` exposes all 31 registers as one 992-bit bus. On a save, `tt_unit`
  copies that bus into `bank[s]` at the clock edge.
- On a restore, `tt_unit` puts `bank[target]` on `restore_data` and asserts `restore_en`.
  The register file then loads all 31 registers in parallel at the same edge.
- Cost: `SLOTS × 992` flip-flops for the banks (about 4K for 4 slots) plus a
  992-bit-wide `SLOTS:1` mux.

## Fixes relative to the earlier RV32IM core this design grew from

1. Removed the register-file write-through bypass. In a single-cycle datapath it forms a
   combinational loop, e.g. `ADD x1, x1, x2`.
2. The branch condition now uses a dedicated comparator on rs1/rs2 and supports all six
   branches. Previously only BEQ worked.
3. Branch and JAL targets use their own `PC + imm` adders. Previously the target was the
   ALU result, i.e. `rs1 - rs2`.
4. JALR now redirects the PC (`jalr_en` was ignored before) and clears bit 0 of the target.
5. MUL/DIV are combinational. The old unit is multi-cycle and needs a stall.
6. Data memory reads combinationally (`dmem #(.SYNC_READ(0))`). Previously load data arrived one cycle late.

## Useful signals in GTKWave

Under `sc_tb.dut.core`: `pc`, `imem_instr`, `tt_en`, `tt_op`, `tt_restore_en`,
`ttu.count`, `ttu.pos`, `ttu.at_cp`, `ttu.overflow`, `rf.regs[*]`.
