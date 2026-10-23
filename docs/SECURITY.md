# Sécurité — plugin-motion

- Aucun secret dans le dépôt : une variable d'environnement de l'utilisateur s'écrit `${VAR}`.
- Un hook d'un plugin installé pour le compte s'applique à toutes les sessions : chaque hook reste inerte hors de son contexte.
- Aucune installation impérative (`npm install`, `pip install`, `bun install`) dans ce que le plugin exécute.
