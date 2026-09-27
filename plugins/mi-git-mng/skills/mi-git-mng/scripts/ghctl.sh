#!/usr/bin/env bash
# ghctl.sh — activa, desactiva y muestra el acceso de GitHub CLI (gh) por repo o global.
#
# Uso:
#   ghctl.sh estado    [repo|global]
#   ghctl.sh activa    [repo|global]   # prepara todo; el login lo hace la persona
#   ghctl.sh desactiva [repo|global]
#
# Modo repo (por defecto):
#   - gh usa un directorio de configuracion propio del repo: ~/.config/gh-repos/<owner>__<repo>
#     (compartido por los worktrees del mismo remoto).
#   - El token se guarda en ese directorio (--insecure-storage) y no en el almacen del sistema,
#     porque el almacen es por usuario de GitHub: con el, cerrar la sesion de un repo la
#     cerraria en todos.
#   - La sesion de Claude del repo lo encuentra por GH_CONFIG_DIR en .claude/settings.local.json,
#     que se excluye de git con .git/info/exclude.
# Modo global: el login normal de gh (directorio por defecto y almacen del sistema).
#
# Nunca imprime tokens.

set -euo pipefail

ACTION="${1:-estado}"
SCOPE="${2:-repo}"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "$*"; }

case "$ACTION" in
  estado|status) ACTION=estado ;;
  activa|activar|on|enable) ACTION=activa ;;
  desactiva|desactivar|off|disable) ACTION=desactiva ;;
  *) die "accion desconocida '$ACTION' (usa: estado | activa | desactiva)" ;;
esac
case "$SCOPE" in
  repo|global) ;;
  *) die "alcance desconocido '$SCOPE' (usa: repo | global)" ;;
esac

# --- gh -----------------------------------------------------------------------------------
GH="$(command -v gh 2>/dev/null || true)"
if [ -z "$GH" ]; then
  for c in "/c/Program Files/GitHub CLI/gh.exe" "/usr/local/bin/gh" "/opt/homebrew/bin/gh"; do
    [ -x "$c" ] && GH="$c" && break
  done
fi
[ -n "$GH" ] || die "gh no esta instalado. Windows: winget install --id GitHub.cli -e | macOS: brew install gh"

# Ruta en formato nativo (Windows necesita C:\... para gh.exe y para settings.json).
native_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

# gh sin variables heredadas de la sesion (GH_TOKEN o GH_CONFIG_DIR de otro repo).
gh_clean() { env -u GH_TOKEN -u GITHUB_TOKEN -u GH_CONFIG_DIR "$GH" "$@"; }
gh_dir()   { local d="$1"; shift; env -u GH_TOKEN -u GITHUB_TOKEN GH_CONFIG_DIR="$(native_path "$d")" "$GH" "$@"; }

# --- JSON (node o python) -----------------------------------------------------------------
# json_env <archivo> set <clave> <valor> | del <clave> | get <clave>
json_env() {
  local file="$1" op="$2" key="$3" val="${4:-}"
  if command -v node >/dev/null 2>&1; then
    FILE="$(native_path "$file")" OP="$op" KEY="$key" VAL="$val" node -e '
      const fs=require("fs"),f=process.env.FILE,op=process.env.OP,k=process.env.KEY;
      let j={}; if(fs.existsSync(f)){const t=fs.readFileSync(f,"utf8").replace(/^\uFEFF/,"").trim(); if(t) j=JSON.parse(t);}
      if(op==="get"){ process.stdout.write((j.env&&j.env[k])||""); process.exit(0); }
      j.env=j.env||{};
      if(op==="set") j.env[k]=process.env.VAL; else delete j.env[k];
      if(Object.keys(j.env).length===0) delete j.env;
      if(Object.keys(j).length===0 && op==="del"){ if(fs.existsSync(f)) fs.unlinkSync(f); process.exit(0); }
      fs.writeFileSync(f, JSON.stringify(j,null,2)+"\n");'
  elif command -v python3 >/dev/null 2>&1; then
    FILE="$file" OP="$op" KEY="$key" VAL="$val" python3 - <<'PY'
import json, os
f, op, k = os.environ["FILE"], os.environ["OP"], os.environ["KEY"]
j = {}
if os.path.exists(f):
    t = open(f, encoding="utf-8-sig").read().strip()
    if t: j = json.loads(t)
if op == "get":
    print((j.get("env") or {}).get(k, ""), end=""); raise SystemExit
j.setdefault("env", {})
if op == "set": j["env"][k] = os.environ["VAL"]
else: j["env"].pop(k, None)
if not j["env"]: j.pop("env")
if not j and op == "del":
    if os.path.exists(f): os.remove(f)
    raise SystemExit
open(f, "w", encoding="utf-8").write(json.dumps(j, indent=2) + "\n")
PY
  else
    die "se necesita node o python3 para editar .claude/settings.local.json"
  fi
}

