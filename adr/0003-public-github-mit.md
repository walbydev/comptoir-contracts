# 0003 — Public GitHub repository under `walbydev`, MIT licence

- **Status**: accepted
- **Date**: 2026-10-25
- **Block**: 1
- **Supersedes**: —

## Context

A Factorio mod is distributed through the official portal, which implies code that other players can
read, report and possibly fix. What remained was where the repository lives and under which licence.
Philippe's decision on 2026-10-25: **public GitHub `walbydev` (3a)**, **MIT** licence.

Homelab convention, for the record: private work lives on the internal Gitea
(`walby-homelab/*`), public work lives on GitHub (`walbydev`). This project is a **public artefact**.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — **Public GitHub `walbydev` + MIT** | low: a second forge to know | none for this project (the code is published anyway) | keeping the code private if the mod ever becomes commercial |
| B — Private Gitea `walby-homelab` | low, consistent with the homelab | a published mod with private code loses its community value; backup and visibility managed for nothing | outside contribution |
| C — Public GitHub + LGPL-3 | low | heavier to explain for a mod; protects against closed forks nobody wants here | closed forks |

## Decision

**Option A.** A is chosen because the value of a published mod lies in visible code: a player who
reports a balancing bug can propose a fix, and the portal points at a public source anyway.

## Consequences

- **Requires**: no personal data, no token, no homelab path in any commit — the repository is
  public, history included.
- **Requires**: the portal publishing token (`FACTORIO_API_KEY`) lives outside the repository.
- **Forbids**: referencing internal resources (private Gitea, LAN IPs) in published documentation.
- **Makes harder**: nothing notable — a public repository is not backed up differently from a
  private one.

## Review

Reopen if: (a) the mod is withdrawn from the portal, (b) part of the code must stay closed
(partnership, restrictively licensed assets), (c) Philippe decides to bring all public work back onto
a self-hosted forge.
