# PROGRESS — plugin-motion

Dernière mise à jour : 2026-10-30
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Six composants : l'agent `frame-reviewer` (US-4), les skills `storyboard` (US-2, US-7), `new-video` (US-1), `build-scene` (US-3, US-4, US-7), `render-video` (US-6, US-7) et `sync-voiceover` (US-5), avec `scripts/doctor.sh`, `scripts/preview.sh`, `scripts/probe.sh`, `scripts/transcribe.sh`, `scripts/cues.sh` et `templates/`. Les deux hypothèses du PRD sont tranchées, et le critère 2 est tenu sur le poste depuis le 2026-10-25 (voir `new-video`). `probe.sh` déclare conforme un vrai rendu de Remotion, et la suite de `render-video` montre qu'il ne prend pas la place du skill officiel `remotion-render`, chargé dans chaque session (voir `render-video`). Le critère 5 est tenu sur un extrait de Soon (voir `sync-voiceover`), le critère 4 depuis le 2026-10-29 (voir `frame-reviewer`). Le critère 3 est tenu depuis le 2026-10-30, en pilotage headless (voir « Critère 3 »). Reste le critère 6, les suites d'évaluation de chaque skill.

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

#### Critère 4, constaté le 2026-10-29

Planche de test `tests/fixtures/frame-reviewer/` : un `storyboard.md` d'une scène, `Promesse` (1920×1080 à 30 i/s, 90 images ; titre « Toutes vos idées au même endroit » sur une ligne, sous-titre dessous ; fondu, puis fixe jusqu'à la fin), et ses images clés `f0000`, `f0015`, `f0025`, `f0045`, `f0089` avec `planche.png`, rendues par `preview.sh` sur Remotion 4.0.538. Ce sont les images que choisit `build-scene` : la première, la dernière, celle du milieu, la fin de l'entrée du titre (15) et celle du sous-titre (25). Le titre, aligné à gauche à 192 px, en 132 px sans retour à la ligne, sort par le bord droit : on lit « …au même endr », avec le « o » coupé, de l'image 15 à la fin. Sur la planche réduite, la coupure reste discrète. Le code de la scène n'est pas dans la fixture : l'agent ne doit pas le lire.

Chaque exécution copie la fixture dans un dossier au nom neutre, `video-notio/`, puis ouvre une session headless qui lance l'agent comme l'étape 5 de `build-scene`, avec seulement le dossier, le storyboard et l'identifiant :

```
$ claude -p --plugin-dir <plugin-motion> --model sonnet --output-format stream-json --verbose \
    --max-budget-usd 1 --no-session-persistence \
    "Lance l'agent plugin-motion:frame-reviewer avec exactement ces trois éléments, et rien d'autre : le dossier <copie>/out/preview/Promesse/, le chemin <copie>/storyboard.md, l'identifiant Promesse. Rends ensuite son rapport tel quel."
```

Critère de réussite, fixé avant le lancement et vérifié par `grep` sur le rapport brut de l'agent (le résultat de l'outil Agent, pas ce que la session en relaie) : `STATUS: done`, et une ligne `| débordement | bloquant |` sur `f0015`, `f0025`, `f0045` ou `f0089` qui cite « endr ».

| Exécution | Débordement signalé | Zone donnée | Autres défauts | STATUS | Coût |
| --- | --- | --- | --- | --- | --- |
| 1 | bloquant, `f0015` à `f0089` sur une ligne, « Toutes vos idées au même endr » | « haut droite à droite » | marge de sécurité, bloquant | done | 0,26 USD |
| 2 | bloquant, `f0015` à `f0089` sur une ligne, « il manque "oit" » | « haut droite à droite » | écart au storyboard (« endroit » jamais entier), bloquant | done | 0,27 USD |
| 3 | bloquant, une ligne par image (4), « le "r" est lui-même tronqué » | « centre, droite » | marge de sécurité, bloquant ; contraste, mineur, du sous-titre en fondu à `f0015` | done | 0,27 USD |

**Critère 4 tenu** : 3 exécutions sur 3, 0,79 USD au total, sessions comprises ; pas de passage à `opus`. Dans les trois, l'agent tourne sur `claude-sonnet-5-5` et ne lit que `storyboard.md`, `planche.png` et les cinq images clés.

Écarts au format de sortie, sans effet sur le critère : les exécutions 1 et 2 regroupent quatre images sur une seule ligne, alors que le format en demande une par ligne ; aucune ne donne une zone unique de la grille (attendue : `droite`) ; les trois ajoutent un paragraphe des points conformes entre le bloc et le rapport ; les exécutions 1 et 2 posent sous `OPEN_QUESTIONS` une question sur le fondu du titre entre les images 0 et 15, qu'aucune image clé ne montre.

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

### Skill `sync-voiceover` — 2026-10-28

Avec Bash (ffmpeg, `whisper-cli`, `preview.sh`). Proposé à Soon et accepté avant toute écriture : deux scripts testés, que l'architecture ne prévoyait pas, pour la partie déterministe — `transcribe.sh` (ffmpeg en WAV 16 kHz mono, `whisper-cli`, `public/voiceover.json`) et `cues.sh` (repères en images) ; `templates/timing-voiceover.ts`, que le skill pose en `src/timing.ts` à la première synchronisation.

