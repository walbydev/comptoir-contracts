#!/usr/bin/env python3
"""tools/run_tests.py — the bench runner: builds a throwaway install, runs one scenario per process.

Description
-----------
Runs `comptoir-test` against `comptoir-contracts` in a directory of its own, in one or both
configurations (without the Space Age DLC, with it), and reports one line per criterion.

Each scenario is a separate game process on a fresh copy of a save created for that configuration.
Three things are checked for every run, and all three must hold for the run to count as green:

1. the game's own log has no Lua error (`--benchmark` can exit 0 with a fatality already logged);
2. `test-results.json` exists, is fresh, and parses;
3. every entry in it has `status == "pass"`, at least one assertion, and no failure.

Usage
-----
    python3 tools/run_tests.py                 # both configurations, every scenario
    python3 tools/run_tests.py --config vanilla
    python3 tools/run_tests.py --scenario a13  # one scenario, for the red/green demonstration
    python3 tools/run_tests.py --list

Exit code is 0 only when every selected run is green in every selected configuration.

Written for the Factorio 2.1 CLI as measured on this machine (2026-10-25): `--config`, `--mod-directory`,
`--create`, `--benchmark`, `--benchmark-ticks`, `--start-server`, `--server-settings`. There is no
`--mod-settings`: the startup setting of the solvency dial is written by patching the generated
`mod-settings.dat` (see `write_mod_settings`), and the game is then *asked* what it read — A10 asserts
the profile it sees, so a patch that did not take is a red test, never a silent pass.

Licence: MIT (see LICENSE)
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MAIN_MOD = "comptoir-contracts"
TEST_MOD = "comptoir-test"
MOD_VERSION = "0.1.0"

DEFAULT_FACTORIO = Path("/opt/data/.local/opt/factorio/bin/x64/factorio")

CONFIGURATIONS = {
    "vanilla": ["base"],
    "space-age": ["base", "elevated-rails", "quality", "recycler", "space-age"],
}

# (scenario id, label, startup profile or None)
RUNS = [
    ("a1", "A1", None),
    ("a2", "A2", None),
    ("a3", "A3", None),
    ("a7", "A7", None),
    ("a9", "A9", None),
    ("a10", "A10/poor", "poor"),
    ("a10", "A10/rich", "rich"),
    ("a10", "A10/unlimited", "unlimited"),
    ("a13", "A13", None),
    ("a14", "A14", None),
    ("a15", "A15", None),
    ("a18", "A18", None),
    ("a19", "A19", None),
    ("a26", "A26", None),
    ("a28", "A28", None),
    ("a29", "A29", None),
    ("a30", "A30", None),
    ("a31", "A31", None),
    ("b1-gui-pure", "B1-gui-pure", None),
]

SOLVENCY_SETTING = "comptoir-solvency"

LOG_PATTERNS = [
    "Error while running event",
    "Lua error",
    "Error in",
    "FATAL",
    "cannot be loaded",
    "Failed to load",
    "Unknown item name",
    "attempt to index",
    "attempt to call",
    "Unknown interface",
    "error(s) found",
]


# --------------------------------------------------------------------------------------------------
# Small shell helpers
# --------------------------------------------------------------------------------------------------


def log(message: str) -> None:
    print(message, flush=True)


def install_root(factorio: Path) -> Path:
    """The unpacked game directory: the first ancestor that has both `data` and `config`."""
    for candidate in [factorio.parent, *factorio.parents]:
        if (candidate / "data").is_dir() and (candidate / "config").is_dir():
            return candidate
    raise SystemExit(f"no game directory above {factorio} (expected a folder with data/ and config/)")


def run_capture(command: list[str], timeout: float) -> tuple[int, str]:
    """Run a short-lived command (map creation) and return (exit code, combined output)."""
    try:
        finished = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as expired:
        output = expired.output or b""
        return 124, output.decode("utf-8", "replace")
    return finished.returncode, finished.stdout.decode("utf-8", "replace")


# --------------------------------------------------------------------------------------------------
# mod-settings.dat: the startup profile of the dial
# --------------------------------------------------------------------------------------------------


def write_mod_settings(target: Path, profile: str, template: bytes) -> None:
    """Write a `mod-settings.dat` that carries `profile` for `SOLVENCY_SETTING`.

    The file is a property tree: a name is `<len byte><bytes>`, a string value is
    `<len byte><bytes>\\x00`. We locate `value` after our setting's name, then the length-prefixed
    string that follows it, and replace that segment in place — no other byte moves, so a value of a
    different length stays valid. The result is re-read before being written, and A10 asserts the
    value the game actually saw: a wrong patch is a red test, not a green one.
    """
    key = SOLVENCY_SETTING.encode()
    start = template.find(key)
    if start < 0:
        raise SystemExit(
            f"mod-settings.dat does not mention {SOLVENCY_SETTING}: run the game once so that it writes "
            "its settings file, then try again"
        )
    value_word = template.find(b"value", start)
    if value_word < 0:
        raise SystemExit("mod-settings.dat: no 'value' node under the setting")
    # The current value is the length-prefixed string right after the node's type bytes.
    for offset in range(value_word + len(b"value"), value_word + len(b"value") + 8):
        length = template[offset]
        end = offset + 1 + length
        if 0 < length < 64 and end + 1 <= len(template) and template[end] == 0:
            candidate = template[offset + 1 : end]
            if all(32 <= byte < 127 for byte in candidate):
                encoded = profile.encode()
                patched = template[:offset] + bytes([len(encoded)]) + encoded + template[end:]
                if patched.find(key) < 0 or profile.encode() not in patched:
                    raise SystemExit("mod-settings.dat: patch did not land")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(patched)
                return
    raise SystemExit("mod-settings.dat: could not find the value string of the setting")


def read_mod_settings(path: Path, name: str) -> str | None:
    """Read back the value we wrote, for the runner's own sanity line."""
    if not path.exists():
        return None
    data = path.read_bytes()
    start = data.find(name.encode())
    if start < 0:
        return None
    value_word = data.find(b"value", start)
    if value_word < 0:
        return None
    for offset in range(value_word + len(b"value"), value_word + len(b"value") + 8):
        length = data[offset]
        end = offset + 1 + length
        if 0 < length < 64 and end + 1 <= len(data) and data[end] == 0:
            candidate = data[offset + 1 : end]
            if all(32 <= byte < 127 for byte in candidate):
                return candidate.decode()
    return None


