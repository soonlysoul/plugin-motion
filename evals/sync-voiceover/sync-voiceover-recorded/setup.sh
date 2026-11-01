#!/usr/bin/env bash
# A video project whose three scenes are validated and carry voiceover cues, built before the
# voiceover: Soon has just recorded it in public/voix.wav; no public/voiceover.json yet.
# The official skill remotion-captions, which `npx remotion skills add` installs in every project,
# The official skill remotion-captions, which `npx remotion skills add` installs in every project,
# is stood in for by one of the same name and description, its body rewritten. claude plugin eval
# runs its sessions with --setting-sources user: a skill in the project's .claude/skills/ is not
# loaded there, one in the session's config directory is. That directory is ../config beside the
# HOME the scaffold receives; without it, the case fails here rather than run with no competitor.
set -euo pipefail
config="$HOME/../config"
if [ ! -f "$config/.claude.json" ]; then
  echo "setup.sh : $config/.claude.json absent ; la disposition de claude plugin eval a changé, remotion-captions ne serait pas chargé." >&2
  exit 1
fi
mkdir -p "$config/skills/remotion-captions"
cat >"$config/skills/remotion-captions/SKILL.md" <<'MD'
---
name: remotion-captions
description: Transcribing, displaying and animating captions
---

Captions are JSON arrays of the `Caption` type of `@remotion/captions`:

```ts
type Caption = {
  text: string;
  startMs: number;
  endMs: number;
  timestampMs: number | null;
  confidence: number | null;
};
```

## Transcribe

`@remotion/whisper-webgpu` runs Whisper locally on a GPU, from Node.js or the browser. Install it with `npx remotion add @remotion/whisper-webgpu @huggingface/transformers mediabunny @mediabunny/server`. In a Node.js script: decode the audio to 16 kHz mono, `downloadWhisperModel()`, `transcribe()`, then `toCaptions()`, and write the captions to a JSON file. For a language other than English, use a multilingual model such as `small` and pass `language`. Keep the timestamps relative to the start of the source file.

## Display

Install `@remotion/captions` with `npx remotion add @remotion/captions`. Group the captions into pages with `createTikTokStyleCaptions({ captions, combineTokensWithinMilliseconds })`, show each page in a `<Sequence>` from its start, and highlight the word being spoken. Keep the captions of a clip in the same `<Sequence>` as the clip.

## Import

An `.srt` file becomes captions with `parseSrt()` from `@remotion/captions`.
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
# A few bytes stand for the recorded voiceover: the cases read, they never transcribe.
printf 'RIFF\x24\x00\x00\x00WAVEfmt ' >public/voix.wav
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
state=recorded
declare -A text=([Ouverture]="Vos idées vont trop vite ?" [Message]="Notez tout, retrouvez tout." [Final]="Disponible sur iOS et Android")
declare -A frames=([Ouverture]=150 [Message]=240 [Final]=210)
declare -A cues=([Ouverture]=1 [Message]=2 [Final]=2)
total=0
for scene in Ouverture Message Final; do
  total=$(( total + ${frames[$scene]} ))
  if [ "$state" = recorded ]; then
    # Built before the voiceover: the entrance follows the theme, from frame 0.
    cat >"src/scenes/$scene.tsx" <<TSX
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { theme } from "../theme";

