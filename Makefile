# Placeholder until the first Lua file lands (block 4 onward).
# Every target must quote real command output — never claim a check passed.

FACTORIO ?= $(HOME)/.local/opt/factorio/bin/x64/factorio
LUAC    ?= luac

.PHONY: help check test package prices dump

help:
	@echo "check    - Lua syntax check over every .lua file"
	@echo "test     - headless Factorio scenario run (not implemented yet)"
	@echo "package  - build the mod zip for the portal (not implemented yet)"
	@echo "dump     - regenerate the prototype data dump from the installed game"
	@echo "prices   - recompute the price table from that dump"

dump:
	cd $(dir $(FACTORIO))../.. && ./bin/x64/factorio --dump-data
	@echo "dump written to script-output/data-raw-dump.json"

prices:
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