# --------------------------------------------------------------------------------------------------
# Preparing a run directory
# --------------------------------------------------------------------------------------------------


def copy_mod(source: Path, destination: Path) -> None:
    """Copy the files a mod needs at runtime, and nothing else (no tests, no docs, no git)."""
    destination.mkdir(parents=True, exist_ok=True)
    wanted_files = ["info.json", "data.lua", "control.lua", "settings.lua", "changelog.txt", "LICENSE"]
    wanted_dirs = ["config", "scripts", "data", "locale", "graphics", "migrations"]
    for name in wanted_files:
        candidate = source / name
        if candidate.is_file():
            shutil.copy2(candidate, destination / name)
    for name in wanted_dirs:
        candidate = source / name
        if candidate.is_dir():
            shutil.copytree(candidate, destination / name, dirs_exist_ok=True)
    for name in ("scenario.lua",):
        candidate = source / name
        if candidate.is_file():
            shutil.copy2(candidate, destination / name)


def write_mod_list(path: Path, configuration: str) -> None:
    mods = [{"name": name, "enabled": True} for name in CONFIGURATIONS[configuration]]
    mods.append({"name": MAIN_MOD, "enabled": True})
    mods.append({"name": TEST_MOD, "enabled": True})
    path.write_text(json.dumps({"mods": mods}, indent=2) + "\n")


