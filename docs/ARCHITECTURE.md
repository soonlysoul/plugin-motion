# Architecture — plugin-motion

2026-10-23 · Soon · PRD : `docs/PRD.md`

**Statut : APPROUVÉ** le 2026-11-01 (« Je valide »).

## Modèle

Plugin au modèle de plugin-flutter : dépôt dédié `soonlysoul/plugin-motion`, plugin à la racine, manifeste sans e-mail, licence MIT, marketplace locale `"source": "./"`, composants à la racine, tests dans `tests/`. Les scripts déterministes vivent dans `scripts/`. Les modèles de fichiers posés dans chaque projet vidéo vivent dans `templates/`, comme dans plugin-flutter.

## Vue d'ensemble

Trois couches, chacune à sa place :

| Couche | Où | Rôle |
| --- | --- | --- |
| Jugement | `skills/`, `agents/` | Interroger Soon, écrire le storyboard, coder les scènes, juger les images, corriger |
| Déterministe | `scripts/` | Diagnostiquer l'environnement, rendre images et planche contact, comparer le MP4 au storyboard : toujours la même réponse pour la même entrée, testés sans réseau |
| Projet vidéo | dossier de chaque vidéo | Ce que le plugin écrit : code Remotion, thème, storyboard, aperçus, rendu |

Le parcours :

```
new-video      : dossier → create-video --blank → remotion skills add → remotion add @remotion/google-fonts → templates/ → doctor.sh
storyboard     : brief → storyboard.md (format, scènes « à faire ») → accord de Soon
build-scene    : storyboard.md → scène suivante → src/scenes/<Scene>.tsx + composition
               → preview.sh → frame-reviewer → corrections → « construite » → validation → « validée »
sync-voiceover : fichier audio → transcribe.sh (Whisper) → public/voiceover.json → cues.sh (repères en images) → preview.sh
render-video   : scènes « validées » → remotion render → probe.sh → rapport
```

Chaque skill commence par lire `storyboard.md` et annonce où en est la vidéo : c'est la reprise (US-7).

## Projet vidéo

Un dossier par vidéo, à l'emplacement tranché dans le PRD :

| Fichier | Écrit par | Contenu |
| --- | --- | --- |
| `storyboard.md` | `storyboard`, `build-scene`, `sync-voiceover` | La source de vérité : format (largeur, hauteur, cadence), puis pour chaque scène son identifiant, sa durée en images, son texte, l'intention du mouvement, ses repères de voix off et son statut (`à faire`, `construite`, `validée`). Ces données forment un bloc ` ```json ` en tête du fichier, lu par jq ; le texte libre de chaque scène suit en dessous. |
| `src/theme.ts` | `new-video` (modèle), `storyboard` | Couleurs, polices et leur graisse, courbes d'accélération, durées types. Les polices sont des Google Fonts, chargées en tête du fichier par `@remotion/google-fonts`, que le rendu attend ; il les télécharge de fonts.gstatic.com, donc demande le réseau ; un nom de police seul n'est pas chargé, et le rendu prend une police de repli. Les scènes n'écrivent aucune couleur, police ni graisse en dur. |
| `src/scenes/<Scene>.tsx` | `build-scene` | Une composition par scène |
| `src/Root.tsx` | `build-scene` | Une `Composition` par scène, plus la composition complète `Video`, qui enchaîne les scènes |
| `src/timing.ts` | `new-video` (modèle), `sync-voiceover` | Conversion des millisecondes en numéro d'image (`Math.round(ms * fps / 1000)`) ; à la première synchronisation, `templates/timing-voiceover.ts` le remplace et y ajoute l'accès aux mots de `voiceover.json` et `cueFrame(scene, n)`, l'image d'un repère depuis le début de sa scène |
| `public/voiceover.json` | `transcribe.sh`, `cues.sh` | Les mots de la voix off avec leur début et leur fin en millisecondes (type `Caption` de Remotion, avec leur confiance), les segments de parole, et les repères de chaque scène en images |
| `out/preview/<Scene>/` | `preview.sh`, `build-scene` | Images clés `f<NNNN>.png`, `planche.png`, et `review.md`, le dernier rapport de `frame-reviewer` |
| `out/<nom>.mp4` | `render-video` | Le rendu final |

