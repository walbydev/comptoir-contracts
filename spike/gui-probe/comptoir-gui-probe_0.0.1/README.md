# Sonde GUI — la fenêtre du comptoir peut-elle remplacer celle du jeu ?

Mod jetable. Il ne sert à rien dans une partie : il répond à **une seule question**, et il se
supprime ensuite.

> Ce fichier est en français parce qu'il est écrit pour le demandeur, pas pour le dépôt — même
> exception que `docs/reader/`. Le code et ses commentaires restent en anglais.

## La question

Quand on ouvre un `container` (notre comptoir `comptoir-counter` en est un), est-ce que **notre
cadre remplace la fenêtre d'inventaire du jeu**, ou est-ce que les deux s'affichent l'un sur
l'autre ? C'est le critère **R1** de l'ADR 0050 : si la fenêtre vanilla ne peut pas être supprimée,
le type de prototype du comptoir est faux et la fenêtre ne doit pas être écrite par-dessus.

La sonde fait exactement trois choses : elle vide `player.opened`, elle pose un cadre nommé
`comptoir-gui-probe` dans `player.gui.screen` (deux libellés + un bouton `close`), et elle écrit
dans la console du jeu le nom de l'entité ouverte.

## Ce que tu fais (quatre étapes)

1. Copie **les deux mods** dans un répertoire de mods de dev (jamais `~/.factorio/mods` si tu tiens
   à tes sauvegardes) :

   ```bash
   mkdir -p ~/comptoir-dev/gui-probe
   # Factorio exige <nom>_<version> comme nom de dossier : la racine du dépôt, recopiée sous ce nom.
   cp -r comptoir-contracts      ~/comptoir-dev/gui-probe/comptoir-contracts_0.1.0
   cp -r comptoir-gui-probe_0.0.1 ~/comptoir-dev/gui-probe/
   factorio --mod-directory ~/comptoir-dev/gui-probe
   ```

   Dans **Settings → Mods**, les deux doivent être listés et cochés : `Comptoir — Contracts` et
   `Comptoir GUI probe`. La sonde dépend du mod principal : si celui-ci est désactivé, le jeu refuse
   de démarrer et le dit.

2. Lance une partie, charge une carte (nouvelle ou existante) et donne-toi le comptoir :

   ```
   /c game.player.insert{name="comptoir-counter", count=1}
   ```

   La commande est silencieuse quand elle réussit. Si rien n'apparaît, c'est que
   `comptoir-contracts` n'est pas chargé.

3. Pose le comptoir au sol, puis **ouvre-le** (clic gauche sur l'entité posée).

4. Regarde l'écran et dis-nous ce que tu vois. La console du jeu affiche déjà
   `[comptoir-gui-probe] opened entity: "comptoir-counter"` — c'est la preuve que la sonde a bien
   réagi à l'ouverture.

## Les deux réponses possibles

- **R1 fermé** — tu ne vois **que notre cadre** : le titre `comptoir-gui-probe`, les deux libellés,
  le bouton `close`, et **aucune grille d'inventaire** derrière. La fenêtre vanilla a bien été
  supprimée par `player.opened = nil`. Le comptoir garde son type `container` et la fenêtre peut
  être écrite comme prévu.
- **R1 ouvert** — tu vois **les deux** : notre cadre *et* la fenêtre d'inventaire du jeu. Dans ce
  cas, note aussi ce que montre la fenêtre vanilla (une grille vide ? les objets du comptoir ? une
  barre de titre « Steel chest » ?), et si notre cadre est devant ou derrière. Cette réponse renvoie
  à l'option B de l'ADR 0045 (une machine d'assemblage à la place du container) : c'est un
  changement de prototype, pas un détail de fenêtre.

Une troisième observation compte aussi : **si tu ne vois rien du tout**, c'est que le cadre a été
détruit juste après sa création. Dis-le tel quel — le message de console dira quand même que la
sonde s'est déclenchée.

## Sur la superposition des cadres

La sonde dessine son cadre dans `player.gui.screen`, la seule surface qu'un mod peut utiliser sans
entité. **Elle ne peut pas garantir l'ordre d'affichage** par rapport à la fenêtre d'inventaire
vanilla : si les deux coexistent, c'est le jeu qui décide laquelle est devant. Le libellé
« vanilla frame visible? look behind this one » est là pour ça — regarde derrière, et autour.

## Ce qui a été prouvé, et ce qui ne peut pas l'être ici

- Prouvé sur cette machine (headless, 2.1.23) : le mod **se charge**, `info.json` est accepté, la
  dépendance sur `comptoir-contracts` est résolue et `control.lua` s'exécute sans erreur Lua.
- **Non prouvable ici** : tout ce qui touche à l'écran. Sans client graphique il n'y a ni `LuaPlayer`
  ni `player.gui`, donc `on_gui_opened`, `player.opened`, `player.gui.screen` et la superposition
  des cadres ne peuvent pas être exercés — c'est le constat de l'ADR 0050, et c'est précisément
  pourquoi cette sonde voyage sur ta machine.
