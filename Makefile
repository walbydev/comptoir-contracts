# Commands for the mod. Every target must quote real command output — never claim a check passed.
#
# `luac` is NOT installed on the reference build machine, so `make check` only runs where Lua 5.2 was
# built; the real verification is a headless Factorio load (`FACTORIO=... make test`). No machine
# path belongs in this repository: FACTORIO is overridable and defaults to the PATH.

FACTORIO ?= factorio
LUAC    ?= luac

.PHONY: help check check-lua check-locale test test-one package prices prices-md dump audit index

help:
	@echo "check     - L1 static gate: Lua syntax (luac) + locale keys (tools/check_locale.py)"
	@echo "test      - the bench: one scenario per criterion, both configurations (TEST_ARGS=...)"
	@echo "test-one  - one scenario, for a red/green demonstration (SCENARIO=a13)"
	@echo "package   - build the mod zip for the portal (not implemented yet)"
	@echo "dump      - regenerate the prototype data dump from the installed game"
	@echo "prices    - regenerate data/prices.lua from that dump (the mod's data file)"
	@echo "prices-md - print the same table as markdown (the table in docs/05-price-table.md)"
	@echo "audit     - check the framing documents for inconsistencies (exit 1 on a problem)"
	@echo "index     - regenerate adr/README.md from the ADR files"

# The framing outgrew human review: 47 ADRs, 77 decision rows. This checks the invariants that a
# reader would otherwise have to reconstruct by hand, and it is the gate before a tag.
audit:
	python3 tools/doc_audit.py

index:
	python3 tools/doc_audit.py --index
	@echo "wrote adr/README.md"

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

# The L1 gate: a PR is green on `make check` or it is not green. Both halves are here for that reason
# — `check-locale` is not a target someone has to remember to run (ADR 0053: the window shipped with
# every caption reading "Unknown key" while this file's syntax half was green).
check: check-lua check-locale

check-lua:
	@files=$$(find . -name '*.lua' -not -path './.git/*'); \
	if [ -z "$$files" ]; then echo "no .lua file yet — nothing to check"; exit 0; fi; \
	for f in $$files; do $(LUAC) -p "$$f" || exit 1; done; \
	echo "lua syntax OK: $$(echo $$files | wc -w) file(s)"

# Every `{"comptoir.<key>"}` in scripts/ and control.lua must exist under `[comptoir]` in BOTH locale
# files, every declared key must be printed somewhere, and every key name must match [a-z0-9-]+.
check-locale:
	python3 tools/check_locale.py

# The bench owns its own verdict: tools/run_tests.py starts Factorio once per scenario, in a
# throwaway install of its own, and exits non-zero when any run is red, when the log carries a Lua
# error, or when a result file never appeared. Override the binary with FACTORIO=..., and narrow with
# TEST_ARGS="--config vanilla --scenario a13".
TEST_ARGS ?= --config both

test:
	python3 tools/run_tests.py --factorio "$(FACTORIO)" $(TEST_ARGS)

# One scenario, both configurations, for the "break it and watch it go red" demonstration.
SCENARIO ?= a13
test-one:
	python3 tools/run_tests.py --factorio "$(FACTORIO)" --scenario $(SCENARIO)

package:
	@echo "no packaging yet — arrives with the first release"
	@exit 1