def write_config_ini(factorio: Path, target: Path, write_data: Path) -> None:
    template = install_root(factorio) / "config" / "config.ini"
    if not template.is_file():
        raise SystemExit(f"no config.ini next to the binary: {template}")
    lines = template.read_text().splitlines()
    out = []
    seen_write = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("write-data="):
            out.append(f"write-data={write_data}")
            seen_write = True
        else:
            out.append(line)
    if not seen_write:
        raise SystemExit("config.ini has no write-data line; the runner needs one to redirect the install")
    target.write_text("\n".join(out) + "\n")


def write_selector(test_mod_dir: Path, scenario: str | None, params: dict | None) -> None:
    """Rewrite `scenario.lua` of the test mod: the only way a mod learns which scenario to run."""
    if scenario is None:
        body = 'return {\n  id = "all",\n  params = nil,\n}\n'
    else:
        rendered = "nil"
        if params:
            fields = []
            for key, value in params.items():
                if isinstance(value, str):
                    fields.append(f'    {key} = "{value}",')
                else:
                    fields.append(f"    {key} = {value},")
            rendered = "{\n" + "\n".join(fields) + "\n  }"
        body = f'return {{\n  id = "{scenario}",\n  params = {rendered},\n}}\n'
    (test_mod_dir / "scenario.lua").write_text(body)


def find_template_settings(factorio: Path, scratch: Path) -> bytes:
    """Find a `mod-settings.dat` we are allowed to copy as a template.

    Order: the runner's own previous run (it is regenerated by the game), then the installed
    write-data. If none exists we ask the game to create one by creating a throwaway map.
    """
    candidates = [
        scratch / "template" / "mod-settings.dat",
        install_root(factorio) / "mods" / "mod-settings.dat",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.read_bytes()
    raise SystemExit(
        "no mod-settings.dat template found: run `make test` once so that the game writes one, "
        "or copy the installed one into out/tests/template/mod-settings.dat"
    )


def prepare(
    rundir: Path,
    factorio: Path,
    configuration: str,
    scenario: str | None,
    profile: str | None,
    params: dict | None,
) -> tuple[Path, Path, Path]:
    """Build (or rebuild) a complete throwaway install for one run."""
    if rundir.exists():
        shutil.rmtree(rundir)
    mods_dir = rundir / "mods"
    write_dir = rundir / "write"
    saves_dir = rundir / "saves"
    for directory in (mods_dir, write_dir, saves_dir):
        directory.mkdir(parents=True, exist_ok=True)

    main_dir = mods_dir / f"{MAIN_MOD}_{MOD_VERSION}"
    test_dir = mods_dir / f"{TEST_MOD}_{MOD_VERSION}"
    copy_mod(REPO, main_dir)
    copy_mod(REPO / "test-mod" / f"{TEST_MOD}_{MOD_VERSION}", test_dir)
    write_selector(test_dir, scenario, params)
    write_mod_list(mods_dir / "mod-list.json", configuration)
    write_config_ini(factorio, rundir / "config.ini", write_dir)

    if profile is not None:
        template = find_template_settings(factorio, REPO / "out" / "tests")
        write_mod_settings(mods_dir / "mod-settings.dat", profile, template)
        # The game may look for the settings next to the write-data instead of the mod directory.
        (write_dir / "mods").mkdir(parents=True, exist_ok=True)
        shutil.copy2(mods_dir / "mod-settings.dat", write_dir / "mods" / "mod-settings.dat")

    return mods_dir, write_dir, saves_dir


def factorio_command(factorio: Path, rundir: Path, mods_dir: Path) -> list[str]:
    return [str(factorio), "--config", str(rundir / "config.ini"), "--mod-directory", str(mods_dir)]


# --------------------------------------------------------------------------------------------------
# One run
# --------------------------------------------------------------------------------------------------


def results_path(write_dir: Path) -> Path:
    return write_dir / "script-output" / "test-results.json"


def log_errors(log_file: Path) -> list[str]:
    if not log_file.is_file():
        return ["no log file was written"]
    text = log_file.read_text(errors="replace")
    found = []
    for pattern in LOG_PATTERNS:
        for line in text.splitlines():
            if pattern in line:
                found.append(line.strip())
    return found


def wait_for_file(path: Path, process: subprocess.Popen, deadline: float) -> bool:
    while time.monotonic() < deadline:
        if path.is_file():
            # Let the writer finish: a half file is not a result.
            size = -1
            for _ in range(20):
                current = path.stat().st_size
                if current == size and current > 0:
                    return True
                size = current
                time.sleep(0.1)
            return True
        if process.poll() is not None:
            return path.is_file()
        time.sleep(0.2)
    return False


def stop(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=8)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=8)


