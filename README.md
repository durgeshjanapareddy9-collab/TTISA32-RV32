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
  VERIFICATION.md     test results with waveform screenshots
  TTISA32_spec.pdf    ISA specification
  TTISA32_RV32IM_ISA.xlsx  full ISA table: encodings, control signals, test coverage
verification_screenshots/  GTKWave and console screenshots of every feature
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

## How this compares to other ways of going back in time

Rolling back program state is not a new idea. What differs is where it is done
and what it costs.

| Approach | Who controls it | Cost of one checkpoint | What is rolled back |
|---|---|---|---|
| Software save/restore (`sw`/`lw` of every register) | the program | ~31 stores + ~31 loads, plus memory space | whatever the program saves |
| Reverse debuggers (GDB reverse execution, record/replay tools) | the debugger, not the program | slows the whole run down | full state, but only while debugging |
| Hardware transactional memory (e.g. Intel TSX) | the program | done by the cache hardware | registers and memory, but only one level: abort back to the start |
| Checkpoints in out-of-order CPUs (branch misprediction recovery) | the hardware only, invisible to software | in hardware | register mapping |
| **TTISA-32 (this project)** | **the program, with 5 instructions** | **1 clock cycle** | **registers x1..x31, several named checkpoints** |

The point of TTISA-32 is that saving and restoring the whole register state is a
normal instruction that the program can use directly, it takes one cycle like
any other instruction, and there are several checkpoints that can be visited in
any order (back, forward, or by handle).

### Advantages

- **One cycle for everything.** CHECKPOINT, SNAPSHOT, RESTORE, REWIND and FORWARD all
  run at CPI = 1. All 31 registers are copied in parallel, so there is no stall and
  no memory traffic.
- **Simple to use.** Five instructions with browser-history behaviour: going back and
  then saving a new checkpoint discards the old "future".
- **Random access with handles.** SNAPSHOT returns a slot ID that can be kept in a
  register or memory and passed to RESTORE later.
- **Fits standard RISC-V.** The instructions use the custom-0 opcode reserved for
  extensions, so normal RV32IM programs are not affected and the stock GNU assembler
  can encode them with `.insn` (see `sw/tt.inc`).
- **Safe on misuse.** An invalid handle, FORWARD at the newest checkpoint or REWIND
  before any checkpoint is a no-op, and running out of slots sets a sticky
  `overflow` flag instead of corrupting state.
- **Easy to change.** The number of slots is a parameter (`TT_SLOTS`).
- **Tested.** 26 checks in `tt_test.s` cover all instructions and edge cases, plus a
  module-level testbench for `tt_unit`.

### Disadvantages and limitations

- **Area.** Every slot is a full copy of x1..x31 (992 flip-flops). With 4 slots the
  checkpoint banks are 3,968 of the core's ~5,030 flip-flops (about 79%), and the TT
  unit is ~7,100 of ~50,000 generic gates (about 14%). Each extra slot adds another
  992 flip-flops. (Yosys 0.33 generic synthesis, `synth -flatten`.)
- **Wide restore path.** A restore selects one of the banks through a 992-bit
  multiplexer and rewrites all registers at once, which costs wiring and power.
- **Only registers are rolled back.** The PC is not restored (execution continues
  after the REWIND), and data memory is not rolled back, so stores done after a
  checkpoint stay. Software has to handle memory itself.
- **Fixed number of checkpoints.** With 4 slots, older history cannot be kept; a full
  timeline drops new saves (the program can check the `-1` handle from SNAPSHOT).
- **No OS support.** There are no traps, interrupts or CSRs, so an operating system
  could not yet save the checkpoint banks on a context switch. FENCE, ECALL and
  EBREAK decode as NOPs.
- **Single-cycle core.** Simple and easy to verify, but the clock period has to cover
  the longest path (including the combinational divider), so it would run slowly
  compared to a pipelined core.
- **Simulation only.** The design is verified in Icarus Verilog; it has not yet been
  run on an FPGA or timed for a real clock frequency.

## Use of AI tools

I used an AI assistant (Claude, by Anthropic) during this project to help improve
the implementation and the documentation. It was used to:

- review the RTL, remove unused logic and add comments
- set up the GTKWave views and take the verification screenshots
- generate the ISA spreadsheet (`docs/TTISA32_RV32IM_ISA.xlsx`) from the assembler
  output and a simulation of the control unit
- draft parts of the documentation, including this README

Every change was reviewed and checked with the full test suite (`make test`).
