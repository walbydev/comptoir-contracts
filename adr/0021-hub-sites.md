# 0021 — Hub sites: dedicated zones instead of a minimum distance (proposed)

- **State**: rejected
  not assumed (spike `spike/hub-site/`, 2026-10-25)
- **Date**: 2026-10-25
- **Would replace**: the minimum-distance rule of `0014`

## The idea

> « J'ai une idée : ne pouvoir poser un hub que sur des zones dédiées, comme les minerais. »

Instead of letting the player build a hub anywhere and refusing it by distance, the map carries a
finite set of **hub sites**, generated like ore patches. The player develops a site; he does not
scatter hubs.

On the design side it is better than the distance rule on every point:

| | Minimum distance (`0014`) | Dedicated sites |
|---|---|---|
| Cap on the number of hubs | implicit, by map size | **explicit and visible** |
| Why two hubs are far apart | an arbitrary radius the player must learn | the map says it: no site, no hub |
| Sprawl | prevented by a rule | impossible by construction |
| Territory | nothing to fight over | a site is a place, and places become scarce |
| Player's first question | "how far is far enough?" | "which site do I open first?" |

## What the engine actually allows — four attempts, measured

The spike tested each path in Factorio 2.1.23 headless. Results are facts, not readings:

| Path | Verdict | Evidence |
|---|---|---|
| Hub = `container` carrying `resource_categories` | **no** | data stage accepts the field, runtime ignores it: `can_place_entity{build_check_type=manual}` → `true` on bare ground |
| Hub = `mining-drill` carrying `resource_categories` | **yes** | same call → `false` on bare ground: the pumpjack mechanism, enforced natively |
| Custom tile + `tile_buildability_rules` | **no** | tile layers are a fixed engine enum (`ground_tile`, `water_tile`); base data uses only those |
| Script check at build time | **yes**, by the mod | the only remaining path for a normal building |

**The trap**: the one native mechanism requires the hub to be a **mining drill**. That means inheriting
an energy source, a mining area, a drilling progress, module slots and a *mining result box* — and
that last point kills it: `0016` requires the hub to carry a **general inventory** fed by inserters and
robots. A mining result box is not that inventory. Making the hub a miner to win a placement rule
would cost the one simplification the requester just bought.

## Recommendation

**Keep the hub a normal building with its inventory, and check the site by script at build time.**
The cost looks like a new hack, and it is not: `0014`'s minimum-distance rule **already** required a
build-time check with a refund (`on_built_entity` + `find_entities_filtered`). Replacing "is there
another hub within R tiles" with "is there a site marker under this hub" costs the same line of code
and buys everything in the table above.

- The site marker is a **resource patch** with its own category, visible on the map with its own
  colour and its own name ("concession"). Nothing can mine it — no drill declares its category — so it
  is a marker that behaves like terrain.
- The player places the hub on the patch; the mod verifies the marker and refunds otherwise, with a
  message naming the rule.
- One hub per site: the same check, per patch.

## Three things this ADR does not know yet, and will not guess

1. **A site near the spawn (Q42)**: nothing in the base data guarantees a patch inside the starting
   area, and `starting_area_amount` does not appear in 2.1's resource prototypes. Without a guaranteed
   first site, a fresh save can show no hub at all — the mod would be invisible for two hours. This is
   a spike, not a paragraph.
2. **Existing saves (Q43)**: autoplace does not run retroactively. A save created before the mod has
   no sites at all. Either the mod seeds one, or the mod is new-game only.
3. **How many sites (Q44)**: a fixed number per surface, a map-generation setting, or the autoplace
   controls. This decides whether hubs are a scarce resource or a decoration.
