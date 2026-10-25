# Smoke test — is this machine able to load a mod at all?

Throwaway, 2026-10-25. It answers one question and then it should be deleted: **can this machine load
an unzipped mod, run `data.lua`, and run `control.lua`?** Nothing about `comptoir-contracts` is tested
here.

## Result — measured on this box, 2026-10-25

The first version of this smoke test **failed**, and that is its whole value:

```
Error while running event comptoir-smoke::on_init()
LuaGameScript doesn't contain key write_file.
```

**`game.write_file` does not exist in 2.1.23.** It was the API the test harness design assumed. The
replacement is **`helpers.write_file(filename, data, append, for_player)`**, which works and writes to
`<write-data>/script-output/`. Verified: the file contains `written by helpers.write_file, tick 0`.

Consequences, applied the same day: `docs/09-tests.md` and ADR `0042` now name `helpers.write_file`, and
`AGENTS.md` carries the rule. A harness built on the old name would have failed at its first assertion,
after the code was written — which is the expensive moment.

## On the requester's machine (graphical client, Linux or Windows)

The mod directory is `~/.factorio/mods` on Linux, `%APPDATA%\Factorio\mods` on Windows. Do **not** put
it there if you value your saves — use a separate directory.

```bash
mkdir -p ~/comptoir-dev/vanilla
cp -r comptoir-smoke_0.0.1 ~/comptoir-dev/vanilla/
factorio --mod-directory ~/comptoir-dev/vanilla
```

Then in game: **Settings → Mods**, `Comptoir smoke test` must be listed and enabled. Start any new map
and look for the item **Comptoir smoke token** in the inventory crafting panel (it has no recipe, so it
appears in the item list, not as a craftable).

Check the third stage:

```bash
cat ~/.factorio/script-output/comptoir-smoke.txt
# control stage OK, tick 0
```

If the file exists and the item is visible, the chain works and real development can start. If the item
is missing, `data.lua` did not run. If the file is missing but the item exists, `control.lua` did not
run — and the log (`factorio-current.log`) says why.

## On this box (headless, no display)

Here the same mod is loaded without a client:

```bash
cd /opt/data/.local/opt/factorio
./bin/x64/factorio --mod-directory <dir> --create /tmp/smoke.zip
ls script-output/comptoir-smoke.txt
```

A map that generates without an error proves `data.lua`; the file proves `control.lua`. This is the
same two-stage check the test harness will use, which is why the smoke test is worth five minutes: it
validates the harness's own foundation before anything is built on it.
