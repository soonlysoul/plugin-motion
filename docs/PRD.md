# PRD — plugin-motion

2026-10-23 · Soon

**Statut : APPROUVÉ** le 2026-10-30 (« oui »).

## Problème

Claude Code sait écrire du code Remotion, mais il ne voit pas la vidéo qu'il produit : il ne perçoit que les images qu'on lui fait rendre. Sans méthode, une vidéo de motion design part directement dans le code. Le résultat est générique, et des textes qui débordent ou se chevauchent arrivent au rendu final sans que personne les ait regardés. Chaque correction demande à Soon de faire des captures et de décrire le défaut. Caler une voix off demande Whisper, la conversion des temps en numéros d'image et la bonne cadence. Et sur NixOS, le navigateur headless que télécharge Remotion peut ne pas se lancer, ce qui ne se découvre qu'au premier rendu. Les skills officiels de Remotion enseignent son API, pas cette méthode de travail ni ces vérifications.

## Solution

plugin-motion permet à Soon de :

- **créer** un projet vidéo Remotion prêt à l'emploi, avec un environnement vérifié ;
- **storyboarder** une vidéo à partir d'un brief, avant toute ligne de code ;
- **construire** chaque scène dans une boucle où Claude rend des images fixes et une planche contact, les fait relire par un regard indépendant et corrige ;
- **caler** les animations sur une voix off, au mot près ;
- **rendre** la vidéo finale et vérifier qu'elle correspond au storyboard.

## Utilisateur cible

Soon, seul, dans Claude Code, sur son poste NixOS (Node 22, ffmpeg 8, nix-ld actif), pour ses propres vidéos de motion design : textes animés, logos, schémas, données. L'usage reste dans la licence gratuite de Remotion (individu, ou société de 3 personnes au plus). Soon veut valider le plan avant le code, garder la main sur la validation des scènes, et ne pas toucher au code lui-même.

## User Stories

