SIM      ?= iverilog
VVP      ?= vvp
PYTHON   ?= python3
BUILD    := build
OUT      := $(BUILD)/tb_v1.vvp

RTL := \
	rtl/mod_add.v \
	rtl/mod_sub.v \
	rtl/mod_mul.v \
	rtl/sync_ram_dp.v \
	rtl/table_rom.v \
	rtl/poly_add_engine.v \
	rtl/pointwise_mul_engine.v \
	rtl/ntt_core.v

TB := tb/tb_v1.sv tb/hardwired_vectors.svh
TABLES := \
	table/twist_fwd.mem \
	table/twist_inv_scale.mem \
	table/twiddle_fwd.mem \
	table/twiddle_inv.mem

.PHONY: sim build golden tables expected clean

sim: $(OUT)
	$(VVP) $(OUT)

build: $(OUT)

$(OUT): $(RTL) $(TB) $(TABLES)
	mkdir -p $(BUILD)
	$(SIM) -g2012 -Irtl -Itb -Wall -o $@ $(RTL) tb/tb_v1.sv

golden:
	$(PYTHON) scripts/golden_model.py

tables:
	$(PYTHON) scripts/gen_tables.py

expected:
	$(PYTHON) scripts/update_expected_vectors.py

clean:
	rm -rf $(BUILD)
