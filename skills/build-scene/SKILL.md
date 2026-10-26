---
name: build-scene
description: "Build one scene of storyboard.md as its own Remotion composition, render its key frames and contact sheet, have frame-reviewer check them, fix, then update its status. Use when Soon starts, resumes or fixes a scene; not for the plan or the final render. « attaque la première scène », « on reprend la vidéo », « le titre de la scène 3 déborde »."
argument-hint: "[scène, ou défaut à corriger]"
when_to_use: "In a folder holding storyboard.md, once its plan is approved."
---

# Build a scene

Address Soon in French. One scene at a time: its code, its key frames, an independent review, then Soon's approval. The plan is the storyboard's: never change a text, a duration or a motion of `storyboard.md` here — only the `status` of the scene being built. A change to the plan goes to `/plugin-motion:storyboard`.

## 1. Where the video stands

Read `storyboard.md` in the current folder; its leading ```` ```json ```` block holds the format and the scenes (`${CLAUDE_PLUGIN_ROOT}/skills/storyboard/reference/format.md`). Absent: propose `/plugin-motion:new-video` and stop. No scene: propose `/plugin-motion:storyboard` and stop.

Announce in one line the format, then each scene with its status. Then take the scene:

- **Named by Soon** — by its identifier, or by its number in the block (« la scène 3 » is the third). With a defect Soon reports (« le titre déborde »), go to step 3 to fix it, whatever its status.
- **Otherwise the first scene that is not `validée`.**
  - `à faire`: go to step 2.
  - `construite`: it was built and reviewed; only Soon's approval is missing. Go straight to step 6: never rebuild it, never start the next one.
- **Every scene `validée`**, and nothing named: say so and propose `/plugin-motion:render-video`.

## 2. Announce the scene

Before any code, announce: the scene (`<n>/<total>`, identifier), its duration in frames and in seconds, its text, its motion intent, its status — and the key frames you will render, by number:

- the first, `0`, and the last, `durationInFrames − 1`;
- the middle, `floor(durationInFrames / 2)`;
- the end of each element's entrance, from `theme.durations.enter` and the staggering you plan;
- for a fix, the frames where the defect shows.

Eight frames at most. Say that they become a contact sheet, reviewed by an independent agent that does not see the code, before Soon validates the scene.

## 3. Write the scene

Use the official Remotion skills of the project (`.claude/skills/`) for the API. The scene is `src/scenes/<id>.tsx`, a component named `<id>`:

- Every colour, font, easing curve and typical duration comes from `src/theme.ts`; none written in the scene. A value missing from the theme goes into it, with its key, after the existing ones.
- The text is the storyboard's, word for word, lines as `\n` gives them.
- Sizes and positions follow the format, read with `useVideoConfig()`: text stays inside the central 90 % of the width and the height, wraps rather than leaves the frame — never `whiteSpace: "nowrap"` on a title — and its size fits its longest line.
- Timings in frames, from the theme; voiceover cues only through `src/timing.ts`, never a frame number written by hand.

In `src/Root.tsx`, one `<Composition id="<id>">` per scene, with the scene's `durationInFrames` and the storyboard's `width`, `height` and `fps`; then the composition `Video`, which plays every scene that has its file, in the storyboard's order, with `<Series>`, for a duration equal to their sum. Leave the other compositions as they are.

A fix touches only the cause of the defect. Once the code of a `validée` scene changes, it is no longer validated: it goes back to `construite` after its review, and to `validée` only on Soon's new approval.

When a file cannot be written in this session, the reply still opens with the announcement of step 2, word for word; then show the code you would write and say it is not written yet.

## 4. Render the key frames

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh <projet> <id> <image>…
```

`<projet>` is the folder of `storyboard.md`, as an absolute path. It renders `out/preview/<id>/f<NNNN>.png` and `planche.png`, removes the images of an earlier round, and prints the paths. Exit 2: a scene or a frame it refuses — fix the arguments. Exit 1: the render failed — read the error, fix the code, render again; this is not a review round.

## 5. Independent review, three rounds at most

Launch the agent `frame-reviewer` with exactly three things: the folder `out/preview/<id>/`, the path of `storyboard.md`, the identifier. Nothing about the code or what you meant to do: its independence holds on that.

Write its `DÉFAUTS` block to `out/preview/<id>/review.md`, under `## Tour <n>`, after the earlier rounds. Then:

- **A `bloquant` defect**: fix its cause in the code (step 3), render again the same frames plus those of the defect (step 4), and review again. A `mineur` defect is fixed in the same pass when it is cheap, otherwise kept for Soon.
- **No `bloquant` defect**: set the scene's `status` to `construite` in `storyboard.md` — that field only — and go to step 6.
- **Third round with a `bloquant` defect left**: stop fixing. Set `construite`, and give the remaining defects to Soon in step 6, with what you tried.

Its `OPEN_QUESTIONS` go to Soon in step 6.

## 6. Soon's approval

Show `out/preview/<id>/planche.png` — its path, and the image when the session can read it — with the result of the last round of `review.md`: « aucun défaut », or the defects left, and the open questions.

Ask Soon to approve the contact sheet or to name what to change, and stop there: say nothing yet of the next scene, not even what a yes would lead to. Never mark a scene `validée` without Soon's yes: rhythm and taste are Soon's.

- **Yes**: set the scene's `status` to `validée`. Propose the next scene that is not `validée`, or `/plugin-motion:render-video` when every scene is.
- **A change**: back to step 3 for this scene; the rounds start again from one. A change to the plan itself (text, duration, motion) is the storyboard's: propose `/plugin-motion:storyboard`.
