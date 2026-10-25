#!/usr/bin/env bash
# scripts/doctor.sh with simulated binaries (MOTION_NPX, MOTION_NODE, MOTION_FFMPEG,
# MOTION_FFPROBE), a stub ldd and a PATH with or without Whisper: everything present, Remotion
# versions out of line, ffmpeg missing, a render trial failing on a named library, Whisper missing;
# then Node outside engines.node, dependencies not installed, and a folder that is not a project.
# No network, no Remotion, no browser.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_doctor
DOCTOR="$PLUGIN_ROOT/scripts/doctor.sh"

if [[ ! -f $DOCTOR ]]; then
  fail "scripts/doctor.sh présent" "absent"
  finish
  exit
fi
pass "scripts/doctor.sh présent"

work=$(mktemp -d)
plain_path=$(path_without whisper-cli whisper-cpp ldd)
trap 'rm -rf "$work" "$plain_path"' EXIT

# Simulated binaries. The npx stub logs its calls; STUB_RENDER=fail makes Remotion's headless
# Chrome stop on a missing library, as it does under nix-ld without nss, nspr and expat.
mkdir "$work/bin" "$work/tools" "$work/chrome"
cat >"$work/bin/node" <<'EOF'
#!/usr/bin/env bash
echo "v${STUB_NODE_VERSION:-22.23.2}"
EOF
cat >"$work/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
echo "ffmpeg version 8.1.2 Copyright (c) 2000-2026 the FFmpeg developers"
EOF
cat >"$work/bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
echo "ffprobe version 8.1.2 Copyright (c) 2007-2026 the FFmpeg developers"
EOF
cat >"$work/bin/npx" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
case "$1 $2" in
  "remotion browser") echo "Has browser at $STUB_CHROME" ;;
  "remotion compositions")
    if [[ ${STUB_RENDER:-ok} == fail ]]; then
      echo "Error: Failed to launch the browser process!" >&2
      echo "$STUB_CHROME: error while loading shared libraries: libnspr4.so: cannot open shared object file: No such file or directory" >&2
      exit 1
    fi
    echo "MyComp Deux" ;;
  "remotion still") printf 'PNG' >"$4" ;;
  *) echo "npx stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
