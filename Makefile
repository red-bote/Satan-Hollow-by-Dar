# Basys3 port driver (generic; per-machine values in machine.conf).
# See contrib/SPEC.md.
#
# User:  make roms bitstream load clean (open: Vivado GUI)
# Dev:   make pristine baseline patch project diffs check

include machine.conf

U := contrib/tools/user
D := contrib/tools/dev
PROMS_DONE := $(SRC_DIR)/$(PRJ_DIR)/proms/.done

.PHONY: help roms bitstream load open clean \
        pristine fetch extract normalize baseline patch project diffs check

help:
	@echo "User targets (fresh clone):"
	@echo "  roms       build make_vhdl_prom, unzip $(ROMSET) from ROMDIR (default ~/roms), generate PROM VHDL"
	@echo "  bitstream  Vivado batch build of $(SRC_DIR)/$(PRJ_DIR)/$(PRJ).xpr (runs roms if PROM VHDL is missing)"
	@echo "  load       program the bitstream into Basys3 SRAM"
	@echo "  open       open the project in the Vivado GUI"
	@echo "  clean      remove Vivado outputs, roms, generated PROM VHDL"
	@echo "Dev targets:"
	@echo "  pristine   delete $(SRC_DIR)/"
	@echo "  baseline   fetch + extract + normalize (then commit)"
	@echo "  patch      apply contrib/patches/*.patch in place"
	@echo "  project    generate the Vivado project from contrib/basys3/*.patch"
	@echo "  diffs      regenerate contrib/basys3/*.patch from the tracked project files"
	@echo "  check      pristine baseline patch project, then git diff --exit-code"

roms:
	$(U)/roms.sh

$(PROMS_DONE):
	$(U)/roms.sh

bitstream: $(PROMS_DONE)
	$(U)/bitstream.sh

load:
	openFPGALoader -b basys3 $(SRC_DIR)/$(PRJ_DIR)/$(PRJ).runs/impl_1/$(TOP).bit

open:
	$(U)/open.sh

clean:
	$(U)/clean.sh

pristine:
	rm -rf $(SRC_DIR)

fetch:
	$(D)/fetch.sh

extract: fetch
	unzip -q -o dloads/$(SRC_DIR).zip -d .

normalize:
	$(D)/normalize.sh $(SRC_DIR)

baseline: fetch extract normalize

patch:
	$(D)/apply_patches.sh

project:
	$(D)/project.sh

diffs:
	$(D)/diffs.sh

check:
	$(MAKE) pristine baseline patch project
	git diff --exit-code -- $(SRC_DIR)
