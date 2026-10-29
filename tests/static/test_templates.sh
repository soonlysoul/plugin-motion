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
