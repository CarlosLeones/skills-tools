# skills-tools

Herramientas personales para agentes de código. El repo es un **marketplace de plugins de Claude Code**; los skills siguen el formato estándar `SKILL.md`, así que otros agentes compatibles también pueden usarlos.

## Plugins

| Plugin | Qué hace |
|---|---|
| [`mi-git-mng`](plugins/mi-git-mng/skills/mi-git-mng/SKILL.md) | **Mi Git Manager.** Activa, desactiva y muestra el acceso de GitHub CLI (`gh`) para el agente, por repo (por defecto) o global. Con `view_actions`, analiza y documenta los GitHub Actions del repo con diagramas |

## Instalar en Claude Code

Desde GitHub (en cualquier laptop):

```bash
claude plugin marketplace add CarlosLeones/skills-tools
claude plugin install mi-git-mng@leones-tools
```

Desde una copia local del repo:

```bash
claude plugin marketplace add /ruta/a/skills-tools
claude plugin install mi-git-mng@leones-tools
```

Se carga en la **siguiente sesión**. Para recibir cambios: `claude plugin marketplace update leones-tools`.

Si el repo es privado, la máquina necesita acceso de lectura a GitHub (la credencial normal de git sirve).

## Instalar en otros agentes

Copiar la carpeta `plugins/mi-git-mng/skills/mi-git-mng/` (con su `scripts/`) a la carpeta de skills del agente. Por ejemplo, para Claude Code sin plugins: `~/.claude/skills/mi-git-mng/`.

## Uso de mi-git-mng

```
/mi-git-mng estado            # ¿dónde está activo gh?
/mi-git-mng activa            # en este repo
/mi-git-mng activa global     # en todas las sesiones
/mi-git-mng desactiva         # en este repo
/mi-git-mng desactiva global
/mi-git-mng view_actions      # informe del CI/CD en docs/ (.md + .html)
/mi-git-mng view_actions md   # solo Markdown
```

También funciona en lenguaje natural: "activa gh en este repo", "desactiva gh", "documenta las actions de este repo".

### view_actions

Lee los workflows de `.github/workflows/` y genera `docs/github-actions.md` y `docs/github-actions.html` con:
- resumen del pipeline;
- tabla de workflows;
- diagrama general (eventos → workflows → jobs → ambientes y servicios);
- flujos por escenario ("mergeo a main", "promuevo a PROD"…);
- ambientes y cómo se protege cada uno;
- riesgos y mejoras, con archivo y línea.

Es de solo lectura, nunca copia valores sensibles y no hace commit de los informes. Si `gh` está activo, suma el historial de ejecuciones.

### Cómo funciona

- **Modo repo:**
  - `gh` usa un directorio de configuración propio, `~/.config/gh-repos/<owner>__<repo>`.
  - La sesión del agente lo encuentra por `GH_CONFIG_DIR`, escrito en `.claude/settings.local.json` del repo. Ese archivo se excluye de git con `.git/info/exclude`.
  - El token queda en ese directorio (`--insecure-storage`), fuera del repo. Así cada repo tiene su propia sesión y desactivar uno no afecta a los demás.
- **Modo global:** el login normal de `gh`.
- **El login siempre lo hace la persona** en su terminal, autorizando en el navegador. El agente prepara todo y verifica, pero no se da acceso a sí mismo.
- `git` no cambia: fetch y push siguen con la credencial habitual.

### Límites

- **La separación por repo es de comodidad, no un aislamiento fuerte.** Un proceso del mismo usuario podría apuntar `GH_CONFIG_DIR` al directorio de otro repo. Combinarlo con reglas de permisos del agente (`ask` para `gh pr create`, `gh pr merge`, `gh api`, `gh workflow run`).
- **El login por web da un token amplio**, válido para todos los repos de la cuenta. El skill controla **dónde** se usa `gh`, no **qué** puede hacer. Para limitar lo que puede hacer, usar tokens fine-grained.

### Requisitos

- `gh`
- `git`
- `bash` (en Windows, el de Git for Windows)
- `node` o `python3`

## Agregar un skill

1. Crear el plugin, con su manifiesto y su skill:

   ```
   plugins/<nombre>/
     .claude-plugin/plugin.json      ← name, version, description, author, license
     skills/<nombre>/SKILL.md        ← frontmatter name + description (cuándo usarlo)
     skills/<nombre>/scripts/        ← opcional: pasos mecánicos
     skills/<nombre>/references/     ← opcional: detalle que se lee solo si hace falta
   ```

   Si encaja como una acción de un plugin existente, agregarla ahí (como `view_actions` en `mi-git-mng`) en vez de crear otro.
2. Registrarlo en `.claude-plugin/marketplace.json`, en `plugins`.
3. Validar:

   ```bash
   claude plugin validate .
   claude plugin validate plugins/<nombre>
   ```

4. Subir la `version` del plugin en `plugin.json` y en `marketplace.json` en cada cambio, para que se detecte la actualización.

**Reglas del repo (es público):**
- Nada de secretos, tokens, correos, rutas personales ni información de empresas o clientes. Lo específico de un trabajo va en un marketplace privado aparte.
- Scripts cortos y legibles: quien instala un plugin ejecuta su código.
- Los `.sh` se guardan con finales LF (`.gitattributes`), para que funcionen en macOS y Linux.

## Licencia

[MIT](LICENSE)