def run_game(command: list[str], path_to_watch: Path, write_dir: Path, timeout: float, stdin_data: bytes = b"") -> dict:
    """Start the game, wait for the file it must produce, stop it, and judge the run."""
    started = time.monotonic()
    process = subprocess.Popen(
        command,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    try:
        if stdin_data and process.stdin is not None:
            try:
                process.stdin.write(stdin_data)
                process.stdin.flush()
            except (BrokenPipeError, ValueError):
                pass
        found = wait_for_file(path_to_watch, process, started + timeout)
        exit_code = process.poll()
    finally:
        stop(process)
    elapsed = time.monotonic() - started
    return {
        "found": found,
        "exit": exit_code,
        "elapsed": elapsed,
        "log_errors": log_errors(write_dir / "factorio-current.log"),
        "log_file": write_dir / "factorio-current.log",
    }


def tail(path: Path, lines: int = 25) -> str:
    if not path.is_file():
        return ""
    content = path.read_text(errors="replace").splitlines()
    return "\n".join(content[-lines:])


def create_map(factorio: Path, rundir: Path, mods_dir: Path, save: Path, timeout: float = 180.0) -> dict:
    command = factorio_command(factorio, rundir, mods_dir) + ["--create", str(save)]
    code, output = run_capture(command, timeout)
    return {"exit": code, "output": output, "save": save}


def remember_settings(mods_dir: Path, write_dir: Path, template_dir: Path) -> bool:
    """Keep the `mod-settings.dat` the game just used, as the template for the next patch."""
    for candidate in (mods_dir / "mod-settings.dat", write_dir / "mods" / "mod-settings.dat"):
        if candidate.is_file():
            template_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidate, template_dir / "mod-settings.dat")
            return True
    return False


def ensure_template(factorio: Path, base: Path, configuration: str) -> bool:
    """Make sure a settings template exists before a run that needs to patch it (A10)."""
    template_dir = base / "template"
    if (template_dir / "mod-settings.dat").is_file():
        return True
    rundir = base / "_template"
    mods_dir, write_dir, saves_dir = prepare(rundir, factorio, configuration, "a1", None, None)
    created = create_map(factorio, rundir, mods_dir, saves_dir / "template.zip")
    ok = created["exit"] == 0 and remember_settings(mods_dir, write_dir, template_dir)
    shutil.rmtree(rundir, ignore_errors=True)
    return ok


# --------------------------------------------------------------------------------------------------
# Judging
# --------------------------------------------------------------------------------------------------


def judge(run: dict, expected_label: str) -> dict:
    """Turn one game run into a verdict: log, file, parse, statuses."""
    verdict = {
        "label": expected_label,
        "green": False,
        "notes": [],
        "checks": 0,
        "failures": 0,
        "log_errors": run["log_errors"],
        "elapsed": run["elapsed"],
    }
    if run["log_errors"]:
        verdict["notes"].append("log errors: " + " | ".join(run["log_errors"][:4]))
    payload = None
    if run["found"]:
        try:
            payload = json.loads(results_path(run["write_dir"]).read_text())
        except (json.JSONDecodeError, OSError) as error:
            verdict["notes"].append(f"unreadable test-results.json: {error}")
    else:
        verdict["notes"].append("test-results.json never appeared")
    if payload is not None:
        verdict["tick"] = payload.get("tick")
        entries = payload.get("tests", [])
        if not entries:
            verdict["notes"].append("no test entry in test-results.json")
        for entry in entries:
            verdict["checks"] += entry.get("checks", 0)
            verdict["failures"] += entry.get("failures", 0)
            if entry.get("status") != "pass":
                verdict["notes"].append(f"{entry.get('id')} {entry.get('status')}: " + " | ".join(entry.get("detail", [])[:3]))
            else:
                for line in entry.get("detail", []):
                    if line.startswith("NOTE "):
                        verdict["notes"].append(line[5:])
    verdict["green"] = (
        run["found"]
        and payload is not None
        and not run["log_errors"]
        and verdict["checks"] > 0
        and verdict["failures"] == 0
        and not any("status" in note for note in verdict["notes"])
    )
    return verdict


