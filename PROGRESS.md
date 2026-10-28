# PROGRESS — plugin-motion

Dernière mise à jour : 2026-10-28
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Cinq composants : l'agent `frame-reviewer` (US-4), les skills `storyboard` (US-2, US-7), `new-video` (US-1), `build-scene` (US-3, US-4, US-7) et `render-video` (US-6, US-7), avec `scripts/doctor.sh`, `scripts/preview.sh`, `scripts/probe.sh` et `templates/`. Les deux hypothèses du PRD sont tranchées, et le critère 2 est tenu sur le poste depuis le 2026-10-25 (voir `new-video`). `probe.sh` déclare conforme un vrai rendu de Remotion, et la suite de `render-video` montre qu'il ne prend pas la place du skill officiel `remotion-render`, chargé dans chaque session (voir `render-video`). Restent : `sync-voiceover` (US-5, critère 5), l'enchaînement complet du critère 3 et les trois exécutions de `frame-reviewer` du critère 4.

## Composants

### Agent `frame-reviewer` — 2026-10-23

Outils `Read, Glob`, modèle `sonnet`, sans écriture ni commande : aucune portée ni garde.

Rouge, avant l'agent :

```
$ bash tests/static/test_agent_frame_reviewer.sh
  ÉCHEC  agents/frame-reviewer.md présent
         absent
test_agent_frame_reviewer : 0 réussis, 1 échoués, 0 sautés
exit 1
```

Vert, après l'agent (`check-agent` : conforme) :

```
$ bash tests/static/test_agent_frame_reviewer.sh
  ok     agents/frame-reviewer.md présent
  ok     en-tête strict
  ok     outils : Read, Glob
  ok     modèle : sonnet
test_agent_frame_reviewer : 4 réussis, 0 échoués, 0 sautés
exit 0

$ bash tests/run-all.sh
réussies : 9
échouées : 0
sautées : 1
  - claude plugin validate skills --strict (skills absent)
bloquées : 0
alertes : 0
exit 0
```

