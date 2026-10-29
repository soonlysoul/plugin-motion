#!/usr/bin/env bash
# scripts/transcribe.sh with a simulated ffmpeg (MOTION_FFMPEG), whisper-cli (MOTION_WHISPER) and
# whisper-vad-speech-segments (MOTION_WHISPER_VAD), which print outputs recorded on 2026-10-28 from
# tests/fixtures/voiceover/: whisper.cpp 1.8.4, ggml-large-v3-turbo-q5_0 and ggml-silero-v6.2.0, on
# an extract Soon recorded (« Vos idées vont trop vite ? Notez tout, retrouvez tout. Notio.
# Disponible sur iOS et Android. »), converted to a 16 kHz mono WAV; silence: ten seconds without a
# word. Whisper starts each word after a pause at the end of the word before; the segments of
# speech of the VAD put it back where it is said. Cases: transcription, language, silence,
# refusals. No network, no model, no audio.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_transcribe
TRANSCRIBE="$PLUGIN_ROOT/scripts/transcribe.sh"
FIXTURES="$PLUGIN_ROOT/tests/fixtures/voiceover"

if [[ ! -f $TRANSCRIBE ]]; then
  fail "scripts/transcribe.sh présent" "absent"
  finish
  exit
fi
pass "scripts/transcribe.sh présent"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Simulated binaries: each logs its arguments, one line per call, prefixed by its name.
# STUB_FFMPEG=fail, STUB_WHISPER=fail make them fail as the real ones do on a bad file.
mkdir "$work/bin"
cat >"$work/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf 'ffmpeg %s\n' "$*" >>"$STUB_LOG"
if [[ ${STUB_FFMPEG:-} == fail ]]; then
  echo "Invalid data found when processing input" >&2
  exit 1
fi
printf 'RIFF' >"${!#}"
EOF
cat >"$work/bin/whisper-cli" <<'EOF'
#!/usr/bin/env bash
printf 'whisper %s\n' "$*" >>"$STUB_LOG"
while [[ $# -gt 0 ]]; do
  case $1 in
    -f) [[ -f $2 ]] && printf 'whisper-wav-present\n' >>"$STUB_LOG"; shift 2 ;;
    -of) base=$2; shift 2 ;;
    *) shift ;;
  esac
done
if [[ ${STUB_WHISPER:-} == fail ]]; then
  echo "error: failed to read audio data as wav" >&2
  exit 1
fi
cp "$STUB_WHISPER_JSON" "$base.json"
EOF
cat >"$work/bin/whisper-vad-speech-segments" <<'EOF'
#!/usr/bin/env bash
printf 'vad %s\n' "$*" >>"$STUB_LOG"
cat "$STUB_VAD"
EOF
chmod +x "$work/bin/"*
mkdir "$work/models"
: >"$work/models/ggml-large-v3-turbo-q5_0.bin"
: >"$work/models/ggml-silero-v6.2.0.bin"

# make_project <dir>: three scenes, 150 + 240 + 210 = 600 frames at 30 i/s, the voice in public/.
make_project() {
  mkdir -p "$1/public" "$1/src"
  printf 'RIFF....WAVEfmt ' >"$1/public/voix.wav"
  printf 'RIFF....WAVEfmt ' >"$1/voix.wav"
  cat >"$1/storyboard.md" <<'EOF'
# Storyboard — Notio

```json
{
  "format": { "width": 1920, "height": 1080, "fps": 30 },
  "voiceover": true,
  "scenes": [
    { "id": "Ouverture", "durationInFrames": 150, "text": "", "motion": "…", "cues": [ { "word": "Vos", "action": "x" } ], "status": "validée" },
    { "id": "Message", "durationInFrames": 240, "text": "", "motion": "…", "cues": [], "status": "validée" },
    { "id": "Final", "durationInFrames": 210, "text": "", "motion": "…", "cues": [], "status": "validée" }
  ]
}
```
EOF
}

