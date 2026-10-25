#!/usr/bin/env bash
# doctor.sh <projet> — diagnostic of the machine for a Remotion video project, changing nothing in
# the system: one line per check (ok, manque, avertissement) with its correction. Node against the
# engines.node of package.json; ffmpeg and ffprobe; one version for remotion and every @remotion/*
# of package.json; a render trial of one frame, which names the libraries the headless Chrome
# lacks; whisper-cpp, a warning only. Its first run downloads Remotion's headless Chrome into the
# project's node_modules.
# Exit 0 when every mandatory check passes, 1 otherwise, 2 on a refusal.
# Binaries replaceable for the tests: MOTION_NPX, MOTION_NODE, MOTION_FFMPEG, MOTION_FFPROBE.
set -uo pipefail

NPX=${MOTION_NPX:-npx} NODE=${MOTION_NODE:-node} FFMPEG=${MOTION_FFMPEG:-ffmpeg} FFPROBE=${MOTION_FFPROBE:-ffprobe}
NIXOS="via /plugin-nixos:modifie"
PLAN_B="plan B : le chromium de nixpkgs, installé $NIXOS, désigné à Remotion par --browser-executable (ou Config.setBrowserExecutable dans remotion.config.ts)"

refuse() { echo "doctor.sh : $1" >&2; exit 2; }

project=${1:-}
[[ -n $project ]] || refuse "usage : doctor.sh <projet>"
[[ -d $project ]] || refuse "dossier introuvable : $project"
command -v jq >/dev/null 2>&1 || refuse "jq introuvable ; il lit package.json."
[[ -f $project/package.json ]] || refuse "$project/package.json absent : ce dossier n'est pas un projet Remotion (/plugin-motion:new-video le crée)."
jq -e 'type == "object"' "$project/package.json" >/dev/null 2>&1 || refuse "$project/package.json n'est pas du JSON lisible."

work=$(mktemp -d) || refuse "mktemp -d a échoué."
trap 'rm -rf "$work"' EXIT
failures=0 warnings=0

# report <ok|manque|avertissement> <check> <text>
report() {
  printf '%-14s %s : %s\n' "$1" "$2" "$3"
  case $1 in
    manque) failures=$((failures + 1)) ;;
    avertissement) warnings=$((warnings + 1)) ;;
  esac
}

# plural <count> <word>: « 1 avertissement », « 2 avertissements ».
plural() { printf '%d %s%s' "$1" "$2" "$( (($1 > 1)) && echo s)"; }

