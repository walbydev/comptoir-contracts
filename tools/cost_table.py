#!/usr/bin/env python3
"""Compute the canonical production cost of an item from the game's own data.

Why this script exists: the price table of `comptoir-contracts` must not be a table of
numbers someone guessed. It is derived from recipes, and recipes change between game
versions. When Factorio 2.2 lands, this script is re-run and the table is regenerated;
that is the whole point of keeping it in the repository.

Source of truth: `factorio --dump-data` writes `script-output/data-raw-dump.json`
(measured: 29 MB with base + space-age, 662 recipes, Factorio 2.1.23 build 87750).

Cost model, in raw-material units ("1 unit = one ore-equivalent"):

    raw(item) = sum over raw resources of amount * weight

- Solid ore, stone and coal weigh 1.
- Crude oil weighs 2: one unit of it feeds several products after refining.
- Water weighs 0: it is free and infinite.
- Everything else recurses into its ingredients, and a multi-output recipe splits its
  input cost across its results in proportion to their amounts.

Machine time (`energy_required`, in seconds at crafting speed 1) and a reference energy
figure are measured and printed, but they are NOT part of the cost. Rationale: a
solar-powered base produces for free, so charging energy would punish the player who
builds cleanly, and time is a throughput constraint, not a material one.

Usage:
    python3 tools/cost_table.py                 # the v1 candidate list
    python3 tools/cost_table.py --all           # every craftable item
    python3 tools/cost_table.py --dump PATH     # another data dump
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

DEFAULT_DUMP = "/opt/data/.local/opt/factorio/script-output/data-raw-dump.json"

# Raw resources: the recursion stops here. The rule is one raw resource = one unit,
# except water (free and infinite) and uranium (four times scarcer than iron).
# Oil does NOT get a weight: its real cost already shows up in the recipes, since basic
# oil processing turns 100 crude oil into 45 petroleum gas. That 55 % loss is the cost.
RAW_WEIGHTS = {
    "iron-ore": 1.0,
    "copper-ore": 1.0,
    "stone": 1.0,
    "coal": 1.0,
    "uranium-ore": 4.0,
    "wood": 1.0,
    "crude-oil": 1.0,
    "water": 0.0,
}

# Reference machine per recipe category, for the energy column only.
CATEGORY_POWER_KW = {
    "smelting": 90.0,          # stone furnace
    "crafting": 150.0,         # assembling machine 2
    "crafting-with-fluid": 180.0,
    "chemistry": 180.0,
    "oil-processing": 420.0,
    "centrifuging": 350.0,
    "electronics": 150.0,
    "electromagnetics": 150.0,
    "rocket-building": 480.0,
}

# The v1 counter list: materials only, no buildings (decided 2026-10-25).
V1_ITEMS = [
    # tier 1
    "iron-plate", "copper-plate", "steel-plate", "stone-brick",
    "iron-gear-wheel", "copper-cable", "electronic-circuit",
    # tier 2
    "pipe", "plastic-bar", "sulfur", "engine-unit", "battery", "advanced-circuit",
    # tier 3
    "low-density-structure", "processing-unit", "electric-engine-unit",
]

CREDITS_PER_UNIT = 10  # scale: one ore-equivalent = 10 credits, so the table stays integral
PAYOUT_FACTOR = 1.15   # D46 band: cost < payout < price
PRICE_FACTOR = 1.50    # D46 band: price = cost * 1.5


def load(dump_path: str) -> dict:
    with open(dump_path, encoding="utf-8") as fh:
        return json.load(fh)


def build_index(data: dict) -> dict[str, list[dict]]:
    """item name -> recipes that produce it, primary product first."""
    index: dict[str, list[dict]] = {}
    for recipe in data["recipe"].values():
        results = recipe.get("results") or []
        main = recipe.get("main_product")
        if main:
            results = sorted(results, key=lambda r: r["name"] != main)
        for res in results:
            index.setdefault(res["name"], []).append(recipe)
    return index


class Cost:
    def __init__(self, data: dict):
        self.recipes = data["recipe"]
        self.index = build_index(data)
        self.memo: dict[str, float] = {}
        self.memo_time: dict[str, float] = {}
        self.memo_energy: dict[str, float] = {}
        self.unresolved: set[str] = set()
        self.stack: set[str] = set()
        self.memo_fluid: dict[str, bool] = {}
        self.memo_depth: dict[str, int] = {}
        self.recipe_tech = self._recipe_technologies(data)

    @staticmethod
    def _recipe_technologies(data: dict) -> dict[str, dict]:
        """recipe name -> the technology that unlocks it (with its science packs)."""
        out: dict[str, dict] = {}
        for tech in (data.get("technology") or {}).values():
            for effect in tech.get("effects") or []:
                if effect.get("type") == "unlock-recipe":
                    out.setdefault(effect["recipe"], tech)
        return out

    def _tech_of(self, item: str) -> dict | None:
        recipe = self._pick(item)
        if not recipe:
            return None
        return self.recipe_tech.get(recipe["name"])

    def science_packs(self, item: str) -> list[str]:
        tech = self._tech_of(item)
        if not tech:
            return []
        unit = tech.get("unit") or {}
        packs = []
        for ing in unit.get("ingredients") or []:
            # the dump writes these as ["automation-science-pack", 1]
            if isinstance(ing, (list, tuple)):
                packs.append(str(ing[0]))
            elif isinstance(ing, dict):
                packs.append(ing["name"])
        return packs

    def tier(self, item: str) -> int:
        """Tier = how deep the item sits in the oil chain. Measured, not chosen.

        The first attempt used science packs ("the highest pack that unlocks the recipe")
        and it lies: in base 2.1.23, `advanced-circuit` is unlocked by a technology that
        costs only red and green science, while the item needs plastic, therefore oil, so a
        contract could ask for one before the player can possibly build it. What gates an
        item is not the colour of its research, it is whether the chain is reachable:

            0  no fluid anywhere in the tree            -> tier 1 (pre-oil)
            1  needs an oil product directly            -> tier 2
            2  needs an item that needs oil             -> tier 2
            3+ needs a chain of oil-based items         -> tier 3
        """
        depth = self.oil_depth(item)
        if depth == 0:
            return 1
        if depth <= 2:
            return 2
        return 3

    def oil_depth(self, item: str) -> int:
        """0 if the recipe tree contains no fluid, else 1 + the deepest oiled ingredient."""
        if item in RAW_WEIGHTS:
            return 1 if item == "crude-oil" else 0
        if item in self.memo_depth:
            return self.memo_depth[item]
        if item in self.stack:
            return 0
        recipe = self._pick(item)
        if not recipe:
            return 0
        self.stack.add(item)
        depth = 0
        for ing in recipe.get("ingredients") or []:
            if ing.get("type") == "fluid" and ing["name"] != "water":
                depth = max(depth, 1)
            else:
                d = self.oil_depth(ing["name"])
                depth = max(depth, d + 1 if d > 0 else 0)
        self.stack.discard(item)
        self.memo_depth[item] = depth
        return depth

    def uses_fluid(self, item: str) -> bool:
        """True if any fluid appears anywhere in the recipe tree (i.e. oil is required)."""
        if item in RAW_WEIGHTS:
            return item in ("crude-oil", "water")
        if item in self.memo_fluid:
            return self.memo_fluid[item]
        if item in self.stack:
            return False
        recipe = self._pick(item)
        if not recipe:
            return False
        self.stack.add(item)
        fluid = False
        for ing in recipe.get("ingredients") or []:
            if ing.get("type") == "fluid" and ing["name"] != "water":
                fluid = True
            elif self.uses_fluid(ing["name"]):
                fluid = True
        self.stack.discard(item)
        self.memo_fluid[item] = fluid
        return fluid

    def _pick(self, name: str) -> dict | None:
        """Choose the canonical recipe for an item.

        Order of preference: the recipe named after the item (that is Factorio's own
        convention for the canonical one), then a plain `crafting` recipe, then the one
        with the fewest ingredients.

        Two traps this function exists to avoid, both measured on real data:
        - picking blindly by ingredient count gave a plastic bar worth 140 iron plates;
        - barrel recipes (`empty-petroleum-gas-barrel` has ONE ingredient) made a unit of
          petroleum gas worth 0.1, because emptying a barrel is not producing a fluid.
        """
        candidates = [r for r in self.index.get(name, []) if self._usable(r)]
        if not candidates:
            return None
        def rank(r):
            own_name = 0 if r.get("name") == name else 1
            cats = r.get("categories") or ["crafting"]
            plain = 0 if "crafting" in cats else 1
            fluid = 1 if r.get("ingredients") and any(
                i.get("type") == "fluid" for i in r["ingredients"]) else 0
            return (own_name, plain, fluid, len(r.get("ingredients") or []))
        return sorted(candidates, key=rank)[0]

    @staticmethod
    def _usable(recipe: dict) -> bool:
        """Barrel fill/empty recipes are storage, not production."""
        name = recipe.get("name", "")
        if "barrel" in name:
            return False
        if name.startswith(("empty-", "fill-")):
            return False
        return True

    def _unit_inputs(self, recipe: dict, depth: int = 0) -> tuple[float, float, float]:
        """Raw cost, seconds and kJ for ONE unit of the recipe's primary output."""
        out_amount = 1.0
        if recipe.get("results"):
            out_amount = max(r["amount"] for r in recipe["results"]) or 1.0
        seconds = float(recipe.get("energy_required") or 0.5)
        cost = 0.0
        for ing in recipe.get("ingredients") or []:
            per_unit = float(ing["amount"]) / out_amount
            cost += per_unit * self.of(ing["name"], depth + 1)
        power = CATEGORY_POWER_KW.get((recipe.get("categories") or ["crafting"])[0], 150.0)
        energy_kj = power * seconds / out_amount
        return cost, seconds / out_amount, energy_kj

    def of(self, name: str, depth: int = 0) -> float:
        if name in RAW_WEIGHTS:
            return RAW_WEIGHTS[name]
        if name in self.memo:
            return self.memo[name]
        if depth > 12 or name in self.stack:
            self.unresolved.add(name)
            return 0.0
        recipe = self._pick(name)
        if recipe is None:
            self.unresolved.add(name)
            self.memo[name] = 0.0
            return 0.0
        self.stack.add(name)
        cost, seconds, energy = self._unit_inputs(recipe, depth)
        self.stack.discard(name)
        self.memo[name] = cost
        self.memo_time[name] = seconds
        self.memo_energy[name] = energy
        return cost

    def report(self, names: list[str]) -> list[dict]:
        rows = []
        for name in names:
            raw = self.of(name)
            credits = max(1, math.ceil(raw * CREDITS_PER_UNIT))
            rows.append({
                "item": name,
                "raw": round(raw, 2),
                "credits": credits,
                "seconds": round(self.memo_time.get(name, 0.0), 2),
                "energy_kj": round(self.memo_energy.get(name, 0.0), 1),
                "payout": math.ceil(credits * PAYOUT_FACTOR),
                "price": math.ceil(credits * PRICE_FACTOR),
                "tier": self.tier(name),
                "fluid": self.uses_fluid(name),
                "packs": ",".join(self.science_packs(name)),
            })
        rows.sort(key=lambda r: (r["tier"], r["credits"]))
        return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", default=DEFAULT_DUMP)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--markdown", action="store_true", help="emit a markdown table")
    args = ap.parse_args()

    path = Path(args.dump)
    if not path.exists():
        print(f"missing data dump: {path}", file=sys.stderr)
        print("run: factorio --dump-data", file=sys.stderr)
        return 2

    data = load(str(path))
    calc = Cost(data)
    names = sorted(calc.index) if args.all else V1_ITEMS
    rows = calc.report(names)

    if args.markdown:
        print("| Item | Tier | Fluid | Credits | s (x1) | kJ | Payout | Shop price |")
        print("|---|---|---|---|---|---|---|---|")
        for r in rows:
            print(f"| `{r['item']}` | {r['tier']} | {'yes' if r['fluid'] else 'no'} | "
                  f"{r['credits']} | {r['seconds']} | {r['energy_kj']} | "
                  f"{r['payout']} | {r['price']} |")
    else:
        for r in rows:
            print(f"{r['item']:<24} t{r['tier']} fluid={str(r['fluid']):<5} "
                  f"raw={r['raw']:>8} cr={r['credits']:>5} "
                  f"s={r['seconds']:>6} kJ={r['energy_kj']:>8} "
                  f"payout={r['payout']:>5} price={r['price']:>5} "
                  f"packs={r['packs']}")

    if calc.unresolved:
        print(f"\nunresolved (cost 0, check by hand): {sorted(calc.unresolved)}",
              file=sys.stderr)
    print(f"\n{len(rows)} items · {CREDITS_PER_UNIT} credits per raw unit · "
          f"payout=x{PAYOUT_FACTOR} price=x{PRICE_FACTOR}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
