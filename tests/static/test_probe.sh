#!/usr/bin/env bash
# scripts/probe.sh with a simulated ffprobe (MOTION_FFPROBE) that prints recorded outputs of
# `ffprobe -v error -print_format json -show_format -show_streams`, from tests/fixtures/probe/:
# MP4s encoded on 2026-10-26 by ffmpeg 8.1.2 (testsrc, libx264; voix.mp4 adds an AAC sine), and
# recorded from their folder. conforme: 1920×1080, 30 i/s, 600 images; voix: the same with an
# audio track; decale: 602 images; cadence: 600 images at 30000/1001; resolution: 1280×720.
# Cases: conforme, duration off by 2 frames, wrong frame rate, wrong resolution, audio track
# missing when voiceover is true, and storyboards that cannot be read. No network, no video.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_probe
PROBE="$PLUGIN_ROOT/scripts/probe.sh"
FIXTURES="$PLUGIN_ROOT/tests/fixtures/probe"

if [[ ! -f $PROBE ]]; then
  fail "scripts/probe.sh présent" "absent"
  finish
  exit
fi
pass "scripts/probe.sh présent"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Simulated ffprobe: logs its arguments, prints the file STUB_PROBE names; STUB_PROBE=fail makes
# it fail as ffprobe does on a file that is not a video.
mkdir "$work/bin"
cat >"$work/bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
if [[ $STUB_PROBE == fail ]]; then
  echo "${!#}: Invalid data found when processing input" >&2
  exit 1
fi
cat "$STUB_PROBE"
EOF
chmod +x "$work/bin/ffprobe"

# Outputs derived from the recorded ones, for what no encode gives directly.
jq '.streams[0].nb_frames = "601" | .streams[0].duration = "20.033333"' "$FIXTURES/conforme.json" >"$work/une-image.json"
jq 'del(.streams[0].nb_frames)' "$FIXTURES/conforme.json" >"$work/sans-nb-frames.json"
jq '.streams |= map(select(.codec_type != "video"))' "$FIXTURES/voix.json" >"$work/sans-video.json"

