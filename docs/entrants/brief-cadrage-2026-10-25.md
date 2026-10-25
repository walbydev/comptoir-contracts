# Brief de cadrage — « Contrats de compagnies » (mod Factorio 2.1)

> Document de passation écrit par Hermes `web-coder` le 2026-10-25.
> Destinataire : Hermes `cadrage`. Source : demande de Philippe du 2026-10-25 (Telegram).
> Rien ici n'est un plan d'implémentation : c'est la matière d'entrée du cadrage.

## 1. Demande d'origine (verbatim)

> « J'aime bien l'idée des contrats de compagnies via un hub de communication commerciale ce qui
> permet d'obtenir des crédits et/ou des technologies. Les crédits accumulés permettent d'acheter
> des stacks de matériaux ou des technologies se passant de recherche. J'aimerais quelque chose
> d'équilibré. Le hub est un ascenseur spatial relié à un spatioport qui permet aux marchands de
> venir chercher les commandes des contrats réalisés. »

## 2. Concept en une phrase

Un mod Factorio 2.1 où un **hub commercial** (ascenseur spatial + spatioport) propose des
**contrats de livraison** de la compagnie ; les livraisons rapportent des **crédits** et/ou des
**technologies**, et les crédits achètent des **stacks de matériaux** ou des **technologies sans
recherche** — le tout calibré pour ne jamais remplacer la production locale.

## 3. Boucle de jeu visée

1. Le hub apparaît (technologie dédiée ou offert au départ — à trancher).
2. Il propose N contrats disponibles, chacun avec : items demandés, quantité, délai, récompense
   (crédits et/ou technologie), éventuellement une pénalité de retard.
3. Le joueur produit et **livre au hub** (insertion physique ou envoi par fusée — à trancher).
4. La livraison déclenche le départ du vaisseau marchand (animation) et crédite la récompense.
5. Les crédits s'échangent dans le GUI du hub : matériaux (stacks) ou technologies.
6. De nouveaux contrats arrivent dans le temps ; leur niveau suit la progression du joueur.

## 4. Mécaniques explicitement demandées

- Hub = **ascenseur spatial relié à un spatioport**, avec des **marchands** qui viennent chercher
  les commandes terminées (mise en scène visuelle, pas seulement un menu).
- Récompenses : **crédits** et/ou **technologies**.
- Dépense des crédits : **stacks de matériaux** ou **technologies sans recherche**.
- **Équilibre** : c'est une exigence, pas une intention vague. Le hub doit rester un complément,
  jamais un raccourci qui trivialise la production ou l'arbre technologique.

## 5. Faits techniques vérifiés le 2026-10-25 (sur ce poste)

Ces points sont établis par exécution, pas par mémoire — ils contraignent le cadrage.

1. **Chaîne de test locale complète.** Factorio headless 2.1.23 (build 87750, linux64) est installé
   dans `/opt/data/.local/opt/factorio` (téléchargé depuis factorio.com, 61 Mo, sans licence). Il
   charge les mods, génère une map et exécute le control stage :
   ```
   $ factorio --create probe.zip --mod-directory ./mods
   0.099 Loading mod probe-mod 0.1.0 (data.lua)
   0.291 Checksum of probe-mod: 1839892835
   1.489 Script @__probe-mod__/control.lua:14: [probe] control stage alive - base version 2.1.23
   ```
   Conséquence : **on peut tester ce mod sans client graphique**, donc en CI, et sans Philippe.
2. **Lua 5.2.4 compilé localement** (`luac -p`) pour la vérification syntaxique immédiate.
3. **L'ascenseur spatial n'existe pas dans le jeu.** Aucun prototype `space-elevator`, aucune
   occurrence de « elevator » dans `data/base` ni `data/space-age` de la 2.1.23 :
   ```
   [probe2] space-elevator type present: false
   ```
   → le hub est une **entité créée par le mod**, avec ses graphismes (réutilisation d'assets
   existants possible : `rocket-silo`, `cargo-landing-pad`, `cargo-pod`).
4. **Types de prototypes disponibles** (224 au total) incluent `market`, `rocket-silo`,
   `cargo-landing-pad`, `cargo-pod`, `space-location` — donc un silo fonctionnel et un marché à
   offres sont techniquement à portée.
5. **Événements runtime existants** (extrait vérifié) : `on_market_item_purchased`,
   `on_research_finished`, `on_research_cancelled`, `on_cargo_pod_started_ascending`,
   `on_cargo_pod_finished_ascending`, `on_cargo_pod_delivered_cargo`, la famille `on_gui_*`
   (`on_gui_click`, `on_gui_closed`, `on_gui_selected_tab_changed`, …).
6. **Pièges de version confirmés par le jeu lui-même** (erreurs réelles rencontrées) :
   - depuis 2.0, l'état persistant s'écrit dans `storage`, plus dans `global` ;
   - en 2.1, `recipe.category` a fusionné en `recipe.categories = {"crafting"}`.

