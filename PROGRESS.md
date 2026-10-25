# PROGRESS — plugin-motion

Dernière mise à jour : 2026-10-25
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Trois composants : l'agent `frame-reviewer` (US-4), le skill `storyboard` (US-2, US-7) et le skill `new-video` (US-1), avec `scripts/doctor.sh` et `templates/`. Les deux hypothèses du PRD sont tranchées, et le critère 2 est tenu sur le poste depuis le 2026-10-25 (voir `new-video`). Prochaine étape : ajouter le composant suivant, `/plugin-plugin:add`.

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