# make_project <dir> <voiceover>: a video project of three scenes, 150 + 240 + 210 = 600 frames
# at 1920×1080 and 30 i/s, its MP4 in out/; a second json block after the first, as a decoy.
make_project() {
  mkdir -p "$1/out"
  printf 'MP4' >"$1/out/notio.mp4"
  cat >"$1/storyboard.md" <<EOF
# Storyboard — Notio

\`\`\`json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": $2,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": 150, "text": "Vos idées vont trop vite ?", "motion": "…", "cues": [], "status": "validée" },
    { "id": "Message", "durationInFrames": 240, "text": "Notez tout, retrouvez tout.", "motion": "…", "cues": [], "status": "validée" },
    { "id": "Final", "durationInFrames": 210, "text": "Disponible sur iOS et Android", "motion": "…", "cues": [], "status": "validée" }
  ]
}
\`\`\`

## Ouverture

\`\`\`json
{ "format": { "width": 1280, "height": 720, "fps": 25 }, "voiceover": false, "scenes": [ { "id": "Leurre", "durationInFrames": 10 } ] }
\`\`\`
EOF
}

# run_probe <ffprobe output: a file, or fail> <args...>: sets PRO_STATUS, PRO_OUT and PRO_ERR.
run_probe() {
  local probe=$1 out err
  shift
  out=$(mktemp) err=$(mktemp)
  : >"$work/calls.log"
  env MOTION_FFPROBE="${STUB_FFPROBE:-$work/bin/ffprobe}" STUB_PROBE="$probe" STUB_LOG="$work/calls.log" \
    "$BASH" "$PROBE" "$@" >"$out" 2>"$err"
  PRO_STATUS=$?
  PRO_OUT=$(<"$out") PRO_ERR=$(<"$err")
  rm -f "$out" "$err"
}

# verdict <label> <jq test on the verdict>
verdict() {
  if jq -e "$2" >/dev/null 2>&1 <<<"$PRO_OUT"; then
    pass "$1"
  else
    fail "$1" "$2 ; obtenu : $(jq -c . <<<"$PRO_OUT" 2>/dev/null || printf '%s' "${PRO_OUT:0:300}") ; stderr : ${PRO_ERR:0:200}"
  fi
}
expect_status() {
  [[ $PRO_STATUS == "$2" ]] && pass "$1" || fail "$1" "attendu exit $2, obtenu $PRO_STATUS ; stderr : ${PRO_ERR:0:300}"
}
expect_refusal() {
  if [[ $PRO_STATUS == 2 && $PRO_ERR =~ $2 && -z $PRO_OUT ]]; then
    pass "$1"
  else
    fail "$1" "attendu exit 2, « $2 » et rien sur stdout ; obtenu exit $PRO_STATUS ; stderr : ${PRO_ERR:0:300} ; stdout : ${PRO_OUT:0:100}"
  fi
}
expect_no_call() {
  [[ ! -s $work/calls.log ]] && pass "$1" || fail "$1" "$(cat "$work/calls.log")"
}

sans_voix="$work/sans-voix" avec_voix="$work/avec-voix"
make_project "$sans_voix" false
make_project "$avec_voix" true

echo "# conforme"
run_probe "$FIXTURES/conforme.json" "$sans_voix" out/notio.mp4
expect_status "conforme : exit 0" 0
verdict "un verdict JSON sur stdout" 'type == "object"'
verdict "verdict : conforme" '.verdict == "conforme"'
verdict "durée : 600 images attendues, 600 lues, écart 0, tolérance 1" \
  '.durationInFrames == {expected: 600, actual: 600, gap: 0, tolerance: 1, ok: true}'
verdict "cadence : 30 attendue, 30 lue" '.fps == {expected: 30, actual: 30, gap: 0, ok: true}'
verdict "largeur : 1920" '.width == {expected: 1920, actual: 1920, gap: 0, ok: true}'
verdict "hauteur : 1080" '.height == {expected: 1080, actual: 1080, gap: 0, ok: true}'
verdict "audio non exigé sans voix off" '.audio == {required: false, present: false, ok: true}'
verdict "ne lit que le premier bloc json" '.width.expected == 1920 and .fps.expected == 30 and .durationInFrames.expected == 600'
verdict "nomme le MP4 lu, en chemin absolu" ".mp4 == \"$sans_voix/out/notio.mp4\""
call=$(<"$work/calls.log")
[[ $(grep -c . <<<"$call") == 1 ]] && pass "ffprobe appelé une fois" || fail "ffprobe appelé une fois" "$call"
[[ $call == *"-print_format json"* && $call == *-show_streams* && $call == *-show_format* ]] \
  && pass "ffprobe en JSON, flux et format" || fail "ffprobe en JSON, flux et format" "$call"
[[ $call == *" $sans_voix/out/notio.mp4" ]] && pass "un MP4 relatif se lit depuis le projet" || fail "un MP4 relatif se lit depuis le projet" "$call"
run_probe "$FIXTURES/conforme.json" "$sans_voix" "$sans_voix/out/notio.mp4"
expect_status "un MP4 en chemin absolu : exit 0" 0
run_probe "$FIXTURES/voix.json" "$avec_voix" out/notio.mp4
expect_status "voix off et piste audio : exit 0" 0
verdict "audio exigé et présent" '.verdict == "conforme" and .audio == {required: true, present: true, ok: true}'
run_probe "$FIXTURES/voix.json" "$sans_voix" out/notio.mp4
verdict "une piste audio sans voix off reste conforme" '.verdict == "conforme" and .audio == {required: false, present: true, ok: true}'
run_probe "$work/une-image.json" "$sans_voix" out/notio.mp4
expect_status "601 images : exit 0, à une image près" 0
verdict "601 images : écart 1, dans la tolérance" '.durationInFrames.gap == 1 and .durationInFrames.ok == true'
run_probe "$work/sans-nb-frames.json" "$sans_voix" out/notio.mp4
expect_status "sans nb_frames : exit 0" 0
verdict "sans nb_frames, la durée vient des secondes × cadence" '.durationInFrames.actual == 600'

echo "# durée décalée de 2 images"
run_probe "$FIXTURES/decale.json" "$sans_voix" out/notio.mp4
expect_status "602 images : exit 1" 1
verdict "verdict : non conforme" '.verdict == "non conforme"'
verdict "durée : 602 lues, écart +2" '.durationInFrames == {expected: 600, actual: 602, gap: 2, tolerance: 1, ok: false}'
verdict "les autres contrôles restent conformes" '.fps.ok and .width.ok and .height.ok and .audio.ok'

echo "# mauvaise cadence"
run_probe "$FIXTURES/cadence.json" "$sans_voix" out/notio.mp4
expect_status "29,97 i/s : exit 1" 1
verdict "cadence : 29.97 lue, écart -0.03" '.verdict == "non conforme" and .fps == {expected: 30, actual: 29.97, gap: -0.03, ok: false}'
verdict "la durée en images reste conforme" '.durationInFrames.actual == 600 and .durationInFrames.ok'

echo "# mauvaise résolution"
run_probe "$FIXTURES/resolution.json" "$sans_voix" out/notio.mp4
expect_status "1280×720 : exit 1" 1
verdict "largeur et hauteur non conformes, avec leur écart" \
  '.verdict == "non conforme" and .width == {expected: 1920, actual: 1280, gap: -640, ok: false} and .height == {expected: 1080, actual: 720, gap: -360, ok: false}'

echo "# piste audio manquante avec voix off"
run_probe "$FIXTURES/conforme.json" "$avec_voix" out/notio.mp4
expect_status "voix off sans piste audio : exit 1" 1
verdict "audio exigé, absent" '.verdict == "non conforme" and .audio == {required: true, present: false, ok: false}'
verdict "seul l'audio est en défaut" '.durationInFrames.ok and .fps.ok and .width.ok and .height.ok'

echo "# MP4 illisible"
run_probe "$FIXTURES/conforme.json" "$sans_voix" out/absent.mp4
expect_refusal "refuse un MP4 absent (exit 2)" 'absent\.mp4'
expect_no_call "ffprobe n'est pas lancé sur un MP4 absent"
run_probe fail "$sans_voix" out/notio.mp4
expect_refusal "refuse un fichier que ffprobe ne lit pas (exit 2)" 'Invalid data'
run_probe "$work/sans-video.json" "$sans_voix" out/notio.mp4
expect_refusal "refuse un fichier sans piste vidéo (exit 2)" 'vidéo'
STUB_FFPROBE="$work/bin/absent" run_probe "$FIXTURES/conforme.json" "$sans_voix" out/notio.mp4
expect_refusal "refuse sans ffprobe, renvoie à doctor.sh (exit 2)" 'doctor\.sh'

echo "# storyboard illisible"
# bad_storyboard <dir> <content of the json block, or - for none>
bad_storyboard() {
  mkdir -p "$work/$1/out"
  printf 'MP4' >"$work/$1/out/notio.mp4"
  if [[ $2 == - ]]; then
    printf '# Storyboard\n\nPas de bloc.\n' >"$work/$1/storyboard.md"
  else
    printf '# Storyboard\n\n```json\n%s\n```\n' "$2" >"$work/$1/storyboard.md"
  fi
}
mkdir -p "$work/sans-storyboard/out"
run_probe "$FIXTURES/conforme.json" "$work/sans-storyboard" out/notio.mp4
expect_refusal "refuse un projet sans storyboard.md" 'storyboard\.md'
bad_storyboard sans-bloc -
run_probe "$FIXTURES/conforme.json" "$work/sans-bloc" out/notio.mp4
expect_refusal "refuse un storyboard sans bloc json" 'json'
bad_storyboard bloc-casse '{ "format": { "width": 1920, '
run_probe "$FIXTURES/conforme.json" "$work/bloc-casse" out/notio.mp4
expect_refusal "refuse un bloc json illisible" 'json'
bad_storyboard sans-format '{ "voiceover": false, "scenes": [ { "id": "A", "durationInFrames": 10 } ] }'
run_probe "$FIXTURES/conforme.json" "$work/sans-format" out/notio.mp4
expect_refusal "refuse un storyboard sans format" 'format'
bad_storyboard cadence-texte '{ "format": { "width": 1920, "height": 1080, "fps": "30" }, "voiceover": false, "scenes": [ { "id": "A", "durationInFrames": 10 } ] }'
run_probe "$FIXTURES/conforme.json" "$work/cadence-texte" out/notio.mp4
expect_refusal "refuse une cadence qui n'est pas un nombre entier" 'fps'
bad_storyboard voix-texte '{ "format": { "width": 1920, "height": 1080, "fps": 30 }, "voiceover": "oui", "scenes": [ { "id": "A", "durationInFrames": 10 } ] }'
run_probe "$FIXTURES/conforme.json" "$work/voix-texte" out/notio.mp4
expect_refusal "refuse un voiceover qui n'est pas true ou false" 'voiceover'
bad_storyboard sans-scene '{ "format": { "width": 1920, "height": 1080, "fps": 30 }, "voiceover": false, "scenes": [] }'
run_probe "$FIXTURES/conforme.json" "$work/sans-scene" out/notio.mp4
expect_refusal "refuse un storyboard sans scène" 'scène'
bad_storyboard duree-absente '{ "format": { "width": 1920, "height": 1080, "fps": 30 }, "voiceover": false, "scenes": [ { "id": "A", "durationInFrames": 10 }, { "id": "B" } ] }'
run_probe "$FIXTURES/conforme.json" "$work/duree-absente" out/notio.mp4
expect_refusal "refuse une scène sans durée entière, et la nomme" 'B.*durationInFrames'
expect_no_call "ffprobe n'est pas lancé sur un storyboard illisible"
run_probe "$FIXTURES/conforme.json" "$sans_voix"
expect_refusal "refuse un appel sans MP4" 'usage'
run_probe "$FIXTURES/conforme.json"
expect_refusal "refuse un appel sans projet" 'usage'

finish