Coût en contexte permanent (`claude plugin details`) : ~193 tokens pour le plugin, dont ~190 pour `frame-reviewer` (estimé ~80 dans l'architecture) ; ~1,4k à chaque appel.

Reste à faire pour le critère 4 : trois exécutions sur une planche de test où un texte déborde volontairement (`tests/fixtures/`).

### Skill `storyboard` — 2026-10-24

Sans Bash ni script. Lit `storyboard.md` et annonce où en est la vidéo ; pose les questions qui manquent au brief, une à la fois (public, durée totale, ton ; le format garde la valeur du storyboard sauf mention contraire) ; écrit les scènes en `à faire` et les valeurs de `theme.ts` ; une scène changée repasse en `à faire` et garde son identifiant ; s'arrête sur l'accord de Soon, sans code. Le format du bloc JSON est fixé dans `skills/storyboard/reference/format.md` : `format`, `voiceover`, `scenes[]` (`id`, `durationInFrames`, `text`, `motion`, `cues`, `status`).

Suite `evals/storyboard/` : trois cas positifs (brief d'une appli de notes, brief vertical d'une newsletter, scène 2 qui montre le logo au lieu du slogan), deux négatifs (rendre le MP4, créer un projet), trois exécutions chacun, outils en lecture seule. Chaque cas, sauf la création d'un projet, pose son projet vidéo par `setup.sh` : le `storyboard.md` vide qu'il écrit (1920×1080 à 30 i/s, `voiceover: false`, `scenes: []`) est celui que le modèle de `new-video` devra poser.

Lancement hors de `pp.sh eval-run`, qui ne passe pas `--scaffold` : sans lui, les cas tournent dans un dossier vide, sans `storyboard.md`. Commande annoncée par `pp.sh eval-plan`, `--scaffold` ajouté avec l'accord de Soon, verdict par `pp.sh eval-verdict`. Écart de plugin-plugin 0.1.2, à corriger de son côté.

Rouge, avant le skill (un bras ; « oui » de Soon) :

```
$ claude plugin eval /home/soon/Documents/Claude-plugin/plugin-motion --case 'storyboard-*' --no-publish --max-cost-usd 4 --ablation none --scaffold --output-dir …/evals/results/storyboard-20261024T001714
claude plugin eval : exit 1
$ bash pp.sh eval-verdict … storyboard …/aggregate-result.json
rouge : storyboard-brief-notes : WITH 0.33, Δ —
rouge : storyboard-brief-vertical : WITH 0.33, Δ —
rouge : storyboard-change-scene : WITH 0.00, Δ —
ok : storyboard-new-project (négatif) : WITH 1.00, Δ —
ok : storyboard-render-request (négatif) : WITH 1.00, Δ —
coût : 2,08 USD
verdict : rouge
exit 1
```

Le premier lancement avait été refusé avant tout chargement, dossier jamais approuvé, sans session ni coût ; Soon l'a approuvé dans un terminal.

Vert, après le skill (`check-skill` : conforme ; deux bras ; « oui » de Soon) :

```
$ claude plugin eval /home/soon/Documents/Claude-plugin/plugin-motion --case 'storyboard-*' --no-publish --max-cost-usd 8 --scaffold --output-dir …/evals/results/storyboard-20261024T003153
claude plugin eval : exit 0
$ bash pp.sh eval-verdict … storyboard …/aggregate-result.json
ok : storyboard-brief-notes (positif) : WITH 1.00, Δ +1.00
ok : storyboard-brief-vertical (positif) : WITH 1.00, Δ +0.83
ok : storyboard-change-scene (positif) : WITH 1.00, Δ +1.00
ok : storyboard-new-project (négatif) : WITH 1.00, Δ +0.00
ok : storyboard-render-request (négatif) : WITH 1.00, Δ +0.00
coût : 3,70 USD
verdict : vert
exit 0
```

Sans le skill, le témoin découpe aussitôt en scènes et pose plusieurs questions à la fois ; sur la scène 2, il écrit « à construire » et ne demande pas d'accord. Le motif `600 images` passe déjà sans le skill au rouge : c'est le correcteur `llm` qui distingue. Vu dans une réponse du cas 3 : le skill demande où est le logo alors que `public/logo.svg` existe.

Coût en contexte permanent (`claude plugin details`) : ~120 tokens pour `storyboard` (estimé ~100 ; ~210 avant réduction de la description), ~313 pour le plugin ; ~1,3k à chaque appel.

### Skill `new-video` — 2026-10-25

Avec Bash (npx, `doctor.sh`). Hors d'un dossier qui contient `storyboard.md` : prend le dossier de la demande, ou propose `~/Vidéos/motion/<nom>` et attend la confirmation ; refuse un dossier non vide, nomme ce qu'il contient, n'y touche pas et propose `~/Vidéos/motion/<nom>` du même nom. Puis `npx --yes create-video@latest --yes --blank <dossier>`, `npx remotion skills add`, copie de `templates/theme.ts`, `templates/timing.ts` (dans `src/`) et `templates/storyboard.md`, lance `scripts/doctor.sh`, présente le diagnostic en tableau ; sur un échec, s'arrête sur les corrections, sans rien changer au système ; sinon propose le storyboard dans une session ouverte dans le dossier, où se chargent les skills officiels.

Les trois modèles de `templates/` sont, octet pour octet, ceux que pose `evals/storyboard/storyboard-brief-notes/setup.sh` ; `tests/static/test_templates.sh` le garde. `timing.ts` ne contient que `msToFrame` : l'accès aux mots de `voiceover.json`, prévu par l'architecture, viendra avec `sync-voiceover`.

#### Hypothèses du PRD, constatées le 2026-10-24

Sur un projet créé dans le scratchpad de la session, avec l'accord de Soon pour le réseau (npm, GitHub, téléchargement du Chrome de Remotion), cache npm dans le scratchpad, rien d'installé sur le système.

- `npx create-video@latest --yes --blank essai` : Remotion 4.0.538, versions exactes (sans `^`) pour `remotion`, `@remotion/cli` et `@remotion/eslint-config-flat` ; `engines.node` vaut `^20.19.0 || ^22.13.0 || >=24` dans le `package.json` du projet, nulle part dans les paquets de Remotion ; dépendances installées (348 paquets, 25 s) et premier commit git. Un dossier vide existant est accepté ; un dossier non vide est refusé par `create-video` lui-même (« Something already exists at … », exit 1).
- **Skills officiels** : `npx remotion skills add` installe 12 skills de `remotion-dev/skills` (GitHub) dans `./.agents/skills/<nom>/`, liés pour Claude Code dans `./.claude/skills/<nom>`, et écrit `skills-lock.json` ; non interactif. Ils ne se chargent que dans une session ouverte dans le projet. Recouvrements possibles, dans un projet seulement : `remotion-create` (« Create a new Remotion video ») avec `new-video`, qui s'arrête de toute façon dans un dossier qui contient `storyboard.md` ; `remotion-render` (« Export a Remotion video ») avec le futur `render-video`, à tester dans sa suite.
- **Chrome headless sous nix-ld** : `npx remotion browser ensure` télécharge `chrome-headless-shell` (98,9 Mo) dans `node_modules/.remotion/` ; nix-ld le charge, mais il s'arrête : `error while loading shared libraries: libnspr4.so: cannot open shared object file`. `ldd` y ajoute `libnss3.so`, `libnssutil3.so` et `libexpat.so.1`. Avec `nspr`, `nss` et `expat` (64 bits, déjà dans le store) ajoutés à `NIX_LD_LIBRARY_PATH` pour ce seul processus, `npx remotion still MyComp … --frame=0` rend l'image (PNG 1280×720, exit 0). Correction à appliquer sur le poste, par `/plugin-nixos:modifie` : `nspr`, `nss` et `expat` dans `programs.nix-ld.libraries`. Le plan B (chromium de nixpkgs) reste proposé par `doctor.sh`.
- CLI constatée pour `doctor.sh` : `remotion compositions --quiet` écrit les identifiants séparés par des espaces (`MyComp Deux`) ; `remotion still` exige l'identifiant ; `remotion browser ensure` écrit `Has browser at <chemin>`. Pour `preview.sh` : `remotion render <id> out/frames --frames=0,30,90 --image-format=png` rend plusieurs images en un appel (skill officiel `remotion-render`).

#### `doctor.sh`, test d'abord

Rouge, avant `doctor.sh` et `templates/` :

```
$ bash tests/static/test_doctor.sh
  ÉCHEC  scripts/doctor.sh présent
         absent
test_doctor : 0 réussis, 1 échoués, 0 sautés
exit 1

$ bash tests/static/test_templates.sh
  ÉCHEC  templates/theme.ts présent
         absent
  ÉCHEC  templates/timing.ts présent
         absent
  ÉCHEC  templates/storyboard.md présent
         absent
test_templates : 0 réussis, 3 échoués, 0 sautés
exit 1
```

Vert, après (`shellcheck -S warning` : aucun avertissement sur `doctor.sh`) :

```
$ bash tests/static/test_doctor.sh
  ok     scripts/doctor.sh présent
# tout présent
  ok     tout présent : exit 0
  ok     node accepté par engines.node
  ok     ffmpeg 8.1.2
  ok     ffprobe 8.1.2
  ok     versions de Remotion alignées
  ok     essai de rendu sur la première composition
  ok     whisper présent
  ok     diagnostic prêt
  ok     rend l'image 0 de MyComp
  ok     l'image d'essai est rendue hors du projet
  ok     le projet est inchangé
  ok     aucune installation lancée
# versions de Remotion désalignées
  ok     versions désalignées : exit 1
  ok     nomme les versions et la correction
  ok     diagnostic en échec
# ffmpeg absent
  ok     ffmpeg absent : exit 1
  ok     ffmpeg manque, installation via plugin-nixos
  ok     ffprobe reste ok
# essai de rendu en échec, bibliothèque nommée
  ok     rendu en échec : exit 1
  ok     nomme la bibliothèque de l'erreur
  ok     liste les autres bibliothèques manquantes
  ok     propose les paquets dans programs.nix-ld.libraries
  ok     propose le plan B du PRD
  ok     aucun rendu après l'échec du navigateur
  ok     sans binaire à inspecter, nomme la bibliothèque de l'erreur
# Whisper absent
  ok     Whisper absent : exit 0, un avertissement
  ok     avertit, avec l'installation via plugin-nixos
  ok     diagnostic prêt malgré l'avertissement
# Node hors de engines.node
  ok     node 20.19.0 accepté
  ok     node 22.13.0 accepté
  ok     node 24.0.0 accepté
  ok     node 25.1.3 accepté
  ok     node 18.20.4 refusé
  ok     node 20.18.9 refusé
  ok     node 21.7.0 refusé
  ok     node 22.12.0 refusé
  ok     node 23.11.1 refusé
  ok     node refusé : exit 1
# dépendances non installées
  ok     dépendances absentes : exit 1
  ok     demande npm install
  ok     npx n'est pas lancé
# refus
  ok     refuse un dossier sans package.json (exit 2)
  ok     refuse un appel sans projet (exit 2)
test_doctor : 44 réussis, 0 échoués, 0 sautés
exit 0

$ bash tests/static/test_templates.sh
  ok     templates/theme.ts identique au src/theme.ts des cas d'évaluation
  ok     templates/timing.ts identique au src/timing.ts des cas d'évaluation
  ok     templates/storyboard.md identique au storyboard.md des cas d'évaluation
  ok     storyboard.md : 1920×1080 à 30 i/s, sans voix off ni scène
test_templates : 4 réussis, 0 échoués, 0 sautés
exit 0
```

Au-delà des cinq cas de l'architecture, trois contrôles testés : Node hors de `engines.node` (plages npm `||`, `^`, `~`, `>=`… ; une plage non lue donne un avertissement) ; dépendances non installées, sans quoi `npx` irait chercher Remotion sur le réseau, à une autre version ; la liste complète des bibliothèques manquantes par `ldd` sur le navigateur, le chargeur s'arrêtant à la première.

Essai réel (critère 2), sur le projet du scratchpad, poste tel quel :

```
$ bash scripts/doctor.sh …/scratchpad/probe/essai
ok             node : v22.23.2, accepté par engines.node « ^20.19.0 || ^22.13.0 || >=24 »
ok             ffmpeg : 8.1.2
ok             ffprobe : 8.1.2
ok             versions de Remotion : 4.0.538 pour 3 paquets (remotion et @remotion/*)
manque         essai de rendu : le Chrome headless de Remotion ne se lance pas, bibliothèques manquantes : libexpat.so.1, libnspr4.so, libnss3.so, libnssutil3.so — correction : ajouter expat, nspr, nss à programs.nix-ld.libraries via /plugin-nixos:modifie, puis relancer doctor.sh ; plan B : le chromium de nixpkgs, installé via /plugin-nixos:modifie, désigné à Remotion par --browser-executable (ou Config.setBrowserExecutable dans remotion.config.ts).
avertissement  whisper : whisper-cli introuvable ; seul sync-voiceover en a besoin — correction : installer le paquet nixpkgs whisper-cpp via /plugin-nixos:modifie.
diagnostic : 1 contrôle en échec, 1 avertissement ; rien n'a été modifié sur le système.
exit 1
```

Le même, avec `nspr`, `nss` et `expat` ajoutés à `NIX_LD_LIBRARY_PATH` pour ce seul processus : `essai de rendu : image 0 de MyComp rendue`, `diagnostic : prêt (1 avertissement)`, exit 0, en 4 s ; `git status` du projet inchangé.

Correction appliquée le 2026-10-25 par `/plugin-nixos:modifie` : `nspr`, `nss` et `expat` dans `programs.nix-ld.libraries`, sous le domaine `developpement` (`conf-nixos/modules/programs/dev.nix`, commit `f29f0e4` du dépôt NixOS), appliquée par Soon. Critère 2 tenu, sur le même projet, sans aide :

```
$ bash scripts/doctor.sh …/scratchpad/probe/essai
ok             node : v22.23.2, accepté par engines.node « ^20.19.0 || ^22.13.0 || >=24 »
ok             ffmpeg : 8.1.2
ok             ffprobe : 8.1.2
ok             versions de Remotion : 4.0.538 pour 3 paquets (remotion et @remotion/*)
ok             essai de rendu : image 0 de MyComp rendue
avertissement  whisper : whisper-cli introuvable ; seul sync-voiceover en a besoin — correction : installer le paquet nixpkgs whisper-cpp via /plugin-nixos:modifie.
diagnostic : prêt (1 avertissement)
exit 0
```

#### Suite d'évaluation

`evals/new-video/` : deux cas positifs (nouvelle vidéo sans dossier, d'où `~/Vidéos/motion/<nom>` ; `./promo` non vide, refusé), deux négatifs (un brief dans un projet qui a son `storyboard.md` ; rendre le MP4 dans un projet avancé), trois exécutions chacun, outils en lecture seule, sans Bash : aucun cas ne lance de commande ni n'utilise le réseau, donc pas de bac à sable. Les `setup.sh` des négatifs sont des copies de ceux de `storyboard-brief-notes` et `storyboard-render-request`. Lancement hors de `pp.sh eval-run`, comme pour `storyboard` : commande annoncée par `pp.sh eval-plan`, `--scaffold` ajouté, verdict par `pp.sh eval-verdict`.

Rouge, avant le skill (un bras ; « oui » de Soon) :

```
$ claude plugin eval /home/soon/Documents/Claude-plugin/plugin-motion --case 'new-video-*' --no-publish --max-cost-usd 3 --ablation none --scaffold --output-dir …/evals/results/new-video-20261024T012554
claude plugin eval : exit 1
$ bash pp.sh eval-verdict … new-video …/aggregate-result.json
rouge : new-video-default-folder : WITH 0.00, Δ —
rouge : new-video-folder-not-empty : WITH 0.00, Δ —
ok : new-video-render-request (négatif) : WITH 1.00, Δ —
ok : new-video-storyboard-brief (négatif) : WITH 1.00, Δ —
coût : 1,57 USD
verdict : rouge
exit 1
```

Vert, après le skill (`check-skill` : conforme ; deux bras ; plafond porté à 6 USD avant l'annonce, l'estimation haute étant de 5,52 USD ; « oui » de Soon) :

```
$ claude plugin eval /home/soon/Documents/Claude-plugin/plugin-motion --case 'new-video-*' --no-publish --max-cost-usd 6 --scaffold --output-dir …/evals/results/new-video-20261025T161054
claude plugin eval : exit 0
$ bash pp.sh eval-verdict … new-video …/aggregate-result.json
ok : new-video-default-folder (positif) : WITH 1.00, Δ +1.00
ok : new-video-folder-not-empty (positif) : WITH 1.00, Δ +1.00
ok : new-video-render-request (négatif) : WITH 1.00, Δ +0.00
ok : new-video-storyboard-brief (négatif) : WITH 1.00, Δ +0.00
coût : 2,40 USD
verdict : vert
exit 0
```

Sans le skill, sur `./promo`, le témoin voit les deux fichiers mais propose de créer le projet à côté puis de le copier dedans (`cp -rn … ./promo/`) ; sans dossier désigné, il ne propose aucun emplacement par défaut. Avec le skill, les trois réponses proposent `~/Vidéos/motion/lancement-appli` et attendent la confirmation ; sur `./promo`, elles nomment `notes.md` et `logo.svg`, n'y touchent pas et proposent `~/Vidéos/motion/promo`.

Coût en contexte permanent (`claude plugin details`) : ~120 tokens pour `new-video` (estimé ~100 ; ~140 avant réduction de la description), ~430 pour le plugin ; ~1,4k à chaque appel.

### Skill `build-scene` — 2026-10-26

Avec Bash (`preview.sh`) et l'agent `frame-reviewer`. Lit `storyboard.md`, annonce l'état des scènes, prend la scène nommée (identifiant ou numéro) ou la première qui n'est pas `validée` : une scène `construite` va droit à l'approbation de Soon, sans être reconstruite. Annonce la scène et ses images clés (0, milieu, dernière, fins d'entrée ; 8 au plus), écrit `src/scenes/<id>.tsx` avec les seules valeurs de `theme.ts`, l'inscrit dans `src/Root.tsx` avec la composition `Video` (`<Series>`), lance `preview.sh`, puis `frame-reviewer` avec le seul dossier, `storyboard.md` et l'identifiant ; écrit `review.md` par tour, corrige les défauts bloquants, 3 tours au plus ; passe la scène en `construite`, montre la planche et attend Soon pour `validée`.

#### `preview.sh`, test d'abord

Rouge, avant le script :

```
$ bash tests/static/test_preview.sh
  ÉCHEC  scripts/preview.sh présent
         absent
test_preview : 0 réussis, 1 échoués, 0 sautés
exit 1
```

Vert après une première version, une image par `remotion still` : `test_preview : 43 réussis, 0 échoués, 0 sautés`, exit 0.

Mesure sur le poste (projet du scratchpad, scène `Message` de 240 images, texte animé), l'architecture laissant le choix ouvert :

| Méthode | Temps |
| --- | --- |
| `remotion still` depuis les sources, 4 images | 41 s (un bundle par image) |
| `remotion bundle`, une fois | 3,1 s |
| puis `remotion still` × 6 depuis le bundle | 10,4 s |
| puis `remotion render --sequence`, les 240 images | 8,6 s |
| puis `remotion render --sequence --frames=0,8,15,70,120,239` | 1,8 s |

La liste d'images de `--frames`, notée en 2026-10-24 d'après le skill officiel `remotion-render`, est constatée : Remotion rend exactement ces images, nommées selon `--image-sequence-pattern` mais complétées au nombre de chiffres de la plus grande (`f000.png`, `f239.png` ; `element-7.png` pour une seule). `preview.sh` rend donc dans un dossier temporaire et renomme en `f<NNNN>.png`. Test changé d'abord :

```
$ bash tests/static/test_preview.sh
…
  ÉCHEC  un seul rendu pour toutes les images
  ÉCHEC  rend la scène depuis le bundle, en séquence, hors du projet
  ÉCHEC  rend 0, 15 et 239, triées et sans doublon, en PNG
…
test_preview : 26 réussis, 19 échoués, 0 sautés
exit 1
```

puis vert :

```
$ bash tests/static/test_preview.sh
…
test_preview : 45 réussis, 0 échoués, 0 sautés
exit 0
```

Cas couverts : scène inconnue (et bloc json leurre après le premier), images hors durée, négatives, décimales, vides ou absentes ; un bundle hors du projet, un seul rendu, images triées et sans doublon ; un seul assemblage ffmpeg, dans l'ordre, par `tile`, chaque image étiquetée ; chemins affichés, planche en dernier ; images d'un tour précédent retirées, `review.md` gardé ; rendu en échec (exit 1, erreur de Remotion, renvoi à `src/Root.tsx`, pas de planche) ; storyboard absent, sans bloc json, illisible, durée absente. `shellcheck -S warning` : rien sur `preview.sh` ; sur le test, le seul SC2034 de `SUITE`, comme `test_doctor.sh`.

Essai réel, sur le poste, sans aide :

```
$ time bash scripts/preview.sh …/scratchpad/projet Message 0 8 15 70 120 239
…/out/preview/Message/f0000.png
…/out/preview/Message/f0008.png
…/out/preview/Message/f0015.png
…/out/preview/Message/f0070.png
…/out/preview/Message/f0120.png
…/out/preview/Message/f0239.png
…/out/preview/Message/planche.png
real	0m5,212s
exit 0
$ bash scripts/preview.sh …/scratchpad/projet Message 240
preview.sh : image 240 hors de la scène Message, qui dure 240 images : de 0 à 239.
exit 2
```

Planche relue : 3 × 2 images, étiquetées sous l'image, identique à celle de la première version. L'image 70 montre un vrai chevauchement (« tout » agrandi mord la virgule) : une planche toute prête pour un essai de `frame-reviewer` sur une vraie scène.

#### Suite d'évaluation

`evals/build-scene/` : trois cas positifs (première scène d'un storyboard à faire ; reprise d'une vidéo dont `Message` est `construite` ; titre de la scène 3 qui déborde, `fontSize: 200` et `nowrap`), deux négatifs (MP4 final, toutes scènes validées ; scène ajoutée au plan). Trois exécutions, outils en lecture seule, sans Bash (choix de Soon) : les projets de test n'ont pas `node_modules`. `setup.sh` tirés d'un même générateur, autonomes. Lancement hors de `pp.sh eval-run`, `--scaffold` ajouté, verdict par `pp.sh eval-verdict`.

Les sessions coûtent ici 0,35 à 0,58 USD, au-delà des 0,13 à 0,23 USD de l'estimation de `eval-plan` : le premier passage rouge a touché son plafond.

Rouge, avant le skill (un bras ; « oui » de Soon) :

```
$ claude plugin eval . --case 'build-scene-*' --no-publish --max-cost-usd 4 --ablation none --scaffold --output-dir ./evals/results/build-scene-20261025T203717
claude plugin eval : exit 2
partiel : cost_ceiling ; résultats incomplets, à ne pas comparer
ok : build-scene-add-scene (négatif) : WITH 1.00, Δ —
rouge : build-scene-first-scene : WITH 0.33, Δ —
rouge : build-scene-fix-overflow : WITH 0.00, Δ —
rouge : build-scene-render-request : WITH 0.83, Δ —
coût : 4,20 USD
verdict : bloqué
exit 2
$ claude plugin eval . --case 'build-scene-re*' --no-publish --max-cost-usd 4 --ablation none --scaffold --output-dir ./evals/results/build-scene-20261025T-rouge2
claude plugin eval : exit 1
ok : build-scene-render-request (négatif) : WITH 1.00, Δ —
rouge : build-scene-resume : WITH 0.22, Δ —
coût : 1,43 USD
verdict : rouge
exit 1
```

Premier vert, après le skill (deux bras, plafond 18 USD ; « oui » de Soon) : verdict rouge, 6,17 USD. `first-scene` 0,67 : une réponse sans l'annonce de la scène, quand l'écriture est refusée ; `resume` 0,83 : une réponse finit par « si tu valides, j'enchaîne sur Final ». Skill corrigé (l'annonce ouvre la réponse même sans écriture ; rien sur la scène suivante avant la réponse de Soon), `check-skill` conforme. Vert, relancé sur les cinq cas (plafond 10 USD, `--keep-temp` ; « oui » de Soon) :

```
$ claude plugin eval . --case 'build-scene-*' --no-publish --max-cost-usd 10 --keep-temp --scaffold --output-dir ./evals/results/build-scene-20261025T222919
claude plugin eval : exit 0
$ bash pp.sh eval-verdict … build-scene …/aggregate-result.json
ok : build-scene-add-scene (négatif) : WITH 1.00, Δ +0.33
ok : build-scene-first-scene (positif) : WITH 1.00, Δ +1.00
ok : build-scene-fix-overflow (positif) : WITH 1.00, Δ +1.00
ok : build-scene-render-request (négatif) : WITH 1.00, Δ +0.17
ok : build-scene-resume (positif) : WITH 1.00, Δ +1.00
coût : 6,72 USD
verdict : vert
exit 0
```

Sans le skill, le témoin trouve la cause du débordement, mais ne parle ni d'images clés, ni de planche, ni de relecture, ni de statut ; sur la reprise, il conteste les statuts du storyboard d'après le code et part sur `Final`. Coût total des évaluations de `build-scene` : 18,52 USD.

Coût en contexte permanent (`claude plugin details`) : ~150 tokens pour `build-scene` (estimé ~100), ~582 pour le plugin ; ~2k à chaque appel.

### Skill `render-video` — 2026-10-28

Avec Bash (`npx remotion render`, `probe.sh`). Lit `storyboard.md` et annonce le format, le total en images et en secondes, la voix off prévue ou non, et le statut de chaque scène. Une scène qui n'est pas `validée` est nommée avec ce qu'elle implique (`à faire` ou sans fichier : absente de `Video`, MP4 incomplet ; `construite` : planche non approuvée) ; le skill propose de la finir par `/plugin-motion:build-scene` ou de rendre quand même, et s'arrête sans donner de commande. Vérifie la composition `Video` de `src/Root.tsx` (format du storyboard, durée égale au total, audio si voix off), rend `npx remotion render Video out/<nom>.mp4` (`<nom>` : celui de Soon, sinon le `name` de `package.json`, sinon le dossier), lance `probe.sh` et présente le verdict par contrôle, avec la cause probable de chaque écart ; ne corrige rien et ne change aucun statut. La description renvoie l'image fixe, la scène seule et l'export transparent au skill officiel `remotion-render` du projet.

#### `probe.sh`, test d'abord

Sorties `ffprobe -v error -print_format json -show_format -show_streams` enregistrées dans `tests/fixtures/probe/`, sur des MP4 encodés par ffmpeg 8.1.2 dans le scratchpad (`testsrc`, libx264 ; une sinusoïde AAC pour `voix`) : `conforme` (1920×1080, 30 i/s, 600 images), `voix` (le même avec une piste audio), `decale` (602 images), `cadence` (600 images à 30000/1001), `resolution` (1280×720). Le test en dérive trois : 601 images, sans `nb_frames`, sans piste vidéo.

Rouge, avant le script :

```
$ bash tests/static/test_probe.sh
  ÉCHEC  scripts/probe.sh présent
         absent
test_probe : 0 réussis, 1 échoués, 0 sautés
exit 1
```

Vert, après :

```
$ bash tests/static/test_probe.sh
  ok     scripts/probe.sh présent
# conforme
  ok     conforme : exit 0
  ok     un verdict JSON sur stdout
  ok     verdict : conforme
  ok     durée : 600 images attendues, 600 lues, écart 0, tolérance 1
  ok     cadence : 30 attendue, 30 lue
  ok     largeur : 1920
  ok     hauteur : 1080
  ok     audio non exigé sans voix off
  ok     ne lit que le premier bloc json
  ok     nomme le MP4 lu, en chemin absolu
  ok     ffprobe appelé une fois
  ok     ffprobe en JSON, flux et format
  ok     un MP4 relatif se lit depuis le projet
  ok     un MP4 en chemin absolu : exit 0
  ok     voix off et piste audio : exit 0
  ok     audio exigé et présent
  ok     une piste audio sans voix off reste conforme
  ok     601 images : exit 0, à une image près
  ok     601 images : écart 1, dans la tolérance
  ok     sans nb_frames : exit 0
  ok     sans nb_frames, la durée vient des secondes × cadence
# durée décalée de 2 images
  ok     602 images : exit 1
  ok     verdict : non conforme
  ok     durée : 602 lues, écart +2
  ok     les autres contrôles restent conformes
# mauvaise cadence
  ok     29,97 i/s : exit 1
  ok     cadence : 29.97 lue, écart -0.03
  ok     la durée en images reste conforme
# mauvaise résolution
  ok     1280×720 : exit 1
  ok     largeur et hauteur non conformes, avec leur écart
# piste audio manquante avec voix off
  ok     voix off sans piste audio : exit 1
  ok     audio exigé, absent
  ok     seul l'audio est en défaut
# MP4 illisible
  ok     refuse un MP4 absent (exit 2)
  ok     ffprobe n'est pas lancé sur un MP4 absent
  ok     refuse un fichier que ffprobe ne lit pas (exit 2)
  ok     refuse un fichier sans piste vidéo (exit 2)
  ok     refuse sans ffprobe, renvoie à doctor.sh (exit 2)
# storyboard illisible
  ok     refuse un projet sans storyboard.md
  ok     refuse un storyboard sans bloc json
  ok     refuse un bloc json illisible
  ok     refuse un storyboard sans format
  ok     refuse une cadence qui n'est pas un nombre entier
  ok     refuse un voiceover qui n'est pas true ou false
  ok     refuse un storyboard sans scène
  ok     refuse une scène sans durée entière, et la nomme
  ok     ffprobe n'est pas lancé sur un storyboard illisible
  ok     refuse un appel sans MP4
  ok     refuse un appel sans projet
test_probe : 50 réussis, 0 échoués, 0 sautés
exit 0
```

Le verdict est un objet JSON : `verdict` (`conforme` ou `non conforme`), `mp4`, puis `durationInFrames` (attendu : la somme des scènes ; lu : `nb_frames` de la piste vidéo, ou ses secondes × sa cadence ; tolérance 1), `fps`, `width`, `height`, chacun avec `expected`, `actual`, `gap` et `ok`, et `audio` (`required` : `voiceover` ; `present` ; `ok`). Une piste audio sans voix off reste conforme. Un MP4 absent, que ffprobe ne lit pas ou sans piste vidéo est refusé (exit 2), comme un storyboard sans bloc json, illisible, sans format, à cadence non entière, à `voiceover` autre que `true` ou `false`, sans scène ou dont une scène n'a pas de durée entière. Quatre mutations du script, chacune prise par le test : tolérance portée à 2 images, contrôle audio neutralisé, lecture au-delà du premier bloc json, cadence arrondie à l'entier. `shellcheck -S warning` : rien sur `probe.sh` ; sur le test, le seul SC2034 de `SUITE`.

#### Essai réel

Projet de trois scènes dans le scratchpad (`Ouverture` 45, `Message` 60, `Final` 45 : 150 images, 1920×1080 à 30 i/s), `src/` écrit à la main, `node_modules` lié à celui du projet d'essai du 2026-10-24 (Remotion 4.0.538), cache npm dans le scratchpad, sans réseau :

```
$ npx remotion render Video out/essai-rendu.mp4
Encoded 150/150
+                    out/essai-rendu.mp4 76.6 kB
real	0m7,876s
exit 0
$ bash scripts/probe.sh …/scratchpad/essai-rendu out/essai-rendu.mp4 | jq -c '{verdict, durationInFrames, fps, width, height, audio}'
{"verdict":"conforme","durationInFrames":{"expected":150,"actual":150,"gap":0,"tolerance":1,"ok":true},"fps":{"expected":30,"actual":30,"gap":0,"ok":true},"width":{"expected":1920,"actual":1920,"gap":0,"ok":true},"height":{"expected":1080,"actual":1080,"gap":0,"ok":true},"audio":{"required":false,"present":false,"ok":true}}
exit 0
```

Sans audio dans la composition, Remotion n'écrit aucune piste audio (une seule piste, h264, `nb_frames` 150) : le contrôle de la voix off a donc un sens. Le même MP4 avec `"voiceover": true` : `non conforme`, `audio` `{"required":true,"present":false,"ok":false}`, exit 1. Avec un `<Audio src={staticFile("voix.wav")} />` (sinusoïde de 5 s) dans `Video`, rendu en 8,1 s : `conforme`, `audio` `{"required":true,"present":true,"ok":true}`, exit 0.

#### Suite d'évaluation

`evals/render-video/` : deux cas positifs (« Toutes les scènes sont validées, sors-moi le MP4 final. » ; « Lance le rendu final de la vidéo. » avec `Message` construite et `Final` à faire, sans fichier), deux négatifs, du ressort de `remotion-render` (« Exporte la scène Ouverture seule en WebM transparent… » ; « Rends l'image 120 de la scène Message en PNG… »). Trois exécutions, outils en lecture seule, sans Bash : les projets de test n'ont pas `node_modules`. `setup.sh` tirés d'un même générateur, autonomes ; la composition `Video` y enchaîne les scènes qui ont leur fichier. Lancement hors de `pp.sh eval-run`, `--scaffold` ajouté, verdict par `pp.sh eval-verdict`.

**Concurrence avec `remotion-render`.** `claude plugin eval` lance chaque session avec `--setting-sources user` (constaté dans la CLI 2.1.296) : un skill posé dans `.claude/skills/` du projet, là où `npx remotion skills add` le lie, n'y est pas chargé. Constaté sans coût, clé factice et API sur `127.0.0.1:9` : sous `--setting-sources user`, seul `$CLAUDE_CONFIG_DIR/skills/` est lu ; sous `user,project`, `.claude/skills/` aussi. Chaque `setup.sh` pose donc un remplaçant de `remotion-render`, même nom et même description (« Export a Remotion video »), corps réécrit (pas de licence trouvée pour `remotion-dev/skills`), dans `$HOME/../config/skills/`, le dossier de configuration de la session ; il sort en 1 si `$HOME/../config/.claude.json` manque, plutôt que de tourner sans concurrent. Vérifié dans les traces gardées : `remotion-render` est chargé dans chacune des 42 sessions ; au vert, dans le bras avec le plugin, les cas positifs invoquent `plugin-motion:render-video` et jamais `remotion-render`, les négatifs `remotion-render` et jamais `render-video`. Les sessions coûtent ici 0,09 à 0,47 USD (0,21 en moyenne au rouge).

Rouge, avant le skill (un bras, plafond 6 USD pour 12 sessions à 0,40 USD, `--keep-temp` pour lire les skills chargés ; « oui » de Soon) :

```
$ claude plugin eval . --case 'render-video-*' --no-publish --max-cost-usd 6 --ablation none --keep-temp --scaffold --output-dir ./evals/results/render-video-20261026T124339
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . render-video …/aggregate-result.json
rouge : render-video-final : WITH 0.00, Δ —
rouge : render-video-not-validated : WITH 0.33, Δ —
ok : render-video-still (négatif) : WITH 1.00, Δ —
ok : render-video-transparent (négatif) : WITH 1.00, Δ —
coût : 2,52 USD
verdict : rouge
exit 1
```

Sans le skill, sur le MP4 final, le modèle invoque `remotion-render`, rend vers `out/notio.mp4` et ne contrôle rien au storyboard. Sur les scènes non validées, il les signale bien, mais propose un rendu provisoire, souvent avec sa commande : le correcteur `asks-first` en passait 2 sur 3. Resserré après le rouge, avant le skill : il exige `/plugin-motion:build-scene` et aucune commande de rendu ; les trois réponses rouges y échouent, et le verdict rouge du cas tient de toute façon par `skill-fired`, inchangé, à 0 appel sur 3.

Vert, après le skill (`check-skill` : conforme ; deux bras, plafond 12 USD pour 24 sessions, `--keep-temp` ; « oui » de Soon) :

```
$ claude plugin eval . --case 'render-video-*' --no-publish --max-cost-usd 12 --keep-temp --scaffold --output-dir ./evals/results/render-video-20261026T125709
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . render-video …/aggregate-result.json
ok : render-video-final (positif) : WITH 1.00, Δ +1.00
ok : render-video-not-validated (positif) : WITH 1.00, Δ +1.00
ok : render-video-still (négatif) : WITH 1.00, Δ +0.00
rouge : render-video-transparent : WITH 0.83, Δ +0.00
coût : 4,94 USD
verdict : rouge
exit 1
```

`render-video` ne s'est déclenché dans aucun négatif. Les deux refus de `transparent-export`, un par bras, portaient sur des réponses justes (VP9 en `yuva420p`, fond opaque à retirer, ProRes 4444 en repli), presque identiques à celles acceptées : la clause FAIL « announces a check of the video against the storyboard » prenait la vérification du WebM exporté (150 images, 1920×1080) pour le contrôle de la vidéo finale. Clause précisée (échoue : rendre `Video` entière ou un MP4 final, proposer `probe.sh`), skill inchangé ; relance du seul cas (6 sessions, plafond 3 USD ; « oui » de Soon) :

```
$ claude plugin eval . --case 'render-video-transparent' --no-publish --max-cost-usd 3 --keep-temp --scaffold --output-dir ./evals/results/render-video-transparent-20261028T110637
claude plugin eval : exit 0
$ bash pp.sh eval-verdict . render-video …/aggregate-result.json
ok : render-video-transparent (négatif) : WITH 1.00, Δ +0.00
coût : 1,29 USD
verdict : vert
exit 0
```

Le vert se compose de ces deux passages : les trois premiers cas du premier, le cas transparent du second. Le cas `still` garde une clause FAIL de même forme ; elle a passé 6 sur 6. Sans le skill, sur le MP4 final, le témoin rend vers `out/notio.mp4` sans annoncer de contrôle au storyboard ; sur les scènes non validées, il propose un rendu partiel avec sa commande. Coût total des évaluations de `render-video` : 8,75 USD.

Coût en contexte permanent (`claude plugin details`) : ~150 tokens pour `render-video` (estimé ~100), ~730 pour le plugin ; ~1,5k à chaque appel.

Reste à faire pour le critère 3 : l'enchaînement complet sur un brief de 3 scènes, de `new-video` à `render-video`, sans que Soon touche au code ; `probe.sh` y est déjà constaté sur un vrai rendu de Remotion (essai réel ci-dessus).
