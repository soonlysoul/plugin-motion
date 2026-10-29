#!/usr/bin/env bash
# cues.sh <projet> — the voiceover cues of storyboard.md in frames, for sync-voiceover. Reads the
# frame rate, the scenes and their cues in the json block of storyboard.md, as probe.sh does, and
# the words of public/voiceover.json that transcribe.sh writes. Each cue, in the order of the scenes
# and of their cues, takes the first word after the word of the cue before that equals its word,
# case and punctuation aside — or the word its wordIndex names, when sync-voiceover set one. Its
# frame in the video is round(startMs × fps / 1000), the formula of msToFrame in src/timing.ts; its
# frame in its scene, that minus the frames of the scenes before.
# Prints a JSON report: verdict (« calé » or « non calé »), fps, total, each cue with its word, its
# frames, whether it falls in its scene and whether its word opens a segment of speech (the speech
# of voiceover.json; null without it), and the end of the voice against the total. When every
# cue has its word inside its scene and the voice ends within the video, writes the cues into
# public/voiceover.json, by scene, { word, index, startMs, frame }: what cueFrame of src/timing.ts
# reads. Writes nothing otherwise; never touches storyboard.md.
# Exit 0 when calé, 1 when not, 2 on a refusal.
set -uo pipefail

refuse() { echo "cues.sh : $1" >&2; exit 2; }

project=${1:-}
[[ -n $project ]] || refuse "usage : cues.sh <projet>"
[[ -d $project ]] || refuse "dossier absent : $project"
project=$(cd "$project" && pwd)
command -v jq >/dev/null 2>&1 || refuse "jq introuvable ; il lit storyboard.md et voiceover.json."
storyboard=$project/storyboard.md voiceover=$project/public/voiceover.json
[[ -f $storyboard ]] || refuse "$storyboard absent : ce dossier n'est pas un projet vidéo storyboardé (/plugin-motion:storyboard l'écrit)."

