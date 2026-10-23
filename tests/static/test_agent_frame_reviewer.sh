#!/usr/bin/env bash
# agents/frame-reviewer.md: present, strict header, tools Read, Glob, model sonnet.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../headers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../headers.sh"
SUITE=test_agent_frame_reviewer
FILE="$PLUGIN_ROOT/agents/frame-reviewer.md"

if [[ ! -f $FILE ]]; then
  fail "agents/frame-reviewer.md présent" "absent"
  finish
  exit
fi
pass "agents/frame-reviewer.md présent"
errors=$(agent_structure_errors "$FILE")
[[ -z $errors ]] && pass "en-tête strict" || fail "en-tête strict" "$errors"
read_frontmatter "$FILE"
tools=$(tr ',' '\n' <<<"${FM[tools]-}" | sed 's/ //g' | sort | paste -sd, -)
[[ $tools == "Glob,Read" ]] && pass "outils : Read, Glob" || fail "outils : Read, Glob" "$tools"
[[ ${FM[model]-} == sonnet ]] && pass "modèle : sonnet" || fail "modèle : sonnet" "${FM[model]-absent}"

finish
