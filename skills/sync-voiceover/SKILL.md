---
name: sync-voiceover
description: "Sync the cues of storyboard.md to a recorded voiceover: transcribe it word by word with whisper.cpp, set each cue's frame on its word, lengthen a scene the voice overruns, send touched scenes back to review. Use when Soon has recorded or re-recorded the voiceover, or a cue misses its word; not for captions, which the project's remotion-captions covers, nor music. « cale les animations sur la voix off », « la voix off dépasse la fin »."
argument-hint: "[fichier audio de public/]"
when_to_use: "In a folder holding storyboard.md with a voiceover planned."
---

# Sync the scenes to the voiceover

Address Soon in French. Each cue of `storyboard.md` names a word of the voiceover and what happens on it; this skill finds when the word is said and makes the scene act on that frame. The timing is the voice's: never cut, speed up or trim the audio, and never move a cue to another scene. A change to the words or the cues goes to `/plugin-motion:storyboard`; captions shown on screen go to the project's `remotion-captions`.

## 1. Where the video stands

Read `storyboard.md` in the current folder; its leading ```` ```json ```` block holds the format, `voiceover` and the scenes with their `cues` (`${CLAUDE_PLUGIN_ROOT}/skills/storyboard/reference/format.md`). Absent: propose `/plugin-motion:new-video` and stop. `"voiceover": false`, or no cue in any scene: say so, propose `/plugin-motion:storyboard` to plan the voiceover and its cues, and stop.

Announce in one line the format and the total — the sum of the scenes' `durationInFrames`, in frames and in seconds; then each scene with its status and its cues: the target word, and what happens on it.

## 2. The voiceover file

The file Soon names, else the one `public/voiceover.json` names in `audio`, else the only audio file of `public/` (`.wav`, `.mp3`, `.m4a`, `.flac`, `.ogg`). Several, or none: ask Soon which, and stop. A file outside `public/` is copied there first: the composition `Video` plays it with `staticFile()`.

## 3. Transcribe

When `public/voiceover.json` is absent, names another file, or Soon says the voice was recorded again:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/transcribe.sh <projet> public/<fichier> [langue]
```

`<projet>` is the folder of `storyboard.md`, as an absolute path; the language is `fr` unless Soon or the brief says otherwise. It takes about seven seconds per second of voice: give it up to ten minutes. It converts the file with ffmpeg to a 16 kHz mono WAV outside the project, transcribes it with `whisper-cli`, lists the segments of speech with whisper.cpp's voice detection, and moves each word said after a pause to where its segment of speech opens: Whisper alone starts it at the end of the word before, up to a second early. It writes `public/voiceover.json` — the file, the model, the language, the words with `startMs`, `endMs` and `confidence` (Remotion's `Caption` type), the segments of speech, and empty `cues` — and prints a summary: the words, the words moved, where the voice ends in milliseconds and in frames against the total.

- Exit 1: no word heard. Say so; the file may be silent or the wrong one. Stop.
- Exit 2: a refusal, said in its message. `whisper-cli` or ffmpeg missing: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh <projet>` names the fix, installing goes through `/plugin-nixos:modifie`; stop. A model missing — Whisper's (574 Mo) or the voice detection's (885 Ko): the message gives the file and the command that downloads it once into the user's cache. Ask Soon before downloading, and stop until the yes.

Otherwise keep `public/voiceover.json` as it is: the transcription is the slow step.

## 4. Cues to frames

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cues.sh <projet>
```

Each cue, in the order of the scenes and of their cues, takes the first word after the word of the cue before that equals its word, case and punctuation aside; its frame is `round(startMs × fps / 1000)` — `msToFrame` of `src/timing.ts` — counted from the start of its scene. The JSON report gives `verdict` (`calé` or `non calé`); for each cue its `index` in the words, the transcribed `text`, `startMs`, `frameInVideo`, `sceneStart`, `frame`, `inScene` and `atSpeechStart`; then `voice`: where the voice ends (`endMs`, `endFrame`) and by how many frames it overruns the video (`overflow`). Exit 0: every cue falls in its scene and the voice within the video; the cues are written into `public/voiceover.json`. Exit 1: nothing written; fix what the report shows, then run it again —

