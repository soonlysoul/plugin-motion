#!/usr/bin/env bash
# A video project with three scenes in storyboard.md: Ouverture and Message validated, Final
# built; scene 2, Message, shows the slogan. Code and theme as build-scene left them.
set -euo pipefail
mkdir -p src/scenes public
cat >package.json <<'EOF'
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
EOF
cat >public/logo.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240"><rect width="240" height="240" rx="48" fill="#ffcc00"/><text x="120" y="150" font-size="96" text-anchor="middle">N</text></svg>
EOF
cat >src/index.ts <<'EOF'
import { registerRoot } from "remotion";
import { RemotionRoot } from "./Root";

registerRoot(RemotionRoot);
EOF
cat >src/theme.ts <<'EOF'
// Thème de la vidéo : les scènes ne lisent leurs couleurs, polices, courbes et durées qu'ici.
import { Easing } from "remotion";

export const theme = {
  colors: { background: "#14141f", text: "#ffffff", accent: "#ffcc00" },
  fonts: { title: "Archivo Black", body: "Inter" },
  easing: { enter: Easing.out(Easing.back(1.6)), exit: Easing.in(Easing.cubic) },
  durations: { enter: 10, hold: 20, exit: 8 },
} as const;
EOF
cat >src/timing.ts <<'EOF'
// Millisecondes en numéro d'image.
export const msToFrame = (ms: number, fps: number) => Math.round((ms * fps) / 1000);
EOF
for scene in Ouverture Message Final; do
  cat >"src/scenes/$scene.tsx" <<EOF
import { AbsoluteFill } from "remotion";
import { theme } from "../theme";

export const $scene: React.FC<{ text: string }> = ({ text }) => (
  <AbsoluteFill style={{ backgroundColor: theme.colors.background, color: theme.colors.text }}>
    <h1 style={{ fontFamily: theme.fonts.title }}>{text}</h1>
  </AbsoluteFill>
);
EOF
done
cat >src/Root.tsx <<'EOF'
import { Composition } from "remotion";
import { Final } from "./scenes/Final";
import { Message } from "./scenes/Message";
import { Ouverture } from "./scenes/Ouverture";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="Ouverture" component={Ouverture} durationInFrames={150} fps={30} width={1920} height={1080} defaultProps={{ text: "Vos idées vont trop vite ?" }} />
    <Composition id="Message" component={Message} durationInFrames={240} fps={30} width={1920} height={1080} defaultProps={{ text: "Notez tout, retrouvez tout." }} />
    <Composition id="Final" component={Final} durationInFrames={210} fps={30} width={1920} height={1080} defaultProps={{ text: "Disponible sur iOS et Android" }} />
  </>
);
EOF
cat >storyboard.md <<'EOF'
# Storyboard — Notio

```json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": false,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": 150, "text": "Vos idées vont trop vite ?", "motion": "La question tombe ligne à ligne avec un rebond court, puis se fige au centre.", "cues": [], "status": "validée" },
    { "id": "Message", "durationInFrames": 240, "text": "Notez tout, retrouvez tout.", "motion": "Le slogan glisse depuis la droite ; le mot « tout » pulse deux fois.", "cues": [], "status": "validée" },
    { "id": "Final", "durationInFrames": 210, "text": "Disponible sur iOS et Android", "motion": "Les badges des stores montent en cascade, puis fondu au noir.", "cues": [], "status": "construite" }
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
EOF
