# 08 — Security and rights

- **Status**: specified 2026-10-25 — one question open (§2, per-force economy)
- **Depends on**: ADR `0040` (trust model), `0026` (cooperative), `0016` (hub is the warehouse)

## 1. What the mod is exposed to

A Factorio mod is not a service: no network port, no credentials, no database, no user accounts. The
attack surface is narrow and entirely local:

| Surface | Reality | Answer |
|---|---|---|
| **the shared pot** | any player can accept a contract and default | bounded by design (ADR 0040), not by permissions |
| **the hub container** | any player can take the goods or mine the building | no protection possible; documented |
| **saved data** | a save can be edited with `/c` or offline tools | no anti-cheat, ever |
| **the repository** | public | no secret, no key, no host name — stated in `AGENTS.md` |
| **the publish key** | the only real secret in the project | environment variable only, never in git |

## 2. What the mod is allowed to store — and does not

- Everything lives in `storage`, per mod, per save. **Nothing is written outside it**: no files in
  `script-output` outside the test harness, no config, no cache.
- **No personal data.** Contracts are non-nominative (`0024`) and the cooperative is a single account
  (`0026`), so the mod stores **no player name, no player id, no playtime, no statistics**. A company has
  a name generated from a word list, not a player.
- **No network code at all.** The mod makes no HTTP call, opens no socket, and sends nothing anywhere.
  This is the promise behind D65, and it is maintainable precisely because the code has no such module.

### Open: per-force economy (Q56)

In a normal game there is one force. On a PvP or scenario map there may be several. Two readings:

- **A — state is per force**: each force has its own companies, its own cooperative, its own credits.
  No leakage between opponents, and `storage` mirrors how the engine already isolates forces.
- **B — one global economy**: companies are shared across forces, so an opponent's currency is the same
  as yours.

A is the coherent reading of "companies owned by nobody in particular but operated by everybody", and it
is what this document assumes until answered. It is cheap either way at design time and **expensive to
change after release**, because it decides the shape of the saved data.

## 3. Rights over the work itself

| Aspect | State |
|---|---|
| **licence** | MIT (`LICENSE`) — anyone may fork, reuse, or sell a derivative; attribution kept |
| **the name** | the portal account owns `comptoir-contracts`; the MIT licence grants no right to publish under that name |
| **assets** | the mod **ships no art**: it references base-game sprites and clones base prototypes. No third-party asset is redistributed, so there is no asset licence to respect or to violate |
| **attribution** | nothing to attribute: no copied code, no borrowed mod, no external library |
| **the requester's rights** | the requester owns the project; the licence is what protects players' freedom to fork it |

## 4. The one thing that must never happen

**A secret in the repository.** The repository is public. The publish key, the portal password, and any
token live outside it, are read from the environment at publish time, and never appear in `.git/config`,
a test fixture, an example file, or a commit message. This project already paid for that lesson once on
a previous chantier; it is written here so it is not relearned.

## 5. Accepted criteria

- **A25**: the mod declares **no dependency** that can reach the network, and the built archive contains
  no key, token, or absolute path.
- **A26**: a fresh save contains **no player name or player id** anywhere in `storage`.
- **A27**: removing the mod from a save leaves no queued script: loading the save without the mod
  produces the engine's own "missing mods" warning, and no crash from `on_load`/`on_configuration_changed`.
