#!/usr/bin/env bash
# probe.sh <projet> <mp4> — compares the final MP4 with storyboard.md, for render-video. Reads the
# format, the voiceover and the scenes in the json block of storyboard.md, as preview.sh does, and
# the MP4 with `ffprobe -print_format json`; a relative <mp4> is taken from the project. Checks the
# duration in frames against the sum of the scenes, to one frame; the frame rate; the width and the
# height; an audio track when a voiceover is planned. The duration is the video stream's nb_frames,
# or its seconds × its frame rate when the container gives no frame count.
# Prints the verdict as JSON: verdict (« conforme » or « non conforme »), the MP4, then for each
# check what the storyboard expects, what the MP4 holds, the gap and ok.
# Exit 0 when conforming, 1 when a check fails, 2 on a refusal.
# Binary replaceable for the tests: MOTION_FFPROBE.
set -uo pipefail

FFPROBE=${MOTION_FFPROBE:-ffprobe}

refuse() { echo "probe.sh : $1" >&2; exit 2; }

project=${1:-} mp4=${2:-}
[[ -n $project && -n $mp4 ]] || refuse "usage : probe.sh <projet> <mp4>"
[[ -d $project ]] || refuse "dossier introuvable : $project"
project=$(cd "$project" && pwd)
command -v jq >/dev/null 2>&1 || refuse "jq introuvable ; il lit storyboard.md."
storyboard=$project/storyboard.md
[[ -f $storyboard ]] || refuse "$storyboard absent : ce dossier n'est pas un projet vidéo storyboardé (/plugin-motion:storyboard l'écrit)."

# The first ```json block of storyboard.md, the only source of truth for the data.
data=$(awk '/^```json[[:space:]]*$/ && !open { open = 1; next } open && /^```[[:space:]]*$/ { exit } open { print }' "$storyboard")
[[ -n $data ]] || refuse "aucun bloc \`\`\`json dans $storyboard."
jq -e 'type == "object"' <<<"$data" >/dev/null 2>&1 || refuse "le bloc json de $storyboard est illisible."
problem=$(jq -r '
  def whole: if type == "number" then . == floor and . > 0 else false end;
  if (.format | type) != "object" then "pas de format (width, height, fps)"
  elif (.format.width | whole | not) or (.format.height | whole | not) then "format.width et format.height doivent être des nombres entiers de pixels"
  elif (.format.fps | whole | not) then "format.fps doit être un nombre entier"
  elif (.voiceover | type) != "boolean" then "voiceover doit valoir true ou false"
  elif (.scenes | type) != "array" or (.scenes | length) == 0 then "aucune scène"
  else first(.scenes[] | select(.durationInFrames? | whole | not)
             | "la scène \(.id? // "sans id") : durationInFrames doit être un nombre entier positif") // empty
  end' <<<"$data")
[[ -z $problem ]] || refuse "$problem dans $storyboard."

[[ $mp4 == /* ]] || mp4=$project/$mp4
[[ -f $mp4 ]] || refuse "MP4 introuvable : $mp4 ; render-video le rend dans out/."
command -v "$FFPROBE" >/dev/null 2>&1 || refuse "ffprobe introuvable ($FFPROBE) ; doctor.sh dit quoi installer."

err=$(mktemp) || refuse "mktemp a échoué."
trap 'rm -f "$err"' EXIT
probe=$("$FFPROBE" -v error -print_format json -show_format -show_streams "$mp4" 2>"$err") \
  || refuse "ffprobe ne lit pas $mp4 : $(tail -n 3 "$err")"
jq -e '.streams | type == "array"' <<<"$probe" >/dev/null 2>&1 || refuse "sortie de ffprobe illisible pour $mp4."
jq -e 'any(.streams[]; .codec_type == "video")' <<<"$probe" >/dev/null || refuse "aucune piste vidéo dans $mp4."

result=$(jq -n --argjson sb "$data" --argjson p "$probe" --arg mp4 "$mp4" '
  def rate: (split("/") | map(tonumber? // 0)) as [$n, $d] | if $n > 0 and $d > 0 then $n / $d else null end;
  def round3: . * 1000 | round / 1000;
  def check($expected; $actual): {expected: $expected, actual: $actual, gap: ($actual - $expected | round3), ok: ($actual == $expected)};
  first($p.streams[] | select(.codec_type == "video")) as $v
  | ([$v.avg_frame_rate, $v.r_frame_rate] | map(strings | rate | numbers) | first) as $rate
  | ($v.nb_frames | if type == "string" and test("^[0-9]+$") then tonumber else null end) as $count
  | (($v.duration // $p.format.duration) | tonumber? // null) as $seconds
  | if $rate == null then {refusal: "cadence illisible dans la piste vidéo de \($mp4)"}
    elif ($v.width | type) != "number" or ($v.height | type) != "number" then {refusal: "dimensions illisibles dans la piste vidéo de \($mp4)"}
    elif $count == null and $seconds == null then {refusal: "durée illisible dans la piste vidéo de \($mp4)"}
    else
      ($count // ($seconds * $rate | round)) as $frames
      | ([$sb.scenes[].durationInFrames] | add) as $total
      | any($p.streams[]; .codec_type == "audio") as $audio
      | {
          mp4: $mp4,
          durationInFrames: {expected: $total, actual: $frames, gap: ($frames - $total), tolerance: 1, ok: (($frames - $total | fabs) <= 1)},
          fps: check($sb.format.fps; $rate | round3),
          width: check($sb.format.width; $v.width),
          height: check($sb.format.height; $v.height),
          audio: {required: $sb.voiceover, present: $audio, ok: ($audio or ($sb.voiceover | not))}
        }
      | {verdict: (if all(.[] | objects; .ok) then "conforme" else "non conforme" end)} + .
    end')
refusal=$(jq -r '.refusal // empty' <<<"$result")
[[ -z $refusal ]] || refuse "$refusal."

jq . <<<"$result"
[[ $(jq -r .verdict <<<"$result") == conforme ]]
