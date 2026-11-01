---
name: new-video
description: "Create a Remotion video project in an empty folder, with an empty storyboard.md, and check that this machine renders it. Use when Soon starts a new video, outside a video project; not for a brief, a scene or a render. « nouvelle vidéo », « crée un projet vidéo »."
argument-hint: "[dossier]"
when_to_use: "Outside a folder holding storyboard.md."
---

# New video

Address Soon in French. This skill lays a video project and diagnoses the machine. It writes no scene and changes nothing in the system: no sudo, no NixOS configuration, no package installed — that is plugin-nixos's.

## 1. Not inside a video project

When the current folder holds `storyboard.md`, it is already a video project: say so in one line, propose `/plugin-motion:storyboard` for its plan, and stop without creating anything.

## 2. The folder

Take the folder from Soon's request. None given: propose `~/Vidéos/motion/<nom>`, with `<nom>` in kebab-case and ASCII, drawn from the request (« le lancement de mon appli » gives `lancement-appli`). Ask Soon to confirm it or to give another folder, and wait. One question, and none about the content of the video: the brief belongs to storyboard.

Before any command, look at the folder, hidden files included: `ls -A <dossier>`, or Glob `<dossier>/*` and `<dossier>/.*` when Bash is not allowed.

- Absent or empty: go to step 3.
- Not empty: refuse it. Name what it holds, five entries at most, and touch none of it: never empty it, move its files, create the project inside it anyway, merge into it or overwrite it. Propose `~/Vidéos/motion/<nom>` with the folder's own name (`./promo` gives `~/Vidéos/motion/promo`), or another empty folder Soon names; ask Soon to confirm, and stop until Soon answers. `create-video` would refuse it too.

The folder Soon confirms goes through this check again.

## 3. Create

Say that these commands use the network (npm, GitHub), then run them. `<dossier>` is the folder written as an absolute path, `~` expanded.

1. `mkdir -p <parent>`, the parent folder of `<dossier>`.
2. `npx --yes create-video@latest --yes --blank <dossier>`: the blank template. It installs the dependencies, about 350 packages, and makes a first git commit.
3. In `<dossier>`: `npx remotion skills add`. It installs the official Remotion skills in `.agents/skills/`, links them for Claude Code in `.claude/skills/`, and writes `skills-lock.json`.
4. In `<dossier>`: `npx remotion add @remotion/google-fonts`, at the version of `remotion`. `src/theme.ts` loads its fonts with it; without it, no scene builds.
5. Copy the templates of the plugin with `cp`, unchanged — storyboard and the scripts read them as they are:
   - `${CLAUDE_PLUGIN_ROOT}/templates/theme.ts` to `<dossier>/src/theme.ts`;
   - `${CLAUDE_PLUGIN_ROOT}/templates/timing.ts` to `<dossier>/src/timing.ts`;
   - `${CLAUDE_PLUGIN_ROOT}/templates/storyboard.md` to `<dossier>/storyboard.md`: the default format, 1920×1080 at 30 fps, with no scene.

A command that fails: stop, show its error and what the folder now holds. Never retry it with other options, never delete what it left.

## 4. Diagnose

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh <dossier>`. It changes nothing in the system; its first run downloads Remotion's headless Chrome, about 100 MB, into the project. It writes one line per check — `ok`, `manque` or `avertissement` — with its correction, then a `diagnostic` line.

Present the diagnosis as a table: check, status, what it found, correction. Then, by its exit code:

- **0**: the project is ready. Say the warnings; they block nothing (Whisper only serves sync-voiceover).
- **1**: stop on the corrections, in the order of the lines. Apply none yourself. A change to the system — `programs.nix-ld.libraries`, a package, chromium — goes through `/plugin-nixos:modifie`, for Soon to run. A correction inside the project (`npm install`, `npx remotion upgrade`) is proposed, and run only on Soon's yes. Once corrected, run doctor.sh again.
- **2**: show its message: the folder is not a Remotion project.

## 5. Propose the storyboard

Once the diagnosis is ready, say what was laid: the folder, the official Remotion skills, `@remotion/google-fonts`, `src/theme.ts` and its fonts (Inter, until the storyboard sets them), `src/timing.ts`, `storyboard.md`. Then propose the storyboard: open Claude Code in the folder (`cd <dossier> && claude`), where the official Remotion skills load, and give the brief of the video; `/plugin-motion:storyboard` takes it there.
