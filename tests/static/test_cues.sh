#!/usr/bin/env bash
# scripts/cues.sh: the voiceover cues of storyboard.md matched to the words of public/voiceover.json,
# in order, and converted to frames counted from the start of their scene. Projects of three scenes
# (Ouverture 150, Message 240, Final 210: 600 frames at 30 i/s) and transcriptions of « Vos idées vont
# trop vite ? Notez tout, retrouvez tout. Notio. Disponible sur iOS et Android. », as transcribe.sh
# writes them. Cases: every cue in its scene, a voice longer than the video, a cue outside its scene,
# a word Whisper misheard and the wordIndex that fixes it, a word said twice, case and accents, the
# frame rate of the storyboard, rounding, whether the word opens a segment of speech, refusals. Pure
# jq: no binary to simulate.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_cues
CUES="$PLUGIN_ROOT/scripts/cues.sh"

if [[ ! -f $CUES ]]; then
  fail "scripts/cues.sh présent" "absent"
  finish
  exit
fi
pass "scripts/cues.sh présent"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# words <text startMs endMs|…>: the words array of voiceover.json, as Captions.
words() {
  local item text start end
  IFS='|' read -ra items <<<"$1"
  for item in "${items[@]}"; do
    end=${item##* } item=${item% *}
    start=${item##* } text=${item% *}
    jq -nc --arg t "$text" --argjson s "$start" --argjson e "$end" \
      '{text: $t, startMs: $s, endMs: $e, timestampMs: null, confidence: 0.93}'
  done | jq -sc .
}
TAKE1='Vos 1000 1200|idées 1200 1560|vont 1560 1740|trop 1740 1960|vite ? 1960 2400|Notez 5600 5960|tout, 5960 6300|retrouvez 7400 7900|tout. 7900 8300|Notio. 13600 14200|Disponible 15400 15980|sur 15980 16160|iOS 16160 16600|et 16600 16760|Android. 16760 17400'
SLOW=${TAKE1/Disponible 15400 15980|sur 15980 16160|iOS 16160 16600|et 16600 16760|Android. 16760 17400/Disponible 18600 19160|sur 19160 19340|iOS 19340 19800|et 20200 20380|Android. 20700 21400}
MISHEARD=${TAKE1/Notio./Nausio.}
HALF=${TAKE1/vite ? 1960/vite ? 1950}
EXACT=${TAKE1/Android. 16760 17400/Android. 16760 20000}
# The segments of speech that transcribe.sh writes beside the words: « vite » is said inside the
# first, the four other cues open one. SPEECH=null leaves them out.
SPEECH='[[1000, 2400], [5600, 6300], [7400, 8300], [13600, 14200], [15400, 17400]]'

# make_project <dir> <words> [cues of Ouverture] [cues of Message] [cues of Final] [durations] [fps]
# A second json block after the first, as a decoy; stale cues in voiceover.json, to be replaced.
make_project() {
  local dir=$1 list=$2 c1=${3:-'[ { "word": "vite", "action": "rebond" } ]'}
  local c2=${4:-'[ { "word": "Notez", "action": "glisse" }, { "word": "retrouvez", "action": "glisse" } ]'}
  local c3=${5:-'[ { "word": "Notio", "action": "logo" }, { "word": "Disponible", "action": "badges" } ]'}
  local d=${6:-150 240 210} fps=${7:-30} d1 d2 d3
  read -r d1 d2 d3 <<<"$d"
  mkdir -p "$dir/public"
  cat >"$dir/storyboard.md" <<EOF
# Storyboard — Notio

\`\`\`json
{
  "format": { "width": 1920, "height": 1080, "fps": $fps },
  "voiceover": true,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": $d1, "text": "Vos idées vont trop vite ?", "motion": "…", "cues": $c1, "status": "validée" },
    { "id": "Message", "durationInFrames": $d2, "text": "Notez tout, retrouvez tout.", "motion": "…", "cues": $c2, "status": "validée" },
    { "id": "Final", "durationInFrames": $d3, "text": "Disponible sur iOS et Android", "motion": "…", "cues": $c3, "status": "validée" }
  ]
}
\`\`\`

## Ouverture

\`\`\`json
{ "format": { "width": 1280, "height": 720, "fps": 25 }, "voiceover": true, "scenes": [ { "id": "Leurre", "durationInFrames": 10, "cues": [] } ] }
\`\`\`
EOF
  jq -n --argjson w "$(words "$list")" --argjson s "$SPEECH" \
    '{audio: "voix.wav", model: "ggml-small.bin", words: $w, speech: $s, cues: {Leurre: [{word: "x", index: 0, startMs: 0, frame: 0}]}}
     | if .speech == null then del(.speech) else . end' \
    >"$dir/public/voiceover.json"
  cp "$dir/storyboard.md" "$dir/storyboard.avant"
  cp "$dir/public/voiceover.json" "$dir/voiceover.avant"
}

# run_cues <args...>: sets CUE_STATUS, CUE_OUT and CUE_ERR.
run_cues() {
  local out err
  out=$(mktemp) err=$(mktemp)
  "$BASH" "$CUES" "$@" >"$out" 2>"$err"
  CUE_STATUS=$?
  CUE_OUT=$(<"$out") CUE_ERR=$(<"$err")
  rm -f "$out" "$err"
}

# report <label> <jq test on the report printed on stdout>
report() {
  if jq -e "$2" >/dev/null 2>&1 <<<"$CUE_OUT"; then
    pass "$1"
  else
    fail "$1" "$2 ; obtenu : $(jq -c . <<<"$CUE_OUT" 2>/dev/null || printf '%s' "${CUE_OUT:0:300}") ; stderr : ${CUE_ERR:0:200}"
  fi
}
# written <label> <dir> <jq test on public/voiceover.json>
written() {
  if jq -e "$3" "$2/public/voiceover.json" >/dev/null 2>&1; then
    pass "$1"
  else
    fail "$1" "$3 ; voiceover.json : $(jq -c .cues "$2/public/voiceover.json" 2>/dev/null | head -c 300)"
  fi
}
expect_status() {
  [[ $CUE_STATUS == "$2" ]] && pass "$1" || fail "$1" "attendu exit $2, obtenu $CUE_STATUS ; stderr : ${CUE_ERR:0:300}"
}
expect_refusal() {
  if [[ $CUE_STATUS == 2 && $CUE_ERR =~ $2 && -z $CUE_OUT ]]; then
    pass "$1"
  else
    fail "$1" "attendu exit 2, « $2 » et rien sur stdout ; obtenu exit $CUE_STATUS ; stderr : ${CUE_ERR:0:300} ; stdout : ${CUE_OUT:0:100}"
  fi
}
untouched() {
  cmp -s "$2/storyboard.md" "$2/storyboard.avant" && cmp -s "$2/public/voiceover.json" "$2/voiceover.avant" \
    && pass "$1" || fail "$1" "storyboard.md ou voiceover.json modifié"
}

echo "# chaque repère dans sa scène"
p=$work/cale
make_project "$p" "$TAKE1"
run_cues "$p"
expect_status "tout est calé : exit 0" 0
report "un rapport JSON sur stdout" 'type == "object"'
report "verdict : calé" '.verdict == "calé"'
report "cadence et total du premier bloc json" '.fps == 30 and .total == 600'
report "cinq repères, dans l'ordre des scènes" '[.cues[] | "\(.scene)/\(.n)/\(.word)"] == ["Ouverture/0/vite", "Message/0/Notez", "Message/1/retrouvez", "Final/0/Notio", "Final/1/Disponible"]'
report "vite : mot 4 « vite ? », 1960 ms, image 59, scène à 0" \
  '.cues[0] == {scene: "Ouverture", n: 0, word: "vite", index: 4, text: "vite ?", startMs: 1960, frameInVideo: 59, sceneStart: 0, frame: 59, inScene: true, atSpeechStart: false, ok: true}'
report "Notez : image 168 de la vidéo, 18 de Message, qui commence à 150" \
  '.cues[1] | .index == 5 and .frameInVideo == 168 and .sceneStart == 150 and .frame == 18 and .inScene'
report "retrouvez : mot 7, image 72 de Message" '.cues[2] | .index == 7 and .frame == 72'
report "Notio : ponctuation ignorée, mot 9 « Notio. », image 18 de Final, qui commence à 390" \
  '.cues[3] | .index == 9 and .text == "Notio." and .sceneStart == 390 and .frame == 18'
report "Disponible : mot 10, image 72 de Final" '.cues[4] | .index == 10 and .frame == 72 and .ok'
report "vite, dit en milieu de phrase, n'ouvre pas de segment de parole" '.cues[0].atSpeechStart == false'
report "Notez, retrouvez, Notio et Disponible ouvrent chacun un segment" '[.cues[1:][] | .atSpeechStart] == [true, true, true, true]'
report "voix : finit à 17400 ms, image 522, dans les 600" '.voice == {endMs: 17400, endFrame: 522, overflow: 0, ok: true}'
report "voiceover.json écrit, nommé en chemin absolu" ".written == true and .voiceover == \"$p/public/voiceover.json\""
written "repères écrits par scène, en images depuis le début de la scène" "$p" \
  '.cues == {Ouverture: [{word: "vite", index: 4, startMs: 1960, frame: 59}], Message: [{word: "Notez", index: 5, startMs: 5600, frame: 18}, {word: "retrouvez", index: 7, startMs: 7400, frame: 72}], Final: [{word: "Notio", index: 9, startMs: 13600, frame: 18}, {word: "Disponible", index: 10, startMs: 15400, frame: 72}]}'
written "les anciens repères sont remplacés, pas fusionnés" "$p" '.cues | has("Leurre") | not'
written "audio, modèle et mots gardés" "$p" \
  "$(printf '.audio == "voix.wav" and .model == "ggml-small.bin" and .words == %s' "$(jq -c .words "$p/voiceover.avant")")"
cmp -s "$p/storyboard.md" "$p/storyboard.avant" && pass "storyboard.md inchangé" || fail "storyboard.md inchangé"
run_cues "$p"
expect_status "relancé sur ses propres repères : exit 0" 0
written "relancé : mêmes repères" "$p" '.cues.Final[1].frame == 72 and (.cues | keys) == ["Final", "Message", "Ouverture"]'

echo "# voix plus longue que la vidéo"
p=$work/longue
make_project "$p" "$SLOW"
run_cues "$p"
expect_status "voix jusqu'à l'image 642 : exit 1" 1
report "verdict : non calé" '.verdict == "non calé"'
report "voix : 21400 ms, image 642, 42 images de trop" '.voice == {endMs: 21400, endFrame: 642, overflow: 42, ok: false}'
report "les repères restent calculés : Disponible à 168 dans Final" '.cues[4] | .frame == 168 and .inScene and .ok'
report "rien n'est écrit" '.written == false'
untouched "storyboard.md et voiceover.json inchangés" "$p"
p=$work/juste
make_project "$p" "$EXACT"
run_cues "$p"
expect_status "voix finie à 20000 ms, image 600 sur 600 : exit 0" 0
report "voix : image 600, aucun dépassement" '.voice == {endMs: 20000, endFrame: 600, overflow: 0, ok: true}'

echo "# repère hors de sa scène"
p=$work/hors
make_project "$p" "$TAKE1" '' '' '' '50 240 310'
run_cues "$p"
expect_status "Ouverture de 50 images, vite à l'image 59 : exit 1" 1
report "vite hors de sa scène, image 59 donnée" '.cues[0] | .frame == 59 and .inScene == false and .ok == false'
report "Notez : 168 − 50 = 118 dans Message" '.cues[1] | .sceneStart == 50 and .frame == 118 and .inScene'
report "verdict non calé, rien d'écrit" '.verdict == "non calé" and .written == false'
untouched "hors scène : fichiers inchangés" "$p"
p=$work/bord
make_project "$p" "$TAKE1" '' '' '' '59 241 300'
run_cues "$p"
expect_status "Ouverture de 59 images (0 à 58), vite à l'image 59 : exit 1" 1
report "l'image qui suit la fin de la scène est hors de la scène" '.cues[0] | .frame == 59 and .inScene == false'

echo "# mot mal entendu, puis wordIndex"
p=$work/mal-entendu
make_project "$p" "$MISHEARD"
run_cues "$p"
expect_status "« Nausio. » pour Notio : exit 1" 1
report "Notio sans mot : index, images et début de segment nuls" '.cues[3] | .word == "Notio" and .index == null and .frame == null and .inScene == false and .atSpeechStart == null and .ok == false'
report "le repère suivant est trouvé quand même" '.cues[4] | .index == 10 and .ok'
untouched "mot manquant : fichiers inchangés" "$p"
p=$work/index
make_project "$p" "$MISHEARD" '' '' '[ { "word": "Notio", "action": "logo", "wordIndex": 9 }, { "word": "Disponible", "action": "badges" } ]'
run_cues "$p"
expect_status "wordIndex 9 posé : exit 0" 0
report "wordIndex l'emporte : mot 9 « Nausio. », image 18" '.cues[3] | .index == 9 and .text == "Nausio." and .frame == 18 and .ok'
written "wordIndex : repère écrit avec son mot visé" "$p" '.cues.Final[0] == {word: "Notio", index: 9, startMs: 13600, frame: 18}'

echo "# mot dit deux fois"
p=$work/deux-fois
make_project "$p" "$TAKE1" '[]' '[ { "word": "tout", "action": "pulse" }, { "word": "tout", "action": "pulse" } ]' '[]'
run_cues "$p"
expect_status "« tout » deux fois : exit 0" 0
report "le premier tout est le mot 6, le second le mot 8" '[.cues[] | .index] == [6, 8]'
report "images 29 et 87 de Message" '[.cues[] | .frame] == [29, 87]'
written "scènes sans repère : listes vides" "$p" '.cues.Ouverture == [] and .cues.Final == [] and (.cues.Message | length) == 2'

echo "# casse et accents"
p=$work/casse
make_project "$p" "$TAKE1" '[ { "word": "IDÉES", "action": "x" } ]' '[ { "word": "notez", "action": "x" } ]' '[ { "word": "disponible,", "action": "x" } ]'
run_cues "$p"
expect_status "IDÉES, notez, disponible, : exit 0" 0
report "IDÉES trouve idées (mot 1, image 36)" '.cues[0] | .index == 1 and .frame == 36'
report "notez et disponible, trouvent Notez et Disponible" '[.cues[1].index, .cues[2].index] == [5, 10]'
report "idées, au milieu de la première phrase, n'ouvre pas de segment" '.cues[0].atSpeechStart == false'
p=$work/premier-mot
make_project "$p" "$TAKE1" '[ { "word": "vos", "action": "x" } ]'
run_cues "$p"
report "le premier mot ouvre le premier segment, qui commence avec lui" '.cues[0] | .index == 0 and .atSpeechStart == true'

echo "# sans segments de parole"
p=$work/sans-segments
SPEECH=null make_project "$p" "$TAKE1"
run_cues "$p"
expect_status "voiceover.json sans speech : exit 0" 0
report "sans speech, atSpeechStart reste nul" 'all(.cues[]; .atSpeechStart == null)'

echo "# cadence du storyboard"
p=$work/cadence
make_project "$p" "$TAKE1" '' '' '' '' 25
run_cues "$p"
expect_status "25 i/s : Notez tombe avant Message, exit 1" 1
report "25 i/s : vite à l'image 49" '.fps == 25 and .cues[0].frame == 49'
report "25 i/s : Notez à 140, soit −10 dans Message" '.cues[1] | .frameInVideo == 140 and .frame == -10 and .inScene == false'

echo "# arrondi"
p=$work/demi
make_project "$p" "$HALF"
run_cues "$p"
report "1950 ms à 30 i/s : 58,5 arrondi à 59, comme msToFrame" '.cues[0].frame == 59'

echo "# refus"
run_cues
expect_refusal "refuse un appel sans projet" 'usage'
run_cues "$work/absent"
expect_refusal "refuse un dossier absent" 'absent'
mkdir -p "$work/sans-storyboard/public"
run_cues "$work/sans-storyboard"
expect_refusal "refuse un projet sans storyboard.md" 'storyboard\.md'
# bad <name> <transform of the json block (jq), or - to drop the block>
bad() {
  make_project "$work/$1" "$TAKE1"
  local block
  if [[ $2 == - ]]; then
    printf '# Storyboard\n\nPas de bloc.\n' >"$work/$1/storyboard.md"
  else
    block=$(sed -n '/^```json$/,/^```$/p' "$work/$1/storyboard.md" | sed '1d;$d' | sed -n '1,/^}$/p' | jq -c "$2")
    printf '# Storyboard\n\n```json\n%s\n```\n' "$block" >"$work/$1/storyboard.md"
  fi
  cp "$work/$1/storyboard.md" "$work/$1/storyboard.avant"
  run_cues "$work/$1"
}
bad sans-bloc -
expect_refusal "refuse un storyboard sans bloc json" 'json'
make_project "$work/bloc-casse" "$TAKE1"
printf '# Storyboard\n\n```json\n{ "format": \n```\n' >"$work/bloc-casse/storyboard.md"
run_cues "$work/bloc-casse"
expect_refusal "refuse un bloc json illisible" 'illisible'
bad sans-cadence 'del(.format.fps)'
expect_refusal "refuse une cadence absente" 'fps'
bad sans-voix '.voiceover = false'
expect_refusal "refuse un storyboard sans voix off" 'voix off'
bad sans-scene '.scenes = []'
expect_refusal "refuse un storyboard sans scène" 'scène'
bad duree '.scenes[1].durationInFrames = 2.5'
expect_refusal "refuse une scène sans durée entière, et la nomme" 'Message'
bad double '.scenes[2].id = "Message"'
expect_refusal "refuse deux scènes du même id, et le nomme" 'Message'
bad sans-mot '.scenes[2].cues[0].word = ""'
expect_refusal "refuse un repère sans mot, et nomme sa scène" 'Final'
bad index-negatif '.scenes[2].cues[0].wordIndex = -1'
expect_refusal "refuse un wordIndex négatif" 'wordIndex'
bad index-decimal '.scenes[2].cues[0].wordIndex = 2.5'
expect_refusal "refuse un wordIndex décimal" 'wordIndex'
bad index-hors '.scenes[2].cues[0].wordIndex = 15'
expect_refusal "refuse un wordIndex au-delà des 15 mots" 'wordIndex'
untouched "un refus ne touche à rien" "$work/index-hors"
p=$work/sans-voiceover
make_project "$p" "$TAKE1"
rm -f "$p/public/voiceover.json"
run_cues "$p"
expect_refusal "refuse sans voiceover.json, renvoie à transcribe.sh" 'transcribe\.sh'
p=$work/voiceover-casse
make_project "$p" "$TAKE1"
printf '{ "words": [' >"$p/public/voiceover.json"
run_cues "$p"
expect_refusal "refuse un voiceover.json illisible" 'voiceover\.json'
p=$work/sans-mots
make_project "$p" "$TAKE1"
jq '.words = []' "$p/voiceover.avant" >"$p/public/voiceover.json"
run_cues "$p"
expect_refusal "refuse une transcription sans mot" 'mot'
p=$work/mot-sans-temps
make_project "$p" "$TAKE1"
jq '.words[3].startMs = "1740"' "$p/voiceover.avant" >"$p/public/voiceover.json"
run_cues "$p"
expect_refusal "refuse un mot sans temps numérique, et donne son rang" '3'
p=$work/speech-casse
make_project "$p" "$TAKE1"
jq '.speech = [[1000, "2400"]]' "$p/voiceover.avant" >"$p/public/voiceover.json"
run_cues "$p"
expect_refusal "refuse des segments de parole mal formés" 'speech'

finish
