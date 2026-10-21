# Fase 12.2: base de separación integrada en12.3

Estado actualizado: API desplegada con tickets-api:fase12-3, dos conexiones y continuidad temporal. El detalle operativo y las limitaciones están en [FASE12_3.md](FASE12_3.md). No repetir la creación de consultor_api. Esta guía conserva el diseño base de12.2.

## Conexiones externas

Conexion e IConexion conservan OpenConnectionAsync como primario para login, /me, Activo/Rol/PuedeOperar, healthcheck y todas las escrituras. ConnectionStrings:Escritura prevalece sobre el selector legado SecretsApi:ClaveConexionBaseDatos (DefaultConnection). Si falta Lectura se conserva temporalmente el funcionamiento primario anterior, únicamente para compatibilidad de instalaciones antiguas. El archivo candidato incluye ambas claves nuevas; no se pretende operar con la compatibilidad legada en el despliegue nuevo.

Se preparó fuera de Git /var/lib/mobile-support-tickets/prueba_docker/secrets-lectura-escritura.json, dueño1654:1654 modo0400. Conserva JWT y valores originales y agrega Escritura a postgres y Lectura a postgres_lectura con consultor_api. El archivo activo secrets.json no cambió. La clave consultora está fuera de Git en consultor_api.key,1654:1654 modo0400. No imprimir archivos, cadenas, parámetros o tokens. Preparar_consultor.py no sobrescribe archivos ni roles existentes y no se debe reejecutar para rotar credenciales.

La reversión de enrutamiento es SecretsApi:LecturasEnPrimario=true; usa la misma cuenta consultora en postgres. SecretsApi:PermitirFallbackLectura permite deshabilitar el único fallback. La apertura es2s y comandos3s; lectura completa tiene presupuesto7s y primer intento3s. Middleware limita la petición completa, incluida autorización, a9s, por debajo del timeout Flutter15s. No cambia URLs ni perfiles de escucha. Cancelación del cliente se propaga. Indisponibilidad transitoria devuelve503/Retry-After5, no401,404 o listas vacías. Errores SQL permanentes no se ocultan mediante fallback. No se reintentan escrituras ni commits inciertos.

## Rutas y consistencia

Solo Sucursales, Agenda, Eventos.Listar, Solicitudes.Listar y Tecnicos usan EjecutarLecturaAsync. Todo se materializa en una sola conexión y transacción REPEATABLE READ READ ONLY por operación; agenda y evidencias comparten snapshot. No se sustituye SQL por agenda_tickets.

Antes de consultar tickets/eventos/solicitudes se obtienen IDs autorizados en el primario; la consulta secundaria conserva Alcance y además exige ANY(@permitidos). Técnicos conserva su filtro y se restringe a IDs autorizados por el primario. Se trata de una intersección: un estado atrasado puede ocultar datos recientes, pero no puede ampliar el alcance primario. La proyección primaria de IDs consume recursos y memoria proporcionalmente al alcance; revisar paginación si aumenta el volumen. No promete eliminar todas las consultas del primario. Persiste la posibilidad habitual de cambios concurrentes después del snapshot de autorización.

Crear mantiene INSERT y lectura de respuesta en la misma conexión primaria. Evidencia, Eventos.Guardar, Solicitudes.Crear/Revisar, Actualizar y Asignar no se enrutan a réplica; los SELECT FOR UPDATE y deduplicación quedan primarios. X-Consistencia: inmediata permite dirigir un GET al primario con cuenta de consulta. Este encabezado solo pide mayor consistencia; nunca reduce autorización ni concede escritura.

Las consultas GET ordinarias son eventualmente consistentes. La garantía causal entre una escritura y un GET posterior de otra petición/instancia no se promete automáticamente: el cliente actual no envía el encabezado. La respuesta de la escritura sí procede del primario. La propagación de una barrera LSN o la coordinación del ciclo Flutter pertenece a una fase posterior; no se implementó un plazo fijo que aparente esa garantía.

La fase12.3 se implementó posteriormente; ver FASE12_3.md. Diseño original que resolvía: separar envío/descarga Flutter, disponibilidad por capacidad, autorización degradada y política de revocación. En12.3 login/me/escrituras siguen dependiendo del primario; GET protegidos pueden usar autorización temporal previamente validada, durante120s y sin renovación desde réplica. Las pruebas de caída usan mocks o un destino de prueba127.0.0.1:1 dentro de un contenedor de validación; ningún nodo real fue detenido ni aislado.

## Privilegios del consultor

Inventario exacto en columnas_consulta.json; crear_consultor.sql concede SELECT por columna sobre siete tablas, CONNECT tickets_db y USAGE public. No concede acceso a Roles, agenda_tickets, secuencias ni PasswordHash. No añade permisos de ejecución sobre funciones. get_user_by_username es SECURITY INVOKER y requiere columnas que el consultor no puede leer. Sin membresías de roles, SUPERUSER, CREATEDB, CREATEROLE, REPLICATION ni BYPASSRLS. Sin INSERT/UPDATE por columna, DELETE/TRUNCATE ni CREATE en public/tickets_db. Se configuraron default_transaction_read_only y statement_timeout3s, pero la barrera de escritura real es la ACL.