# --------------------------------------------------------------------------------------------------
# The two halves of the mid-flight save
# --------------------------------------------------------------------------------------------------


def run_server_save(ctx: dict, save: Path) -> dict:
    """Phase 1: play until the car is in the air, save the map, stop.

    A save is never written by the benchmark mode (measured): the persistence proof needs a server.
    """
    rundir, factorio, mods_dir, write_dir = ctx["rundir"], ctx["factorio"], ctx["mods_dir"], ctx["write_dir"]
    server_settings = rundir / "server-settings.json"
    server_settings.write_text(
        json.dumps(
            {
                "name": "comptoir bench",
                "description": "throwaway",
                "tags": [],
                "max_players": 0,
                "visibility": {"public": False, "lan": False},
                "username": "bench",
                "password": "",
                "token": "",
                "game_password": "",
                "require_user_verification": False,
                "max_upload_in_kilobytes_per_second": 0,
                "max_upload_slots": 0,
                "minimum_latency_in_ticks": 0,
                "ignore_player_limit_for_returning_players": True,
                "allow_commands": "admins-only",
                "autosave_interval": 0,
                "autosave_slots": 0,
                "afk_autokick_interval": 0,
                "auto_pause": False,
                "only_admins_can_pause_the_game": False,
                "autosave_only_on_server": True,
                "non_blocking_saving": False,
                "minimum_segment_size": 25,
                "minimum_segment_size_peer_count": 20,
                "maximum_segment_size": 100,
                "maximum_segment_size_peer_count": 10,
            },
            indent=2,
        )
        + "\n"
    )
    command = factorio_command(factorio, rundir, mods_dir) + [
        "--start-server",
        str(save),
        "--server-settings",
        str(server_settings),
    ]
    marker = write_dir / "script-output" / "mid-flight.json"
    run = run_game(command, marker, write_dir, ctx["timeout"])
    run["write_dir"] = write_dir
    if not marker.is_file():
        run["found"] = False
        return run
    try:
        run["marker"] = json.loads(marker.read_text())
    except json.JSONDecodeError as error:
        run["log_errors"] = run["log_errors"] + [f"unreadable mid-flight.json: {error}"]
    return run


