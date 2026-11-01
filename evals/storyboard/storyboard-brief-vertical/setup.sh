#!/usr/bin/env bash
# A video project as new-video leaves it: blank Remotion template, theme.ts and timing.ts from
# templates/, and storyboard.md at the default format with no scene yet.
set -euo pipefail
mkdir -p src public
cat >package.json <<'EOF'
{
  "name": "video",
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
EOF
cat >src/index.ts <<'EOF'
import { registerRoot } from "remotion";
import { RemotionRoot } from "./Root";

registerRoot(RemotionRoot);
EOF
cat >src/Root.tsx <<'EOF'
export const RemotionRoot: React.FC = () => {
  return <></>;
};
EOF
cat >src/theme.ts <<'EOF'
// Thème de la vidéo : les scènes ne lisent leurs couleurs, polices, courbes et durées qu'ici.
import { Easing } from "remotion";
// Polices : des Google Fonts, chargées ici par @remotion/google-fonts ; le rendu attend qu'elles soient prêtes.
import { loadFont as loadTitleFont } from "@remotion/google-fonts/Inter";
import { loadFont as loadBodyFont } from "@remotion/google-fonts/Inter";

const fontWeights = { title: "700", body: "400" } as const;
const title = loadTitleFont("normal", { weights: [fontWeights.title], subsets: ["latin"] });
const body = loadBodyFont("normal", { weights: [fontWeights.body], subsets: ["latin"] });

export const theme = {
  colors: { background: "#ffffff", text: "#111111", accent: "#3366ff" },
  fonts: { title: title.fontFamily, body: body.fontFamily },
  fontWeights,
  easing: { enter: Easing.out(Easing.cubic), exit: Easing.in(Easing.cubic) },
  durations: { enter: 15, hold: 30, exit: 10 },
} as const;
EOF
cat >src/timing.ts <<'EOF'
// Millisecondes en numéro d'image.
export const msToFrame = (ms: number, fps: number) => Math.round((ms * fps) / 1000);
EOF
cat >storyboard.md <<'EOF'
# Storyboard

```json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": false,
  "scenes": []
}
```
EOF
