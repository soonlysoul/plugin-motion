#!/usr/bin/env bash
# preview.sh <projet> <Scene> <image>… — renders the given frames of one scene and assembles them
# into a contact sheet, for frame-reviewer and Soon. Reads the scene and its duration in the json
# block of storyboard.md; refuses an unknown scene and a frame outside the scene. One bundle of the
# project, outside it, then one render of the frame list as an image sequence (measured on
# 2026-10-25 on a 240-frame scene: 3 s for the bundle, 1.8 s for 6 frames, against 10.4 s by one
# still per frame and 8.6 s for the whole sequence), into out/preview/<Scene>/f<NNNN>.png, then
# planche.png with ffmpeg's tile filter. Images of an earlier round are removed; review.md is kept.
# Prints the paths produced, the contact sheet last.
# Exit 0 when the contact sheet is written, 1 when a render or the assembly fails, 2 on a refusal.
# Binaries replaceable for the tests: MOTION_NPX, MOTION_FFMPEG.
set -uo pipefail

NPX=${MOTION_NPX:-npx} FFMPEG=${MOTION_FFMPEG:-ffmpeg}
THUMB_WIDTH=640

refuse() { echo "preview.sh : $1" >&2; exit 2; }
failed() { echo "preview.sh : $1" >&2; exit 1; }

project=${1:-} scene=${2:-}
[[ -n $project && -n $scene ]] || refuse "usage : preview.sh <projet> <Scene> <image>…"
shift 2
[[ -d $project ]] || refuse "dossier introuvable : $project"
project=$(cd "$project" && pwd)
command -v jq >/dev/null 2>&1 || refuse "jq introuvable ; il lit storyboard.md."
storyboard=$project/storyboard.md
[[ -f $storyboard ]] || refuse "$storyboard absent : ce dossier n'est pas un projet vidéo storyboardé (/plugin-motion:storyboard l'écrit)."

# The first ```json block of storyboard.md, the only source of truth for the data.
data=$(awk '/^```json[[:space:]]*$/ && !open { open = 1; next } open && /^```[[:space:]]*$/ { exit } open { print }' "$storyboard")
[[ -n $data ]] || refuse "aucun bloc \`\`\`json dans $storyboard."
jq -e '.scenes | type == "array"' <<<"$data" >/dev/null 2>&1 \
  || refuse "le bloc json de $storyboard est illisible ou n'a pas de liste scenes."
known=$(jq -r '[.scenes[].id // empty] | join(", ")' <<<"$data")
jq -e --arg id "$scene" 'any(.scenes[]; .id == $id)' <<<"$data" >/dev/null \
  || refuse "scène inconnue : $scene ; scènes du storyboard : ${known:-aucune}."
duration=$(jq -r --arg id "$scene" 'first(.scenes[] | select(.id == $id)) | .durationInFrames
  | if type == "number" and . == floor and . > 0 then . else empty end' <<<"$data")
[[ -n $duration ]] || refuse "la scène $scene n'a pas de durationInFrames entière et positive dans $storyboard."

(($# > 0)) || refuse "aucune image demandée : donner un ou plusieurs numéros, de 0 à $((duration - 1))."
frames=()
for frame in "$@"; do
  [[ $frame =~ ^[0-9]+$ ]] || refuse "image « $frame » : un numéro entier est attendu, de 0 à $((duration - 1))."
  ((10#$frame < duration)) || refuse "image $frame hors de la scène $scene, qui dure $duration images : de 0 à $((duration - 1))."
  frames+=("$((10#$frame))")
done
mapfile -t frames < <(printf '%s\n' "${frames[@]}" | sort -nu)

command -v "$NPX" >/dev/null 2>&1 || refuse "npx introuvable ($NPX) ; doctor.sh dit quoi installer."
command -v "$FFMPEG" >/dev/null 2>&1 || refuse "ffmpeg introuvable ($FFMPEG) ; doctor.sh dit quoi installer."

out=$project/out/preview/$scene
mkdir -p "$out" || failed "impossible de créer $out."
rm -f "$out"/f[0-9][0-9][0-9][0-9].png "$out/planche.png"

work=$(mktemp -d) || failed "mktemp -d a échoué."
trap 'rm -rf "$work"' EXIT

# show_error <log> <what failed>: the last lines of Remotion's error, stack frames left out.
show_error() {
  local text
  text=$(grep -vE '^[[:space:]]+at ' "$1" | grep . | tail -n 5)
  failed "$2 :"$'\n'"$text"$'\n'"Vérifier que src/Root.tsx déclare la composition $scene et que le projet se rend (doctor.sh)."
}

(cd "$project" && "$NPX" remotion bundle --out-dir "$work/bundle" --log=error) >"$work/log" 2>&1 \
  || show_error "$work/log" "le bundle du projet a échoué"

list=$(IFS=,; echo "${frames[*]}")
(cd "$project" && "$NPX" remotion render "$work/bundle" "$scene" "$work/frames" --sequence --image-format=png \
  --frames="$list" --image-sequence-pattern='f[frame].[ext]' --log=error) >"$work/log" 2>&1 \
  || show_error "$work/log" "le rendu des images $list de $scene a échoué"

# Remotion pads the frame numbers to the digits of the largest one; the previews always take four.
images=()
for frame in "${frames[@]}"; do
  image=$out/$(printf 'f%04d' "$frame").png
  rendered=""
  for candidate in "$work/frames"/f*.png; do
    name=${candidate##*/f} name=${name%.png}
    [[ $name =~ ^[0-9]+$ ]] && ((10#$name == frame)) && rendered=$candidate && break
  done
  [[ -n $rendered && -s $rendered ]] || failed "l'image $frame de $scene manque après le rendu (images reçues : $(ls "$work/frames" 2>/dev/null | paste -sd' ' -))."
  mv "$rendered" "$image" || failed "impossible d'écrire $image."
  images+=("$image")
done

# Each frame is scaled, framed in grey with its number in a band below it, so that nothing of the
# picture is covered; the frames are then tiled, three per row at most.
count=${#images[@]}
columns=$((count < 3 ? count : 3))
rows=$(((count + columns - 1) / columns))
inputs=() filter="" labels=""
for i in "${!images[@]}"; do
  name=$(basename "${images[$i]}" .png)
  inputs+=(-i "${images[$i]}")
  filter+="[$i:v]scale=$THUMB_WIDTH:-2,pad=iw+8:ih+48:4:4:color=0x808080,drawtext=text='$name':x=8:y=h-40:fontsize=28:fontcolor=white[t$i];"
  labels+="[t$i]"
done
filter+="${labels}concat=n=$count:v=1:a=0,tile=${columns}x${rows}:color=0x808080"
"$FFMPEG" -hide_banner -loglevel error -y "${inputs[@]}" -filter_complex "$filter" -frames:v 1 "$out/planche.png" >"$work/log" 2>&1 \
  && [[ -s $out/planche.png ]] || failed "l'assemblage de la planche a échoué : $(tail -n 3 "$work/log")"

printf '%s\n' "${images[@]}" "$out/planche.png"
