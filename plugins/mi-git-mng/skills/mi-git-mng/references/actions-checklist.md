# Checklist de observaciones

Revisar cada punto. Reportar **solo lo que aplica**, con archivo y línea, y marcarlo como **riesgo** o **mejora**. No listar lo que está bien.

## Riesgos

| Qué buscar | Por qué importa |
|---|---|
| `pull_request_target` o `workflow_run` que hacen checkout del código del PR | Código de un fork corre con secretos y permisos de escritura |
| `${{ github.event.* }}` (título, body, nombre de rama, comentario) dentro de `run:` | Inyección de comandos: el texto lo controla quien abre el PR. Pasarlo por `env:` |
| Secretos, tokens, contraseñas, IDs de cuenta o URLs internas **en claro** en el YAML | Quedan en el historial de git |
| Sin bloque `permissions` (o `write-all`) | El `GITHUB_TOKEN` hereda el permiso por defecto del repo, que puede ser escritura en todo |
| Runner **self-hosted** en un repo público o disparado por `pull_request` de forks | Código ajeno corre en una máquina propia |
| Deploy a producción sin `environment` con aprobación, o disparable por cualquiera con escritura | Nada impide un deploy accidental |
| Secretos impresos con `echo`, o pasados en la línea de comandos a herramientas que los loguean | Aparecen en los logs de Actions |
| Credenciales de nube estáticas (`AWS_ACCESS_KEY_ID` en secrets) en lugar de OIDC | Credenciales de larga vida que se pueden filtrar |
| `curl ... \| bash` o descarga de binarios sin verificar | Cadena de suministro |

## Mejoras

| Qué buscar | Sugerencia |
|---|---|
| Acciones de terceros fijadas por tag (`@v4`) en workflows de deploy | Fijar por SHA del commit |
| Deploy sin `concurrency` | Dos deploys simultáneos al mismo ambiente se pisan |
| Jobs sin `timeout-minutes` en runners propios | Un job colgado ocupa el runner indefinidamente |
| Build y test repetidos en varios workflows | Workflow reutilizable (`workflow_call`) o acción compuesta |
| Sin cache de dependencias (`actions/cache`, `cache:` en setup-*) | Builds más lentos |
| Filtros `paths` que dejan afuera archivos que afectan el build | Cambios que no disparan CI |
| Versiones de acciones con avisos de deprecación (p. ej. Node 16/20) | Actualizar antes de que dejen de funcionar |
| Nombres de job o workflow poco descriptivos | Se leen en la pestaña Actions y en los checks del PR |
