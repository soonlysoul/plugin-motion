#!/usr/bin/env bash
# scripts/preview.sh with simulated binaries (MOTION_NPX, MOTION_FFMPEG): unknown scene, frame out
# of the scene's duration, the render and assembly commands expected, stale frames of an earlier
# round, a failing render, and storyboards that cannot be read. No network, no Remotion, no browser.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_preview
PREVIEW="$PLUGIN_ROOT/scripts/preview.sh"

if [[ ! -f $PREVIEW ]]; then
  fail "scripts/preview.sh présent" "absent"
  finish
  exit
fi
pass "scripts/preview.sh présent"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Simulated binaries; both log their calls. The render of a frame list writes f<frame>.png padded
# as Remotion pads it, to the digits of the largest frame; STUB_RENDER=fail makes it fail.
mkdir "$work/bin"
cat >"$work/bin/npx" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
case "$1 $2" in
  "remotion bundle")
    out=$(sed -n 's/.*--out-dir \([^ ]*\).*/\1/p' <<<"$*")
    mkdir -p "$out" && printf '<html></html>' >"$out/index.html" ;;
  "remotion render")
    if [[ ${STUB_RENDER:-ok} == fail ]]; then
      echo "Error: Could not find composition with ID $4" >&2
      exit 1
    fi
    list=$(sed -n 's/.*--frames=\([^ ]*\).*/\1/p' <<<"$*")
    IFS=, read -ra frames <<<"$list"
    width=${#frames[-1]}
    mkdir -p "$5"
    for f in "${frames[@]}"; do printf 'PNG' >"$5/$(printf "f%0${width}d" "$f").png"; done ;;
  *) echo "npx stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
