#!/usr/bin/env bash
# transcribe.sh <projet> <audio> [langue] — the voiceover transcribed word by word, for sync-voiceover.
# <audio> lies in the project's public/, where the composition Video plays it with staticFile(); a
# relative path is taken from the project. ffmpeg converts it to a 16 kHz mono WAV outside the
# project; whisper-cli transcribes it (voice activity detection, one word per segment, full JSON);
# whisper-vad-speech-segments lists its segments of speech. Whisper starts a word said after a pause
# at the end of the word before, the pause included (measured on 2026-10-28: up to 1.1 s early): a
# word in whose span a segment of speech opens starts where that segment opens.
# Writes public/voiceover.json: the audio file, the model, the language, the words as Remotion
# Captions (text, startMs, endMs, timestampMs, confidence: the lowest probability of its tokens), the
# segments of speech [start, end] in milliseconds, and cues {}, which cues.sh fills. Prints a JSON
# summary: the words, the segments, the words moved, and where the voice ends against the total of
# storyboard.md. Exit 0 when written, 1 when no word was heard (nothing written), 2 on a refusal.
# Binaries replaceable for the tests: MOTION_FFMPEG, MOTION_WHISPER, MOTION_WHISPER_VAD; models:
# MOTION_WHISPER_MODEL and MOTION_WHISPER_VAD_MODEL, in ~/.cache/plugin-motion/ by default.
set -uo pipefail

FFMPEG=${MOTION_FFMPEG:-ffmpeg}
WHISPER=${MOTION_WHISPER:-whisper-cli}
VAD=${MOTION_WHISPER_VAD:-whisper-vad-speech-segments}
cache=${XDG_CACHE_HOME:-$HOME/.cache}/plugin-motion
MODEL=${MOTION_WHISPER_MODEL:-$cache/ggml-large-v3-turbo-q5_0.bin}
VAD_MODEL=${MOTION_WHISPER_VAD_MODEL:-$cache/ggml-silero-v6.2.0.bin}

refuse() { echo "transcribe.sh : $1" >&2; exit 2; }

project=${1:-} audio=${2:-} lang=${3:-fr}
[[ -n $project && -n $audio ]] || refuse "usage : transcribe.sh <projet> <audio de public/> [langue]"
[[ -d $project ]] || refuse "dossier absent : $project"
project=$(cd "$project" && pwd)
[[ $lang =~ ^([a-z]{2,3}|auto)$ ]] || refuse "langue illisible : $lang (fr, en, … ou auto)."
command -v jq >/dev/null 2>&1 || refuse "jq introuvable ; il lit storyboard.md et écrit voiceover.json."
storyboard=$project/storyboard.md
[[ -f $storyboard ]] || refuse "$storyboard absent : ce dossier n'est pas un projet vidéo storyboardé (/plugin-motion:storyboard l'écrit)."

# The first ```json block of storyboard.md: its frame rate and the durations of its scenes.
data=$(awk '/^```json[[:space:]]*$/ && !open { open = 1; next } open && /^```[[:space:]]*$/ { exit } open { print }' "$storyboard")
[[ -n $data ]] || refuse "aucun bloc \`\`\`json dans $storyboard."
jq -e 'type == "object"' <<<"$data" >/dev/null 2>&1 || refuse "le bloc json de $storyboard est illisible."
problem=$(jq -r '
  def whole: if type == "number" then . == floor and . > 0 else false end;
  if (.format | type) != "object" or (.format.fps | whole | not) then "format.fps doit être un nombre entier"
  elif (.scenes | type) != "array" or (.scenes | length) == 0 then "aucune scène"
  else first(.scenes[] | select(.durationInFrames | whole | not)
             | "la scène \(.id? // "sans id") : durationInFrames doit être un nombre entier positif") // empty
  end' <<<"$data")
[[ -z $problem ]] || refuse "$problem dans $storyboard."

[[ $audio == /* ]] || audio=$project/$audio
[[ -f $audio ]] || refuse "fichier audio absent : $audio"
audio=$(cd "$(dirname "$audio")" && pwd)/$(basename "$audio")
[[ $audio == "$project/public/"* ]] \
  || refuse "$audio n'est pas dans $project/public/ : la composition Video joue la voix off par staticFile(), qui ne lit que public/ ; l'y copier d'abord."

command -v "$FFMPEG" >/dev/null 2>&1 || refuse "ffmpeg introuvable ($FFMPEG) ; doctor.sh dit quoi installer."
command -v "$WHISPER" >/dev/null 2>&1 \
  || refuse "whisper-cli introuvable ($WHISPER) : installer le paquet nixpkgs whisper-cpp via /plugin-nixos:modifie ; doctor.sh le vérifie."
command -v "$VAD" >/dev/null 2>&1 \
  || refuse "whisper-vad-speech-segments introuvable ($VAD) : il vient du paquet whisper-cpp, avec whisper-cli."
if [[ ! -f $MODEL ]]; then
  [[ ${MODEL##*/} == ggml-large-v3-turbo-q5_0.bin ]] \
    && refuse "modèle Whisper absent : $MODEL (574 Mo). Le télécharger une fois, avec l'accord de Soon : mkdir -p ${MODEL%/*} && whisper-cpp-download-ggml-model large-v3-turbo-q5_0 ${MODEL%/*}"
  refuse "modèle Whisper absent : $MODEL (MOTION_WHISPER_MODEL)."