Les skills officiels de Remotion sont installés dans le projet par `npx remotion skills add` ; le dossier exact reste à constater à la création (hypothèse du PRD).

## Composants

Chaque composant répond à une user story ; aucun n'existe « au cas où ».

| Composant | Type | User stories | Pourquoi ce type | Coût permanent estimé |
| --- | --- | --- | --- | --- |
| `new-video` | skill | US-1 | Dialogue et jugement : dossier, nom, lecture du diagnostic et conseil de correction | ~100 tokens |
| `storyboard` | skill | US-2, US-7 | Jugement : découper un brief en scènes, choisir durées et intentions de mouvement, faire valider | ~100 tokens |
| `build-scene` | skill | US-3, US-4, US-7 | Jugement : coder une scène, choisir les images clés, corriger d'après le rapport | ~100 tokens |
| `sync-voiceover` | skill | US-5, US-7 | Jugement : associer chaque repère au mot visé, recaler les scènes | ~100 tokens |
| `render-video` | skill | US-6, US-7 | Dialogue : avertir des scènes non validées, présenter le rapport de conformité | ~100 tokens |
| `frame-reviewer` | agent | US-4 | Tâche bornée et répétée par scène, dans un contexte neuf : un regard qui n'a pas écrit la scène trouve mieux ses défauts | ~80 tokens |
| `doctor.sh` | script | US-1 | Déterministe : présence et versions des outils, essai de rendu | 0 |
| `preview.sh` | script | US-4 | Déterministe : rendre des images données et les assembler | 0 |
| `probe.sh` | script | US-6 | Déterministe : comparer les métadonnées du MP4 au storyboard | 0 |
| `transcribe.sh` | script | US-5 | Déterministe : convertir, transcrire, recaler les débuts de mots sur la parole | 0 |
| `cues.sh` | script | US-5 | Déterministe : associer les repères aux mots, millisecondes en images | 0 |

Total estimé : ~580 tokens.

### Skills

Invocation des skills : déclenchement automatique par leur description, et toujours possible par `/plugin-motion:<skill>`. Les descriptions sont bornées : seul `new-video` agit hors d'un dossier qui contient `storyboard.md`.

| Skill | Appelle | S'arrête |
| --- | --- | --- |
| `new-video` | `npx create-video --yes --blank`, `npx remotion skills add`, `npx remotion add @remotion/google-fonts`, `templates/`, `doctor.sh` | refuse un dossier non vide ; sur un échec de `doctor.sh`, s'arrête avec la correction à appliquer, sans rien modifier du système |
| `storyboard` | — | après l'accord de Soon sur `storyboard.md` ; aucun code écrit |
| `build-scene` | `preview.sh`, l'agent `frame-reviewer` | après une scène, passée en `validée` ou rendue à Soon avec ses défauts restants |
| `sync-voiceover` | `transcribe.sh` (ffmpeg, `whisper-cpp`), `cues.sh`, `preview.sh` | après le recalage, scènes touchées repassées en `construite` |
| `render-video` | `npx remotion render`, `probe.sh` | après le rapport de `probe.sh` |

`new-video` :

- demande le dossier et le nom de la vidéo, puis lance `npx create-video --yes --blank <dossier>`, `npx remotion skills add` et `npx remotion add @remotion/google-fonts` (réseau : npm) ;
- copie depuis `templates/` : `src/theme.ts`, `src/timing.ts` et un `storyboard.md` vide au format par défaut tranché dans le PRD ;
- lance `doctor.sh` et présente son diagnostic ; termine en proposant `storyboard`.

`storyboard` :

- pose les questions qui manquent au brief, une à la fois (public, durée totale, ton, format si autre que celui par défaut) ;
- écrit `storyboard.md` avec toutes les scènes en `à faire` ; la durée totale est la somme des durées des scènes ;
- complète `theme.ts` d'après le ton (couleurs, polices et leur graisse, courbes) ;
- sur un storyboard existant, une scène modifiée repasse en `à faire`.

`build-scene` :

