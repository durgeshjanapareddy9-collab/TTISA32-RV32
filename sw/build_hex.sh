#!/bin/bash
# Assemble a test program into a $readmemh hex file for the instruction memory.
# Usage: build_hex.sh <prog.s> <out.hex>
#
# The output is padded with NOPs to IMEM_WORDS (default 1024, the testbench's
# instruction-memory depth) so $readmemh fills the whole memory.
set -e
PREFIX=${RISCV_PREFIX:-riscv64-unknown-elf-}
IMEM_WORDS=${IMEM_WORDS:-1024}
SRC=$1
OUT=$2
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

${PREFIX}as -march=rv32im -mabi=ilp32 -I "$(dirname "$SRC")" -o "$TMP/prog.o" "$SRC"
${PREFIX}ld -m elf32lriscv -Ttext=0 -e 0 -o "$TMP/prog.elf" "$TMP/prog.o"
${PREFIX}objcopy -O binary -j .text "$TMP/prog.elf" "$TMP/prog.bin"
hexdump -v -e '1/4 "%08x\n"' "$TMP/prog.bin" > "$TMP/prog.hex"

WORDS=$(wc -l < "$TMP/prog.hex")
if [ "$WORDS" -gt "$IMEM_WORDS" ]; then
    echo "error: $SRC is $WORDS words, instruction memory holds $IMEM_WORDS" >&2
    exit 1
fi
{ cat "$TMP/prog.hex"; yes 00000013 | head -n $((IMEM_WORDS - WORDS)); } > "$OUT"
