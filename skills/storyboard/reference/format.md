# Format of storyboard.md

`storyboard.md` opens with a title, then one ```` ```json ```` block: the data that the scripts (`preview.sh`, `probe.sh`) read with jq and that every skill reads first. The free text follows the block. The block is the only source of truth for the data: the free text never repeats a duration or a status.

## The JSON block

```json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": false,
  "scenes": [
    {
      "id": "Ouverture",
      "durationInFrames": 150,
      "text": "Vos idées vont trop vite ?",
      "motion": "La question tombe ligne à ligne avec un rebond court, puis se fige au centre.",
      "cues": [],
      "status": "à faire"
    }
  ]
}
```

| Field | Rule |
| --- | --- |
| `format.width`, `format.height` | Whole numbers of pixels. 1920×1080 by default; 1080×1920 vertical; 1080×1080 square. |
| `format.fps` | Whole number; 30 by default. |
| `voiceover` | `true` when the brief plans a voiceover, else `false`. `probe.sh` then expects an audio track. |
| `scenes` | In playing order. `[]` in the storyboard new-video lays. |
| `id` | Unique, PascalCase, ASCII letters and digits, starting with a capital: `^[A-Z][A-Za-z0-9]*$`. It names `src/scenes/<id>.tsx` and the scene's composition. |
| `durationInFrames` | Whole number above 0: seconds × fps, rounded. The sum over the scenes is the total of the video. |
| `text` | What appears on screen, word for word, lines separated by `\n`; `""` for a scene without text. |
| `motion` | The intent of the motion in words: what enters, from where, how, and on what rhythm. Never code. |
| `cues` | `[]` without a voiceover. With one: `{ "word": "<mot visé>", "action": "<ce qui tombe dessus>" }` per cue; sync-voiceover adds the frame. |
| `status` | `à faire`, `construite` or `validée`, exactly. The storyboard skill writes only `à faire`. |

## The free text

Below the block:

```markdown
## Brief

- Sujet : …
- Public : …
- Durée totale : 20 s, soit 600 images.
- Ton : …
- Format : 1920×1080 à 30 i/s.
- Temps forts : …

## <id>

What the viewer must take away from the scene, its layout, what is on screen before and after.
```

One `## <id>` section per scene, in the order of the block, with the same identifier.

## src/theme.ts from the tone

`theme.ts` holds `colors`, `fonts`, `easing` and `durations` (in frames). Set its values, keep its keys and its shape; the scenes read nothing else.

| Ton | Easing | Durations | Colours and fonts |
| --- | --- | --- | --- |
| dynamique, énergique | entries with overshoot (`Easing.out(Easing.back(1.6))`) | short: entry 8 to 12 frames | strong contrast, one saturated accent, heavy title font |
| calme, posé | `Easing.inOut(Easing.cubic)` | long: entry 20 to 30 frames | soft contrast, muted palette, light font |
| sérieux, institutionnel | `Easing.out(Easing.cubic)` | medium: entry 15 frames | neutral palette, one accent, sober sans-serif |

Another tone: choose by analogy, and say the choice in the approval message.