# run_transcribe <whisper output> <vad output> <args...>: sets TR_STATUS, TR_OUT, TR_ERR.
# STUB_BIN, MODEL and VAD_MODEL override the binaries' folder and the models.
run_transcribe() {
  local json=$1 vad=$2 out err
  shift 2
  out=$(mktemp) err=$(mktemp)
  : >"$work/calls.log"
  env MOTION_FFMPEG="${STUB_BIN:-$work/bin}/ffmpeg" MOTION_WHISPER="${STUB_BIN:-$work/bin}/whisper-cli" \
    MOTION_WHISPER_VAD="${STUB_BIN:-$work/bin}/whisper-vad-speech-segments" \
    MOTION_WHISPER_MODEL="${MODEL:-$work/models/ggml-large-v3-turbo-q5_0.bin}" \
    MOTION_WHISPER_VAD_MODEL="${VAD_MODEL:-$work/models/ggml-silero-v6.2.0.bin}" \
    STUB_WHISPER_JSON="$json" STUB_VAD="$vad" STUB_LOG="$work/calls.log" \
    "$BASH" "$TRANSCRIBE" "$@" >"$out" 2>"$err"
  TR_STATUS=$?
  TR_OUT=$(<"$out") TR_ERR=$(<"$err")
  rm -f "$out" "$err"
}
summary() {
  if jq -e "$2" >/dev/null 2>&1 <<<"$TR_OUT"; then pass "$1"
  else fail "$1" "$2 ; obtenu : $(jq -c . <<<"$TR_OUT" 2>/dev/null || printf '%s' "${TR_OUT:0:300}") ; stderr : ${TR_ERR:0:200}"; fi
}
written() {
  if jq -e "$3" "$2/public/voiceover.json" >/dev/null 2>&1; then pass "$1"
  else fail "$1" "$3 ; voiceover.json : $(head -c 400 "$2/public/voiceover.json" 2>/dev/null)"; fi
}
expect_status() {
  [[ $TR_STATUS == "$2" ]] && pass "$1" || fail "$1" "attendu exit $2, obtenu $TR_STATUS ; stderr : ${TR_ERR:0:300}"
}
expect_refusal() {
  if [[ $TR_STATUS == 2 && $TR_ERR =~ $2 && -z $TR_OUT ]]; then pass "$1"
  else fail "$1" "attendu exit 2, « $2 » et rien sur stdout ; obtenu exit $TR_STATUS ; stderr : ${TR_ERR:0:300} ; stdout : ${TR_OUT:0:100}"; fi
}
expect_no_call() {
  [[ ! -s $work/calls.log ]] && pass "$1" || fail "$1" "$(cat "$work/calls.log")"
}
calls() { grep -c "^$1 " "$work/calls.log"; }
call() { grep -m 1 "^$1 " "$work/calls.log"; }

VOIX="$FIXTURES/voix.json" VOIX_VAD="$FIXTURES/voix.vad.txt"
SILENCE="$FIXTURES/silence.json" SILENCE_VAD="$FIXTURES/silence.vad.txt"

echo "# transcription"
p=$work/projet
make_project "$p"
printf '{ "audio": "ancienne.wav", "words": [], "cues": { "Ouverture": [ { "word": "Vos", "index": 0, "startMs": 0, "frame": 0 } ] } }\n' \
  >"$p/public/voiceover.json"
(cd "$p" && find . -type f ! -path ./public/voiceover.json | sort) >"$work/avant.txt"
cp "$p/storyboard.md" "$work/storyboard.avant"
run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_status "transcription écrite : exit 0" 0
summary "un résumé JSON sur stdout" 'type == "object"'
summary "15 mots, 5 segments de parole, 4 débuts recalés" '.words == 15 and .speech == 5 and .corrected == 4'
summary "voix finie à 10030 ms, image 301 sur 600, sans dépassement" '.endMs == 10030 and .endFrame == 301 and .total == 600 and .overflow == 0'
summary "nomme voiceover.json en chemin absolu" ".voiceover == \"$p/public/voiceover.json\""
written "fichier, modèle et langue" "$p" '.audio == "voix.wav" and .model == "ggml-large-v3-turbo-q5_0.bin" and .language == "fr"'
written "le segment vide de Whisper est écarté, les textes sans espace" "$p" \
  '[.words[].text] == ["Vos", "idées", "vont", "trop", "vite.", "Notez", "tout.", "Retrouvez", "tout.", "Notio.", "Disponible", "sur", "iOS", "et", "Android."]'
written "un mot au type Caption : text, startMs, endMs, timestampMs, confidence" "$p" \
  '.words[0] == {text: "Vos", startMs: 1670, endMs: 1790, timestampMs: null, confidence: 0.924}'