- prend la scène désignée, ou la première qui n'est pas `validée` ;
- écrit `src/scenes/<Scene>.tsx` avec les seules valeurs de `theme.ts`, et l'inscrit dans `src/Root.tsx` ;
- choisit les images clés (première, dernière, milieu, fin d'entrée de chaque élément) et lance `preview.sh` ;
- lance `frame-reviewer` avec la planche, les images clés et `storyboard.md`, écrit son rapport dans `out/preview/<Scene>/review.md`, corrige les défauts bloquants et recommence, dans la limite de tours tranchée dans le PRD ;
- passe la scène en `construite`, puis en `validée` selon la règle tranchée dans le PRD ; à la limite de tours, rend la main à Soon avec les défauts restants.

`sync-voiceover` :

- prend un fichier audio de `public/` et le fait transcrire par `transcribe.sh` : ffmpeg le convertit en WAV 16 kHz mono, le format qu'attend whisper.cpp ; `whisper-cli` (paquet nixpkgs `whisper-cpp`, installé via plugin-nixos) le transcrit mot par mot, et la détection vocale de whisper.cpp en donne les segments de parole ; un mot dans lequel s'ouvre un segment commence à ce début de segment. Modèles téléchargés une fois, avec l'accord de Soon, dans `~/.cache/plugin-motion/` : `ggml-large-v3-turbo-q5_0.bin` (574 Mo) et `ggml-silero-v6.2.0.bin` (885 Ko) ;
- associe chaque repère du storyboard au mot visé par `cues.sh`, qui en donne l'image et dit si le mot ouvre un segment de parole ; quand Whisper a mal entendu, le skill choisit le mot (`wordIndex`) ; les scènes lisent leurs repères par `src/timing.ts`, jamais par des numéros d'image en dur ;
- allonge une scène si la voix off la dépasse, puis repasse en `construite` chaque scène touchée et relance `preview.sh` sur ses repères.

`render-video` :

- liste les scènes qui ne sont pas `validées` et, s'il y en a, demande à Soon avant de rendre ;
- lance `npx remotion render Video out/<nom>.mp4`, puis `probe.sh`, et présente le verdict.

## Hooks

Aucun en v1. Les vérifications déterministes sont des scripts appelés par les skills. Un hook d'un plugin installé pour le compte s'applique à **toutes** les sessions, pour peu de gain ici.

## Agents

**`frame-reviewer`** : relit les images d'une scène et rend la liste de ses défauts. Il ne parle jamais à Soon et met ce qu'il ne peut trancher sous `OPEN_QUESTIONS`.

- **Outils déclarés** : `Read, Glob`, et rien d'autre : ni `Bash`, ni `Write`, ni `Agent`. Sans écriture ni commande, il n'a pas de portée à déclarer et s'ajoute sans garde de portée.
- **Modèle** : `sonnet`. L'agent tourne jusqu'à 3 fois par scène, et repérer un défaut sur une planche est une tâche bornée. Passage à `opus` si le critère 4 échoue.
- **Entrée** : les chemins de `out/preview/<Scene>/` (planche et images clés), de `storyboard.md` et l'identifiant de la scène. Il ne lit pas `src/`.
- **Sortie** : une liste de défauts, chacun avec son image, sa zone, son type (débordement, chevauchement, lisibilité, contraste, marge de sécurité, écart au storyboard) et sa gravité (`bloquant` ou `mineur`), puis `OPEN_QUESTIONS`. Une liste vide dit « aucun défaut ».
- **Indépendance** : elle tient à la consigne et au contexte neuf. `Read` n'est pas restreint, mais un agent sans écriture ni commande ne peut rien changer au projet.

## Scripts

`#!/usr/bin/env bash`, bash et jq. Les binaires sont remplaçables pour les tests : `MOTION_NPX`, `MOTION_NODE`, `MOTION_FFMPEG`, `MOTION_FFPROBE`, `MOTION_WHISPER`, `MOTION_WHISPER_VAD`. Code de sortie non nul et message clair à chaque refus.

| Script | Rôle |
| --- | --- |
| `doctor.sh <projet>` | Une ligne par contrôle (`ok`, `manque`, `avertissement`), avec sa correction : Node à la version que demande Remotion ; ffmpeg et ffprobe ; versions identiques de `remotion` et de tous les `@remotion/*` de `package.json` ; essai de rendu d'une image. Si l'essai échoue, nomme la bibliothèque manquante quand l'erreur la donne et propose le plan B du PRD. `whisper-cpp` absent donne un avertissement, pas un échec, avec l'installation à demander à plugin-nixos. Sortie 0 si tous les contrôles obligatoires passent, 1 sinon. |
| `preview.sh <projet> <Scene> <image>…` | Refuse une scène inconnue et une image hors de la durée de la scène ; rend chaque image demandée en `out/preview/<Scene>/f<NNNN>.png` avec la CLI Remotion, puis assemble `planche.png` avec le filtre ffmpeg `tile`, chaque image étiquetée de son numéro sous l'image. Affiche les chemins produits. Un bundle du projet, puis un seul rendu de la liste d'images en séquence PNG (mesure ci-dessous). |
| `probe.sh <projet> <mp4>` | Lit le format et les scènes de `storyboard.md`, lit le MP4 avec `ffprobe -print_format json`, compare la durée (à une image près), la cadence, la largeur et la hauteur, et la piste audio si une voix off est prévue. Verdict JSON (`conforme`, et l'écart de chaque contrôle) ; sortie 0 si conforme, 1 sinon. |
| `transcribe.sh <projet> <audio> [langue]` | Refuse un fichier hors de `public/`, un binaire ou un modèle absent (avec la commande qui le télécharge, sans la lancer). ffmpeg en WAV 16 kHz mono hors du projet ; `whisper-cli --vad -ml 1 -sow -ojf` ; `whisper-vad-speech-segments -vp 0` ; recale chaque mot sur le segment de parole qui s'ouvre dans son intervalle. Écrit `public/voiceover.json` (mots au type `Caption`, segments, repères vides) et un résumé JSON ; sortie 0, 1 si aucune parole, 2 sur un refus. |
| `cues.sh <projet>` | Associe dans l'ordre chaque repère au premier mot égal qui suit le précédent (casse et ponctuation à part), ou au `wordIndex` posé par le skill ; image dans la vidéo `round(startMs × fps / 1000)`, image dans la scène, dans la scène ou non, début de segment de parole ou non ; fin de la voix face au total. Rapport JSON ; sortie 0 et repères écrits dans `voiceover.json` quand tout est calé, 1 sans rien écrire sinon, 2 sur un refus. |

## Tests et évaluations

- Suite déterministe `tests/run-all.sh` : bash et jq, sans réseau ni quota (critère 1).
  - `doctor.sh` avec binaires simulés : tout présent, versions Remotion désalignées, ffmpeg absent, essai de rendu en échec avec une bibliothèque nommée, Whisper absent (critère 2) ;
  - `preview.sh` avec binaires simulés : scène inconnue, image hors durée, commandes de rendu et d'assemblage attendues ;
  - `probe.sh` sur des sorties `ffprobe` enregistrées : conforme, durée décalée de 2 images, mauvaise cadence, mauvaise résolution, piste audio manquante (critère 3) ;
  - `transcribe.sh` avec ffmpeg, whisper et la détection vocale simulés, sur leurs sorties enregistrées pour un extrait réel et pour un silence ; `cues.sh` sur des transcriptions de test : repère hors de sa scène, mot mal entendu, mot dit deux fois, voix plus longue que la vidéo (critère 5) ;
  - en-tête de `frame-reviewer` : exactement `Read, Glob` ;
  - lecture des données de `storyboard.md` par les scripts, sur des storyboards de test valides et invalides.
- Une suite d'évaluation par skill (`evals/<skill>/`) : au moins un cas qui doit le déclencher, un qui ne le doit pas, trois exécutions par cas (critère 6).
- `frame-reviewer`, trois exécutions sur une planche de test enregistrée dans `tests/fixtures/`, où un texte déborde volontairement (critère 4).
- Les critères 2, 3 et 5 se vérifient aussi par des essais réels sur le poste, consignés dans `PROGRESS.md`. Les hypothèses du PRD (Chrome headless, dossier des skills officiels) se vérifient avant la première scène.

## Hors périmètre, et ce qui le rouvrirait

- **Hook de garde du rendu final** : `render-video` avertit déjà des scènes non validées. Rouvert si, à l'usage, des rendus finaux partent avant validation : hook `PreToolUse` sur `remotion render`, mode fail-open, inerte hors d'un projet qui contient `storyboard.md`.
- **Skill de reprise** : les statuts de `storyboard.md` suffisent. Rouvert si une reprise demande plus que lire ces statuts (plusieurs vidéos à la fois, état hors du storyboard).
- **Skills officiels de Remotion embarqués dans le plugin** : ils suivent les versions de Remotion, que le projet vidéo installe. Rouvert si `npx remotion skills add` cesse d'exister ou demande le réseau à chaque session.
- **Garde de portée d'agent** : `frame-reviewer` est en lecture seule, il n'y a rien à garder. Rouvert si un agent du plugin a besoin de `Bash` ou d'écrire.
- **Serveur MCP déclaré** : la CLI Remotion et ffmpeg suffisent, et un serveur ajoute le coût de ses schémas à chaque session. Rouvert si une fonction n'est accessible que par un serveur MCP.
- **Code de serveur MCP, channels, output styles, commandes classiques, options de plugin, dépendances de plugin, language servers** : hors du modèle. Rouverts seulement si l'un d'eux devenait indispensable à une user story.

## Décisions

- Remotion seul, rendu local : un moteur testable, sans coût ni identifiant cloud — 2026-10-23.
- Skills officiels de Remotion installés par projet, pas embarqués : ils suivent la version de Remotion du projet — 2026-10-23.
- Vérification visuelle par images fixes et planche contact : Claude ne voit que les images qu'on lui rend — 2026-10-23.
- `frame-reviewer` en lecture seule (`Read, Glob`), sans accès au code : un regard indépendant, sans portée à garder — 2026-10-23.
- Aucun hook en v1 : un hook du compte toucherait toutes les sessions, et les scripts suffisent — 2026-10-23.
- Statuts des scènes dans `storyboard.md` plutôt qu'un skill de reprise : un seul fichier lu au départ de chaque skill — 2026-10-23.
- `doctor.sh` diagnostique sans modifier le système : la configuration NixOS relève de plugin-nixos — 2026-10-23.
- Données du storyboard en bloc JSON dans `storyboard.md` : une seule source de vérité, lue par jq, sans `yq` — 2026-10-23.
- Skills déclenchés par leur description, bornés aux dossiers qui contiennent `storyboard.md` sauf `new-video` : le critère 6 teste ce déclenchement — 2026-10-23.
- `frame-reviewer` sur `sonnet`, `opus` si le critère 4 échoue : jusqu'à 3 passages par scène, à ménager sur le quota — 2026-10-23.
- `whisper-cpp` de nixpkgs plutôt que `@remotion/install-whisper-cpp` ou Whisper en Python : construit pour NixOS, sans compilation par projet ni PyTorch — 2026-10-23.
- `preview.sh` rend la liste des images clés en un seul `remotion render --sequence --frames=<liste>` depuis un bundle : 1,8 s pour 6 images d'une scène de 240, contre 10,4 s image par image et 8,6 s pour la séquence entière ; le coût suit le nombre d'images, pas la longueur de la scène — 2026-10-25.
- La partie déterministe de `sync-voiceover` en deux scripts testés, `transcribe.sh` et `cues.sh`, et `cueFrame` dans `templates/timing-voiceover.ts`, posé à la première synchronisation : un `timing.ts` qui importerait `public/voiceover.json` ferait échouer le bundle de tout projet sans voix off (constaté sur Remotion 4.0.538) — 2026-10-28.
- Débuts de mots recalés sur la détection vocale de whisper.cpp : sur un extrait de Soon, Whisper seul place un mot dit après une pause jusqu'à 1,1 s trop tôt, son DTW 90 à 250 ms trop tard ; les segments de parole tombent à ±10 ms des débuts mesurés sans Whisper. Un repère en milieu de phrase reste approché, et signalé — 2026-10-28.
- Modèle `ggml-large-v3-turbo-q5_0` (574 Mo) : multilingue, à peu près la taille de `small`, et « Notio » bien transcrit — 2026-10-28.
