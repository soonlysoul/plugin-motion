# PROGRESS — plugin-motion

Dernière mise à jour : 2026-10-24
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Deux composants : l'agent `frame-reviewer` (US-4) et le skill `storyboard` (US-2, US-7). Prochaine étape : ajouter le composant suivant, `/plugin-plugin:add`.

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
