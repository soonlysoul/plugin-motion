#!/usr/bin/env bash
# templates/: theme.ts, timing.ts and storyboard.md, byte for byte the files that the eval cases
# lay as a project new-video left (evals/storyboard/storyboard-brief-notes/setup.sh), and the
# leading JSON block of storyboard.md at the default format of the PRD.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_templates
SETUP="$PLUGIN_ROOT/evals/storyboard/storyboard-brief-notes/setup.sh"

if [[ ! -f $SETUP ]]; then
  fail "setup.sh du cas storyboard-brief-notes présent" "absent : $SETUP"
  finish
  exit
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(cd "$work" && "$BASH" "$SETUP") || fail "setup.sh s'exécute" "$SETUP"

for pair in theme.ts:src/theme.ts timing.ts:src/timing.ts storyboard.md:storyboard.md; do
  template=templates/${pair%%:*} laid=${pair#*:}
  if [[ ! -f $PLUGIN_ROOT/$template ]]; then
    fail "$template présent" "absent"
  elif cmp -s "$PLUGIN_ROOT/$template" "$work/$laid"; then
    pass "$template identique au $laid des cas d'évaluation"
  else
    fail "$template identique au $laid des cas d'évaluation" "$(diff "$PLUGIN_ROOT/$template" "$work/$laid" | head -n 6)"
  fi
done

# theme.ts loads its two fonts, title and body, with @remotion/google-fonts: a family only named
# is not loaded, and the headless Chrome renders a fallback font. One weight per role, in
# fontWeights, loaded and read by the scenes; the latin subset, enough for French.
theme=$PLUGIN_ROOT/templates/theme.ts
if [[ -f $theme ]]; then
  ok=1
  for role in title body; do
    Role=${role^}
    grep -qE "^import \{ loadFont as load${Role}Font \} from \"@remotion/google-fonts/[A-Z][A-Za-z0-9]*\";$" "$theme" || ok=0
    grep -qF "const $role = load${Role}Font(\"normal\", { weights: [fontWeights.$role], subsets: [\"latin\"] });" "$theme" || ok=0
  done
  ((ok)) && pass "theme.ts charge la police du titre et celle du texte par @remotion/google-fonts" \
    || fail "theme.ts charge la police du titre et celle du texte par @remotion/google-fonts" "$(grep -n -E 'import|load|fonts' "$theme")"
  grep -qE '^const fontWeights = \{ title: "[1-9]00", body: "[1-9]00" \} as const;$' "$theme" \
    && grep -qxF '  fontWeights,' "$theme" \
    && pass "theme.ts donne une graisse par rôle, chargée et lue par les scènes (theme.fontWeights)" \
    || fail "theme.ts donne une graisse par rôle, chargée et lue par les scènes (theme.fontWeights)" "$(grep -n -i 'weight' "$theme")"
  grep -qxF '  fonts: { title: title.fontFamily, body: body.fontFamily },' "$theme" \
    && pass "theme.fonts : les familles chargées, aucun nom écrit en dur" \
    || fail "theme.fonts : les familles chargées, aucun nom écrit en dur" "$(grep -n 'fonts:' "$theme")"
fi

# Every eval case that lays a theme lays it in that form, declares @remotion/google-fonts at the
# version of remotion, and its scenes take their weight from the theme with their family.
for setup in "$PLUGIN_ROOT"/evals/*/*/setup.sh; do
  grep -q '^export const theme = {$' "$setup" || continue
  case_name=$(basename "$(dirname "$setup")")
  if grep -qE '^  fonts: \{ title: "' "$setup"; then
    fail "$case_name : thème qui charge ses polices" "$(grep -n '^  fonts:' "$setup")"
    continue
  fi
  remotion=$(sed -n 's/^    "remotion": "\(.*\)"$/\1/p' "$setup")
  grep -qF "\"@remotion/google-fonts\": \"$remotion\"" "$setup" \
    && grep -qxF '  fonts: { title: title.fontFamily, body: body.fontFamily },' "$setup" \
    && pass "$case_name : thème qui charge ses polices, @remotion/google-fonts $remotion déclaré" \
    || fail "$case_name : thème qui charge ses polices, @remotion/google-fonts ${remotion:-?} déclaré" "$(grep -n -E 'google-fonts|^  fonts:' "$setup")"
  bare=$(grep -n 'fontFamily: theme\.fonts\.' "$setup" | grep -vE 'fontFamily: theme\.fonts\.(title|body), fontWeight: theme\.fontWeights\.\1\b' || true)
  [[ -z $bare ]] && pass "$case_name : chaque police d'une scène vient avec sa graisse du thème" \
    || fail "$case_name : chaque police d'une scène vient avec sa graisse du thème" "$(head -n 3 <<<"$bare")"
done

# timing-voiceover.ts: the src/timing.ts that sync-voiceover lays, byte for byte the one of the
# eval cases of a project synced to its voiceover, with the msToFrame of timing.ts unchanged.
SYNCED="$PLUGIN_ROOT/evals/sync-voiceover/sync-voiceover-captions/setup.sh"
template=$PLUGIN_ROOT/templates/timing-voiceover.ts
if [[ ! -f $template ]]; then
  fail "templates/timing-voiceover.ts présent" "absent"
else
  synced=$(mktemp -d)
  mkdir -p "$synced/config" "$synced/home" "$synced/proj"
  echo '{}' >"$synced/config/.claude.json"
  (cd "$synced/proj" && HOME="$synced/home" "$BASH" "$SYNCED") || fail "setup.sh du cas sync-voiceover-captions s'exécute" "$SYNCED"
  if cmp -s "$template" "$synced/proj/src/timing.ts"; then
    pass "templates/timing-voiceover.ts identique au src/timing.ts d'un projet synchronisé des cas d'évaluation"
  else
    fail "templates/timing-voiceover.ts identique au src/timing.ts d'un projet synchronisé des cas d'évaluation" \
      "$(diff "$template" "$synced/proj/src/timing.ts" | head -n 6)"
  fi
  rm -rf "$synced"
  line=$(grep '^export const msToFrame' "$PLUGIN_ROOT/templates/timing.ts")
  [[ -n $line ]] && grep -qxF "$line" "$template" \
    && pass "timing-voiceover.ts garde le msToFrame de timing.ts" \
    || fail "timing-voiceover.ts garde le msToFrame de timing.ts" "${line:-msToFrame absent de timing.ts}"
  grep -q '^import voiceover from "\.\./public/voiceover\.json";$' "$template" \
    && grep -q '^export const cueFrame = (scene: string, n: number): number' "$template" \
    && pass "timing-voiceover.ts lit public/voiceover.json et donne cueFrame(scene, n)" \
    || fail "timing-voiceover.ts lit public/voiceover.json et donne cueFrame(scene, n)"
fi

if [[ -f $PLUGIN_ROOT/templates/storyboard.md ]]; then
  block=$(sed -n '/^```json$/,/^```$/p' "$PLUGIN_ROOT/templates/storyboard.md" | sed '1d;$d')
  jq -e '.format == {width: 1920, height: 1080, fps: 30} and .voiceover == false and .scenes == []' <<<"$block" >/dev/null 2>&1 \
    && pass "storyboard.md : 1920×1080 à 30 i/s, sans voix off ni scène" \
    || fail "storyboard.md : 1920×1080 à 30 i/s, sans voix off ni scène" "${block:0:300}"
fi

finish
