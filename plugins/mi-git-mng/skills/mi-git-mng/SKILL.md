---
name: mi-git-mng
description: Mi Git Manager (MiGitMng). (1) Activa, desactiva o muestra el estado del acceso de GitHub CLI (gh) para el agente, por repo (por defecto) o global. (2) view_actions — analiza los GitHub Actions del repo, explica su flujo con diagramas Mermaid y genera documentación .md/.html. Usar cuando la persona diga "activa gh", "desactiva gh", "estado de gh", "¿tengo gh activo?", "view_actions", "analiza/documenta las actions", "explícame los workflows", "cómo es el CI/CD de este repo", o invoque /mi-git-mng.
---

# Mi Git Manager (mi-git-mng)

Herramientas para trabajar con git y GitHub desde el agente:

- **Acceso a `gh`:** controla **dónde** puede usar el agente la GitHub CLI (crear PRs, ver el CI, etc.). No cambia cómo funciona `git`: fetch y push siguen con la credencial habitual.
- **`view_actions`:** analiza y documenta el CI/CD (GitHub Actions) del repo.

## Acciones

`/mi-git-mng <acción> [opciones]`

| Acción | Sinónimos | Qué hace | Opciones |
|---|---|---|---|
| `estado` (por defecto) | status, ¿está activo? | Muestra dónde está activo `gh` y con qué cuenta | `repo` \| `global` |
| `activa` | activar, on, habilita | Habilita `gh` para el agente | `repo` (por defecto) \| `global` |
| `desactiva` | desactivar, off, quita | Quita el acceso de `gh` | `repo` (por defecto) \| `global` |
| `view_actions` | ver actions, analiza/documenta las actions, CI/CD | Informe del flujo de GitHub Actions, con diagramas | `md` \| `html` \| `ambos` (por defecto), y una carpeta (por defecto `docs/`) |

**Alcance de `activa`, `desactiva` y `estado`:**
- `repo` (por defecto): solo el repo actual. Cada worktree lleva su propio `settings.local.json`.
- `global`: todas las sesiones, con el login normal de `gh`. Se usa cuando la persona dice "global", "en todos lados" o "para todo".

---

## Acceso a gh (`estado`, `activa`, `desactiva`)

Todo lo mecánico lo hace el script. Ejecutarlo con Bash desde el directorio del repo:

```bash
bash "<ruta de este skill>/scripts/ghctl.sh" <estado|activa|desactiva> [repo|global]
```

Después, resumirle el resultado a la persona en lenguaje simple.

### activa
1. Correr el script con `activa`. Prepara el directorio de `gh` del repo, escribe `GH_CONFIG_DIR` en `.claude/settings.local.json` y lo excluye de git.
2. **El login lo hace la persona, nunca el agente.** Mostrarle el comando que imprime el script (PowerShell o Bash) y pedirle que lo corra en **su** terminal y autorice en el navegador. El login es la barrera humana: el agente no se da acceso a sí mismo.
3. Cuando la persona avise que terminó, correr `estado` y confirmar la cuenta.
4. Recordarle que se aplica en la **próxima sesión** de Claude abierta en ese repo.

### desactiva
1. Correr el script con `desactiva`. Cierra la sesión de `gh` de ese alcance, borra el directorio del repo y quita `GH_CONFIG_DIR`.
2. Verificar con `estado`.
3. Explicar cómo invalidar el token también en GitHub: Settings → Applications → Authorized OAuth Apps → GitHub CLI. Advertir que revocarlo cierra **todas** las sesiones de `gh` de la cuenta.

### estado
Correr el script con `estado` y resumir: si está activo en el repo, si está activo global y con qué cuenta.

---

## view_actions

Seguir el procedimiento completo de [references/view-actions.md](references/view-actions.md): inventario, lectura de los workflows, historial opcional, informe con diagramas, HTML y verificación.

Recursos que usa:
- `scripts/actions-inventario.sh`: lista los workflows, las acciones propias, las carpetas `.github` que no corren y si `gh` tiene sesión.
- `scripts/md2html.js` + `assets/actions-template.html`: convierten el informe `.md` en un `.html` con los diagramas.
- `references/actions-diagramas.md`: convenciones de Mermaid.
- `references/actions-checklist.md`: riesgos y mejoras a revisar.

Es de solo lectura: no toca los workflows ni hace commit de los informes.

---

## Reglas

- **Nunca** mostrar, copiar ni pedir tokens. No usar `gh auth token` ni `git credential`, ni leer `hosts.yml`.
- **Nunca** correr `gh auth login` en nombre de la persona.
- **Nunca** anteponer `GH_CONFIG_DIR=...` a comandos para usar la sesión de otro repo. Solo lo usa el script, y solo para el repo actual.
- **No** ejecutar `gh auth setup-git`: git debe seguir con su credencial actual.
- Si `gh` no está instalado, el script lo avisa. Ofrecer el comando de instalación; no instalar sin confirmación.
- En modo repo, el token queda en `~/.config/gh-repos/<owner>__<repo>/hosts.yml`, fuera del repo. Es texto plano en el disco del usuario, como `~/.aws/credentials`. Mencionarlo si la persona pregunta por seguridad.
- En `view_actions`, **nunca** copiar valores sensibles que aparezcan en los workflows (secretos, firmas de URL, IDs de cuenta): solo referenciar archivo y línea.