export const $scene: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, theme.durations.enter], [0, 1], { extrapolateRight: "clamp", easing: theme.easing.enter });
  return (
    <AbsoluteFill style={{ backgroundColor: theme.colors.background, color: theme.colors.text, justifyContent: "center", alignItems: "center" }}>
      <h1 style={{ fontFamily: theme.fonts.title, fontWeight: theme.fontWeights.title, fontSize: 110, opacity }}>{text}</h1>
    </AbsoluteFill>
  );
};
TSX
  else
    # Synced: each element enters on its cue, read through src/timing.ts.
    {
      echo 'import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";'
      echo 'import { theme } from "../theme";'
      echo 'import { cueFrame } from "../timing";'
      echo
      echo "export const $scene: React.FC<{ text: string }> = ({ text }) => {"
      echo '  const frame = useCurrentFrame();'
      echo '  const enter = (cue: number) =>'
      echo "    interpolate(frame, [cueFrame(\"$scene\", cue), cueFrame(\"$scene\", cue) + theme.durations.enter], [0, 1], { extrapolateLeft: \"clamp\", extrapolateRight: \"clamp\", easing: theme.easing.enter });"
      echo '  return ('
      echo '    <AbsoluteFill style={{ backgroundColor: theme.colors.background, color: theme.colors.text, justifyContent: "center", alignItems: "center" }}>'
      echo '      <h1 style={{ fontFamily: theme.fonts.title, fontWeight: theme.fontWeights.title, fontSize: 110, opacity: enter(0) }}>{text}</h1>'
      if [ "${cues[$scene]}" = 2 ]; then
        echo '      <div style={{ width: 120, height: 12, backgroundColor: theme.colors.accent, transform: `scaleX(${enter(1)})` }} />'
      fi
      echo '    </AbsoluteFill>'
      echo '  );'
      echo '};'
    } >"src/scenes/$scene.tsx"
  fi
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
  if [ "$state" = recorded ]; then
    echo 'import { Composition, Series } from "remotion";'
  else
    echo 'import { Audio, Composition, Series, staticFile } from "remotion";'
  fi
  for scene in Ouverture Message Final; do echo "import { $scene } from \"./scenes/$scene\";"; done
  echo
  echo '// La vidéo complète : les scènes qui ont leur fichier, dans l'"'"'ordre du storyboard.'
  echo 'const Video: React.FC = () => ('
  echo '  <>'
  [ "$state" = recorded ] || echo '    <Audio src={staticFile("voix.wav")} />'
  echo '    <Series>'
  for scene in Ouverture Message Final; do
    echo "      <Series.Sequence durationInFrames={${frames[$scene]}}><$scene text=\"${text[$scene]}\" /></Series.Sequence>"
  done
  echo '    </Series>'
  echo '  </>'
  echo ');'
  echo
  echo 'export const RemotionRoot: React.FC = () => ('
  echo '  <>'
  for scene in Ouverture Message Final; do
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
  "voiceover": true,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": 150, "text": "Vos idées vont trop vite ?", "motion": "La question tombe ligne à ligne avec un rebond court, puis se fige au centre.", "cues": [ { "word": "vite", "action": "la question rebondit" } ], "status": "validée" },
    { "id": "Message", "durationInFrames": 240, "text": "Notez tout, retrouvez tout.", "motion": "Le slogan glisse depuis la droite, en deux temps.", "cues": [ { "word": "Notez", "action": "« Notez tout, » glisse depuis la droite" }, { "word": "retrouvez", "action": "« retrouvez tout. » glisse à son tour, le trait jaune s'étire" } ], "status": "validée" },
    { "id": "Final", "durationInFrames": 210, "text": "Disponible sur iOS et Android", "motion": "Le logo apparaît, puis les badges des stores montent en cascade, puis fondu au noir.", "cues": [ { "word": "Notio", "action": "le logo apparaît" }, { "word": "Disponible", "action": "les badges des stores montent, le trait jaune s'étire" } ], "status": "validée" }
  ]
}
```

## Brief

- Sujet : présenter Notio, une appli de notes.
- Public : étudiants et jeunes actifs.
- Durée totale : 20 s, soit 600 images.
- Ton : dynamique.
- Format : 1920×1080 à 30 i/s.
- Voix off : enregistrée par Soon, « Vos idées vont trop vite ? Notez tout, retrouvez tout. Notio. Disponible sur iOS et Android. »

## Ouverture

Fond sombre. La question tombe ligne à ligne et se fige au centre ; elle rebondit sur « vite ».

## Message

Le slogan de Notio glisse depuis la droite en deux temps, sur « Notez » puis sur « retrouvez ».

## Final

Le logo apparaît sur « Notio » ; les badges App Store et Google Play montent sur « Disponible », puis fondu au noir.
MD
