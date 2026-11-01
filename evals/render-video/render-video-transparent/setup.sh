#!/usr/bin/env bash
# A video project ready for its final render: three scenes, all validated, the composition Video.
# The official skill remotion-render, which `npx remotion skills add` installs in every project,
# is stood in for by one of the same name and description, its body rewritten. claude plugin eval
# runs its sessions with --setting-sources user: a skill in the project's .claude/skills/ is not
# loaded there, one in the session's config directory is. That directory is ../config beside the
# HOME the scaffold receives; without it, the case fails here rather than run with no competitor.
set -euo pipefail
config="$HOME/../config"
if [ ! -f "$config/.claude.json" ]; then
  echo "setup.sh : $config/.claude.json absent ; la disposition de claude plugin eval a changé, remotion-render ne serait pas chargé." >&2
  exit 1
fi
mkdir -p "$config/skills/remotion-render"
cat >"$config/skills/remotion-render/SKILL.md" <<'MD'
---
name: remotion-render
description: Export a Remotion video
---

## Render a video

```
npx remotion render <composition-id> <output>
```

All options: https://www.remotion.dev/docs/cli/render

## Render a still

```
npx remotion still <composition-id> <output.png> --frame=<n>
```

## Several frames as images, in one call

```
npx remotion render <composition-id> out/frames --frames=0,30,90 --image-format=png
```

## Transparent video

An alpha channel needs PNG frames and a codec that keeps it: ProRes 4444 (`--codec=prores --prores-profile=4444 --image-format=png --pixel-format=yuva444p10le`) or WebM (`--codec=vp8` or `--codec=vp9`, `--image-format=png --pixel-format=yuva420p`). The composition must not paint an opaque background.
MD
mkdir -p src/scenes public
cat >package.json <<'JSON'
{
  "name": "notio-promo",
  "private": true,
  "scripts": { "dev": "remotion studio", "render": "remotion render" },
  "dependencies": {
    "@remotion/cli": "4.0.300",
    "@remotion/google-fonts": "4.0.300",
    "react": "19.0.0",
    "react-dom": "19.0.0",
    "remotion": "4.0.300"
  }
}
JSON
cat >public/logo.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240"><rect width="240" height="240" rx="48" fill="#ffcc00"/><text x="120" y="150" font-size="96" text-anchor="middle">N</text></svg>
SVG
cat >src/index.ts <<'TS'
import { registerRoot } from "remotion";
import { RemotionRoot } from "./Root";

registerRoot(RemotionRoot);
TS
cat >src/theme.ts <<'TS'
// Thème de la vidéo : les scènes ne lisent leurs couleurs, polices, courbes et durées qu'ici.
import { Easing } from "remotion";
// Polices : des Google Fonts, chargées ici par @remotion/google-fonts ; le rendu attend qu'elles soient prêtes.
import { loadFont as loadTitleFont } from "@remotion/google-fonts/ArchivoBlack";
import { loadFont as loadBodyFont } from "@remotion/google-fonts/Inter";

const fontWeights = { title: "400", body: "400" } as const;
const title = loadTitleFont("normal", { weights: [fontWeights.title], subsets: ["latin"] });
const body = loadBodyFont("normal", { weights: [fontWeights.body], subsets: ["latin"] });

export const theme = {
  colors: { background: "#14141f", text: "#ffffff", accent: "#ffcc00" },
  fonts: { title: title.fontFamily, body: body.fontFamily },
  fontWeights,
  easing: { enter: Easing.out(Easing.back(1.6)), exit: Easing.in(Easing.cubic) },
  durations: { enter: 10, hold: 20, exit: 8 },
} as const;
TS
cat >src/timing.ts <<'TS'
// Millisecondes en numéro d'image.
export const msToFrame = (ms: number, fps: number) => Math.round((ms * fps) / 1000);
TS
built='Ouverture Message Final'
declare -A text=([Ouverture]="Vos idées vont trop vite ?" [Message]="Notez tout, retrouvez tout." [Final]="Disponible sur iOS et Android")
declare -A frames=([Ouverture]=150 [Message]=240 [Final]=210)
total=0
for scene in $built; do
  total=$(( total + ${frames[$scene]} ))
  cat >"src/scenes/$scene.tsx" <<TSX
