---
name: storyboard
description: "Turn a video brief into the scenes of storyboard.md — frames, text, motion, status — approved before any code, or update a scene of it. Use when Soon gives a brief or changes the plan; not for creating, building or rendering. « découpe-la en scènes », « mets le plan à jour »."
argument-hint: "[brief, ou changement de scène]"
when_to_use: "In a folder holding storyboard.md."
---

# Storyboard

Address Soon in French. The storyboard is the plan of the video and its source of truth: every other skill of plugin-motion reads it first. Write no code here: no scene, no composition, nothing under `src/` but the values of `src/theme.ts`.

The format of `storyboard.md` — its leading JSON block, its fields, the free text below — is in `${CLAUDE_PLUGIN_ROOT}/skills/storyboard/reference/format.md`. Read it before writing the file.

## 1. Where the video stands

Read `storyboard.md` in the current folder. Absent: say that this folder is not a video project, propose `/plugin-motion:new-video`, and stop without writing anything. A leading JSON block that does not parse, or that lacks `format` or `scenes`: say what is wrong and stop.

Before anything else, announce where the video stands, in one line: the format (`<largeur>×<hauteur> à <fps> i/s`), then each scene with its status, or « aucune scène ». This line is how an interrupted video resumes.

Then go to step 2 for a brief of the whole video, to step 4 for a change to scenes that exist.

## 2. The brief, one question at a time

A brief has four elements: the **public**, the **durée totale**, the **ton**, the **format**. An element counts only when Soon has said it; never infer it from the subject. The format keeps the value of `storyboard.md` unless Soon names another (« vertical » is 1080×1920, « carré » 1080×1080); say the change in the restatement.

Restate in one line what the brief gives: the subject, each element known, the total duration in seconds and in frames (`20 s, soit 600 images`, frames = seconds × fps), and the strong moments Soon named.

Then ask the first element still missing, in this order: public, durée totale, ton. One question per message, then wait for the answer. Never ask two questions at once, and never propose a scene while an element is missing. With the four elements known, go to step 3.

## 3. Write the storyboard

1. Cut the video into scenes. One idea per scene; a scene for each strong moment of the brief; 2 to 6 seconds a scene unless the brief says otherwise.
2. Give each scene its duration in frames, a whole number. The durations add up to the total exactly: adjust the last scene, never the total.
3. Write each scene as `format.md` says: an identifier, its duration, its text word for word, the intent of its motion in words, its voiceover cues, and the status `à faire`.
4. Write `storyboard.md`: the JSON block, then the brief, then one section per scene. Keep the format of the block exactly; the scripts read it with jq.
5. Set the values of `src/theme.ts` from the tone: colours, fonts, easing curves, typical durations, as `format.md` says. Change values only, never its keys or its shape.

## 4. Change a plan that exists

Change only what Soon asks: a text, a motion, a duration, the order, a scene added or removed. Make the change at once on its most direct reading, and put any doubt in the approval message of step 5 rather than asking first.

- A scene that changes goes back to `à faire`, whatever its status. Every other scene keeps its fields and its status, word for word.
- A changed scene keeps its identifier: it names the scene's code, which build-scene rebuilds. A new scene takes a new identifier.
- A duration that changes moves the total: say the new total. When Soon has fixed the total, ask which scene gives way.
- Never touch `src/`: the code of a scene back to `à faire` is build-scene's.

## 5. Approval

Show the plan as a table: number, identifier, duration in frames and in seconds, text, motion intent, status; then the total in frames and in seconds. Mark the scenes that changed. When `storyboard.md` cannot be written, show the JSON block you would write and say it is not written yet.

Ask Soon to approve the storyboard, and stop there: no code before a yes. A change asked: back to step 4. Once approved, propose `/plugin-motion:build-scene` for the first scene `à faire`.
