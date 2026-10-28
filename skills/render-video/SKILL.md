---
name: render-video
description: "Render the final MP4 of the whole video of storyboard.md, then check it against the storyboard with probe.sh: duration, frame rate, resolution, audio track. Use when Soon wants the finished video; not for one scene, a still or a transparent export, which the project's remotion-render covers. « sors-moi le MP4 final », « lance le rendu final »."
argument-hint: "[nom du fichier MP4]"
when_to_use: "In a folder holding storyboard.md, once its scenes are built."
---

# Render the final video

Address Soon in French. The final render comes last: every scene validated, one render of the composition `Video`, then its check against the storyboard by `probe.sh`. Change nothing here — neither the code, nor the plan, nor a status: a fix goes to `/plugin-motion:build-scene`, a change of plan to `/plugin-motion:storyboard`.

## 1. Where the video stands

Read `storyboard.md` in the current folder; its leading ```` ```json ```` block holds the format and the scenes (`${CLAUDE_PLUGIN_ROOT}/skills/storyboard/reference/format.md`). Absent: propose `/plugin-motion:new-video` and stop. No scene: propose `/plugin-motion:storyboard` and stop.

Announce in one line the format (`<width>×<height>` at `<fps>` i/s), the total — the sum of the scenes' `durationInFrames`, in frames and in seconds — and whether a voiceover is planned; then each scene with its status.

## 2. Scenes not validated

Every scene `validée`: go to step 3.

Otherwise name each scene that is not, with its status, and what it means for the render:

- `à faire`, or no `src/scenes/<id>.tsx`: the scene is missing from `Video`, so the MP4 would be shorter than the storyboard and incomplete;
- `construite`: built and reviewed, but Soon has not approved its contact sheet.

Ask Soon to choose: finish these scenes first with `/plugin-motion:build-scene` (recommended), or render anyway. Stop there and wait for the answer: give no render command yet, not even the one a yes would run.

Rendering anyway: go on; the report of step 6 names the scenes that were not validated.

## 3. The composition `Video`

Read `src/Root.tsx`. The composition `Video` must exist, with the storyboard's `width`, `height` and `fps`, and a `durationInFrames` equal to the total of the scenes it plays. With `"voiceover": true`, it must play the voiceover's audio file. When it is missing or differs, say what differs and propose `/plugin-motion:build-scene`, which keeps `Video` up to date; stop.

## 4. Render

The file is `out/<nom>.mp4`: `<nom>` is the name Soon gives, else the `name` of `package.json`, else the folder's name. From the folder of `storyboard.md`:

```
npx remotion render Video out/<nom>.mp4
```

It takes a few seconds per second of video; give the command up to ten minutes. On a failure, show the last lines of the error without its stack frames, then: an error of the browser or of a library goes to `bash ${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh <projet>`, an error of the code to `/plugin-motion:build-scene`; stop.

When the command cannot run in this session, still give the announcement of step 1, then the render command with its file, then the check of step 5 with the values it will expect from the storyboard — the total in frames, to one frame, and in seconds; the frame rate; `<width>×<height>`; an audio track required or not — and say that nothing was rendered.

## 5. Check against the storyboard

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh <projet> out/<nom>.mp4
```

`<projet>` is the folder of `storyboard.md`, as an absolute path. It compares the MP4 with the storyboard: its duration in frames with the total, to one frame; its frame rate; its width and height; an audio track when a voiceover is planned. It prints a JSON verdict, `conforme` or `non conforme`, with for each check `expected`, `actual`, `gap` and `ok`. Exit 0: conforming. Exit 1: a check fails. Exit 2: a refusal — an unreadable storyboard, a missing or unreadable MP4; fix it and check again.

## 6. Report

Give the path of the MP4 and the verdict, then one row per check: contrôle, attendu, lu, écart, verdict.

For each check that fails, its likely cause, without fixing it here:

- **duration**: `Video` in `src/Root.tsx` does not play every scene, or not for their durations — `/plugin-motion:build-scene`;
- **frame rate, width, height**: the values of `<Composition id="Video">` differ from the storyboard's format — `/plugin-motion:build-scene`;
- **audio**: `Video` plays no audio file although a voiceover is planned.

Name the scenes rendered while not validated, if any. Stop after the report; never change a status.
