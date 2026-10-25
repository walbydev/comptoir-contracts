# Commands for the mod. Every target must quote real command output — never claim a check passed.
#
# `luac` is NOT installed on the reference build machine, so `make check` only runs where Lua 5.2 was
# built; the real verification is a headless Factorio load (`FACTORIO=... make test`). No machine
# path belongs in this repository: FACTORIO is overridable and defaults to the PATH.

FACTORIO ?= factorio
LUAC    ?= luac

.PHONY: help check test package prices prices-md dump

help:
	@echo "check     - Lua syntax check over every .lua file (needs luac, not installed here)"
	@echo "test      - headless Factorio scenario run (not implemented yet)"
	@echo "package   - build the mod zip for the portal (not implemented yet)"
	@echo "dump      - regenerate the prototype data dump from the installed game"
	@echo "prices    - regenerate data/prices.lua from that dump (the mod's data file)"
	@echo "prices-md - print the same table as markdown (the table in docs/05-price-table.md)"

# The game writes the dump to its own write-data directory (app-root/script-output when the
# installation is a plain zip/unpacked build): no `cd` is needed, and none is done.
dump:
	$(FACTORIO) --dump-data
	@echo "dump written to script-output/data-raw-dump.json"

# data/prices.lua is committed (it is generated but shipped); this target must be diff-free when
# nothing moved. The write goes through a temporary file so a generator failure cannot truncate it.
prices:
	python3 tools/cost_table.py --lua > data/prices.lua.tmp
	mv data/prices.lua.tmp data/prices.lua
	@echo "wrote data/prices.lua"

prices-md:
	python3 tools/cost_table.py --markdown

check:
	@files=$$(find . -name '*.lua' -not -path './.git/*'); \
	if [ -z "$$files" ]; then echo "no .lua file yet — nothing to check"; exit 0; fi; \
	for f in $$files; do $(LUAC) -p "$$f" || exit 1; done; \
	echo "lua syntax OK: $$(echo $$files | wc -w) file(s)"

test:
	@echo "no test harness yet — arrives with the first control.lua"
	@exit 1

package:
	@echo "no packaging yet — arrives with the first release"
	@exit 1
