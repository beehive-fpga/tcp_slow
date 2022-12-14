# Makefile

# defaults
SIM ?= Questa
TOPLEVEL_LANG ?= verilog

FLIST_NAME = tb_tcp_slow.flist
TOP_CORE_PKG = tb_tcp_slow

# This is already in the flist, but cocotb needs to receive at least one Verilog 
# source file I guess to kick the compilation. There's probably a better way to 
# hand it a dummy file, but just give it the top level for now I guess
VERILOG_SOURCES += $(PWD)/tb_tcp_slow.sv
COMPILE_ARGS += "-f $(PWD)/$(FLIST_NAME)"

SIM_ARGS = -voptargs=+acc
# SCRIPT_FILE = wave.do
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = tb_tcp_slow

# MODULE is the basename of the Python test file
MODULE = tb_tcp_slow

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

export BEEHIVE_DESIGN_ROOT=$(PWD)

.PHONY: gen_filelist
gen_filelist:
	export BEEHIVE_DESIGN_ROOT=$(PWD)
	fusesoc --config=$(PWD)/fusesoc.conf run --setup --target=sim --no-export uwcse:beehive:$(TOP_CORE_PKG)
	python3 $(BEEHIVE_PROJECT_ROOT)/util/scripts/generate_filelist.py --target=flist \
		--edam_file=build/uwcse_beehive_$(TOP_CORE_PKG)_0.1/sim-modelsim/uwcse_beehive_$(TOP_CORE_PKG)_0.1.eda.yml \
		--output_file=$(FLIST_NAME)

.PHONY: init_fusesoc
init_fusesoc:
	echo "[main]" > fusesoc.conf
	echo "cache_root = $(PWD)" >> fusesoc.conf
	fusesoc library add tcp_engine $(BEEHIVE_PROJECT_ROOT)/network_tiles/tcp/tcp_slow
	fusesoc library add basejump_modules $(BEEHIVE_PROJECT_ROOT)/network_tiles/tcp_hw/basejump_files
	fusesoc library add buckfast_ram $(BEEHIVE_PROJECT_ROOT)/network_tiles/tcp_hw/common
	fusesoc library add buckfast_includes $(BEEHIVE_PROJECT_ROOT)/network_tiles/tcp_hw/include
	fusesoc library add beehive_includes $(BEEHIVE_PROJECT_ROOT)/include
	fusesoc library add beehive_util $(BEEHIVE_PROJECT_ROOT)/util
