# TTISA32-RV32: a time-travel RISC-V single-cycle processor

A single-cycle **RV32IM** processor in Verilog, extended with **TTISA-32**. TTISA-32 is a
set of custom instructions that save the register state as checkpoints and move
back and forth between them in one clock cycle.

| Instruction | Effect |
|---|---|
| `CHECKPOINT`  | Save the current register state |
| `SNAPSHOT rd` | Save the state and write its checkpoint ID to `rd` |
| `RESTORE rs1` | Restore the checkpoint whose ID is in `rs1` |
| `REWIND`      | Go back to the previous checkpoint |
| `FORWARD`     | Go forward to the next checkpoint |

The instructions use the RISC-V custom-0 opcode `0001011`. Each one executes in a
single cycle (CPI = 1). The core keeps 4 checkpoints of registers x1–x31 by default.

```asm
CHECKPOINT            # CP0
add  s3, s1, s2
CHECKPOINT            # CP1
sub  s4, s3, s1
REWIND                # back to CP1: s4 is undone, s3 is kept
add  s5, s1, s2       # execution continues from CP1
```

The full semantics, encoding and datapath are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
The original ISA table is [docs/TTISA32_spec.pdf](docs/TTISA32_spec.pdf).

## Repository layout

```
rtl/
  rv32_sc_top.v       core + instruction memory + data memory
  rv32_sc_core.v      single-cycle datapath, next-PC logic, write-back
  tt_unit.v           TTISA-32 checkpoint banks and timeline pointer
  tt_regfile.v        register file with one-cycle save/restore of x1..x31
  muldiv_comb.v       combinational RV32M multiply/divide
  control_unit.v      main decoder (RV32I, RV32M, TTISA-32)
  alu.v decoder.v imm_gen.v lsu.v fetch_unit.v imem.v dmem.v
tb/
  sc_tb.v             full-system testbench (runs programs from sw/)
  unit/*_tb.v         module-level testbenches
sw/
  rv32i_test.s        every RV32I instruction, 57 checks
  rv32m_test.s        every RV32M instruction with corner cases, 20 checks
  tt_test.s           all TTISA-32 instructions and edge cases, 26 checks
  tt_demo.s           the execution example from the spec
  tt.inc              TTISA-32 assembler macros (CHECKPOINT, REWIND, ...)
  test_macros.inc     CHECK / pass / fail helpers
  build_hex.sh        assemble a .s file into a $readmemh .hex file
docs/
  ARCHITECTURE.md     design and TTISA-32 semantics
  TTISA32_spec.pdf    ISA specification
```

## Requirements

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) (`iverilog`, `vvp`)
- RISC-V GNU binutils (`riscv64-unknown-elf-as`, `-ld`, `-objcopy`).
  On Ubuntu: `sudo apt install iverilog binutils-riscv64-unknown-elf`.
  Set `RISCV_PREFIX` to use a different toolchain prefix.
- GTKWave (optional, for waveforms)

## Running

```bash
make test               # all unit tests + all test programs
make unit               # module-level testbenches only
make programs           # test programs on the full core only
make run  T=tt_demo     # instruction-by-instruction trace of one program
make wave T=tt_test     # write waves/tt_test.vcd, then: gtkwave waves/tt_test.vcd
make clean
```

Expected output of `make test`:

```
=== Unit tests ===
tt_unit      PASS
muldiv_comb  PASS
control      PASS
decoder      PASS
lsu          PASS
dmem         PASS
imem         PASS
fetch        PASS
=== Test programs ===
rv32i_test   PASS
rv32m_test   PASS
tt_test      PASS
tt_demo      PASS
```

## Writing your own program

```asm
.include "test_macros.inc"
.include "tt.inc"

.text
    li    s1, 42
    CHECKPOINT
    li    s1, 7
    REWIND
    CHECK 1, s1, 42       # fails the program unless s1 == 42
    j     pass

    TEST_END              # defines pass (a0 = 1) and fail (gp = failing check)
```

Save it as `sw/myprog.s` and run `make run T=myprog`. A program stops at `ebreak`.
The testbench prints PASS when `a0 == 1`. Otherwise it prints the check number held in `gp`.
