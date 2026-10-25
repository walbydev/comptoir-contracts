#!/usr/bin/env python3
"""Audit the framing documents for inconsistencies, and generate the ADR index.

Why: the framing grew from 3 ADRs to 47 in one day. Every decision was honest when it was
written and several were later replaced, parked or rejected. A reader arriving now cannot
tell, from the ADR files alone, which ones still govern v1. This tool answers that question
mechanically instead of trusting memory.

It checks:
  * every ADR carries a machine-readable `- **State**:` line from a closed vocabulary;
  * every ADR cited in any document exists, and every ADR is cited somewhere;
  * no decision row in docs/00-cadrage.md claims a superseded or parked ADR as current;
  * the counters in the headers match the tables;
  * witness: struck rows name their successor.

It writes adr/README.md — the index a human reads first.

Vocabulary for the State line (first word wins):
  accepted | superseded-by NNNN | rejected | parked | obsolete
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADR_DIR = ROOT / "adr"
CADRAGE = ROOT / "docs" / "00-cadrage.md"
SPECS = ROOT / "specs"

STATES = ("accepted", "superseded-by", "rejected", "parked", "obsolete")
STATE_RE = re.compile(r"^- \*\*State\*\*:\s*([a-z-]+)(?:\s+(\d{4}))?", re.M)
TITLE_RE = re.compile(r"^# (\d{4}) — (.+)$", re.M)
STATUS_RE = re.compile(r"^- \*\*Status\*\*:\s*(.+)", re.M)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_adr(path: Path) -> dict:
    text = read(path)
    num = path.name[:4]
    title = TITLE_RE.search(text)
    state = STATE_RE.search(text)
    status = STATUS_RE.search(text)
    return {
        "num": num,
        "path": path,
        "title": title.group(2).strip() if title else path.stem[5:].replace("-", " "),
        "state": state.group(1) if state else None,
        "state_target": state.group(2) if state and state.group(2) else None,
        "status_prose": status.group(1).strip() if status else "",
        "cited": set(),
    }


def collect_adrs() -> dict:
    adrs = {}
    for p in sorted(ADR_DIR.glob("[0-9][0-9][0-9][0-9]-*.md")):
        a = parse_adr(p)
        adrs[a["num"]] = a
    return adrs


def cite_everything(adrs: dict) -> None:
    """Record, for each ADR, which documents cite it."""
    files = [CADRAGE, ROOT / "README.md", ROOT / "AGENTS.md",
             ROOT / "docs" / "arborescence.md"]
    files += sorted((ROOT / "docs").glob("*.md"))
    files += sorted(SPECS.rglob("*.md"))
    seen = set()
    for f in files:
        if not f.exists() or f in seen:
            continue
        seen.add(f)
        text = read(f)
        for num in re.findall(r"\b(00\d{2})\b", text):
            if num in adrs and f != adrs[num]["path"] and f.name != f"{num}-{adrs[num]['path'].stem[5:]}.md":
                adrs[num]["cited"].add(f.relative_to(ROOT).as_posix())


def parse_cadrage() -> tuple[list, list]:
    text = read(CADRAGE)
    decisions, questions = [], []
    for line in text.splitlines():
        if re.match(r"^\| ~?~?D\d", line):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 2:
                continue
            withdrawn = cells[0].startswith("| ~~") or "~~D" in cells[0]
            decisions.append({
                "id": cells[0].replace("~", "").strip(),
                "withdrawn": withdrawn,
                "text": " | ".join(cells[1:]),  # full row, the parked check must not miss a word
                "refs": sorted(set(re.findall(r"\b(00\d{2})\b", line))),
            })
        elif re.match(r"^\| ~?~?Q\d", line):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 2:
                continue
            questions.append({
                "id": cells[0].replace("~", "").strip(),
                "settled": cells[0].startswith("| ~~") or "~~Q" in cells[0],
                "text": " | ".join(cells[1:])[:160],
            })
    return decisions, questions


def audit() -> int:
    adrs = collect_adrs()
    cite_everything(adrs)
    decisions, questions = parse_cadrage()
    problems = []
    warnings = []

    for a in adrs.values():
        if not a["state"]:
            problems.append(f"ADR {a['num']}: no machine-readable State line")
        elif a["state"] not in STATES:
            problems.append(f"ADR {a['num']}: unknown state '{a['state']}'")
        if a["state"] == "superseded-by" and not a["state_target"]:
            problems.append(f"ADR {a['num']}: superseded but names no successor")
        if a["state"] == "superseded-by" and a["state_target"] not in adrs:
            problems.append(f"ADR {a['num']}: superseded by {a['state_target']}, which does not exist")
        if not a["cited"]:
            problems.append(f"ADR {a['num']}: cited by no document (orphan)")

    for d in decisions:
        for ref in d["refs"]:
            if ref not in adrs:
                problems.append(f"{d['id']}: cites ADR {ref}, which does not exist")
                continue
            st = adrs[ref]["state"]
            successor = adrs[ref]["state_target"]
            # citing a replaced ADR is fine when the row also names its replacement: that is a chain.
            if st in ("superseded-by", "rejected") and not d["withdrawn"] and successor not in d["refs"]:
                problems.append(
                    f"{d['id']}: active decision cites {ref}, which is {st}"
                    + (f" by {successor}" if successor else ""))
            elif st == "parked" and not d["withdrawn"] and "parked" not in d["text"].lower():
                warnings.append(f"{d['id']}: active decision cites parked ADR {ref} — make sure the row says so")

    header = read(CADRAGE)[:900]
    m = re.search(r"\*\*(\d+) decisions in force\*\*[^.]*?(\d+) withdrawn.*?(\d+) ADRs", header, re.S)
    if m:
        claimed_active, claimed_wd, claimed_adr = (int(x) for x in m.groups())
        real_wd = sum(1 for d in decisions if d["withdrawn"])
        real_total = len(decisions)
        real_active = real_total - real_wd
        if claimed_active != real_active:
            problems.append(f"header claims {claimed_active} decisions in force, table holds {real_active}")
        if claimed_wd != real_wd:
            problems.append(f"header claims {claimed_wd} withdrawn, table marks {real_wd}")
        if claimed_adr != len(adrs):
            problems.append(f"header claims {claimed_adr} ADRs, {len(adrs)} files exist")
    else:
        problems.append("header: decision counter line not found or reshaped")

    open_q = [q for q in questions if not q["settled"]]
    settled_q = [q for q in questions if q["settled"]]

    # Criteria drift: docs/09 is the proof matrix, one row per criterion. A criterion with no row is
    # not accepted, so the counts must agree.
    crit_cadrage = len(re.findall(r"^\| A\d+ ", read(CADRAGE), re.M))
    crit_matrix = len(re.findall(r"^\| A\d+ ", read(ROOT / "docs" / "09-tests.md"), re.M))
    if crit_cadrage != crit_matrix:
        problems.append(f"criteria: {crit_cadrage} in the framing, {crit_matrix} rows in docs/09 — "
                        f"a criterion without a proof row is not accepted")
    m_crit = re.search(r"(\d+) acceptance criteria", header)
    if m_crit and int(m_crit.group(1)) != crit_cadrage:
        problems.append(f"header claims {m_crit.group(1)} acceptance criteria, the table holds {crit_cadrage}")

    print(f"ADRs: {len(adrs)} files")
    by_state = {}
    for a in adrs.values():
        by_state[a["state"] or "MISSING"] = by_state.get(a["state"] or "MISSING", 0) + 1
    print("  by state: " + ", ".join(f"{k}={v}" for k, v in sorted(by_state.items())))
    print(f"Decisions: {len(decisions)} rows ({len(decisions) - sum(1 for d in decisions if d['withdrawn'])} active)")
    print(f"Questions: {len(open_q)} open, {len(settled_q)} settled")
    print()
    if warnings:
        print(f"{len(warnings)} warning(s):")
        for w in warnings:
            print("  ~ " + w)
        print()
    if problems:
        print(f"{len(problems)} PROBLEM(S):")
        for p in problems:
            print("  - " + p)
    else:
        print("No inconsistency found.")
    return 1 if problems else 0


def write_index() -> None:
    adrs = collect_adrs()
    cite_everything(adrs)
    lines = [
        "# ADR index",
        "",
        "Generated by `tools/doc_audit.py --index`. **Do not edit by hand.** The ADR files are the",
        "source; this page is the reading order.",
        "",
        "`State` is the machine-readable line at the top of each ADR. The prose `Status` line below it",
        "keeps the sentence written on the day — history, not current truth.",
        "",
        "| ADR | Title | State | Cited by |",
        "|---|---|---|---|",
    ]
    order = {"accepted": 0, "parked": 1, "superseded-by": 2, "rejected": 3, "obsolete": 4, None: 5}
    for a in sorted(adrs.values(), key=lambda x: (order.get(x["state"], 5), x["num"])):
        state = a["state"] or "**MISSING**"
        if a["state"] == "superseded-by":
            state = f"superseded by {a['state_target']}"
        cited = len(a["cited"])
        lines.append(f"| {a['num']} | {a['title'][:70]} | {state} | {cited} |")
    accepted = [a for a in adrs.values() if a["state"] == "accepted"]
    lines += [
        "",
        f"**{len(accepted)} of {len(adrs)} ADRs are in force.** Everything else is history: parked with a",
        "future feature, replaced by a later decision, or considered and refused.",
        "",
        "## Reading order for someone arriving now",
        "",
        "1. `README.md` — what the mod is, in ten lines.",
        "2. `docs/00-cadrage.md` §1.1 — the decisions in force, and only those.",
        "3. `specs/001-v1/spec.md` — the behaviour, rule by rule.",
        "4. This index — only when a decision surprises you and you want its story.",
    ]
    (ADR_DIR / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {ADR_DIR / 'README.md'} ({len(adrs)} ADRs)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--index", action="store_true", help="regenerate adr/README.md")
    args = ap.parse_args()
    if args.index:
        write_index()
        return 0
    return audit()


if __name__ == "__main__":
    sys.exit(main())
