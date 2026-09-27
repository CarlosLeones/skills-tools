# view_actions — análisis y documentación de GitHub Actions

Produce un informe que explica **cómo funciona el CI/CD** del repo a alguien que no leyó los YAML.
Es de **solo lectura**: no modifica workflows ni dispara ejecuciones.

## Argumentos

`/mi-git-mng view_actions [md|html|ambos] [carpeta-de-salida]`

- **Formato:** `ambos` por defecto. `md` se ve bien en GitHub, que renderiza Mermaid; `html` se abre en el navegador.
- **Carpeta:** por defecto, `docs/` del repo, con los archivos `github-actions.md` y `github-actions.html`.
- Si la persona indica otra ruta o formato en lenguaje natural, respetarla.

## Pasos

### 1. Inventario

```bash
bash "<ruta del skill>/scripts/actions-inventario.sh"
```

- **Sin workflows activos:** decirlo y terminar, sin generar archivos.
- **Carpetas `.github` fuera de la raíz:** avisar que sus workflows **no corren**.

### 2. Leer cada workflow completo

Leer todos los `.github/workflows/*.y*ml` y las acciones propias (`action.yml`). De cada uno extraer:

- **Disparadores:** eventos (`push`, `pull_request`, `workflow_dispatch`, `release`, `schedule`, `workflow_run`, `workflow_call`, `repository_dispatch`…), filtros de `branches`, `tags` y `paths`, e `inputs` de los disparos manuales.
- **Jobs:**
  - `needs` (el orden), condiciones `if`, `runs-on` (marcar los runners **self-hosted**), `environment`, `concurrency`, `timeout-minutes`, `strategy.matrix`.
  - **Pasos:** resumirlos por intención (checkout, setup, restore, build, test, publicar artefacto, deploy, notificar), sin copiarlos uno por uno.
- **Credenciales:** `permissions` (del workflow y de cada job), nombres de `secrets.*` y `vars.*` usados (**solo nombres**) y OIDC (`id-token: write`, `configure-aws-credentials`).
- **Integraciones externas:** nube (AWS, Azure), almacenamiento (S3), mensajería (Teams, Slack), gestión (ClickUp, Jira), Power Automate, webhooks.
- **Relaciones entre workflows:** `workflow_run`, `workflow_call`, artefactos que uno sube y otro baja, tags o releases que uno crea y otro escucha.

Si no está claro qué hace un script o una acción de terceros, decirlo en lugar de suponer. Los scripts que viven en el runner, fuera del repo, no se pueden ver: indicarlo.

### 3. Historial real (opcional)

Si el inventario dice que `gh` tiene sesión, sumar un resumen de las últimas ejecuciones por workflow (resultado y fecha):

```bash
gh run list --limit 30 --json workflowName,event,headBranch,conclusion,createdAt
```

Sin sesión, omitirlo y decir que el análisis se basa solo en los archivos. Si la persona quiere el historial, sugerir `/mi-git-mng activa`.

### 4. Escribir el informe (.md)

Estructura, en español y en lenguaje simple:

1. **`# CI/CD de <repo>`** y un **resumen** de 3 a 5 líneas: qué hace el pipeline de punta a punta.
2. **Inventario**, en una tabla: workflow, archivo, qué lo dispara y qué hace (una línea).
3. **Diagrama general** (Mermaid `flowchart LR`): eventos → workflows → jobs → destinos (ambientes o servicios externos). Seguir [actions-diagramas.md](actions-diagramas.md).
4. **Ciclo de vida de una versión**, si hay varios ambientes: del merge a producción.
5. **Flujos por escenario**, la parte más útil para una persona:
   - "Hago push", "Abro un PR", "Mergeo a `main`", "Creo un tag o release", "Lo disparo a mano", "Corre programado".
   - Solo los escenarios que existan, cada uno con la secuencia de lo que ocurre.
   - Si un escenario esperable **no dispara nada** (por ejemplo, no hay CI al abrir un PR), decirlo.
6. **Detalle por workflow:** jobs, orden, runner, environment, secretos por nombre e integraciones. Agregar un diagrama por workflow **solo si tiene 3 o más jobs o dependencias no triviales**.
7. **Ambientes y despliegues:** qué va a cada ambiente y con qué control (environment con reviewers, restricción de usuarios, etc.).
8. **Observaciones:** riesgos y mejoras según [actions-checklist.md](actions-checklist.md).
   - Cada una con archivo y línea, marcada como **riesgo** o **mejora**, y con "qué hacer".
   - No inventar problemas: lo que está bien no se lista.
9. **Historial**, si se hizo el paso 3.
10. Pie: commit analizado (`git rev-parse --short HEAD`) y fecha.

**Reglas de contenido:**
- **Nunca** copiar valores de secretos, tokens, firmas de URLs (`sig=`), IDs de cuenta ni URLs internas que aparezcan en claro. Mencionarlos como "valor en claro en `<archivo>:<línea>`" y listarlo como riesgo.
- Si un workflow es simple (1 job, sin dependencias), no forzar un diagrama propio: basta el general.

### 5. Generar el HTML (si corresponde)

```bash
node "<ruta del skill>/scripts/md2html.js" docs/github-actions.md docs/github-actions.html
```

El HTML carga `marked` y `mermaid` (versiones fijas) desde `cdn.jsdelivr.net` y usa tema claro u oscuro según el sistema. Sin `node`, entregar solo el `.md` y avisarlo.

### 6. Verificar y entregar

- **Revisar los bloques Mermaid:** ids simples, y textos con caracteres especiales entre comillas.
- **Confirmar que no se copió ningún valor sensible:** buscar `sig=`, `token`, `key` y `password` en los archivos generados.
- **Si hay navegador disponible:** servir la carpeta por HTTP local (un `file://` no ejecuta scripts en el panel), abrir el HTML y confirmar que cada diagrama tiene su SVG, sin "Syntax error".
- **Resumen en el chat:** el flujo principal en pocas líneas y las observaciones más importantes, con enlaces a los archivos.
- **No** hacer commit de los archivos: preguntar si los quiere versionar.