EOF
# ldd as it answers on the headless Chrome under nix-ld without nss, nspr and expat.
cat >"$work/tools/ldd" <<'EOF'
#!/usr/bin/env bash
printf '\tlibdl.so.2 => /lib/libdl.so.2 (0x0)\n\tlibnspr4.so => not found\n\tlibnss3.so => not found\n\tlibnssutil3.so => not found\n\tlibexpat.so.1 => not found\n'
EOF
printf '#!/usr/bin/env bash\necho whisper-cli\n' >"$work/tools/whisper-cli"
printf '#!/usr/bin/env bash\n' >"$work/chrome/chrome-headless-shell"
chmod +x "$work"/bin/* "$work"/tools/* "$work/chrome/chrome-headless-shell"

# make_project <dir> [version of @remotion/cli]: a project as create-video --blank leaves it,
# dependencies installed.
make_project() {
  mkdir -p "$1/src" "$1/node_modules/.bin"
  : >"$1/node_modules/.bin/remotion"
  jq -n --arg cli "${2:-4.0.538}" '{name: "essai", engines: {node: "^20.19.0 || ^22.13.0 || >=24"}, private: true,
    dependencies: {"@remotion/cli": $cli, react: "19.2.3", "react-dom": "19.2.3", remotion: "4.0.538"},
    devDependencies: {"@remotion/eslint-config-flat": "4.0.538", typescript: "5.9.3"}}' >"$1/package.json"
}

# run_doctor <project> [env assignments...]: sets DOC_STATUS, DOC_OUT (stdout) and DOC_ERR.
run_doctor() {
  local project=$1 out err
  shift
  out=$(mktemp) err=$(mktemp)
  : >"$work/npx.log"
  env PATH="$work/tools:$plain_path" MOTION_NPX="$work/bin/npx" MOTION_NODE="$work/bin/node" \
    MOTION_FFMPEG="$work/bin/ffmpeg" MOTION_FFPROBE="$work/bin/ffprobe" STUB_LOG="$work/npx.log" \
    STUB_CHROME="$work/chrome/chrome-headless-shell" "$@" "$BASH" "$DOCTOR" "$project" >"$out" 2>"$err"
  DOC_STATUS=$?
  DOC_OUT=$(<"$out") DOC_ERR=$(<"$err")
  rm -f "$out" "$err"
}

expect_exit() {
  [[ $DOC_STATUS == "$2" ]] && pass "$1" || fail "$1" "attendu exit $2, obtenu $DOC_STATUS ; stdout : ${DOC_OUT:0:400} ; stderr : ${DOC_ERR:0:200}"
}

# expect_line <label> <regex...>: one line of the diagnostic matches every regex.
expect_line() {
  local label=$1 line regex
  shift
  while IFS= read -r line; do
    for regex in "$@"; do grep -qE -- "$regex" <<<"$line" || continue 2; done
    pass "$label"
    return
  done <<<"$DOC_OUT"
  fail "$label" "aucune ligne ne correspond à : $* ; sortie : ${DOC_OUT:0:600}"
}

tree_of() { find "$1" -printf '%P %y %s\n' | sort; }

echo "# tout présent"
make_project "$work/complet"
before=$(tree_of "$work/complet")
run_doctor "$work/complet"
expect_exit "tout présent : exit 0" 0
expect_line "node accepté par engines.node" '^ok +node : ' 'v22\.23\.2' '\^22\.13\.0'
expect_line "ffmpeg 8.1.2" '^ok +ffmpeg : ' '8\.1\.2'
expect_line "ffprobe 8.1.2" '^ok +ffprobe : ' '8\.1\.2'
expect_line "versions de Remotion alignées" '^ok +versions de Remotion : ' '4\.0\.538'
expect_line "essai de rendu sur la première composition" '^ok +essai de rendu : ' 'MyComp'
expect_line "whisper présent" '^ok +whisper : ' 'whisper-cli'
expect_line "diagnostic prêt" '^diagnostic : prêt'
grep -qE '^remotion still MyComp [^ ]+\.png --frame=0$' "$work/npx.log" \
  && pass "rend l'image 0 de MyComp" || fail "rend l'image 0 de MyComp" "$(cat "$work/npx.log")"
render_out=$(sed -n 's/^remotion still MyComp \([^ ]*\) .*/\1/p' "$work/npx.log")
[[ -n $render_out && $render_out != "$work/complet"/* ]] \
  && pass "l'image d'essai est rendue hors du projet" || fail "l'image d'essai est rendue hors du projet" "$render_out"
[[ $(tree_of "$work/complet") == "$before" ]] && pass "le projet est inchangé" || fail "le projet est inchangé"
grep -qE 'install|upgrade' "$work/npx.log" && fail "aucune installation lancée" "$(cat "$work/npx.log")" \
  || pass "aucune installation lancée"

echo "# versions de Remotion désalignées"
make_project "$work/desaligne" 4.0.530
run_doctor "$work/desaligne"
expect_exit "versions désalignées : exit 1" 1
expect_line "nomme les versions et la correction" '^manque +versions de Remotion : ' '@remotion/cli 4\.0\.530' 'remotion 4\.0\.538' 'npx remotion upgrade'
expect_line "diagnostic en échec" '^diagnostic : 1 contrôle en échec'

echo "# ffmpeg absent"
make_project "$work/sans-ffmpeg"
run_doctor "$work/sans-ffmpeg" MOTION_FFMPEG="$work/absent/ffmpeg"
expect_exit "ffmpeg absent : exit 1" 1
expect_line "ffmpeg manque, installation via plugin-nixos" '^manque +ffmpeg : ' 'paquet nixpkgs ffmpeg' '/plugin-nixos:modifie'
expect_line "ffprobe reste ok" '^ok +ffprobe : '

echo "# essai de rendu en échec, bibliothèque nommée"
make_project "$work/sans-nss"
run_doctor "$work/sans-nss" STUB_RENDER=fail
expect_exit "rendu en échec : exit 1" 1
expect_line "nomme la bibliothèque de l'erreur" '^manque +essai de rendu : ' 'libnspr4\.so'
expect_line "liste les autres bibliothèques manquantes" '^manque +essai de rendu : ' 'libnss3\.so' 'libnssutil3\.so' 'libexpat\.so\.1'
expect_line "propose les paquets dans programs.nix-ld.libraries" '^manque +essai de rendu : ' 'nspr' 'nss' 'expat' 'programs\.nix-ld\.libraries'
expect_line "propose le plan B du PRD" '^manque +essai de rendu : ' 'chromium' '--browser-executable'
grep -q '^remotion still' "$work/npx.log" && fail "aucun rendu après l'échec du navigateur" || pass "aucun rendu après l'échec du navigateur"
run_doctor "$work/sans-nss" STUB_RENDER=fail STUB_CHROME="$work/absent/chrome-headless-shell"
expect_line "sans binaire à inspecter, nomme la bibliothèque de l'erreur" '^manque +essai de rendu : ' 'libnspr4\.so' 'nspr'

echo "# Whisper absent"
make_project "$work/sans-whisper"
run_doctor "$work/sans-whisper" PATH="$plain_path"
expect_exit "Whisper absent : exit 0, un avertissement" 0
expect_line "avertit, avec l'installation via plugin-nixos" '^avertissement +whisper : ' 'whisper-cpp' '/plugin-nixos:modifie'
expect_line "diagnostic prêt malgré l'avertissement" '^diagnostic : prêt' '1 avertissement'

echo "# Node hors de engines.node"
make_project "$work/node"
for version in 20.19.0 22.13.0 24.0.0 25.1.3; do
  run_doctor "$work/node" STUB_NODE_VERSION=$version
  expect_line "node $version accepté" '^ok +node : ' "v${version//./\\.}"
done
for version in 18.20.4 20.18.9 21.7.0 22.12.0 23.11.1; do
  run_doctor "$work/node" STUB_NODE_VERSION=$version
  expect_line "node $version refusé" '^manque +node : ' "v${version//./\\.}" '/plugin-nixos:modifie'
done
expect_exit "node refusé : exit 1" 1

echo "# dépendances non installées"
make_project "$work/sans-modules"
rm -rf "$work/sans-modules/node_modules"
run_doctor "$work/sans-modules"
expect_exit "dépendances absentes : exit 1" 1
expect_line "demande npm install" '^manque +essai de rendu : ' 'npm install'
[[ ! -s $work/npx.log ]] && pass "npx n'est pas lancé" || fail "npx n'est pas lancé" "$(cat "$work/npx.log")"

echo "# refus"
mkdir "$work/vide"
run_doctor "$work/vide"
[[ $DOC_STATUS == 2 && $DOC_ERR == *package.json* ]] && pass "refuse un dossier sans package.json (exit 2)" \
  || fail "refuse un dossier sans package.json (exit 2)" "exit $DOC_STATUS ; stderr : $DOC_ERR"
run_doctor ""
[[ $DOC_STATUS == 2 && -n $DOC_ERR ]] && pass "refuse un appel sans projet (exit 2)" \
  || fail "refuse un appel sans projet (exit 2)" "exit $DOC_STATUS ; stderr : $DOC_ERR"

finish