# --------------------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------------------


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Run the comptoir-contracts test bench.")
    parser.add_argument("--factorio", default=os.environ.get("FACTORIO_BIN", str(DEFAULT_FACTORIO)))
    parser.add_argument("--config", dest="configuration", default="both", choices=["both", "vanilla", "space-age"])
    parser.add_argument("--scenario", default=None, help="run a single scenario id (a1 … a30, a9-save, a9-resume)")
    parser.add_argument("--profile", default=None, choices=["poor", "rich", "unlimited"], help="startup profile for a10")
    parser.add_argument("--timeout", type=float, default=240.0, help="seconds per game run")
    parser.add_argument("--keep", action="store_true", help="keep the run directories")
    parser.add_argument("--list", action="store_true", help="list the runs and exit")
    args = parser.parse_args(argv)

    if args.list:
        for scenario, label, profile in RUNS:
            log(f"{label:<14} {scenario:<10} profile={profile or '-'}")
        log("A9/save + A9/resume  a9-save / a9-resume (server mode, then benchmark on the save)")
        return 0

    factorio = Path(args.factorio)
    if not factorio.is_file():
        log(f"error: no factorio binary at {factorio} (use --factorio or FACTORIO_BIN)")
        return 2

    configurations = list(CONFIGURATIONS) if args.configuration == "both" else [args.configuration]
    runs = RUNS
    if args.scenario is not None:
        runs = [entry for entry in RUNS if entry[0] == args.scenario]
        if args.profile is not None:
            runs = [entry for entry in runs if entry[2] == args.profile]
        if not runs and args.scenario not in ("a9-save", "a9-resume"):
            log(f"error: no run matches --scenario {args.scenario} --profile {args.profile}")
            return 2

    verdicts = []
    reports = []
    for configuration in configurations:
        log(f"=== configuration: {configuration} ===")
        base = REPO / "out" / "tests"
        template_dir = base / "template"
        template_dir.mkdir(parents=True, exist_ok=True)
        if any(profile for _, _, profile in runs):
            if not ensure_template(factorio, base, configuration):
                log("warning: no mod-settings.dat template could be produced; the a10 runs will fail loudly")

        for scenario, label, profile in runs:
            rundir = base / configuration / f"{label.replace('/', '-')}"
            params = {"profile": profile} if profile is not None else None
            mods_dir, write_dir, saves_dir = prepare(rundir, factorio, configuration, scenario, profile, params)
            save = saves_dir / "bench.zip"
            created = create_map(factorio, rundir, mods_dir, save)
            if created["exit"] != 0:
                verdicts.append(
                    {
                        "label": label,
                        "green": False,
                        "notes": [f"map creation failed (exit {created['exit']}): {created['output'][-400:]}"],
                        "checks": 0,
                        "failures": 1,
                        "log_errors": [],
                        "elapsed": 0.0,
                    }
                )
                log(f"FAIL {label:<14} map creation (exit {created['exit']})")
                continue
            # Keep a copy of the settings the game just used, as the template for the next patch.
            remember_settings(mods_dir, write_dir, template_dir)

            command = factorio_command(factorio, rundir, mods_dir) + [
                "--benchmark",
                str(save),
                "--benchmark-ticks",
                "400000",
            ]
            run = run_game(command, results_path(write_dir), write_dir, args.timeout)
            run["write_dir"] = write_dir
            verdict = judge(run, label)
            if profile is not None:
                seen = read_mod_settings(mods_dir / "mod-settings.dat", SOLVENCY_SETTING)
                verdict["notes"].append(f"startup profile written: {seen}")
            verdict["configuration"] = configuration
            verdicts.append(verdict)
            reports.append({"configuration": configuration, "label": label, "verdict": verdict})
            mark = "PASS" if verdict["green"] else "FAIL"
            log(f"{mark} {label:<14} {verdict['checks']:>3} checks, {verdict['failures']} failures, {verdict['elapsed']:.1f}s")
            for note in verdict["notes"]:
                log(f"       {note}")

        # The mid-flight save, in server mode, then the resume on the saved map.
        if args.scenario in (None, "a9-save", "a9-resume"):
            label = "A9/resume"
            rundir = base / configuration / "A9-save"
            mods_dir, write_dir, saves_dir = prepare(rundir, factorio, configuration, "a9-save", None, None)
            save = saves_dir / "bench.zip"
            created = create_map(factorio, rundir, mods_dir, save)
            created_mtime = save.stat().st_mtime if save.is_file() else 0.0
            if created["exit"] != 0:
                verdicts.append(
                    {
                        "label": "A9/save",
                        "green": False,
                        "notes": [f"map creation failed: {created['output'][-400:]}"],
                        "checks": 0,
                        "failures": 1,
                        "log_errors": [],
                        "elapsed": 0.0,
                        "configuration": configuration,
                    }
                )
                log("FAIL A9/save        map creation")
            else:
                remember_settings(mods_dir, write_dir, template_dir)
                context = {
                    "rundir": rundir,
                    "factorio": factorio,
                    "mods_dir": mods_dir,
                    "write_dir": write_dir,
                    "timeout": args.timeout,
                }
                first = run_server_save(context, save)
                verdict_first = {
                    "label": "A9/save",
                    "green": bool(first.get("found") and not first["log_errors"]),
                    "notes": [f"saved at tick {first.get('marker', {}).get('tick')}"]
                    if first.get("marker")
                    else ["mid-flight.json never appeared"],
                    "checks": 1 if first.get("marker") else 0,
                    "failures": 0 if first.get("found") else 1,
                    "log_errors": first["log_errors"],
                    "elapsed": first["elapsed"],
                    "configuration": configuration,
                }
                if first["log_errors"]:
                    verdict_first["green"] = False
                    verdict_first["notes"].append("log errors: " + " | ".join(first["log_errors"][:3]))
                verdicts.append(verdict_first)
                log(f"{'PASS' if verdict_first['green'] else 'FAIL'} {'A9/save':<14} {verdict_first['elapsed']:.1f}s")
                for note in verdict_first["notes"]:
                    log(f"       {note}")

                marker = first.get("marker")
                if marker:
                    # The mid-flight map IS the shutdown save: `game.server_save` returns without
                    # writing anything on a headless server (measured), while the server's own save
                    # on SIGTERM overwrites the map it was started from. So the artifact is that
                    # file, and it must be newer than the map we created a moment ago.
                    saved_map = saves_dir / "bench.zip"
                    saved_fresh = saved_map.is_file() and saved_map.stat().st_mtime > created_mtime
                    if not saved_fresh:
                        log("       the server did not save the map on shutdown: skipping the resume half")
                        saved_map = None
                    if saved_map is not None and saved_map.is_file():
                        resume_dir = base / configuration / "A9-resume"
                        resume_mods, resume_write, resume_saves = prepare(
                            resume_dir, factorio, configuration, "a9-resume", None, marker
                        )
                        shutil.copy2(saved_map, resume_saves / "mid-flight.zip")
                        command = factorio_command(factorio, resume_dir, resume_mods) + [
                            "--benchmark",
                            str(resume_saves / "mid-flight.zip"),
                            "--benchmark-ticks",
                            "400000",
                        ]
                        run = run_game(command, results_path(resume_write), resume_write, args.timeout)
                        run["write_dir"] = resume_write
                        verdict = judge(run, label)
                        verdict["configuration"] = configuration
                        verdicts.append(verdict)
                        reports.append({"configuration": configuration, "label": label, "verdict": verdict})
                        mark = "PASS" if verdict["green"] else "FAIL"
                        log(f"{mark} {label:<14} {verdict['checks']:>3} checks, {verdict['failures']} failures, {verdict['elapsed']:.1f}s")
                        for note in verdict["notes"]:
                            log(f"       {note}")
                    else:
                        log("       the save taken by the server was not found: skipping the resume half")

    log("")
    log("=== summary ===")
    total = len(verdicts)
    green = sum(1 for verdict in verdicts if verdict["green"])
    for verdict in verdicts:
        mark = "PASS" if verdict["green"] else "FAIL"
        log(f"{mark}  {verdict.get('configuration', '?'):<10} {verdict['label']:<14} {verdict['checks']:>3} checks")
    log(f"{green}/{total} runs green")

    report = {
        "generated_by": "tools/run_tests.py",
        "configurations": configurations,
        "runs": [
            {
                "configuration": verdict.get("configuration"),
                "label": verdict["label"],
                "green": verdict["green"],
                "checks": verdict["checks"],
                "failures": verdict["failures"],
                "elapsed_seconds": round(verdict["elapsed"], 2),
                "notes": verdict["notes"],
                "log_errors": verdict["log_errors"],
            }
            for verdict in verdicts
        ],
    }
    (REPO / "out" / "tests").mkdir(parents=True, exist_ok=True)
    (REPO / "out" / "tests" / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    log("report: out/tests/report.json")

    if not args.keep:
        for configuration in configurations:
            for child in (REPO / "out" / "tests" / configuration).glob("*"):
                if child.is_dir():
                    shutil.rmtree(child, ignore_errors=True)

    return 0 if green == total and total > 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