- **A cue without its word** (`index` null): Whisper misheard it, a proper noun most often; its `confidence` in `public/voiceover.json` is often low. Read the words around the time its scene plays and choose the one said for it; set `"wordIndex": <index>` in that cue of `storyboard.md` and tell Soon which transcribed word you took. No plausible word: ask Soon.
- **A cue past the end of its scene** (`frame` ≥ `durationInFrames`): lengthen that scene so that the cue lands at least `theme.durations.enter + theme.durations.hold` frames before its end.
- **A cue before the start of its scene** (`frame` < 0): the word is said while the scene before still plays. Propose to Soon to shorten that scene, with the frames, when its own cues still fit; otherwise ask. Never move the cue.
- **The voice longer than the video** (`overflow` > 0): lengthen the last scene so that it ends at least at `endFrame`, plus `theme.durations.exit` for its exit.

A scene's duration changes everywhere at once: its `durationInFrames` in `storyboard.md`, its `<Composition>` and its `<Series.Sequence>` in `src/Root.tsx`, and the `durationInFrames` of `Video`, the new total. Change no scene but the one the report points at.

`atSpeechStart` false: the cue's word is said inside a phrase, where Whisper's timing is only good to a few tenths of a second (measured up to 0.36 s). Tell Soon, and propose to move the cue onto the word that opens the phrase — a change of plan, by `/plugin-motion:storyboard` — or to keep it as it is.

## 5. Wire the scenes

Once `cues.sh` exits 0:

- In `storyboard.md`, set each cue's `"frame"` to the `frame` of the report — that field, the `wordIndex` and the durations of step 4 only.
- `src/timing.ts` without `cueFrame`: copy `${CLAUDE_PLUGIN_ROOT}/templates/timing-voiceover.ts` over it; it keeps `msToFrame` and reads `public/voiceover.json`.
- `Video` in `src/Root.tsx` plays the voiceover from its first frame: `<Audio src={staticFile("<fichier>")} />` before its `<Series>`, when it is missing.
- In each scene with cues, the element of cue `n` starts acting at `cueFrame("<id>", n)`, imported from `../timing`: never a frame number written in the scene. A scene that times it otherwise has that timing rewired, and only that; the rest of the scene is `build-scene`'s.

## 6. Touched scenes

A scene is touched when its duration or its code changed, or when one of its cue frames differs from the `"frame"` that cue had in `storyboard.md` before step 5 — a cue that had no `"frame"` and gets one touches its scene; a cue written into `public/voiceover.json` at the frame it already had — `transcribe.sh` empties them — does not. Set each touched scene that was `validée` to `construite`; `à faire` stays `à faire`. Render its key frames at its cues — each cue frame, and that frame plus `theme.durations.enter`, with the first and the last frame:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh <projet> <id> <image>…
```

and show `out/preview/<id>/planche.png`. The review and Soon's approval are `build-scene`'s: propose `/plugin-motion:build-scene`, which takes a `construite` scene straight to Soon's approval.

When a command cannot run in this session, do not hand it to an agent: it has no more shell than you. Your last reply, the one Soon reads, then opens with the announcement of step 1 — each scene with its status and its cues, the target word and what happens on it. Then give the commands of steps 3 and 4 with their arguments, and what each does: the first transcribes the voice word by word, locally, with whisper.cpp (`whisper-cli`), into `public/voiceover.json`; the second sets each cue's frame from its word's start at the storyboard's frame rate, counted from the start of its scene, which the scenes read through `cueFrame` of `src/timing.ts`. Then what follows: name the scenes that go back to `construite` — by the rule above, those with a cue without `"frame"`, and those whose duration or cue frames change by what `public/voiceover.json` already holds — their key frames rendered again at the cues. What `public/voiceover.json` already holds is read, not transcribed again: its last `endMs` gives where the voice ends, against the total. Say that nothing was transcribed or changed.

## 7. Report

One row per cue: scène, mot visé, mot transcrit, début (ms), image dans la vidéo, image dans la scène, début de phrase ou non. Then the scenes lengthened, from how many frames to how many, the new total, and the scenes set back to `construite`. Stop there: never set a scene to `validée`.
