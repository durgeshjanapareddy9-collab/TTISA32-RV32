# RV32IM + TTISA-32 single-cycle processor
IVERILOG ?= iverilog
VVP      ?= vvp
IVFLAGS  := -g2012 -Wall -Wno-timescale -Wno-sensitivity-entire-array

RTL   := $(wildcard rtl/*.v)
BUILD := build
WAVES := waves

# System-level test programs (sw/*.s), run on the full core
PROGRAMS := rv32i_test rv32m_test tt_test tt_demo
# Module-level testbenches (tb/unit/*_tb.v)
UNITS    := tt_unit muldiv_comb control decoder lsu dmem imem fetch

.PHONY: all test programs unit run wave clean

all: test

test: unit programs

# ---------- Full-core test programs ----------
$(BUILD)/sc_sim: $(RTL) tb/sc_tb.v
	@mkdir -p $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $@ tb/sc_tb.v $(RTL)

$(BUILD)/%.hex: sw/%.s sw/test_macros.inc sw/tt.inc sw/build_hex.sh
	@mkdir -p $(BUILD)
	sw/build_hex.sh $< $@

programs: $(BUILD)/sc_sim $(addprefix $(BUILD)/,$(addsuffix .hex,$(PROGRAMS)))
	@echo "=== Test programs ==="
	@rc=0; for t in $(PROGRAMS); do \
	    printf "%-12s " $$t; \
	    out=$$($(VVP) -n $(BUILD)/sc_sim +hex=$(BUILD)/$$t.hex 2>&1); \
	    if echo "$$out" | grep -q "RESULT  : PASS"; then echo PASS; \
	    else echo "$$out" | grep -E "RESULT|FAIL:" | sed 's/RESULT  : //'; rc=1; fi; \
	done; exit $$rc

# ---------- Unit testbenches ----------
$(BUILD)/unit_%: tb/unit/%_tb.v $(RTL)
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -o $@ $< $(RTL)

unit: $(addprefix $(BUILD)/unit_,$(UNITS))
	@echo "=== Unit tests ==="
	@rc=0; for u in $(UNITS); do \
	    printf "%-12s " $$u; \
	    out=$$($(VVP) -n $(BUILD)/unit_$$u 2>&1); st=$$?; \
	    if [ $$st -ne 0 ] || echo "$$out" | grep -qE "FAIL|ERROR"; then echo FAIL; rc=1; \
	    else echo PASS; fi; \
	done; exit $$rc

# ---------- Debug helpers ----------
# Instruction trace of one program:  make run T=tt_demo
T ?= tt_demo
run: $(BUILD)/sc_sim $(BUILD)/$(T).hex
	$(VVP) -n $(BUILD)/sc_sim +hex=$(BUILD)/$(T).hex +trace

# Waveform of one program:  make wave T=tt_test   ->  waves/tt_test.vcd
wave: $(BUILD)/sc_sim $(BUILD)/$(T).hex
	@mkdir -p $(WAVES)
	$(VVP) -n $(BUILD)/sc_sim +hex=$(BUILD)/$(T).hex +vcd=$(WAVES)/$(T).vcd

clean:
	rm -rf $(BUILD) $(WAVES)