written "Notez commence au segment ouvert à 3940 ms, pas à 2850 ms" "$p" '.words[5] | .startMs == 3940 and .endMs == 3950'
written "Retrouvez, Notio. et Disponible recalés à 5380, 7140 et 8160 ms" "$p" '[.words[7, 9, 10].startMs] == [5380, 7140, 8160]'
written "les mots dits sans pause gardent le début de Whisper" "$p" \
  '[.words[1, 2, 3, 4, 6, 8, 11, 12, 13, 14].startMs] == [1790, 2130, 2360, 2590, 3950, 5520, 8530, 8770, 8950, 9340]'
written "confiance : la plus faible des jetons du mot, 0,433 pour Notio." "$p" '.words[9].confidence == 0.433 and .words[10].confidence == 0.71'
written "segments de parole en millisecondes" "$p" '.speech == [[1660, 2980], [3940, 4670], [5380, 6110], [7140, 7740], [8160, 10370]]'
written "les repères d'une transcription précédente sont effacés" "$p" '.cues == {}'
[[ $(calls ffmpeg) == 1 && $(calls whisper) == 1 && $(calls vad) == 1 ]] \
  && pass "ffmpeg, whisper et la détection vocale appelés une fois chacun" \
  || fail "ffmpeg, whisper et la détection vocale appelés une fois chacun" "$(cat "$work/calls.log")"