## 6. Décisions à trancher (recommandation en premier)

| # | Question | Recommandation | Ce que change l'alternative |
|---|---|---|---|
| D1 | Nature des crédits | **Monnaie virtuelle** (`storage`, affichée dans le GUI) | Un item « crédit » physique : plus palpable, mais logistique de stockage, risque de duplication par les splitters/insertion, et ça encombre les inventaires |
| D2 | Livraison au hub | **Insertion physique dans le hub** (quota suivi, puis embarquement animé) | Envoi par fusée depuis un silo : plus spectaculaire et adapté aux gros volumes, mais impose le silo dans le MVP et complique le suivi |
| D3 | Technologies achetables | **Liste curatée**, jamais celles qui débloquent le hub ni la progression obligatoire | Tout l'arbre : casse la boucle de recherche et le rythme du jeu |
| D4 | Nombre de hubs | **Un seul**, posable après une technologie dédiée | Plusieurs hubs : multi-surface et multi-force à gérer dès le MVP |
| D5 | Space Age | **Optionnel** (dépendance `base` seule au MVP) | Dépendance dure à Space Age : réduit le public et fige les planètes dans le périmètre |
| D6 | Forge du dépôt | **GitHub public `walbydev`**, licence MIT | Gitea privée : cohérent avec le reste du homelab, mais un mod publié gagne à montrer son code |

## 7. Équilibre — pistes chiffrées à valider (proposition, pas décision)

Principe directeur : **le hub n'est jamais plus efficace que la production locale.** Il échange du
temps contre un taux de change défavorable, et il faut que le joueur y gagne quand même.

- Unité de compte : 1 crédit ≈ valeur d'une plaque de fer.
- Contrat : `récompense = Σ(quantité × valeur_item) × 1,2 à 1,5`, bonus si livré avant l'échéance,
  pénalité si dépassement (ou expiration sèche — à trancher).
- Achat de matériaux : `prix = Σ(quantité × valeur_item) × 1,5 à 2` — acheter coûte toujours plus
  cher que produire, mais sauve une pénurie ponctuelle.
- Achat de technologie : coût ≈ 1,5 à 2 fois le coût en packs scientifiques équivalent, donc
  rentable uniquement si le joueur a un gros surplus de production et peu de temps.
- Volumes de contrat à l'échelle « stacks » (100–500 unités), délais 10–30 min, 2 à 4 contrats
  simultanés, renouvellement progressif avec le niveau technologique.
- Contre-exemples à éviter explicitement (à écrire dans les critères d'acceptation) : boucle
  infinie contrat → achat de matériaux → revente ; contrat satisfiable sans produire ; technos clés
  achetables avant d'avoir construit la chaîne correspondante.

## 8. Architecture technique pressentie (à confirmer au bloc 4 du cadrage)

Vertical slices, un dossier par fonctionnalité :

```
factorio-contrats/
  info.json  data.lua  settings.lua  control.lua
  src/data/{hub, contracts, shop, technologies, locale}
  src/control/{hub-gui, delivery, contracts, credits, shop, migrations}
  graphics/{hub, merchant-ship, icons}
  locale/{fr, en}
  tests/            # scénarios headless + assertions
  tools/{run-tests.sh, package.sh}
  docs/             # cadrage, ADR, arborescence, tests
```

Tests : harnais headless déjà opérationnel (data stage + control stage + génération de map),
scénarios déterministes avec assertions Lua, plus `luac -p` en pré-commit. Publication : zip
`factorio-contrats_x.y.z.zip` avec `info.json` à la racine.

## 9. Risques identifiés

- **Équilibrage** : le risque principal, et celui qui demande le plus d'itérations jouées.
- **GUI Lua** : coût de rendu et ergonomie ; éviter les rebuilds complets à chaque tick.
- **Persistance** : tout passe par `storage` ; prévoir des migrations dès la v0.1 (version de save).
- **Compatibilité Space Age / autres mods** : ne pas écraser de prototypes existants.
- **Art** : le poste de travail ne produit pas de pixel art de qualité ; prévoir placeholders
  assumés et une passe graphique ultérieure.
- **Localisation** : FR + EN dès le départ, sinon la dette devient structurelle.

## 10. Non-objectifs proposés

- Pas de nouvelle planète, pas de refonte des recettes de base.
- Pas d'économie multi-joueurs compétitive (pas de PvP, pas de marché entre joueurs).
- Pas de dépendance dure à Space Age dans le MVP.
- Pas de graphismes définitifs dans la v0.1.

## 11. Questions à poser à Philippe (max 3 par message)

1. D1 — crédits virtuels (recommandé) ou item physique ?
2. D3 — technologies achetables : liste curatée (recommandé) ou arbre complet ?
3. D6 — dépôt GitHub public `walbydev` (recommandé) ou Gitea privée ?

(D2, D4, D5 peuvent suivre au bloc 3, avec le périmètre MVP.)
