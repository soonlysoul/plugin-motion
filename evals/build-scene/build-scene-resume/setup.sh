#!/usr/bin/env bash
# A video project interrupted mid-way: Ouverture validated, Message built and reviewed with no
# defect, its contact sheet in out/preview/Message/ awaiting Soon's approval; Final to do.
set -euo pipefail
mkdir -p src/scenes public
cat >package.json <<'JSON'
{
  "name": "notio-promo",
  "private": true,
  "scripts": { "dev": "remotion studio", "render": "remotion render" },
  "dependencies": {
    "@remotion/cli": "4.0.300",
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

export const theme = {
  colors: { background: "#14141f", text: "#ffffff", accent: "#ffcc00" },
  fonts: { title: "Archivo Black", body: "Inter" },
  easing: { enter: Easing.out(Easing.back(1.6)), exit: Easing.in(Easing.cubic) },
  durations: { enter: 10, hold: 20, exit: 8 },
} as const;
TS
cat >src/timing.ts <<'TS'
// Millisecondes en numéro d'image.
export const msToFrame = (ms: number, fps: number) => Math.round((ms * fps) / 1000);
TS
built='Ouverture Message'
overflow=0
preview='Ouverture Message'
declare -A text=([Ouverture]="Vos idées vont trop vite ?" [Message]="Notez tout, retrouvez tout." [Final]="Disponible sur iOS et Android")
declare -A frames=([Ouverture]=150 [Message]=240 [Final]=210)
for scene in $built; do
  if [ "$scene" = Final ] && [ "$overflow" = 1 ]; then
    cat >"src/scenes/$scene.tsx" <<TSX
import { AbsoluteFill } from "remotion";
import { theme } from "../theme";

export const $scene: React.FC<{ text: string }> = ({ text }) => (
  <AbsoluteFill style={{ backgroundColor: theme.colors.background, color: theme.colors.text, justifyContent: "center", paddingLeft: 160 }}>
    <h1 style={{ fontFamily: theme.fonts.title, fontSize: 200, whiteSpace: "nowrap" }}>{text}</h1>
  </AbsoluteFill>
);
TSX
  else
    cat >"src/scenes/$scene.tsx" <<TSX
import { AbsoluteFill } from "remotion";
import { theme } from "../theme";

export const $scene: React.FC<{ text: string }> = ({ text }) => (
  <AbsoluteFill style={{ backgroundColor: theme.colors.background, color: theme.colors.text }}>
    <h1 style={{ fontFamily: theme.fonts.title }}>{text}</h1>
  </AbsoluteFill>
);
TSX
  fi
done
{
  echo 'import { Composition } from "remotion";'
  if [ -z "$built" ]; then
    echo 'import { MyComposition } from "./Composition";'
  fi
  for scene in $built; do echo "import { $scene } from \"./scenes/$scene\";"; done
  echo
  echo 'export const RemotionRoot: React.FC = () => ('
  echo '  <>'
  if [ -z "$built" ]; then
    echo '    <Composition id="MyComp" component={MyComposition} durationInFrames={60} fps={30} width={1280} height={720} />'
  fi
  for scene in $built; do
    echo "    <Composition id=\"$scene\" component={$scene} durationInFrames={${frames[$scene]}} fps={30} width={1920} height={1080} defaultProps={{ text: \"${text[$scene]}\" }} />"
  done
  echo '  </>'
  echo ');'
} >src/Root.tsx
if [ -z "$built" ]; then
  cat >src/Composition.tsx <<'TSX'
export const MyComposition = () => {
  return null;
};
TSX
fi
for scene in $preview; do
  last=$(( ${frames[$scene]} - 1 ))
  mid=$(( ${frames[$scene]} / 2 ))
  mkdir -p "out/preview/$scene"
  for f in 0 10 "$mid" "$last"; do
    printf '\x89PNG\r\n\x1a\n' >"out/preview/$scene/$(printf 'f%04d.png' "$f")"
  done
  printf '\x89PNG\r\n\x1a\n' >"out/preview/$scene/planche.png"
  cat >"out/preview/$scene/review.md" <<MD
# Relecture — $scene

Tour 1 : aucun défaut.

OPEN_QUESTIONS : aucune.
MD
done
cat >storyboard.md <<'MD'
# Storyboard — Notio

```json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": false,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": 150, "text": "Vos idées vont trop vite ?", "motion": "La question tombe ligne à ligne avec un rebond court, puis se fige au centre.", "cues": [], "status": "validée" },
    { "id": "Message", "durationInFrames": 240, "text": "Notez tout, retrouvez tout.", "motion": "Le slogan glisse depuis la droite ; le mot « tout » pulse deux fois.", "cues": [], "status": "construite" },
    { "id": "Final", "durationInFrames": 210, "text": "Disponible sur iOS et Android", "motion": "Les badges des stores montent en cascade, puis fondu au noir.", "cues": [], "status": "à faire" }
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
