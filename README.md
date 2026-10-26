# plugin-motion

Make Remotion motion-design videos storyboard-first: set up a checked video project, storyboard a brief, build each scene in a render-and-review loop, sync animations to a voiceover, and render a final MP4 verified against the storyboard.

Version **0.1.0**, en construction. Livrés : le skill `new-video` (crée un projet vidéo et diagnostique le poste), le skill `storyboard` (découpe un brief en scènes, validées avant tout code), le skill `build-scene` (construit une scène, en rend la planche par `preview.sh`, la fait relire et attend la validation de Soon) et l'agent `frame-reviewer` (relit les images d'une scène sans voir son code). Restent les skills `sync-voiceover` et `render-video`, et le script `probe.sh`. Le cadrage approuvé est dans [docs/PRD.md](docs/PRD.md) et [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ; l'avancement, dans [PROGRESS.md](PROGRESS.md). Claude Code **2.1.295 ou plus** requis.

## Essai local

Prérequis : Claude Code ≥ 2.1.295, `git`, `jq`. Depuis la racine d'un clone de ce dépôt :

```bash
claude --plugin-dir .
```

## Tests

```bash
bash tests/run-all.sh
```

Suite déterministe : bash et jq, sans réseau, sans session, sans quota. Codes de sortie : 0 tout passe, 1 une étape échoue, 2 un prérequis manque.

## Licence

MIT — voir [LICENSE](LICENSE).
