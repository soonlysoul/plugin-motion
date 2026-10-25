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

if [[ -f $PLUGIN_ROOT/templates/storyboard.md ]]; then
  block=$(sed -n '/^```json$/,/^```$/p' "$PLUGIN_ROOT/templates/storyboard.md" | sed '1d;$d')
  jq -e '.format == {width: 1920, height: 1080, fps: 30} and .voiceover == false and .scenes == []' <<<"$block" >/dev/null 2>&1 \
    && pass "storyboard.md : 1920×1080 à 30 i/s, sans voix off ni scène" \
    || fail "storyboard.md : 1920×1080 à 30 i/s, sans voix off ni scène" "${block:0:300}"
fi

finish