# The first ```json block of storyboard.md, the only source of truth for the data.
data=$(awk '/^```json[[:space:]]*$/ && !open { open = 1; next } open && /^```[[:space:]]*$/ { exit } open { print }' "$storyboard")
[[ -n $data ]] || refuse "aucun bloc \`\`\`json dans $storyboard."
jq -e 'type == "object"' <<<"$data" >/dev/null 2>&1 || refuse "le bloc json de $storyboard est illisible."
problem=$(jq -r '
  def whole: if type == "number" then . == floor and . > 0 else false end;
  if (.format | type) != "object" or (.format.fps | whole | not) then "format.fps doit être un nombre entier"
  elif .voiceover != true then "voiceover ne vaut pas true : aucune voix off à caler"
  elif (.scenes | type) != "array" or (.scenes | length) == 0 then "aucune scène"
  else first(
      (.scenes[] | select((.id | type) != "string" or .id == "") | "une scène sans id"),
      (.scenes | map(.id) | group_by(.) | map(select(length > 1))[] | "deux scènes portent le même id, \(.[0])"),
      (.scenes[] | select(.durationInFrames | whole | not) | "la scène \(.id) : durationInFrames doit être un nombre entier positif"),
      (.scenes[] | select(has("cues") and (.cues | type) != "array") | "la scène \(.id) : cues doit être une liste"),
      (.scenes[] | .id as $id | (.cues // [])[] | select((.word | type) != "string" or .word == "")
        | "la scène \($id) : un repère sans mot visé (word)"),
      (.scenes[] | .id as $id | (.cues // [])[] | select(has("wordIndex"))
        | select(.wordIndex | if type == "number" then . != floor or . < 0 else true end)
        | "la scène \($id) : le wordIndex du repère « \(.word) » doit être un entier positif ou nul")
    ) // empty
  end' <<<"$data")
[[ -z $problem ]] || refuse "$problem dans $storyboard."

[[ -f $voiceover ]] || refuse "$voiceover absent : transcrire la voix off d'abord, par scripts/transcribe.sh."
words=$(jq -c '.words' "$voiceover" 2>/dev/null) || refuse "$voiceover est illisible."
problem=$(jq -r '
  if type != "array" or length == 0 then "aucun mot dans words"
  else first(to_entries[] | select((.value.text | type) != "string"
                                   or (.value.startMs | type) != "number" or (.value.endMs | type) != "number")
             | "le mot \(.key) manque de text, startMs ou endMs") // empty
  end' <<<"$words")
[[ -z $problem ]] || refuse "$problem dans $voiceover."
speech=$(jq -c '.speech // null' "$voiceover")
jq -e 'type == "null" or (type == "array" and all(.[]; type == "array" and length == 2 and all(.[]; type == "number")))' \
  <<<"$speech" >/dev/null || refuse "speech doit être une liste de segments [début, fin] en millisecondes dans $voiceover."
problem=$(jq -r --argjson w "$words" '
  first(.scenes[] | .id as $id | (.cues // [])[] | select(has("wordIndex") and .wordIndex >= ($w | length))
        | "la scène \($id) : le wordIndex \(.wordIndex) du repère « \(.word) » dépasse les \($w | length) mots de la transcription") // empty' <<<"$data")
[[ -z $problem ]] || refuse "$problem"

result=$(jq -n --argjson sb "$data" --argjson words "$words" --argjson speech "$speech" --arg voiceover "$voiceover" '
  # Lower case, the accented capitals of French included, then letters and digits only.
  def fold: explode | map(if (. >= 65 and . <= 90) or (. >= 192 and . <= 222 and . != 215) then . + 32
                          elif . == 338 then 339 elif . == 376 then 255 else . end) | implode;
  def norm: fold | gsub("[^\\p{L}\\p{N}]"; "");
  def frame: . * $sb.format.fps / 1000 | round;
  # Word i opens a segment of speech when one starts after the start of the word before, up to its own.
  def opens($i): if $speech == null then null
                 else ((if $i == 0 then -1 else $words[$i - 1].startMs end) as $after
                       | any($speech[]; .[0] > $after and .[0] <= $words[$i].startMs)) end;
  ($words | length) as $count
  | [$sb.scenes[].durationInFrames] as $durations
  | [range(0; $durations | length) as $i | $durations[:$i] | add // 0] as $starts
  | [$sb.scenes | to_entries[] | .key as $s | .value.id as $id | (.value.cues // []) | to_entries[]
     | {s: $s, scene: $id, n: .key, cue: .value}] as $list
  | (reduce $list[] as $c ({next: 0, found: []};
      (if $c.cue | has("wordIndex") then $c.cue.wordIndex
       else ($c.cue.word | norm) as $target
            | first(range(.next; $count) | select(($words[.].text | norm) == $target)) // null
       end) as $i
      | .found += [$c + {index: $i}]
      | if $i == null then . else .next = $i + 1 end)).found
  | map($starts[.s] as $start | $durations[.s] as $duration
        | if .index == null then
            {scene, n, word: .cue.word, index: null, text: null, startMs: null, frameInVideo: null,
             sceneStart: $start, frame: null, inScene: false, atSpeechStart: null, ok: false}
          else
            $words[.index] as $w | ($w.startMs | frame) as $inVideo | ($inVideo - $start) as $f
            | {scene, n, word: .cue.word, index, text: $w.text, startMs: $w.startMs, frameInVideo: $inVideo,
               sceneStart: $start, frame: $f, inScene: ($f >= 0 and $f < $duration), atSpeechStart: opens(.index)}
            | .ok = .inScene
          end) as $cues
  | ($durations | add) as $total
  | ([$words[].endMs] | max) as $end
  | ($end | frame) as $endFrame
  | {endMs: $end, endFrame: $endFrame, overflow: ([$endFrame - $total, 0] | max), ok: ($endFrame <= $total)} as $voice
  | {verdict: (if all($cues[]; .ok) and $voice.ok then "calé" else "non calé" end),
     fps: $sb.format.fps, total: $total, voiceover: $voiceover, written: false, cues: $cues, voice: $voice}')

if [[ $(jq -r .verdict <<<"$result") == calé ]]; then
  tmp=$(mktemp "$project/public/.voiceover.XXXXXX") || refuse "mktemp a échoué dans $project/public."
  if jq --argjson sb "$data" --argjson report "$result" '
       .cues = ($sb.scenes | map({key: .id, value: [.id as $id | $report.cues[] | select(.scene == $id)
                                                   | {word, index, startMs, frame}]}) | from_entries)' \
       "$voiceover" >"$tmp" && mv "$tmp" "$voiceover"; then
    result=$(jq '.written = true' <<<"$result")
  else
    rm -f "$tmp"
    refuse "écriture impossible de $voiceover."
  fi
fi

jq . <<<"$result"
[[ $(jq -r .verdict <<<"$result") == calé ]]
