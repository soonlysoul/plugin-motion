#!/usr/bin/env bash
# Soon's working folder: ./promo already holds the material of the video, and is not a Remotion
# project.
set -euo pipefail
mkdir -p promo
cat >promo/notes.md <<'EOF'
# Lancement de Notio

Vidéo de 20 secondes, ton dynamique. Montrer le logo à la fin.
EOF
cat >promo/logo.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240"><rect width="240" height="240" rx="48" fill="#ffcc00"/><text x="120" y="150" font-size="96" text-anchor="middle">N</text></svg>
EOF