import { AbsoluteFill } from "remotion";
import { theme } from "../theme";

export const $scene: React.FC<{ text: string }> = ({ text }) => (
  <AbsoluteFill style={{ backgroundColor: theme.colors.background, color: theme.colors.text, justifyContent: "center", alignItems: "center" }}>
    <h1 style={{ fontFamily: theme.fonts.title, fontWeight: theme.fontWeights.title, fontSize: 110 }}>{text}</h1>
  </AbsoluteFill>
);
TSX
  last=$(( ${frames[$scene]} - 1 ))
  mid=$(( ${frames[$scene]} / 2 ))
  mkdir -p "out/preview/$scene"
  for f in 0 10 "$mid" "$last"; do
    printf '\x89PNG\r\n\x1a\n' >"out/preview/$scene/$(printf 'f%04d.png' "$f")"
  done
  printf '\x89PNG\r\n\x1a\n' >"out/preview/$scene/planche.png"
  cat >"out/preview/$scene/review.md" <<MD
# Relecture — $scene

## Tour 1

DÉFAUTS : aucun défaut.

OPEN_QUESTIONS : aucune.
MD
done
{
  echo 'import { Composition, Series } from "remotion";'
  for scene in $built; do echo "import { $scene } from \"./scenes/$scene\";"; done
  echo
  echo '// La vidéo complète : les scènes qui ont leur fichier, dans l'"'"'ordre du storyboard.'
  echo 'const Video: React.FC = () => ('
  echo '  <Series>'
  for scene in $built; do
    echo "    <Series.Sequence durationInFrames={${frames[$scene]}}><$scene text=\"${text[$scene]}\" /></Series.Sequence>"
  done
  echo '  </Series>'
  echo ');'
  echo
  echo 'export const RemotionRoot: React.FC = () => ('
  echo '  <>'
  for scene in $built; do
    echo "    <Composition id=\"$scene\" component={$scene} durationInFrames={${frames[$scene]}} fps={30} width={1920} height={1080} defaultProps={{ text: \"${text[$scene]}\" }} />"
  done
  echo "    <Composition id=\"Video\" component={Video} durationInFrames={$total} fps={30} width={1920} height={1080} />"
  echo '  </>'
  echo ');'
} >src/Root.tsx
cat >storyboard.md <<'MD'
# Storyboard — Notio

```json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": false,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": 150, "text": "Vos idées vont trop vite ?", "motion": "La question tombe ligne à ligne avec un rebond court, puis se fige au centre.", "cues": [], "status": "validée" },
    { "id": "Message", "durationInFrames": 240, "text": "Notez tout, retrouvez tout.", "motion": "Le slogan glisse depuis la droite ; le mot « tout » pulse deux fois.", "cues": [], "status": "validée" },
    { "id": "Final", "durationInFrames": 210, "text": "Disponible sur iOS et Android", "motion": "Les badges des stores montent en cascade, puis fondu au noir.", "cues": [], "status": "validée" }
  ]
}
```

## Brief

- Sujet : présenter Notio, une appli de notes.
- Public : étudiants et jeunes actifs.
- Durée totale : 20 s, soit 600 images.
- Ton : dynamique.
- Format : 1920×1080 à 30 i/s.

## Ouverture

Fond sombre. La question tombe ligne à ligne et se fige au centre.

## Message

Le slogan de Notio glisse depuis la droite ; le mot « tout » pulse deux fois, en jaune.

## Final

Les badges App Store et Google Play montent en cascade, puis fondu au noir.
MD