EOF
cat >"$work/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf 'ffmpeg %s\n' "$*" >>"$STUB_LOG"
printf 'PNG' >"${!#}"
EOF
chmod +x "$work"/bin/*

# make_project <dir>: a video project with two scenes in storyboard.md, Ouverture (150 frames)
# and Message (240 frames).
make_project() {
  mkdir -p "$1/src"
  echo '{ "name": "essai", "dependencies": { "remotion": "4.0.538" } }' >"$1/package.json"
  cat >"$1/storyboard.md" <<'EOF'
# Storyboard — essai

```json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": false,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": 150, "text": "Vos idées vont trop vite ?", "motion": "…", "cues": [], "status": "validée" },
    { "id": "Message", "durationInFrames": 240, "text": "Notez tout, retrouvez tout.", "motion": "…", "cues": [], "status": "à faire" }
  ]
}
```

## Ouverture

```json
{ "scenes": [ { "id": "Leurre", "durationInFrames": 10 } ] }
```
EOF
}

# run_preview <args...>: sets PRE_STATUS, PRE_OUT and PRE_ERR. Environment by STUB_ENV.
run_preview() {
  local out err
  out=$(mktemp) err=$(mktemp)
  : >"$work/calls.log"
  env MOTION_NPX="$work/bin/npx" MOTION_FFMPEG="$work/bin/ffmpeg" STUB_LOG="$work/calls.log" \
    ${STUB_ENV:-} "$BASH" "$PREVIEW" "$@" >"$out" 2>"$err"
  PRE_STATUS=$?
  PRE_OUT=$(<"$out") PRE_ERR=$(<"$err")
  rm -f "$out" "$err"
}

expect_refusal() {
  if [[ $PRE_STATUS == 2 && $PRE_ERR =~ $2 ]]; then
    pass "$1"
  else
    fail "$1" "attendu exit 2 et « $2 », obtenu exit $PRE_STATUS ; stderr : ${PRE_ERR:0:300}"
  fi
}
expect_no_call() {
  [[ ! -s $work/calls.log ]] && pass "$1" || fail "$1" "$(cat "$work/calls.log")"
}

p="$work/projet"
make_project "$p"

echo "# scène inconnue"
run_preview "$p" Tarifs 0
expect_refusal "refuse une scène absente du storyboard (exit 2)" 'Tarifs'
[[ $PRE_ERR == *Ouverture* && $PRE_ERR == *Message* ]] && pass "nomme les scènes connues" || fail "nomme les scènes connues" "$PRE_ERR"
expect_no_call "aucun rendu pour une scène inconnue"
run_preview "$p" Leurre 0
expect_refusal "ne lit que le premier bloc json" 'Leurre'

echo "# image hors de la durée"
run_preview "$p" Message 0 240
expect_refusal "refuse l'image 240 d'une scène de 240 images (exit 2)" '240'
[[ $PRE_ERR == *0*239* ]] && pass "donne les images permises, 0 à 239" || fail "donne les images permises, 0 à 239" "$PRE_ERR"
expect_no_call "aucun rendu pour une image hors durée"
for bad in -1 1.5 dix ""; do
  run_preview "$p" Message "$bad"
  expect_refusal "refuse l'image « $bad »" 'image'
done
run_preview "$p" Message
expect_refusal "refuse un appel sans image" 'image'

echo "# rendu et assemblage"
mkdir -p "$p/out/preview/Message"
printf 'PNG' >"$p/out/preview/Message/f0100.png"
printf '# Relecture\n' >"$p/out/preview/Message/review.md"
run_preview "$p" Message 239 0 15 15
[[ $PRE_STATUS == 0 ]] && pass "rendu : exit 0" || fail "rendu : exit 0" "exit $PRE_STATUS ; stderr : ${PRE_ERR:0:300}"
mapfile -t calls <"$work/calls.log"
[[ ${calls[0]:-} =~ ^remotion\ bundle\ .*--out-dir\ ([^ ]+) ]] && bundle=${BASH_REMATCH[1]} || bundle=""
[[ -n $bundle ]] && pass "un seul bundle, d'abord" || fail "un seul bundle, d'abord" "${calls[*]}"
[[ -n $bundle && $bundle != "$p"/* ]] && pass "le bundle est fait hors du projet" || fail "le bundle est fait hors du projet" "$bundle"
[[ $(grep -c '^remotion bundle' "$work/calls.log") == 1 ]] && pass "bundle fait une fois" || fail "bundle fait une fois" "$(cat "$work/calls.log")"
render=$(grep '^remotion render' "$work/calls.log")
[[ $(grep -c . <<<"$render") == 1 ]] && pass "un seul rendu pour toutes les images" || fail "un seul rendu pour toutes les images" "$render"
[[ $render =~ ^remotion\ render\ ([^ ]+)\ Message\ ([^ ]+)\ .*--sequence ]] && [[ ${BASH_REMATCH[1]} == "$bundle" && ${BASH_REMATCH[2]} != "$p"/* ]] \
  && pass "rend la scène depuis le bundle, en séquence, hors du projet" || fail "rend la scène depuis le bundle, en séquence, hors du projet" "$render"
[[ $render == *" --frames=0,15,239"* && $render == *--image-format=png* ]] \
  && pass "rend 0, 15 et 239, triées et sans doublon, en PNG" || fail "rend 0, 15 et 239, triées et sans doublon, en PNG" "$render"
assembly=$(grep '^ffmpeg' "$work/calls.log")
[[ $(grep -c . <<<"$assembly") == 1 ]] && pass "un seul assemblage ffmpeg" || fail "un seul assemblage ffmpeg" "$assembly"
order=$(grep -oE -- "-i [^ ]+" <<<"$assembly" | sed 's/^-i //' | paste -sd' ')
[[ $order == "$p/out/preview/Message/f0000.png $p/out/preview/Message/f0015.png $p/out/preview/Message/f0239.png" ]] \
  && pass "assemble les trois images dans l'ordre" || fail "assemble les trois images dans l'ordre" "$order"
[[ $assembly == *tile=* ]] && pass "assemble par le filtre tile" || fail "assemble par le filtre tile" "$assembly"
[[ $assembly == *drawtext*f0015* ]] && pass "étiquette chaque image de son numéro" || fail "étiquette chaque image de son numéro" "$assembly"
[[ $assembly == *" $p/out/preview/Message/planche.png" ]] && pass "écrit planche.png" || fail "écrit planche.png" "$assembly"
for f in f0000 f0015 f0239 planche; do
  [[ -s $p/out/preview/Message/$f.png ]] && pass "$f.png présent" || fail "$f.png présent"
  grep -qxF "$p/out/preview/Message/$f.png" <<<"$PRE_OUT" && pass "affiche le chemin de $f.png" || fail "affiche le chemin de $f.png" "$PRE_OUT"
done
[[ ! -e $p/out/preview/Message/f0100.png ]] && pass "retire les images d'un tour précédent" || fail "retire les images d'un tour précédent"
[[ -f $p/out/preview/Message/review.md ]] && pass "garde review.md" || fail "garde review.md"
[[ $(tail -n 1 <<<"$PRE_OUT") == "$p/out/preview/Message/planche.png" ]] && pass "la planche en dernier" || fail "la planche en dernier" "$PRE_OUT"

echo "# rendu en échec"
STUB_ENV=STUB_RENDER=fail run_preview "$p" Message 0 15
[[ $PRE_STATUS == 1 ]] && pass "rendu en échec : exit 1" || fail "rendu en échec : exit 1" "exit $PRE_STATUS"
[[ $PRE_ERR == *"Could not find composition"* && $PRE_ERR == *Root.tsx* ]] && pass "montre l'erreur de Remotion et renvoie à src/Root.tsx" \
  || fail "montre l'erreur de Remotion et renvoie à src/Root.tsx" "$PRE_ERR"
grep -q '^ffmpeg' "$work/calls.log" && fail "pas d'assemblage après l'échec" || pass "pas d'assemblage après l'échec"
[[ ! -e $p/out/preview/Message/planche.png ]] && pass "pas de planche périmée après l'échec" || fail "pas de planche périmée après l'échec"

echo "# storyboard illisible"
mkdir "$work/sans-storyboard"
echo '{}' >"$work/sans-storyboard/package.json"
run_preview "$work/sans-storyboard" Message 0
expect_refusal "refuse un projet sans storyboard.md" 'storyboard\.md'
mkdir "$work/sans-bloc"
printf '# Storyboard\n\nPas de bloc.\n' >"$work/sans-bloc/storyboard.md"
run_preview "$work/sans-bloc" Message 0
expect_refusal "refuse un storyboard sans bloc json" 'json'
mkdir "$work/bloc-casse"
printf '# Storyboard\n\n```json\n{ "scenes": [ { "id": "Message", \n```\n' >"$work/bloc-casse/storyboard.md"
run_preview "$work/bloc-casse" Message 0
expect_refusal "refuse un bloc json illisible" 'json'
mkdir "$work/duree-absente"
printf '# Storyboard\n\n```json\n{ "scenes": [ { "id": "Message" } ] }\n```\n' >"$work/duree-absente/storyboard.md"
run_preview "$work/duree-absente" Message 0
expect_refusal "refuse une scène sans durée entière" 'durationInFrames'
run_preview
expect_refusal "refuse un appel sans projet" 'usage'

finish