fi
if [[ ! -f $VAD_MODEL ]]; then
  [[ ${VAD_MODEL##*/} == ggml-silero-v6.2.0.bin ]] \
    && refuse "modèle de détection vocale absent : $VAD_MODEL (885 Ko). Le télécharger une fois, avec l'accord de Soon : curl -L --create-dirs -o $VAD_MODEL https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin"
  refuse "modèle de détection vocale absent : $VAD_MODEL (MOTION_WHISPER_VAD_MODEL)."
fi

tmp=$(mktemp -d) || refuse "mktemp a échoué."
trap 'rm -rf "$tmp"' EXIT
wav=$tmp/voix-16k.wav
threads=$(nproc 2>/dev/null || echo 4)
"$FFMPEG" -nostdin -v error -y -i "$audio" -ar 16000 -ac 1 -c:a pcm_s16le "$wav" 2>"$tmp/ffmpeg.log" \
  || refuse "ffmpeg ne lit pas $audio : $(tail -n 3 "$tmp/ffmpeg.log")"
"$WHISPER" -m "$MODEL" -l "$lang" -t "$threads" -f "$wav" --vad -vm "$VAD_MODEL" -ml 1 -sow -ojf -of "$tmp/whisper" -np \
  >"$tmp/whisper.log" 2>&1 || refuse "whisper-cli a échoué sur $audio : $(tail -n 3 "$tmp/whisper.log")"
transcription=$(jq -c '.transcription' "$tmp/whisper.json" 2>/dev/null)
jq -e 'type == "array"' <<<"$transcription" >/dev/null 2>&1 || refuse "sortie JSON de whisper-cli illisible pour $audio."
"$VAD" -vm "$VAD_MODEL" -vp 0 -t "$threads" -f "$wav" >"$tmp/vad.txt" 2>"$tmp/vad.log" \
  || refuse "whisper-vad-speech-segments a échoué sur $audio : $(tail -n 3 "$tmp/vad.log")"
count=$(sed -nE 's/^Detected ([0-9]+) speech segments.*/\1/p' "$tmp/vad.txt")
speech=$(sed -nE 's/^Speech segment [0-9]+: start = ([0-9.]+), end = ([0-9.]+)$/[\1, \2]/p' "$tmp/vad.txt" | jq -sc 'map(map(. * 10 | round))')
[[ -n $count && $(jq length <<<"$speech") == "$count" ]] \
  || refuse "sortie de whisper-vad-speech-segments illisible : la ligne « Detected N speech segments » et ses N segments manquent."

# The segments are in centiseconds; a word moves to the first segment that opens inside its span.
words=$(jq -c --argjson speech "$speech" '
  [.[] | {text: (.text | sub("^\\s+"; "") | sub("\\s+$"; "")), from: .offsets.from, to: .offsets.to,
          p: [.tokens[]? | select(.text | startswith("[_") | not) | .p]}
   | select(.text != "")
   | . as $w | (first($speech[] | .[0] | select(. > $w.from and . < $w.to)) // null) as $open
   | {text, startMs: ($open // .from), endMs: .to, timestampMs: null,
      confidence: (if (.p | length) == 0 then null else (.p | min * 1000 | round / 1000) end),
      moved: ($open != null)}]' <<<"$transcription")
if [[ $(jq length <<<"$words") == 0 ]]; then
  echo "transcribe.sh : aucune parole reconnue dans $audio ; rien n'est écrit." >&2
  exit 1
fi

voiceover=$project/public/voiceover.json
out=$(mktemp "$project/public/.voiceover.XXXXXX") || refuse "mktemp a échoué dans $project/public."
if ! jq -n --arg audio "${audio#"$project/public/"}" --arg model "${MODEL##*/}" --arg lang "$lang" \
      --argjson words "$words" --argjson speech "$speech" \
      '{audio: $audio, model: $model, language: $lang, words: ($words | map(del(.moved))), speech: $speech, cues: {}}' \
      >"$out" || ! mv "$out" "$voiceover"; then
  rm -f "$out"
  refuse "écriture impossible de $voiceover."
fi

jq -n --argjson sb "$data" --argjson words "$words" --argjson speech "$speech" --arg voiceover "$voiceover" --arg audio "$audio" '
  ([$sb.scenes[].durationInFrames] | add) as $total
  | ([$words[].endMs] | max) as $end
  | ($end * $sb.format.fps / 1000 | round) as $endFrame
  | {voiceover: $voiceover, audio: $audio, words: ($words | length), speech: ($speech | length),
     corrected: ([$words[] | select(.moved)] | length),
     endMs: $end, endFrame: $endFrame, total: $total, overflow: ([$endFrame - $total, 0] | max)}'
