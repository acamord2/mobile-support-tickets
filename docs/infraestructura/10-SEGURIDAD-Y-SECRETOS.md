# Seguridad y secretos

## Configuración externa

| Variable/clave | Uso |
|---|---|
| API_USER_SECRETS_FILE | Archivo externo compatible API base |
| API_SEPARACION_SECRETS_FILE | Archivo activo dos conexiones |
| POSTGRES_PASSWORD_FILE | Inicialización; no rota credencial de volumen existente |
| POSTGRES_DB/POSTGRES_USER | tickets_db/tickets_practica, nombres no secretos |
| GRAFANA_ADMIN_PASSWORD_FILE | Archivo externo Grafana |
| POSTGRES_MONITOR_PASSWORD_FILE | Archivo externo monitor_postgres |
| REPLICA_PGPASS_FILE | Passfile replicación |
| REPLICA_RESPALDO_OK | Evidencia externa de ensayo restauración |
| SUPERVISION_METRICAS_DIR | Solo métricas, no estado/logs completos |
| DOCKER_ROOT_DIR | Ruta efectiva Docker para observación |
| ConnectionStrings:Escritura/Lectura/DefaultConnection | Npgsql primario/standby/legado |
| Jwt:Key, SecretsApi:ClaveJwt | Firma JWT y selector |

[Plantillas](plantillas/README.md) con placeholders, nunca valores reales. Rutas configurables no son credenciales. No distribuir User Secrets, dumps, globales.sql, marcas privadas, passwords, llaves privadas o incident logs. Guardar archivos externos en ubicación protegida; no imprimirlos para diagnóstico.

Lectura efectiva: API1654 modo0400, replicación999:999 modo0400/0600, Grafana472 y exporters65534 mediante archivos protegidos y mounts RO. Comprobar recorrido de directorios y acceso dentro del contenedor. No chmod777. Read-only no concede permiso de lectura por sí mismo.

No contraseñas en CLI, historial, URLs compartidas, screenshots o SQL persistido. Para tareas autorizadas, archivo protegido/memoria y logging de sesión revisado, sin tracing shell. Hashes también sensibles.

## Seguridad Git

.gitignore excluye .env reales, UserSecrets, claves/certificados, artefactos, __pycache__, dumps/backups y estado local. Ignore no elimina secretos ya versionados: revisar índice e historial. SQL DATOS_PRUEBA/BD_COMPLETA preexistentes contienen hashes/contraseñas demo públicas; no son credenciales del despliegue ni se cargaron en esta fase. No reutilizarlos en producción.

Checklist de publicación:

1. Rama prueba_docker y origin https://github.com/acamord2/mobile-support-tickets.git.
2. Archivos explícitos, nunca add -A; diff funcional separado del ruido CRLF/LF.
3. Sin normalizar trabajo ajeno; índice LF para cambios funcionales conservando bytes del worktree.
4. Revisar staged, diff --cached --check, candidatos e historial; buscar indicadores y coincidencias con valores externos sin imprimirlos.
5. Validar Compose/scripts/reglas/diagramas/enlaces/pruebas seguras, sin tests reales de datos/Blackbox.
6. Sin conflictos, push exclusivo prueba_docker, no force ni main.

Ante secreto real, remoto dudoso, conflicto o autenticación fallida: detener publicación, no reescribir historial ni esconder el problema. Plantillas resuelven faltantes privados; no subir artefactos.

## Privilegios y red

Grupo Docker da control equivalente a root del host. Restricciones lógicas supervisor no son una barrera frente a administrador; corre econt y solo requiere root para instalar unidad. Socket Proxy restringe HTTP mediante HAProxy/red interna; mount socket:ro no restringe protocolo. cAdvisor tiene lectura privilegiada del host y exige revisar rutas sensibles.

PostgreSQL/monitoreo no publican puertos Docker. API mantiene5263 en todas interfaces WSL; no afirmar aislamiento LAN. SSH temporal y proxy Windows hacen bind loopback; verificar host key por canal local. No se cambia firewall, WSL/Engine global ni SSH general por documentación.

Development/HTTP es práctica local. TLS público, rotación, cuentas productivas, notificaciones externas, MinIO, backups programados y arranque Windows pendientes.