- **US-1** — En tant que Soon, je veux créer un projet vidéo Remotion d'une seule demande (modèle vierge, skills officiels de Remotion, `theme.ts`, `storyboard.md`) avec un diagnostic de l'environnement, afin de savoir avant la première scène que le rendu fonctionne sur mon poste, ou ce qu'il faut installer.
- **US-2** — En tant que Soon, je veux transformer un brief en storyboard (format, et pour chaque scène sa durée en images, son texte, l'intention du mouvement et son statut), afin de valider le plan de la vidéo avant tout code.
- **US-3** — En tant que Soon, je veux que chaque scène soit une composition à part, construite d'après le storyboard et le thème, afin de pouvoir la tester, la corriger et la reprendre seule.
- **US-4** — En tant que Soon, je veux que Claude rende les images clés et une planche contact de chaque scène, les fasse relire par un agent indépendant qui ne voit pas le code, et corrige les défauts signalés, afin qu'un débordement ou un chevauchement soit trouvé avant le rendu final, sans que j'aie à faire de captures.
- **US-5** — En tant que Soon, je veux caler les animations sur une voix off transcrite mot par mot, afin que chaque animation tombe sur le mot visé.
- **US-6** — En tant que Soon, je veux rendre la vidéo finale en MP4 et vérifier qu'elle correspond au storyboard (durée, cadence, résolution, piste audio), afin d'avoir un fichier conforme sans le contrôler à la main.
- **US-7** — En tant que Soon, je veux que le statut de chaque scène soit écrit dans `storyboard.md` et que chaque skill commence par le lire, afin de reprendre une vidéo interrompue (coupure de quota, fin de session) là où elle s'est arrêtée.

## Critères de succès

1. `tests/run-all.sh` passe sans erreur, en bash et jq, sans réseau ni quota.
2. Sur le poste de Soon, `doctor` sort en 0 sur un projet neuf. Sinon, il nomme précisément ce qui manque (par exemple une bibliothèque du Chrome headless) et la correction à appliquer.
3. À partir d'un brief de 3 scènes, l'enchaînement `new-video` → `storyboard` → `build-scene` (×3) → `render-video` produit un MP4 que `probe` déclare conforme au storyboard : durée à une image près, cadence, résolution, piste audio si elle est prévue. Soon ne touche pas au code.
4. Sur une scène de test où le texte déborde volontairement, `frame-reviewer` signale le débordement à chacune des 3 exécutions.
5. Sur un extrait audio de test, les animations calées par `sync-voiceover` tombent à ±3 images (à 30 i/s) du mot visé.
6. Chaque skill a une suite d'évaluation avec au moins un cas qui doit le déclencher et un qui ne le doit pas, sur trois exécutions par cas, toutes réussies.

## Hors périmètre

- **Rendu dans le cloud** (Remotion Lambda, AWS) : le poste suffit, et le cloud ajoute des coûts et des identifiants. Rouvert si une vidéo devient trop longue à rendre en local.
- **Autres moteurs** (HyperFrames, Manim, After Effects, Blender) : un seul moteur garde le plugin testable. Rouvert si un besoin réel (explication mathématique, 3D) ne tient pas dans Remotion ; ce serait plutôt un autre plugin.
- **Montage de rushs et génération par IA** (images, vidéos, voix de synthèse) : une vidéo ou un son entre seulement comme fichier importé, le plugin ne le produit pas. Rouvert si Soon veut produire ses voix off sans les enregistrer.
- **Publication** (YouTube, réseaux sociaux). Rouvert si Soon publie régulièrement et veut automatiser cette étape.
- **Modification de la configuration NixOS** : `doctor` dit quoi installer, plugin-nixos le fait. Pas de réouverture prévue.
- **Usage en équipe ou pour des clients**, et gestion d'une licence Remotion d'entreprise. Rouvert si l'usage de Soon sort du cadre de la licence gratuite.

## Décisions d'implémentation

- **Nom** : `plugin-motion`, dépôt `soonlysoul/plugin-motion`.
- **Langue des identifiants** : anglais (`new-video`, `storyboard`, `build-scene`, `sync-voiceover`, `render-video`, `frame-reviewer`). Messages et documents en français.
- **Composants** : cinq skills, un agent en lecture seule (`frame-reviewer`, outils `Read` et `Glob`), trois scripts (`doctor`, `preview`, `probe`), aucun hook en v1. Détail dans `docs/ARCHITECTURE.md`.
- **Moteur** : Remotion uniquement, rendu en local. `new-video` installe les skills officiels de Remotion dans chaque projet vidéo ; le plugin ne les embarque pas.
- **Méthode** : storyboard validé avant le code, thème centralisé dans `theme.ts`, une composition par scène, rendu final en dernier.
- **Reprise** : par les statuts de `storyboard.md`, sans skill dédié.
- **Environnement** : `doctor` détecte et nomme ce qui manque, il ne modifie jamais le système.
- **Format par défaut d'une nouvelle vidéo** : 1920×1080 à 30 i/s, la cadence du critère 5. Chaque storyboard peut en changer (par exemple 1080×1920 en vertical).
- **Emplacement des projets vidéo** : le dossier que Soon désigne à chaque `new-video`, avec `~/Vidéos/motion/<nom>` proposé par défaut. Un dossier non vide est refusé.
- **Validation d'une scène** : une scène passe en `validée` quand `frame-reviewer` ne signale plus aucun défaut bloquant **et** que Soon approuve sa planche contact. L'agent repère les défauts techniques ; le rythme et le goût restent à Soon.
- **Tours de correction par scène** : 3 au plus. Au-delà, `build-scene` rend la main à Soon avec les défauts restants.

## Décisions déléguées

Aucune à ce jour.

## Notes complémentaires

- Poste constaté le 2026-10-23 : Node v22.23.2, ffmpeg 8.1.2, Python 3.13.15, nix-ld actif (`NIX_LD` défini, `/lib64/ld-linux-x86-64.so.2` présent), 8 cœurs, 31 Go de RAM. Ni Chromium ni Whisper ne sont installés.
- Hypothèse à vérifier à la création : le Chrome headless téléchargé par Remotion se lance grâce à nix-ld. Plan B : le chromium de nixpkgs, installé via plugin-nixos et désigné à Remotion comme navigateur (`--browser-executable` ou la configuration Remotion) ; `doctor` détecte l'échec et propose ce plan B.
- Hypothèse à vérifier à la création : le dossier où `npx remotion skills add` installe les skills officiels, et leur coexistence avec ceux du plugin sans double déclenchement.
- Whisper : aucun moteur n'est installé ; le choix du moteur relève de l'architecture.
- Licence : plugin-motion est sous MIT et n'embarque pas Remotion. La licence de Remotion s'applique à chaque projet vidéo : gratuite pour un individu ou une société de 3 personnes au plus ; au-delà, licence d'entreprise (environ 25 $ par siège et par mois selon des sources tierces, non confirmé sur la page officielle).
- Banc d'essai d'octobre 2026 (agentskillshub) : Claude Opus 5.5 sans aucun skill produit déjà une vidéo de 15 s conforme en 4,4 min. La valeur du plugin est donc dans la méthode et la vérification, pas dans la connaissance de l'API.
- L'extrait audio du critère 5 a été enregistré par Soon le 2026-10-28 ; le critère y est tenu (voir `PROGRESS.md`, `sync-voiceover`).