ff=$(call ffmpeg) wh=$(call whisper) va=$(call vad)
wav=${ff##* }
[[ $ff == *"-i $p/public/voix.wav "* && $ff == *"-ar 16000 -ac 1 -c:a pcm_s16le "* && $wav == *.wav ]] \
  && pass "ffmpeg : public/voix.wav en WAV 16 kHz mono, PCM 16 bits" || fail "ffmpeg : public/voix.wav en WAV 16 kHz mono, PCM 16 bits" "$ff"
[[ $wav != "$p"/* ]] && pass "le WAV converti est hors du projet" || fail "le WAV converti est hors du projet" "$wav"
[[ ! -e $wav ]] && pass "le dossier temporaire est retiré" || fail "le dossier temporaire est retiré" "$wav"
[[ $wh == *"-m $work/models/ggml-large-v3-turbo-q5_0.bin "* && $wh == *"-l fr "* && $wh == *"-f $wav "* \
   && $wh == *"--vad -vm $work/models/ggml-silero-v6.2.0.bin "* && $wh == *"-ml 1 -sow -ojf "* ]] \
  && pass "whisper : modèle, français, détection vocale, un mot par segment, JSON complet" \
  || fail "whisper : modèle, français, détection vocale, un mot par segment, JSON complet" "$wh"
grep -qx 'whisper-wav-present' "$work/calls.log" && pass "whisper lit le WAV converti" || fail "whisper lit le WAV converti"
[[ $va == *"-vm $work/models/ggml-silero-v6.2.0.bin "* && $va == *"-vp 0 "* && $va == *"-f $wav"* ]] \
  && pass "détection vocale sur le même WAV, sans marge" || fail "détection vocale sur le même WAV, sans marge" "$va"
(cd "$p" && find . -type f ! -path ./public/voiceover.json | sort) >"$work/apres.txt"
cmp -s "$work/avant.txt" "$work/apres.txt" && cmp -s "$p/storyboard.md" "$work/storyboard.avant" \
  && pass "seul public/voiceover.json change dans le projet" || fail "seul public/voiceover.json change dans le projet" "$(diff "$work/avant.txt" "$work/apres.txt")"
run_transcribe "$VOIX" "$VOIX_VAD" "$p" "$p/public/voix.wav"
expect_status "un fichier audio en chemin absolu dans public/ : exit 0" 0

echo "# langue"
run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav en
[[ $(call whisper) == *"-l en "* ]] && pass "la langue passe à whisper" || fail "la langue passe à whisper" "$(call whisper)"
written "et à voiceover.json" "$p" '.language == "en"'

echo "# silence"
p=$work/silence
make_project "$p"
run_transcribe "$SILENCE" "$SILENCE_VAD" "$p" public/voix.wav
expect_status "aucune parole : exit 1" 1
[[ $TR_ERR == *"aucune parole"* ]] && pass "le dit" || fail "le dit" "$TR_ERR"
[[ ! -e $p/public/voiceover.json ]] && pass "rien n'est écrit" || fail "rien n'est écrit"

echo "# refus"
p=$work/refus
make_project "$p"
run_transcribe "$VOIX" "$VOIX_VAD"
expect_refusal "refuse un appel sans projet" 'usage'
run_transcribe "$VOIX" "$VOIX_VAD" "$p"
expect_refusal "refuse un appel sans fichier audio" 'usage'
run_transcribe "$VOIX" "$VOIX_VAD" "$work/absent" public/voix.wav
expect_refusal "refuse un dossier absent" 'absent'
mkdir -p "$work/sans-storyboard/public" && printf 'RIFF' >"$work/sans-storyboard/public/voix.wav"
run_transcribe "$VOIX" "$VOIX_VAD" "$work/sans-storyboard" public/voix.wav
expect_refusal "refuse un projet sans storyboard.md" 'storyboard\.md'
make_project "$work/sans-cadence"
sed -i 's/, "fps": 30//' "$work/sans-cadence/storyboard.md"
run_transcribe "$VOIX" "$VOIX_VAD" "$work/sans-cadence" public/voix.wav
expect_refusal "refuse un storyboard sans cadence" 'fps'
run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/absente.wav
expect_refusal "refuse un fichier audio absent" 'absente\.wav'
expect_no_call "aucun binaire lancé sur un fichier absent"
run_transcribe "$VOIX" "$VOIX_VAD" "$p" voix.wav
expect_refusal "refuse un fichier hors de public/, que Video ne pourrait pas jouer" 'public/'
expect_no_call "aucun binaire lancé sur un fichier hors de public/"
MODEL=$work/models/absent.bin run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "refuse sans modèle Whisper, et le nomme" 'absent\.bin'
mkdir -p "$work/cache"
MODEL=$work/cache/ggml-large-v3-turbo-q5_0.bin run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "modèle par défaut absent : taille et commande de téléchargement" \
  "574 Mo.*whisper-cpp-download-ggml-model large-v3-turbo-q5_0 $work/cache"
VAD_MODEL=$work/cache/ggml-silero-v6.2.0.bin run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "modèle de détection vocale absent : taille et adresse" '885 Ko.*huggingface\.co/ggml-org/whisper-vad'
expect_no_call "aucun binaire lancé sans modèle"
mkdir -p "$work/bin-sans-ffmpeg" && cp "$work/bin/whisper-cli" "$work/bin/whisper-vad-speech-segments" "$work/bin-sans-ffmpeg/"
STUB_BIN=$work/bin-sans-ffmpeg run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "refuse sans ffmpeg, renvoie à doctor.sh" 'doctor\.sh'
mkdir -p "$work/bin-sans-whisper" && cp "$work/bin/ffmpeg" "$work/bin/whisper-vad-speech-segments" "$work/bin-sans-whisper/"
STUB_BIN=$work/bin-sans-whisper run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "refuse sans whisper-cli, nomme le paquet whisper-cpp" 'whisper-cpp'
mkdir -p "$work/bin-sans-vad" && cp "$work/bin/ffmpeg" "$work/bin/whisper-cli" "$work/bin-sans-vad/"
STUB_BIN=$work/bin-sans-vad run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "refuse sans whisper-vad-speech-segments" 'whisper-vad-speech-segments'
cp "$p/public/voiceover.json" "$work/vo.avant" 2>/dev/null || : >"$work/vo.avant"
STUB_FFMPEG=fail run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "un fichier que ffmpeg ne lit pas : son erreur" 'Invalid data'
STUB_WHISPER=fail run_transcribe "$VOIX" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "whisper en échec : son erreur" 'failed to read audio'
printf '{ "transcription": [' >"$work/casse.json"
run_transcribe "$work/casse.json" "$VOIX_VAD" "$p" public/voix.wav
expect_refusal "sortie de whisper illisible" 'whisper'
printf 'rien\n' >"$work/casse.vad.txt"
run_transcribe "$VOIX" "$work/casse.vad.txt" "$p" public/voix.wav
expect_refusal "sortie de la détection vocale illisible" 'segments'
[[ ! -e $p/public/voiceover.json ]] && pass "un refus n'écrit rien" || fail "un refus n'écrit rien"

finish