# comparator_holds <version number> <op> <major> [minor] [patch]: one comparator of an npm range;
# a part left out widens it, as npm reads « 22 » or « ^22.13 ».
comparator_holds() {
  local v=$1 op=$2 a=$((10#$3)) b=${4:-} c=${5:-} p next caret
  p=$((a * 1000000 + 10#${b:-0} * 1000 + 10#${c:-0}))
  if [[ -z $b ]]; then next=$(((a + 1) * 1000000))
  elif [[ -z $c ]]; then next=$((a * 1000000 + (10#$b + 1) * 1000))
  else next=$((p + 1)); fi
  if ((a > 0)) || [[ -z $b ]]; then caret=$(((a + 1) * 1000000))
  elif ((10#$b > 0)) || [[ -z $c ]]; then caret=$((a * 1000000 + (10#$b + 1) * 1000))
  else caret=$((p + 1)); fi
  case $op in
    '' | '=') ((v >= p && v < next)) ;;
    '>=') ((v >= p)) ;;
    '>') ((v >= next)) ;;
    '<') ((v < p)) ;;
    '<=') ((v < next)) ;;
    '~') if [[ -z $b ]]; then ((v >= p && v < next)); else ((v >= p && v < a * 1000000 + (10#$b + 1) * 1000)); fi ;;
    '^') ((v >= p && v < caret)) ;;
  esac
}

# satisfies <X.Y.Z> <range>: 0 when the version meets the npm range (alternatives by ||,
# comparators by spaces, ^ ~ >= > <= < =, partial versions, x and *), 1 when it does not,
# 2 when the range is not understood.
satisfies() {
  local major minor patch v alternative comparator unknown=0 holds
  local -a comparators
  IFS=. read -r major minor patch <<<"$1"
  v=$((10#$major * 1000000 + 10#$minor * 1000 + 10#$patch))
  while IFS= read -r alternative; do
    read -ra comparators <<<"$alternative"
    holds=1
    for comparator in ${comparators[@]+"${comparators[@]}"}; do
      [[ $comparator == [xX*] ]] && continue
      if [[ ! $comparator =~ ^(\^|~|>=|>|<=|<|=)?v?([0-9]+)(\.([0-9]+|[xX*]))?(\.([0-9]+|[xX*]))?$ ]]; then
        unknown=1 holds=0
        break
      fi
      local op=${BASH_REMATCH[1]} a=${BASH_REMATCH[2]} b=${BASH_REMATCH[4]} c=${BASH_REMATCH[6]}
      [[ $b == [xX*] ]] && b="" c=""
      [[ $c == [xX*] ]] && c=""
      comparator_holds "$v" "$op" "$a" "$b" "$c" || { holds=0; break; }
    done
    ((holds)) && return 0
  done <<<"${2//||/$'\n'}"
  return $((unknown ? 2 : 1))
}

check_node() {
  local raw version range
  if ! command -v "$NODE" >/dev/null 2>&1; then
    report manque node "introuvable ($NODE) — correction : installer Node.js (paquets nixpkgs nodejs_<version majeure>) $NIXOS."
    return
  fi
  raw=$("$NODE" --version 2>/dev/null | head -n 1)
  if [[ ! $raw =~ ^v?([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    report manque node "version illisible (« ${raw:0:80} ») — correction : réinstaller Node.js $NIXOS."
    return
  fi
  version=${BASH_REMATCH[1]}
  range=$(jq -r '.engines.node // empty' "$project/package.json")
  if [[ -z $range ]]; then
    report avertissement node "v$version ; package.json ne dit pas la version que demande Remotion (engines.node absent)"
    return
  fi
  satisfies "$version" "$range"
  case $? in
    0) report ok node "v$version, accepté par engines.node « $range »" ;;
    1) report manque node "v$version, hors de engines.node « $range » — correction : installer une version acceptée (paquets nixpkgs nodejs_<version majeure>) $NIXOS." ;;
    *) report avertissement node "v$version ; engines.node « $range » n'est pas lu par doctor.sh, à comparer à la main" ;;
  esac
}

# check_tool <name> <binary> <what needs it>
check_tool() {
  local name=$1 bin=$2 needed=$3 line
  if ! command -v "$bin" >/dev/null 2>&1; then
    report manque "$name" "introuvable ($bin), nécessaire à $needed — correction : installer le paquet nixpkgs ffmpeg, qui fournit ffmpeg et ffprobe, $NIXOS."
    return
  fi
  line=$("$bin" -version 2>/dev/null | head -n 1)
  if [[ $line =~ ^$name\ version\ ([^ ]+) ]]; then
    report ok "$name" "${BASH_REMATCH[1]}"
  else
    report manque "$name" "$bin ne répond pas à -version (« ${line:0:80} ») — correction : réinstaller le paquet nixpkgs ffmpeg $NIXOS."
  fi
}

check_versions() {
  local listing versions
  listing=$(jq -r '[(.dependencies // {}), (.devDependencies // {})] | add | to_entries
    | map(select(.key == "remotion" or (.key | startswith("@remotion/")))) | sort_by(.key)
    | .[] | "\(.key) \(.value)"' "$project/package.json")
  if [[ -z $listing ]]; then
    report manque "versions de Remotion" "remotion absent de package.json — correction : recréer le projet avec /plugin-motion:new-video."
    return
  fi
  versions=$(cut -d' ' -f2 <<<"$listing" | sort -u)
  if [[ $(grep -c . <<<"$versions") == 1 ]]; then
    report ok "versions de Remotion" "$versions pour $(grep -c . <<<"$listing") paquets (remotion et @remotion/*)"
  else
    report manque "versions de Remotion" "désalignées : $(paste -sd, <<<"$listing" | sed 's/,/, /g') — correction : npx remotion upgrade dans le projet, qui met remotion et tous les @remotion/* à une même version."
  fi
}

# library_package <lib>: the nixpkgs package that provides it under nix-ld.
library_package() {
  case $1 in
    libnspr4.so* | libplc4.so* | libplds4.so*) echo nspr ;;
    libnss3.so* | libnssutil3.so* | libsmime3.so* | libssl3.so*) echo nss ;;
    libexpat.so*) echo expat ;;
    *) echo "le paquet qui fournit $1 (/plugin-nixos:cherche)" ;;
  esac
}

# render_failure <log> <browser>: the render trial failed; name what the error gives.
render_failure() {
  local log=$1 browser=$2 libs packages text
  libs=$(grep -oE 'lib[A-Za-z0-9_+.-]*\.so[.0-9]*: cannot open shared object file' "$log" | sed 's/: cannot.*//' | sort -u)
  [[ -n $browser ]] || browser=$(sed -n 's/^\([^ ]*\): error while loading shared libraries.*/\1/p' "$log" | head -n 1)
  # The loader stops at the first missing library; ldd lists them all, as nix-ld would load them.
  if [[ -n $libs && -x $browser ]] && command -v ldd >/dev/null 2>&1; then
    libs=$(
      printf '%s\n' "$libs"
      LD_LIBRARY_PATH=${NIX_LD_LIBRARY_PATH:-} ldd "$browser" 2>/dev/null | awk '$2 == "=>" && $3 == "not" { print $1 }'
    )
    libs=$(grep . <<<"$libs" | sort -u)
  fi
  if [[ -n $libs ]]; then
    packages=$(while IFS= read -r lib; do library_package "$lib"; done <<<"$libs" | sort -u | paste -sd, - | sed 's/,/, /g')
    report manque "essai de rendu" "le Chrome headless de Remotion ne se lance pas, bibliothèques manquantes : $(paste -sd, - <<<"$libs" | sed 's/,/, /g') — correction : ajouter $packages à programs.nix-ld.libraries $NIXOS, puis relancer doctor.sh ; $PLAN_B."
  else
    text=$(grep -vE '^[[:space:]]+at ' "$log" | grep . | tail -n 3 | paste -sd' ' -)
    report manque "essai de rendu" "le rendu d'une image échoue (« ${text:0:300} ») — correction : lire l'erreur ; si le navigateur ne se lance pas, $PLAN_B."
  fi
}

check_render() {
  local browser="" id
  if ! command -v "$NPX" >/dev/null 2>&1; then
    report manque "essai de rendu" "npx introuvable ($NPX) — correction : installer Node.js, qui fournit npx, $NIXOS."
    return
  fi
  # Without its local install, npx would fetch Remotion from the network, at another version.
  if [[ ! -e $project/node_modules/.bin/remotion ]]; then
    report manque "essai de rendu" "dépendances non installées (node_modules/.bin/remotion absent) — correction : npm install dans $project."
    return
  fi
  if ! (cd "$project" && "$NPX" remotion browser ensure) >"$work/browser" 2>"$work/log"; then
    render_failure "$work/log" ""
    return
  fi
  browser=$(sed -n 's/^Has browser at //p' "$work/browser" | tail -n 1)
  if ! (cd "$project" && "$NPX" remotion compositions --quiet) >"$work/ids" 2>"$work/log"; then
    render_failure "$work/log" "$browser"
    return
  fi
  id=$(tr -s '[:space:]' '\n' <"$work/ids" | grep -m 1 .)
  if [[ -z $id ]]; then
    report manque "essai de rendu" "aucune composition dans src/Root.tsx — correction : recréer le projet avec /plugin-motion:new-video."
    return
  fi
  if (cd "$project" && "$NPX" remotion still "$id" "$work/essai.png" --frame=0) >"$work/log" 2>&1 && [[ -s $work/essai.png ]]; then
    report ok "essai de rendu" "image 0 de $id rendue"
  else
    render_failure "$work/log" "$browser"
  fi
}

check_whisper() {
  local bin
  for bin in whisper-cli whisper-cpp; do
    if command -v "$bin" >/dev/null 2>&1; then
      report ok whisper "$bin présent"
      return
    fi
  done
  report avertissement whisper "whisper-cli introuvable ; seul sync-voiceover en a besoin — correction : installer le paquet nixpkgs whisper-cpp $NIXOS."
}

check_node
check_tool ffmpeg "$FFMPEG" "preview.sh (planche contact) et à sync-voiceover"
check_tool ffprobe "$FFPROBE" "probe.sh"
check_versions
check_render
check_whisper

if ((failures == 0)); then
  printf 'diagnostic : prêt (%s)\n' "$(plural "$warnings" avertissement)"
  exit 0
fi
printf "diagnostic : %s en échec, %s ; rien n'a été modifié sur le système.\n" "$(plural "$failures" contrôle)" "$(plural "$warnings" avertissement)"
exit 1