# --- Contexto del repo --------------------------------------------------------------------
repo_context() {
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "no estoy dentro de un repo git (usa 'global' o entra al repo)"
  local url slug
  url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  slug="$(printf '%s' "$url" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
  [ -n "$slug" ] && [ "$slug" != "$url" ] || slug="$(basename "$ROOT")"
  SLUG="$slug"
  CFG_DIR="$HOME/.config/gh-repos/${slug//\//__}"
  SETTINGS="$ROOT/.claude/settings.local.json"
  EXCLUDE="$(git -C "$ROOT" rev-parse --git-path info/exclude)"
  case "$EXCLUDE" in /*|?:*) ;; *) EXCLUDE="$ROOT/$EXCLUDE" ;; esac
}

ensure_excluded() {
  if git -C "$ROOT" check-ignore -q .claude/settings.local.json; then
    info "  - .claude/settings.local.json ya esta ignorado por git"
  else
    mkdir -p "$(dirname "$EXCLUDE")"
    printf '\n# mi-git-mng: configuracion local de Claude (puede apuntar a credenciales)\n.claude/settings.local.json\n' >> "$EXCLUDE"
    info "  - .claude/settings.local.json agregado a .git/info/exclude (ignore solo local)"
  fi
}

login_hint() {
  local d="$1" nd; nd="$(native_path "$d")"
  echo
  echo "Falta el login (lo haces tu, en tu terminal; se abre el navegador para autorizar):"
  echo
  echo "  PowerShell:"
  echo "    \$env:GH_CONFIG_DIR=\"$nd\"; gh auth login --hostname github.com --git-protocol https --web --insecure-storage; Remove-Item Env:GH_CONFIG_DIR"
  echo
  echo "  Git Bash / macOS / Linux:"
  echo "    GH_CONFIG_DIR=\"$nd\" gh auth login --hostname github.com --git-protocol https --web --insecure-storage"
}

# --- Acciones -----------------------------------------------------------------------------
estado_repo() {
  repo_context
  local cur; cur="$(json_env "$SETTINGS" get GH_CONFIG_DIR 2>/dev/null || true)"
  info "Repo: $SLUG ($ROOT)"
  info "  Directorio gh del repo: $(native_path "$CFG_DIR")"
  if [ -n "$cur" ]; then info "  settings.local.json: GH_CONFIG_DIR configurado -> $cur"; else info "  settings.local.json: sin GH_CONFIG_DIR (gh no se activa en este repo)"; fi
  if [ -f "$CFG_DIR/hosts.yml" ] && gh_dir "$CFG_DIR" auth status --hostname github.com >/dev/null 2>&1; then
    info "  Sesion gh del repo: ACTIVA"
    gh_dir "$CFG_DIR" auth status --hostname github.com 2>&1 | sed 's/^/    /'
  else
    info "  Sesion gh del repo: sin sesion"
  fi
  if [ -n "$cur" ] && [ -f "$CFG_DIR/hosts.yml" ]; then
    info "  => ACTIVO en sesiones nuevas de Claude en este repo"
  else
    info "  => INACTIVO en este repo"
  fi
}

estado_global() {
  info "Global (directorio por defecto de gh):"
  if gh_clean auth status --hostname github.com >/dev/null 2>&1; then
    info "  ACTIVO"; gh_clean auth status --hostname github.com 2>&1 | sed 's/^/    /'
  else
    info "  INACTIVO (sin sesion)"
  fi
  if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then info "  Aviso: esta sesion tiene GH_TOKEN/GITHUB_TOKEN definido; gh lo usa antes que cualquier login."; fi
  if [ -n "${GH_CONFIG_DIR:-}" ]; then info "  Esta sesion usa GH_CONFIG_DIR=$GH_CONFIG_DIR"; fi
}

case "$ACTION:$SCOPE" in
  estado:repo)
    estado_repo; echo; estado_global ;;
  estado:global)
    estado_global ;;

  activa:repo)
    repo_context
    info "Activando gh para $SLUG"
    mkdir -p "$CFG_DIR"; chmod 700 "$CFG_DIR" 2>/dev/null || true
    info "  - Directorio: $(native_path "$CFG_DIR")"
    mkdir -p "$ROOT/.claude"
    ensure_excluded
    json_env "$SETTINGS" set GH_CONFIG_DIR "$(native_path "$CFG_DIR")"
    info "  - GH_CONFIG_DIR escrito en .claude/settings.local.json"
    if [ -f "$CFG_DIR/hosts.yml" ] && gh_dir "$CFG_DIR" auth status --hostname github.com >/dev/null 2>&1; then
      info "  - Ya hay sesion en ese directorio; no hace falta login."
    else
      login_hint "$CFG_DIR"
    fi
    echo
    info "Se aplica en la PROXIMA sesion de Claude abierta en este repo (las variables se leen al iniciar)."
    ;;

  activa:global)
    if gh_clean auth status --hostname github.com >/dev/null 2>&1; then
      info "gh global ya tiene sesion:"; gh_clean auth status --hostname github.com 2>&1 | sed 's/^/  /'
    else
      echo "Falta el login global (en tu terminal; se abre el navegador):"
      echo
      echo "  gh auth login --hostname github.com --git-protocol https --web"
      echo
      echo "No ejecutes 'gh auth setup-git': git seguiria con su credencial actual."
    fi
    ;;

  desactiva:repo)
    repo_context
    info "Desactivando gh para $SLUG"
    if [ -f "$CFG_DIR/hosts.yml" ]; then
      gh_dir "$CFG_DIR" auth logout --hostname github.com >/dev/null 2>&1 || true
      info "  - Sesion cerrada en $(native_path "$CFG_DIR")"
    fi
    rm -rf "$CFG_DIR"
    info "  - Directorio del repo borrado"
    if [ -f "$SETTINGS" ]; then
      json_env "$SETTINGS" del GH_CONFIG_DIR
      info "  - GH_CONFIG_DIR quitado de .claude/settings.local.json"
    fi
    echo
    info "La sesion de Claude actual puede conservar la variable hasta cerrarla; ya no hay token que usar."
    info "Para invalidar el token tambien en GitHub: Settings > Applications > Authorized OAuth Apps > GitHub CLI > Revoke"
    info "(revocar cierra TODAS las sesiones de gh de tu cuenta, tambien las de otros repos)."
    ;;

  desactiva:global)
    if gh_clean auth status --hostname github.com >/dev/null 2>&1; then
      gh_clean auth logout --hostname github.com >/dev/null 2>&1 || true
      info "Sesion global de gh cerrada."
    else
      info "gh global ya estaba sin sesion."
    fi
    info "Los repos activados por separado (modo repo) siguen activos; revisalos con 'estado'."
    ;;
esac
