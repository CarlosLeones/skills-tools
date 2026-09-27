#!/usr/bin/env bash
# inventario.sh — lista lo que hay de GitHub Actions en el repo actual (solo lectura).
#
# Uso: inventario.sh [ruta-del-repo]
#
# Imprime:
#   - workflows activos (.github/workflows/*.yml|yaml en la raiz)
#   - acciones propias (action.yml / action.yaml)
#   - dependabot
#   - carpetas .github fuera de la raiz (GitHub las ignora: sus workflows NO corren)
#   - si gh tiene sesion (para sumar historial real de ejecuciones)

set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

echo "Repo: $ROOT"
remote="$(git remote get-url origin 2>/dev/null || true)"
[ -n "$remote" ] && echo "Remoto: $remote"
echo

list() { find . -path ./node_modules -prune -o -path ./.git -prune -o "$@" -print 2>/dev/null | sed 's#^\./##' | sort; }

echo "## Workflows activos (.github/workflows en la raiz)"
wf="$(ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null || true)"
if [ -z "$wf" ]; then
  echo "(ninguno)"
else
  for f in $wf; do
    printf -- "- %s (%s lineas)\n" "$f" "$(wc -l < "$f" | tr -d ' ')"
  done
fi
echo

echo "## Acciones propias (action.yml)"
acts="$(list \( -name action.yml -o -name action.yaml \) -type f)"
[ -n "$acts" ] && printf -- "- %s\n" $acts || echo "(ninguna)"
echo

echo "## Dependabot"
[ -f .github/dependabot.yml ] || [ -f .github/dependabot.yaml ] && echo "- .github/dependabot.y*ml" || echo "(no configurado)"
echo

echo "## Carpetas .github fuera de la raiz (GitHub NO ejecuta sus workflows)"
nested="$(list -type d -name .github | grep -v '^\.github$' || true)"
if [ -n "$nested" ]; then
  for d in $nested; do
    n="$(ls "$d"/workflows/*.y*ml 2>/dev/null | wc -l | tr -d ' ')"
    printf -- "- %s (%s workflows)\n" "$d" "$n"
  done
else
  echo "(ninguna)"
fi
echo

echo "## GitHub CLI"
GH="$(command -v gh 2>/dev/null || true)"
[ -z "$GH" ] && [ -x "/c/Program Files/GitHub CLI/gh.exe" ] && GH="/c/Program Files/GitHub CLI/gh.exe"
if [ -z "$GH" ]; then
  echo "gh: no instalado (el analisis se hace solo con los archivos)"
elif "$GH" auth status --hostname github.com >/dev/null 2>&1; then
  echo "gh: con sesion (se puede sumar historial de ejecuciones con 'gh run list')"
else
  echo "gh: sin sesion (el analisis se hace solo con los archivos)"
fi