TEMP heredado de PUBLIC permanece: permite objetos temporales en el primario si el usuario cambia su modo de transacción; no concede CREATE persistente ni escritura en aplicación. PostgreSQL no permite negar al rol un privilegio heredado de PUBLIC mediante un simple REVOKE individual. No se cambian privilegios globales para eliminarlo durante esta etapa. En standby, recuperación impide también escribir tablas temporales.

## Acceso standby habilitado

HBA ya permite consultor_api y monitor_postgres por SCRAM a tickets_db desde la red Docker privada172.27.0.0/16; mantiene denegación a los demás usuarios/orígenes. Se respaldó antes y recargó sin reiniciar. Se verificaron conexiones TCP reales y recuperación=true. Una promoción inesperada se rechaza; errores de autenticación no activan fallback.

## Validaciones ejecutadas

```sh
cd /home/econt/practica/mobile-support-tickets
python3 infra/lectura/comprobar_permisos.py
python3 infra/lectura/validar_codigo.py --conexiones-reales
```

El SDK temporal requiere salida NuGet durante restauración; la red Docker privada por sí sola no tiene salida. Después se conecta únicamente el validador temporal a base_datos para SELECT; se elimina por ID tras comprobar nombre/etiqueta y ausencia de identidad Compose. No sustituye imágenes ni usa el modo --real antiguo que inserta registros. El código se copia sin bin/obj a /tmp del validador; no modifica la configuración normal ni el APK.

Resultados:18 pruebas de selectores/JWT; enrutamiento de cinco lecturas; preservación primaria de escrituras/permisos y lectura de respuesta; HTTP con controllers/middleware reales y autenticación ficticia solo del test (200/401/403/503); validaciones existentes de evidencia y usuario inactivo; consultas SELECT completas en primario con consultor; RR/RO; fallback acotado; selector de reversión; encabezado inmediato; cancelación; rechazo HBA28000 sin fallback. Se comparó cada columna de las ocho tablas en ambos nodos y se ejecutaron SELECT LIMIT0 sobre las columnas concedidas. Se verificó login/JWT real y destinos HTTP tras el despliegue; no se fabricaron datos ni tokens de usuarios reales.

Durante preparación se corrigió un error del script que había omitido la asignación de contraseña. Antes de completarla se comprobó que consultor_api seguía sin verificador; después se validó SCRAM y autenticación TCP real al primario. No se rotaron credenciales de cuentas existentes.

## Despliegue y reversión

La imagen nueva está activa mediante compose.yaml + compose.api-lectura.yaml. Solo se recreó api. tickets-api:antes-fase12-3 conserva la imagen previa; secrets.json original permanece intacto y la configuración nueva usa el archivo candidato externo. No usar un up global ni --remove-orphans al operar complementos.

```sh
# Estado, sin cambios:
docker compose --env-file .env.example -f compose.yaml -f compose.api-lectura.yaml ps api
# Reversión únicamente si se decide volver a la versión anterior:
docker compose --env-file .env.example -f compose.yaml -f compose.api-anterior.yaml up -d --no-deps api
```

Conservar roles, slots, HBA y volúmenes durante esa reversión. LecturasEnPrimario=true permite reversión lógica manteniendo la cuenta consultora; aplicar cambios del archivo externo requiere recreación controlada de API y comprobarlos antes. No se cambian secretos automáticamente para probar.

## Inventario exacto de esta fase

Raíz: /home/econt/practica/mobile-support-tickets. Los siguientes20 archivos se prepararon o modificaron; los nombres no implican que todos estén previamente versionados.

```text
api/Data/Connections/IConexion.cs
api/Data/Connections/Conexion.cs
api/Data/AccesoTicketsPostgres.cs
api/Data/AccesoEventosPostgres.cs
api/Data/AccesoSolicitudesPostgres.cs
api/Data/AccesoCoordinacionPostgres.cs
api/Services/ConfiguracionSecretsApi.cs
api/Services/LimiteSolicitudBaseDatos.cs
api/Program.cs
api/appsettings.json
tests/api/Program.cs
tests/api/PruebasConfiguracionSecrets.cs
tests/api/PruebasSeparacion.cs
tests/api/PruebasConexionLectura.cs
infra/lectura/README.md
infra/lectura/columnas_consulta.json
infra/lectura/crear_consultor.sql
infra/lectura/preparar_consultor.py
infra/lectura/comprobar_permisos.py
infra/lectura/validar_codigo.py
```

No se modificaron compose.yaml, compose.monitoring.yaml, compose.replica.yaml, Dockerfile, HBA, scripts/configuración de réplica, monitoreo, código Flutter ni SQL de aplicación. El esquema no cambió; solo se creó el rol y sus grants.