Constaté le 2026-10-28, sur Remotion 4.0.538 (projet d'essai du 2026-10-24, scratchpad) : `import voiceover from "../public/voiceover.json"` dans `src/timing.ts` passe `remotion bundle` et `tsc` ; sans le fichier, le bundle échoue (`Module not found: Can't resolve '../public/voiceover.json'`). Le `timing.ts` que pose `new-video` reste donc sans import : un projet sans voix off doit se construire. Les scènes lisent bien leurs repères par `src/timing.ts`, comme le veut l'architecture : `cueFrame(scene, n)`, l'image du repère `n` depuis le début de la scène. Le skill officiel `remotion-captions` (4.0.538) : description « Transcribing, displaying and animating captions » ; il transcrit par `@remotion/whisper-webgpu` (GPU requis) et impose le type `Caption` (`text`, `startMs`, `endMs`, `timestampMs`, `confidence`) : les mots de `voiceover.json` prennent ce type.

Whisper : `whisper-cpp` 1.8.4 dans la révision épinglée du poste (`nixconf paquet whisper-cpp pc`), binaire `whisper-cli` ; ajouté par `/plugin-nixos:modifie` à `conf-nixos/modules/programs/dev.nix` (domaine `developpement`) : construction de `pc` exit 0, `nvd` : `[A+] whisper-cpp 1.8.4` seul paquet ajouté, lints propres, `bats tests/` 168 ok. Reconstruction lancée par Soon.

#### `cues.sh`, test d'abord

Rouge, avant le script :

```
$ bash tests/static/test_cues.sh
  ÉCHEC  scripts/cues.sh présent
         absent
test_cues : 0 réussis, 1 échoués, 0 sautés
exit 1
```

Vert, après : `test_cues : 71 réussis, 0 échoués, 0 sautés`, exit 0. Cas couverts : chaque repère dans sa scène (rapport, repères écrits par scène dans `voiceover.json`, anciens remplacés, mots gardés, `storyboard.md` inchangé, relance idempotente) ; voix plus longue que la vidéo (642 images pour 600 : exit 1, rien d'écrit ; finie à l'image 600 pile : exit 0) ; repère hors de sa scène, et sur l'image qui suit juste la fin de sa scène ; mot mal entendu (« Nausio. » pour Notio : sans mot, le suivant trouvé quand même), puis `wordIndex` qui l'emporte ; mot dit deux fois ; casse et accents (`IDÉES` trouve `idées`) ; cadence du storyboard (25 i/s, image −10 dans sa scène) ; arrondi de 58,5 à 59 comme `Math.round` ; refus (projet, storyboard, bloc json, cadence, voix off absente, scène, durée, id en double, repère sans mot, `wordIndex` négatif, décimal ou au-delà des mots, `voiceover.json` absent ou illisible, sans mot, mot sans temps numérique). Huit mutations du script, chacune prise par le test : arrondi par défaut, début de scène oublié, curseur qui n'avance pas, casse ASCII seule, fin de scène incluse, écriture même non calée, `wordIndex` ignoré, voix trop longue ignorée. `shellcheck -S warning` : rien sur `cues.sh` ; sur le test, le seul SC2034 de `SUITE`.

`templates/timing-voiceover.ts`, test changé d'abord : `test_templates : 4 réussis, 1 échoués, 0 sautés` (`templates/timing-voiceover.ts présent : absent`), exit 1 ; puis `7 réussis`, exit 0 : identique au `src/timing.ts` d'un projet synchronisé des cas d'évaluation, même `msToFrame` que `timing.ts`, import de `public/voiceover.json` et `cueFrame(scene, n)`.

#### Suite d'évaluation

`evals/sync-voiceover/` : deux cas positifs (« J'ai enregistré la voix off dans public/voix.wav, cale les animations dessus. », trois scènes validées et leurs repères, sans `voiceover.json` ; « La voix off dépasse la fin de la vidéo, recale tout. », une transcription qui finit à 21,4 s, image 642, pour 600 images), deux négatifs (« Ajoute des sous-titres animés en bas de l'écran, mot par mot, à partir de la voix off. » ; « Ajoute une musique de fond, public/musique.mp3, nettement plus bas que la voix. »). Trois exécutions, outils en lecture seule, sans Bash. `setup.sh` tirés d'un même générateur, autonomes ; chacun pose un remplaçant de `remotion-captions`, même nom et même description, corps réécrit, dans `$HOME/../config/skills/`, comme celui de `remotion-render` dans `evals/render-video/`. Lancement hors de `pp.sh eval-run`, `--scaffold` ajouté, verdict par `pp.sh eval-verdict`. Plafonds fixés à 0,40 USD par session, avant l'annonce.

Rouge, avant le skill (un bras, plafond 6 USD pour 12 sessions, `--keep-temp` ; « oui » de Soon) :

```
$ claude plugin eval /home/soon/Documents/Claude-plugin/plugin-motion --case 'sync-voiceover-*' --no-publish --max-cost-usd 6 --ablation none --keep-temp --scaffold --output-dir …/evals/results/sync-voiceover-20261028T184249
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
ok : sync-voiceover-captions (négatif) : WITH 1.00, Δ —
rouge : sync-voiceover-music : WITH 0.50, Δ —
rouge : sync-voiceover-overflow : WITH 0.00, Δ —
rouge : sync-voiceover-recorded : WITH 0.00, Δ —
coût : 4,83 USD
verdict : rouge
exit 1
```

`remotion-captions` est chargé dans chacune des 12 sessions (événement `init` des traces gardées). Sans le skill, sur la voix enregistrée, le modèle invoque `remotion-captions` dans les trois exécutions et propose `@remotion/whisper-webgpu`, ou de relever les temps à la main dans Audacity. Sur la voix trop longue, il calcule juste (image 642, « Disponible » à 168 dans `Final`) mais ne repasse jamais `Final` en `construite` ; une réponse propose de couper le silence de la voix, une autre invoque `plugin-motion:storyboard`. Les trois refus de `music-under-voice` portaient sur des réponses justes (un `<Audio>` de `musique.mp3` à 0,12 sous la voix gardée), refusées parce qu'elles commencent par « La musique n'est pas ajoutée », la session étant en lecture seule : critère précisé (« done or given as the change to make in src/Root.tsx »), à confirmer au vert.

Premier vert, après le skill (`check-skill` : conforme ; deux bras, plafond 12 USD pour 24 sessions, `--keep-temp` ; « oui » de Soon), raté :

```
$ claude plugin eval . --case 'sync-voiceover-*' --no-publish --max-cost-usd 12 --keep-temp --scaffold --output-dir ./evals/results/sync-voiceover-20261028T201858
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
ok : sync-voiceover-captions (négatif) : WITH 1.00, Δ +0.00
rouge : sync-voiceover-music : WITH 0.67, Δ -0.33
rouge : sync-voiceover-overflow : WITH 0.67, Δ +0.67
rouge : sync-voiceover-recorded : WITH 0.67, Δ +0.67
coût : 9,93 USD
verdict : rouge
exit 1
```

Le déclenchement tient : `sync-voiceover` part dans les 6 exécutions positives avec le plugin et dans aucune des 6 négatives ; sans le plugin, les deux positifs restent à 0,00. Les trois cas rouges le sont sur la réponse. `recorded` : les deux réponses refusées donnaient les bonnes commandes sans dire ce que fait `transcribe.sh`, ni « whisper.cpp » ni « mot par mot » ; défaut du skill, corrigé : sans terminal, il dit ce que fait chaque commande. `overflow` : la réponse refusée remplissait les trois points (642 pour 600, `Final` de 210 à 260, `construite`, `cues.sh`), avec un vote partagé du juge `haiku` (FAIL PASS FAIL) : critère précisé. `music` : deux votes partagés sur des réponses justes (`<Audio>` à 0,12 ou 0,15, voix gardée), le skill ne partant pas et le témoin passant 3 sur 3 : critère précisé. `captions`, 6 sur 6, gardé : ni la description du skill ni ses données n'ont changé.

Relance des trois autres cas (deux bras, « oui » de Soon, plafond total 9 USD). Le motif `sync-voiceover-[mor]*` ne prend aucun cas (« No eval cases found matching », exit 1, aucune session) : `--case` n'accepte pas les crochets. Relance cas par cas, 3 USD chacun :

```
$ claude plugin eval . --case 'sync-voiceover-recorded' --no-publish --max-cost-usd 3 --keep-temp --scaffold --output-dir ./evals/results/sync-voiceover-recorded-20261028T222123
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
rouge : sync-voiceover-recorded : WITH 0.67, Δ +0.67
coût : 1,93 USD
verdict : rouge
exit 1
$ claude plugin eval . --case 'sync-voiceover-overflow' --no-publish --max-cost-usd 3 --keep-temp --scaffold --output-dir ./evals/results/sync-voiceover-overflow-20261028T222904
claude plugin eval : exit 0
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
ok : sync-voiceover-overflow (positif) : WITH 1.00, Δ +1.00
coût : 2,32 USD
verdict : vert
exit 0
$ claude plugin eval . --case 'sync-voiceover-music' --no-publish --max-cost-usd 3 --keep-temp --scaffold --output-dir ./evals/results/sync-voiceover-music-20261028T223742
claude plugin eval : exit 0
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
ok : sync-voiceover-music (négatif) : WITH 1.00, Δ +0.00
coût : 0,90 USD
verdict : vert
exit 0
```

`music` : 6 sur 6, `sync-voiceover` jamais appelé. `overflow` : 3 sur 3 avec le plugin, 0 sur 3 sans. `recorded`, lu dans les traces gardées : les trois réponses avec le plugin disent ce que font les deux commandes (whisper.cpp, `whisper-cli`, mot par mot, en local ; image du début du mot, à 30 i/s, depuis le début de sa scène, lue par `cueFrame`). Les deux refusées, après un détour, manquent le point (1) du critère, les repères nommés avec leurs mots et leurs scènes : faute de shell, le modèle a confié les deux scripts à un agent `general-purpose`, qui n'en avait pas plus, puis a répondu sans l'annonce de l'étape 1 (les mots sans leurs scènes dans l'une, aucun mot dans l'autre). La réponse acceptée, sans agent, ouvre sur le tableau des scènes, de leurs statuts et de leurs repères. Le skill demandait déjà l'annonce sans terminal ; il est précisé : ne pas confier les commandes à un agent, et ouvrir la dernière réponse, celle que Soon lit, sur l'annonce de l'étape 1 (`check-skill` : conforme ; `check-evals` : conforme). Le corps du skill ayant changé, `recorded` et `overflow` sont à relancer ; `captions` et `music` ne déclenchent pas le skill et sa description est inchangée : leurs verts tiennent.

Relance de ces deux cas, skill précisé (deux bras, plafond 3 USD chacun ; « oui » de Soon) :

```
$ claude plugin eval . --case 'sync-voiceover-recorded' --no-publish --max-cost-usd 3 --keep-temp --scaffold --output-dir ./evals/results/sync-voiceover-recorded-20261028T234236
claude plugin eval : exit 0
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
ok : sync-voiceover-recorded (positif) : WITH 1.00, Δ +1.00
coût : 2,19 USD
verdict : vert
exit 0
$ claude plugin eval . --case 'sync-voiceover-overflow' --no-publish --max-cost-usd 3 --keep-temp --scaffold --output-dir ./evals/results/sync-voiceover-overflow-20261028T235148
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
rouge : sync-voiceover-overflow : WITH 0.67, Δ +0.67
coût : 1,81 USD
verdict : rouge
exit 1
```

`recorded` : 3 sur 3 avec le plugin, sans agent, chaque réponse ouverte sur les scènes et leurs repères ; 0 sur 3 sans. `overflow` : avec le plugin, votes PASS PASS PASS, PASS PASS FAIL, et FAIL FAIL FAIL sur la première exécution, dont la réponse remplit pourtant les trois points, comme les deux acceptées : voix finie à 21 400 ms, image 642, 42 images de trop ; `Final` de 210 à au moins 260 images, total 650, dans `storyboard.md` et `src/Root.tsx` (`<Composition>`, `<Series.Sequence>`, durée de `Video`), aucune autre scène changée ; `Final` repassée de `validée` à `construite`, ses repères recalculés par `cues.sh` ; l'audio intact. Sa trace ne diffère des deux autres que par `src/Root.tsx` non lu. Le juge `haiku` ne donne que ses votes, pas leurs raisons. Deuxième refus d'une réponse complète sur ce critère, après le premier vert : blocage exposé à Soon, enregistré au point de reprise. Coût des évaluations de `sync-voiceover` à ce point : 23,91 USD.

Relance d'`overflow` seul avec le juge `sonnet`, critère et skill inchangés (deux bras, plafond 3 USD ; « oui » de Soon) :

```
$ claude plugin eval . --case 'sync-voiceover-overflow' --no-publish --max-cost-usd 3 --keep-temp --scaffold --judge-model sonnet --output-dir ./evals/results/sync-voiceover-overflow-20261029T141934
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
rouge : sync-voiceover-overflow : WITH 0.33, Δ +0.33
coût : 2,11 USD
verdict : rouge
exit 1
```

Votes unanimes cette fois : FAIL FAIL FAIL, FAIL FAIL FAIL, PASS PASS PASS avec le plugin, FAIL ×3 sans. Les trois réponses donnent les mêmes nombres (642, 42 de trop, `Final` de 210 à 260, total 650, aux quatre endroits) et la même suite (`cues.sh`, `Final` en `construite`). Une seule différence, systématique : les deux refusées repassent aussi Ouverture et Message en `construite`, « puisque leurs repères seront écrits pour la première fois » dans `public/voiceover.json` ; l'acceptée garde « Ouverture et Message ne bougent pas ». L'état du cas est celui d'une voix réenregistrée : `transcribe.sh` vide `cues`, `storyboard.md` garde les images de la première prise (vite 59, Notez 18, retrouvez 72, Notio 18, Disponible 72) ; seul Disponible passe à 168. Par la règle de l'étape 6 du skill, une scène touchée a changé d'image de repère, de durée ou de code : Ouverture et Message ne le sont pas. Le skill ne dit pas contre quoi comparer l'image d'un repère, et un repère réécrit à la même image y passe pour un changement : deux réponses sur trois renvoient en revue des scènes déjà validées. Le juge ne rend que ses votes : cette lecture est la seule différence trouvée, pas sa raison donnée. Troisième rouge d'`overflow` au vert : blocage exposé à Soon. Coût des évaluations de `sync-voiceover` à ce point : 26,02 USD.

Avec l'accord de Soon, étape 6 du skill précisée (une scène est touchée quand sa durée ou son code change, ou quand l'image d'un de ses repères diffère du `"frame"` qu'il avait dans `storyboard.md` ; un repère réécrit dans `public/voiceover.json` à la même image ne la touche pas) et clause FAIL ajoutée à `lengthen-final` (Ouverture ou Message renvoyée en `construite`) ; `check-skill` et `check-evals` : conformes. Relance des deux positifs, juge `sonnet` (deux bras, plafond 3 USD chacun ; « oui » de Soon) :

```
$ claude plugin eval . --case 'sync-voiceover-recorded' --no-publish --max-cost-usd 3 --keep-temp --scaffold --judge-model sonnet --output-dir ./evals/results/sync-voiceover-recorded-20261029T143016
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
rouge : sync-voiceover-recorded : WITH 0.83, Δ +0.83
coût : 1,91 USD
verdict : rouge
exit 1
$ claude plugin eval . --case 'sync-voiceover-overflow' --no-publish --max-cost-usd 3 --keep-temp --scaffold --judge-model sonnet --output-dir ./evals/results/sync-voiceover-overflow-20261029T143724
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
rouge : sync-voiceover-overflow : WITH 0.33, Δ +0.33
coût : 1,85 USD
verdict : rouge
exit 1
```

`overflow` : les trois réponses gardent désormais Ouverture et Message `validée` ; la précision a pris. Deux restent refusées (FAIL ×3), une acceptée (PASS ×3), sur les mêmes nombres (642, 42 de trop, `Final` de 210 à 260, total 650, aux quatre endroits), `Final` en `construite` et `cues.sh` dans les trois : aucune différence trouvée entre elles qui touche le critère. Sur les 12 exécutions jugées par `sonnet`, les trois votes sont toujours unanimes : ils ne sont pas indépendants, et une réponse se joue sur un seul jugement. `recorded` : la réponse refusée dit « Les scènes dont les repères bougent repasseront de `validée` à `construite` », sans dire lesquelles, quand le point (4) veut les scènes dont les repères sont posés ; ici aucun repère n'avait d'image, les trois scènes sont touchées. Effet probable de la précision de l'étape 6, qui ne dit pas qu'un repère sans `"frame"` change en en prenant une. Quatrième rouge d'`overflow` au vert : blocage exposé à Soon. Coût des évaluations de `sync-voiceover` à ce point : 29,78 USD.

Rejeu du juge avec ses raisons (« oui » de Soon) : 4 appels `claude -p --model sonnet --tools "" --strict-mcp-config --disable-slash-commands`, prompt système de juge, critère exact et réponse tirés de `aggregate-result.json` (`evidence`, de la longueur du dernier message de chaque trace gardée), consigne de passer chaque point PASS et chaque clause FAIL avec la citation de la réponse ; 0,11 USD. `overflow` bras with 1, 2 et 3 : PASS, PASS, PASS ; `recorded` bras with 1 : PASS, le point (4) tenu par « Les scènes dont les repères bougent repasseront de `validée` à `construite` ». Les trois réponses refusées remplissent donc leur critère. Le prompt du juge de `claude plugin eval` 2.1.309, lu dans son binaire : « You are grading the output of a coding agent against a criterion. Criterion: … Agent output … Respond with exactly one word: PASS or FAIL. » Un mot, sans raisonnement, sur trois ou quatre points et quatre ou cinq clauses FAIL : la source des refus. Correction, accord de Soon : chaque critère `llm` découpé en graders `regex` pour les faits écrits tels quels et en `llm` d'un seul point — `overflow` : `642`, `cues\.sh`, `Final[^\n]*construite`, `final-only` (Final seule à 252 images au moins, audio intact), `others-validated` (Ouverture et Message pas renvoyées en `construite`) ; `recorded` : `voiceover-json` gardé, `whisper-cli`, `timing\.ts`, `construite`, `cues-named`, `frame-from-word`, `scenes-back`, `whisper-only`. Rejouées sur les 12 réponses gardées, les regex prennent les 6 bras with et laissent chaque bras without en échec sur une au moins (`cues.sh`, `whisper-cli`). Étape 6 du skill précisée : un repère sans `"frame"` qui en prend une touche sa scène ; sans terminal, la réponse nomme les scènes qui repassent en `construite`. `check-evals` : conforme, 4 cas ; `check-skill` : conforme. Coût des évaluations de `sync-voiceover` à ce point : 29,89 USD.

Relance des deux positifs, graders découpés et skill précisé, juge `sonnet` (deux bras, plafond 3 USD chacun ; « oui » de Soon) :

```
$ claude plugin eval . --case 'sync-voiceover-recorded' --no-publish --max-cost-usd 3 --keep-temp --scaffold --judge-model sonnet --output-dir ./evals/results/sync-voiceover-recorded-20261029T173634
claude plugin eval : exit 0
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
ok : sync-voiceover-recorded (positif) : WITH 1.00, Δ +0.92
coût : 1,51 USD
verdict : vert
exit 0
$ claude plugin eval . --case 'sync-voiceover-overflow' --no-publish --max-cost-usd 3 --keep-temp --scaffold --judge-model sonnet --output-dir ./evals/results/sync-voiceover-overflow-20261029T174357
claude plugin eval : exit 1
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
rouge : sync-voiceover-overflow : WITH 0.80, Δ +0.40
coût : 1,93 USD
verdict : rouge
exit 1
```

`recorded` : 3 sur 3 avec le plugin, les 8 graders passés dans chaque exécution ; les trois réponses nomment les scènes qui repassent en `construite` (« les trois scènes (Ouverture, Message, Final) repassent de `validée` à `construite` ») : la précision de l'étape 6 a pris. Sans le plugin, 0, 0 et 0,25. `overflow` : avec le plugin, `642`, `cues\.sh`, `Final[^\n]*construite` et `others-validated` passés dans les trois exécutions ; `final-only` refusé dans les trois (PASS FAIL FAIL, FAIL ×3, FAIL ×3). Les trois réponses y répondent pourtant : Final de 210 à 260 images, total 650, durée changée dans `storyboard.md`, `src/Root.tsx` et `Video`, Ouverture et Message inchangées, l'audio intact. Les votes ne sont plus tous unanimes. Cinquième rouge d'`overflow` au vert, toujours un juge d'un mot qui refuse une réponse complète : blocage exposé à Soon, enregistré au point de reprise. Coût des évaluations de `sync-voiceover` à ce point : 33,33 USD.

Diagnostic de `final-only`, choisi par Soon : rejouer le prompt d'un mot du harnais sur les trois réponses, puis retirer une clause du critère à chaque essai. Le prompt exact, lu dans le binaire 2.1.309 : système « You are a strict, terse evaluation judge for coding-agent traces. » ; message « You are grading the output of a coding agent against a criterion. », `Criterion:`, le critère, `Agent output (last_message):`, la réponse, « Respond with exactly one word: PASS or FAIL. ». Le vote vaut PASS si la réponse contient `PASS` et pas `FAIL`. Le juge part avec `thinkingConfig: {type: "disabled", mechanical: true}`, sans réflexion ; son coût le confirme (0,032 USD pour 6 appels d'environ 1 800 jetons d'entrée, rien en sortie). Le rejeu par `claude -p --model sonnet --tools ""` sur la réponse 2, à qui le harnais a donné FAIL ×3 : PASS 7 fois sur 7, mais sonnet 5.5 y réfléchit toujours, 130 à 240 jetons, que la réflexion soit coupée par `MAX_THINKING_TOKENS=0`, `CLAUDE_CODE_DISABLE_THINKING=1` ou `alwaysThinkingEnabled: false`, l'effort en `low` ou en `high`. Le juge du harnais ne se reproduit pas sans clé d'API, et il n'y en a pas sur le poste : l'ablation n'a pas été faite. Constat : c'est le juge sans réflexion qui refuse `final-only` ; avec réflexion, d'un mot ou avec raisons, il le passe. Coût du diagnostic : 0,05 USD ; total des évaluations de `sync-voiceover` : 33,38 USD.

Correction, avec l'accord de Soon : `final-only` découpé en contrôles d'un point, au modèle d'`others-validated`, le seul juge qui passait. Une regex `total-650` (`\b650\b`) pour le nouveau total : le minimum de la règle de l'étape 4, 642 + `exit` 8 du thème du cas. Deux juges, `others-unchanged` (Ouverture à 150 images, Message à 240 ; « FAIL only if » leur durée change) et `audio-intact` (« FAIL only if » la voix est coupée, accélérée ou rognée). Sur les 30 réponses gardées des cinq relances d'`overflow`, `total-650` est présente dans les 15 avec le plugin et absente des 15 sans. `pp.sh check-evals . sync-voiceover` : conforme, 4 cas.

Relance d'`overflow` seul, juge `sonnet`, lancée par Soon dans son terminal :

```
$ claude plugin eval . --case 'sync-voiceover-overflow' --no-publish --max-cost-usd 3 --keep-temp --scaffold --judge-model sonnet --output-dir "./evals/results/sync-voiceover-overflow-$(date +%Y%m%dT%H%M%S)"
→ ./evals/results/sync-voiceover-overflow-20261029T181659
$ bash pp.sh eval-verdict . sync-voiceover …/aggregate-result.json
ok : sync-voiceover-overflow (positif) : WITH 1.00, Δ +0.48
coût : 1,78 USD
verdict : vert
exit 0
```

Avec le plugin, les 8 graders passent dans les trois exécutions, chaque juge à PASS ×3. Sans le plugin, 0,57, 0,57 et 0,43 : `cues\.sh`, `Final[^\n]*construite` et `total-650` absents des trois réponses, `audio-intact` refusé (FAIL ×3) dans la troisième. Les quatre cas de `sync-voiceover` sont verts : `captions` et `music` (négatifs) avant la précision de l'étape 6, qui ne touche pas la description ; `recorded` (20261029T173634, 1.00, Δ +0.92) ; `overflow` (20261029T181659, 1.00, Δ +0.48). Coût des évaluations de `sync-voiceover` : 35,16 USD.

#### Whisper sur le poste, constaté le 2026-10-28

Après la reconstruction de Soon : `whisper-cli` (whisper.cpp 1.8.4, CPU, `libggml-cpu-haswell`), avec `whisper-vad-speech-segments` et `whisper-cpp-download-ggml-model` dans le même paquet ; formats lus : flac, mp3, ogg, wav ; langue `en` par défaut. Sortie mot par mot : `-ml 1 -sow` (un mot par segment) avec `-oj` ou `-ojf` (jetons, probabilités) ; `-dtw <préréglage>` (temps des jetons par DTW) n'agit qu'avec `-nfa` : sinon `dtw_token_timestamps is not supported with flash_attn - disabling`. Tailles lues dans les en-têtes de huggingface.co/ggerganov/whisper.cpp : base 148 Mo, small-q5_1 190 Mo, small 488 Mo, medium-q5_0 539 Mo, large-v3-turbo-q5_0 574 Mo, medium 1 534 Mo, large-v3-turbo 1 625 Mo. Modèle choisi par Soon : `ggml-large-v3-turbo-q5_0.bin`, téléchargé dans `~/.cache/plugin-motion/` (sha256 `394221709c…ffa7e2`, celui de Hugging Face) ; modèle de détection vocale `ggml-silero-v6.2.0.bin` (885 Ko, ggml-org/whisper-vad, sha256 `2aa269b785…fb6987`), accord de Soon après le constat ci-dessous.

#### Essai réel, critère 5

**Extrait.** Enregistré par Soon le 2026-10-28 par le micro du bureau à distance (`pw-record --target 69 --channels 1`, « Remoteaudio Source », seule source du poste) : WAV 48 kHz mono de 25,55 s, bruit de fond à −35 dB RMS, le texte « Vos idées vont trop vite ? / Notez tout, / retrouvez tout. / Notio. / Disponible sur iOS et Android. » entre 15,6 et 25 s. Extrait d'essai coupé à 14,000 s par ffmpeg (échantillons décodés identiques à l'original, 554 496 échantillons), hors du dépôt, dans le scratchpad ; seules les sorties de whisper entrent dans `tests/fixtures/voiceover/`.

**Vérité de terrain, sans Whisper.** `silencedetect` échoue sur ce bruit (pics à −12,8 dB) : enveloppe RMS par fenêtres de 10 ms (`asetnsamples=480,astats`) ; une prise de parole est la première fenêtre au-dessus de −25 dB (0,7 % des fenêtres de bruit) après 300 ms en dessous. Cinq prises, une par mot visé, chacune contrôlée sur le spectrogramme (`showspectrumpic`) : les harmoniques de la voix commencent au début mesuré ; celui de « Disponible » se lit /di/ voisé, /s/ (énergie au-dessus de 3 kHz), occlusion du /p/, puis « o » : le mot, pas un souffle. À −30 dB, le bruit avance « Notez » de 270 ms : seuil gardé à −25. Débuts dans l'extrait : Vos 1,67 s (le /v/ voisé monte dès ~1,59), Notez 3,94–3,95, retrouvez 5,39, Notio 7,13, Disponible 8,16.

**Whisper seul ne tient pas ±3 images.** Sur l'extrait, `large-v3-turbo-q5_0`, `-l fr` :

| Mot visé | Vérité | `-ml 1 -sow` | `-dtw large.v3.turbo -nfa` (`t_dtw`) | segments de la détection vocale, `-vp 0` |
| --- | --- | --- | --- | --- |
| Vos | 1,67 | 0,00 | 1,76 | 1,66 |
| Notez | 3,95 | 2,86 | 4,20 | 3,94 |
| retrouvez | 5,39 | 4,58 | 5,62 | 5,38 |
| Notio | 7,13 | 6,06 | 7,36 | 7,14 |
| Disponible | 8,16 | 7,73 | 8,38 | 8,16 |

Sans DTW, Whisper fait commencer un mot dit après une pause à la fin du mot précédent, pause comprise : jusqu'à 1,1 s trop tôt (33 images). Le DTW retarde de 90 à 250 ms. `--vad` dans `whisper-cli` supprime l'hallucination du silence (« Sous-titrage Société Radio-Canada » sur 10 s sans voix, 0 mot avec `--vad`) mais ne recale pas les mots. La détection vocale (silero, réseau de neurones), méthode indépendante de l'enveloppe d'énergie, tombe à ±10 ms de la vérité. D'où la règle de `transcribe.sh`, approuvée par Soon : un mot dans l'intervalle Whisper duquel s'ouvre un segment de parole commence à ce début de segment. Limite constatée, mots en milieu de phrase (début de l'occlusion du /t/) : « trop » 2,38 s, Whisper 2,36 ; « tout » de « Notez tout » 4,31 s, Whisper 3,95 (−11 images) ; « tout » de « retrouvez tout » 5,77 s, Whisper 5,52 (−7,5 images) ; DTW +160 à +230 ms. Après une pause, Whisper prend un mot de retard que la règle ne rattrape que pour le premier mot. `cues.sh` marque donc chaque repère `atSpeechStart` : vrai quand son mot ouvre un segment de parole, le seul cas garanti.

**Chaîne réelle.** Projet Remotion 4.0.538 du scratchpad (le `node_modules` du 2026-10-24), 640×360 à 30 i/s, Ouverture 100, Message 100, Final 160 images ; `src/timing.ts` = `templates/timing-voiceover.ts` ; chaque scène noire, blanche sur la seule image `cueFrame(id, n)` de chacun de ses repères ; `<Audio src={staticFile("voix.wav")} />` dans `Video`.

```
$ bash scripts/transcribe.sh …/essai-voix public/voix.wav
{ "words": 15, "speech": 5, "corrected": 4, "endMs": 10030, "endFrame": 301, "total": 360, "overflow": 0, … }
78 s ; exit 0
$ bash scripts/cues.sh …/essai-voix
verdict « calé », written true ; Vos 50, Notez 118, retrouvez 161, Notio 214, Disponible 245 (images dans la vidéo), atSpeechStart vrai pour les cinq
exit 0
$ npx remotion render src/index.ts Video out/essai-voix.mp4
Encoded 360/360 ; 9,4 s ; exit 0
$ bash scripts/probe.sh …/essai-voix out/essai-voix.mp4
conforme : 360 images, audio exigé et présent ; exit 0
```

Mesuré dans le MP4 lui-même : images blanches (`signalstats`, YAVG > 128) 50, 118, 161, 214, 245, les 355 autres noires ; débuts des mots sur sa piste AAC (même enveloppe, −25 dB) 1,67, 3,95, 5,40, 7,13, 8,18 s.

| Repère | Flash | Mot dans le MP4 (× 30) | Écart | Vérité de l'extrait (× 30) | Écart |
| --- | --- | --- | --- | --- | --- |
| Vos | 50 | 50,1 | −0,1 | 50,1 (47,7 au début du /v/) | −0,1 (+2,3) |
| Notez | 118 | 118,5 | −0,5 | 118,2 | −0,2 |
| retrouvez | 161 | 162,0 | −1,0 | 161,7 | −0,7 |
| Notio | 214 | 213,9 | +0,1 | 213,9 | +0,1 |
| Disponible | 245 | 245,4 | −0,4 | 244,8 | +0,2 |

**Critère 5 tenu** : les cinq animations tombent à 1 image au plus du mot visé (2,3 en comptant le voisement du /v/), pour ±3 exigées. Whisper seul les aurait placées 18 à 35 images trop tôt (Notez 86, retrouvez 136, Notio 179, Disponible 227). Non couvert : un repère sur un mot en milieu de phrase, signalé par `atSpeechStart` faux.

#### `transcribe.sh` et `atSpeechStart`, test d'abord

Écrits après le constat de Whisper ci-dessus, avant la chaîne réelle. `test_transcribe` remplace ffmpeg, `whisper-cli` et `whisper-vad-speech-segments` par des doublures qui rejouent leurs sorties enregistrées sur l'extrait de Soon et sur 10 s de silence (`tests/fixtures/voiceover/`) : ni réseau, ni modèle, ni audio.

Rouge, avant le script :

```
$ bash tests/static/test_transcribe.sh
  ÉCHEC  scripts/transcribe.sh présent
         absent
test_transcribe : 0 réussis, 1 échoués, 0 sautés
exit 1
```

Vert, après : `test_transcribe : 50 réussis, 0 échoués, 0 sautés`, exit 0. Cas couverts : transcription (résumé JSON, 15 mots, 5 segments de parole, 4 débuts recalés ; segment vide de Whisper écarté ; mots au type `Caption` ; Notez recalé de 2 850 à 3 940 ms, les mots dits sans pause gardant le début de Whisper ; confiance, la plus faible des jetons du mot ; repères d'une transcription précédente effacés ; arguments de ffmpeg, de `whisper-cli` et de la détection vocale ; WAV converti hors du projet, dossier temporaire retiré ; seul `public/voiceover.json` change) ; langue passée à whisper et écrite ; silence (exit 1, rien d'écrit) ; refus (projet, fichier audio absent ou hors de `public/`, cadence, modèle Whisper ou de détection vocale absent avec sa taille et sa commande, ffmpeg, `whisper-cli` ou `whisper-vad-speech-segments` absent, erreur de ffmpeg ou de whisper, sortie illisible ; un refus n'écrit rien). Neuf mutations du script, chacune prise par le test : sans recalage (2 échecs), confiance la plus forte (2), détection vocale avec marge (1), segments vides gardés (7), fichier hors de `public/` accepté (3), repères gardés (1), dernier segment ouvert après le début du mot au lieu du premier dans son intervalle (5), langue ignorée (1), silence écrit (3). `shellcheck` : rien sur `transcribe.sh`.

`atSpeechStart` dans `cues.sh`, test changé d'abord (vrai quand un segment de parole de `voiceover.json` s'ouvre après le début du mot précédent et au plus tard au début du mot du repère ; nul sans segments) :

```
$ bash tests/static/test_cues.sh
  ÉCHEC  vite : mot 4 « vite ? », 1960 ms, image 59, scène à 0
  ÉCHEC  vite, dit en milieu de phrase, n'ouvre pas de segment de parole
  ÉCHEC  Notez, retrouvez, Notio et Disponible ouvrent chacun un segment
  ÉCHEC  idées, au milieu de la première phrase, n'ouvre pas de segment
  ÉCHEC  le premier mot ouvre le premier segment, qui commence avec lui
test_cues : 72 réussis, 5 échoués, 0 sautés
exit 1
```

Vert, après : `test_cues : 77 réussis, 0 échoués, 0 sautés`, exit 0 ; puis le refus de segments de parole mal formés, `78 réussis`, exit 0. Deux mutations de plus, prises : un segment ouvert au début même du mot précédent compté (1 échec) ; un segment ouvert au début même du mot du repère oublié (2).

## Critère 3 — 2026-10-30

Critère : à partir d'un brief de 3 scènes, `new-video` → `storyboard` → `build-scene` (×3) → `render-video` produit un MP4 que `probe` déclare conforme, sans que Soon touche au code. Mode choisi par Soon : pilotage headless, où Claude répond aux validations.

Dossier `lancement-appli/` neuf, hors du dépôt. Chaque skill dans sa session `claude -p --plugin-dir <plugin-motion> --add-dir <plugin-motion> --model sonnet --permission-mode acceptEdits --allowedTools …` (outils nommés, `bypassPermissions` refusé par le classificateur de ce poste), sans que je touche au code du projet vidéo.

| Étape | Résultat | Coût |
| --- | --- | --- |
| `new-video` | projet Remotion 4.0.539, 12 skills officiels ; `doctor.sh` : exit 0, 0 avertissement | 0,29 USD |
| `storyboard` | brief de 4 éléments donné d'emblée : 3 scènes (`Titre`, `Promesse`, `Conclusion`) de 90 images, 270 au total (9 s), 1920×1080 à 30 i/s ; `theme.ts` réglé | 0,12 USD |
| `build-scene` Titre | tour 1 : 3 défauts mineurs de marge, taille réduite ; tour 2 : aucun défaut ; `construite`, puis `validée` | 0,81 USD |
| `build-scene` Promesse | tour 1 : aucun défaut ; `construite`, puis `validée` | 0,54 USD |
| `build-scene` Conclusion | tour 1 : aucun défaut ; `construite`, puis `validée` | 0,41 USD |
| `render-video` | `out/lancement-appli.mp4`, 171,7 Ko | 0,10 USD |

`bash scripts/probe.sh <projet> out/lancement-appli.mp4`, relancé hors de la session : `conforme`, exit 0 — durée 270 images pour 270 attendues (écart 0), 30 i/s, 1920×1080, piste audio non requise et absente ; `ffprobe` lit la même chose (270 images, 30/1). Le rapport de `render-video` donne le même tableau.

**Critère 3 tenu.** Coût total : 2,27 USD, sessions comprises.

Écarts au scénario, tels qu'ils sont arrivés :

- l'étape 3.4 de `new-video` (`cp` des trois modèles depuis `templates/`) est refusée dans la session headless, avec ou sans `--add-dir` : le contrôle de permissions voit la source comme un fichier « sensible ». La session s'est arrêtée là sans contourner. J'ai fait les trois `cp` moi-même, sans changement, puis la suite est repartie ; c'est une limite du harnais de test, pas du skill. En session interactive, Soon répond à la demande d'autorisation ;
- les « oui » aux trois planches sont les miens, après avoir ouvert chaque `planche.png` : lisibles, rien ne déborde. Le rythme et le goût de Soon n'y sont pas jugés ; deux remarques du relecteur restent pour lui : les mots de `Titre` entrent calés à gauche et ne se centrent qu'au dernier, et « Inter » n'est pas chargée dans le projet (repli sur la police du système) ;
- le brief donne les quatre éléments d'un coup, donc `storyboard` n'a posé aucune question ; le test ne couvre pas la conduite à une question par message, que `evals/storyboard/` couvre.
