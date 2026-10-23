# Dépannage — plugin-motion

| Symptôme | Cause probable | Que faire |
| --- | --- | --- |
| Le plugin n'apparaît pas | Session lancée sans `--plugin-dir`, ou plugin non installé | `claude --plugin-dir .` depuis la racine du clone ; `claude plugin list` |
| `bash tests/run-all.sh` sort en 2 | `jq` ou `claude` absent du PATH | Installer l'outil manquant par la configuration du poste |
