# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne corrigée, mineure pour un composant ajouté, majeure pour un changement qui casse l'existant.

## [0.1.0] — en cours

### Ajouté

- Charpente posée par plugin-plugin le 2026-10-23 : manifeste, marketplace locale, licence, documents et suite de tests `tests/run-all.sh`.
- Agent `frame-reviewer` : relit les images clés et la planche contact d'une scène, sans voir le code, et rend ses défauts avec leur image, leur zone et leur gravité (outils `Read, Glob`, modèle `sonnet`).
- Skill `storyboard` : transforme un brief en scènes de `storyboard.md` (durée en images, texte, intention du mouvement, statut « à faire »), une question à la fois, et le fait valider avant tout code ; une scène changée repasse en « à faire ». Suite d'évaluation `evals/storyboard/` : trois cas positifs, deux négatifs.
- Skill `new-video` : crée un projet vidéo Remotion dans un dossier vide (`~/Vidéos/motion/<nom>` proposé par défaut, dossier non vide refusé), y installe les skills officiels de Remotion, y copie `theme.ts`, `timing.ts` et un `storyboard.md` vide depuis `templates/`, puis présente le diagnostic de `scripts/doctor.sh` et propose le storyboard. `doctor.sh` vérifie Node, ffmpeg, ffprobe, l'alignement des versions de Remotion, un rendu d'une image (bibliothèques manquantes du Chrome headless nommées, plan B chromium) et whisper-cpp, sans rien modifier du système. Tests `test_doctor` et `test_templates` ; suite d'évaluation `evals/new-video/` : deux cas positifs, deux négatifs.
