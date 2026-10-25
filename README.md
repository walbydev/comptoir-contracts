# factorio-contrats

A Factorio 2.1 mod — **company contracts** through a commercial hub (space elevator plus a
spaceport). Delivered contracts pay credits and/or technologies; credits buy stacks of materials or
technologies without research.

> Guiding rule: **the hub complements local production, it never replaces it.**

**State: framing in progress (block 1).** This repository holds the project definition, not code yet.
No development before tag `v0.1-cadrage`.

| Document | Purpose |
|---|---|
| [`docs/00-cadrage.md`](docs/00-cadrage.md) | master document: ten blocks, environment, vision, scope |
| [`adr/`](adr/) | architecture decisions, numbered, never rewritten |
| [`docs/entrants/`](docs/entrants/) | frozen handoff brief (input material, original language) |
| [`spike/`](spike/) | throwaway prototypes, dated |

## Decisions already made

| Topic | Decision | Trace |
|---|---|---|
| Credits | virtual ledger **plus** a bearer credit-item (giftable, storable), converted both ways **at the hub only** | ADR 0004 (supersedes 0001) |
| Purchasable technologies | curated list, never the full tree | ADR 0002 |
| Space Age | plays identically **with and without** the DLC: own prototypes, DLC assets reused when present | ADR 0005 |
| Forge and licence | public GitHub `walbydev`, MIT | ADR 0003 |
| Money | integer credits only, fixed face value per item, conversion = fixed fee + degressive rate | ADR 0006 |
| Bank | deposit/withdraw with regular interest, funded by the hub's margin (funding rule still open — Q15) | ADR 0007 |
| Players | solo and multiplayer; gifting only via items, never a direct credit transfer | framing §2 |

## Test chain

Target: Factorio **2.1.x**, base only in the MVP. The mod loads and runs **headless**
(`factorio --version` → 2.1.23 verified), which allows deterministic tests without a graphical
client. GUI rendering and balancing feel can only be tested in game.

```bash
make help          # available commands
make check         # Lua syntax check (arrives with the first code)
```

## Language convention

Project definition, documentation, ADRs, code, identifiers, comments and commit messages are written
in **English**. Incoming documents are kept verbatim in their original language under
`docs/entrants/`. Conversation with the requester happens in French.

## Licence

MIT — see [`LICENSE`](LICENSE). No token, no personal data, no internal path in this repository: it
is public, history included.
