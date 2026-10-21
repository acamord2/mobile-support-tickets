# Fases12.2 y12.3: despliegue y continuidad local

## Resultado verificado el2026-10-20

API activa: tickets-api:fase12-3, imagen sha256:218135d79d244c66e75aafb7abbefd87e3d487cca7b4f3be4ff9ce656fbc8210, UID1654:1654. Se recreó únicamente api. Se comprobó que primario, standby y seis servicios originales de monitoreo conservan sus IDs/StartedAt. Se añadió postgres_exporter_lectura; Prometheus se recargó con SIGHUP sin reinicio y Grafana provisionó el dashboard automáticamente.

GET health/database200 connected; disponibilidad200 completo. Login/me200 reales, anónimo y credenciales incorrectas401, técnicos403 para rol técnico. Las cinco lecturas replicables devolvieron X-Destino-Lectura=secundaria; consistencia inmediata devolvió primaria con la cuenta consultora. JWT/credenciales permanecieron en memoria y no se publicaron. No se insertaron datos de negocio; Roles4/Users5 permanecen.

Primario: recuperación=false, sololectura=off. Standby: recuperación=true, sololectura=on. Receptor streaming, sincronización async, slot_postgres_lectura activo/reserved, distancia WAL0bytes. pg_wal48MiB por nodo y retención1GiB. consultor_api no pudo activar READ WRITE en standby: SQLSTATE0A000, sin DML. ACL por columna comprobada en ambos nodos, sin PasswordHash/escritura/CREATE persistente. TEMP heredado de PUBLIC permanece sin cambios globales.

## Seguridad de continuidad

Login, /me, autorizaciones de escritura, SELECT FOR UPDATE y transacciones de negocio siguen en primario. No hay promoción ni reintentos de escrituras inciertas. Consultas seguras usan standby y como máximo un fallback primario con consultor_api; un rechazo de credenciales/HBA no se oculta. Presupuesto HTTP9s, lectura7s, primer intento3s, apertura2s y comando3s.

ContinuidadConsultas conserva en memoria rol y proyecciones de IDs previamente autorizadas, asociadas al hash del JWT, máximo120s desde la validación primaria de cada categoría y nunca renovadas desde standby. Solo GET protegidos con JWT validado pueden recuperar esa información ante fallo transitorio. Se intersecta con los filtros SQL existentes; no se amplía alcance. Identidades nuevas, caché vencida, /me, login y escrituras reciben503/Retry-After5 si no pueden consultar el primario. Un token expirado recibe401 por middleware JWT. Una revocación conocida elimina el alcance cacheado. Un cambio de rol confirmado invalida categorías anteriores.

Las respuestas temporales incluyen X-Modo=solo-consultas y X-Autorizacion=temporal-no-confirmada. Riesgo residual aceptado: durante hasta120s puede desconocerse una revocación o reasignación ocurrida antes de la caída y no observada por esta API. No se llama autorización confirmada. Reiniciar la API borra esa caché: si primario está caído no se autoriza solo por poseer JWT. No se promete continuidad de todas las operaciones ni renovación indefinida.

La disponibilidad anónima /api/health/disponibilidad distingue lectura/escritura; no concede permisos. El healthcheck anterior conserva su significado de primario y las sondas de monitoreo lo siguen usando. Errores SQL permanentes no se convierten silenciosamente en éxito o listas vacías.

## Flutter

ServicioSincronizacion separa envío de descarga. Un503 conserva la operación pendiente, suspende envíos y permite intentar descargas; no confirma una escritura incierta. El modo solo consultas no envía la cola y muestra “Solo consultas; cambios no enviados”. La escritura local offline sigue siendo un pendiente explícito, nunca éxito remoto. Un401 invalida el token, no SQLite.

Las descargas conservan pending, ignoran versiones anteriores por updatedAt y no ocultan filas locales ausentes de una réplica durante modo degradado. Una evidencia pendiente con mismo contenido no se duplica al descargar si se perdió la respuesta; la cola solo se confirma tras recibir el Id del reintento. Después de envíos confirmados, el ciclo pide consistencia=inmediata al primario; si entra en modo solo consultas, permite lectura temporal marcada y preserva datos locales. GET normales mantienen consistencia eventual: una barrera causal persistente entre sesiones/reinicios no se implementó ni se promete.

98 pruebas Flutter aprobadas,2 integraciones reales optativas omitidas; análisis estático sin incidencias. Se usó copia temporal: SDK instalado Flutter3.47.7/Dart3.13.5 requiere4 dependencias de SDK diferentes del lock original. Se resolvieron SOLO en la copia de pruebas; pubspec.lock y la configuración normal de URL del repositorio se conservaron. No se instaló un APK nuevo; adb devices no detectó teléfono. No se eliminó ADB reverse. La validación física de estos cambios queda pendiente de conectar el dispositivo y acordar compilación con el SDK del proyecto.

## Monitoreo real

9/9 targets UP: los8 originales más postgres_replica. Recuperación1, pg_up1, lag0, slot activo1, WAL pendiente0. Se conservan los3 dashboards/30 paneles y se añade replica_local con8 paneles:4 dashboards/38 paneles con resultados reales en cada consulta. Incluye receptor reciente, margen WAL y estado del slot primario. La edad de la última transacción no se interpreta sola como lag. No hay puertos de monitoreo publicados.

Se validaron6 reglas de alerta: ApiNoDisponible, PostgresNoDisponible, RecolectorNoDisponible, ReplicaAtrasada, ReplicaNoDisponible y ReceptorWalNoDisponible. Las reglas locales no equivalen a notificaciones externas; no se instaló Alertmanager.

Muestra puntual Docker: API59.57MiB/0.12%CPU; primario76.59MiB/0.01%; standby36.44MiB/0%; Prometheus54.73MiB/0.52%; Grafana182.9MiB/2.28%; exporter secundario8.824MiB/0%. No son tendencias ni reservas.

## Operación y reversión

```sh
cd /home/econt/practica/mobile-support-tickets
# Estado usando los complementos existentes; no ejecutar un up global.
docker compose --env-file .env.example -f compose.yaml -f compose.api-lectura.yaml ps api
python3 infra/lectura/comprobar_api.py
sudo python3 infra/monitoring/comprobar.py
# Validación de código en SDK temporal y solo SELECT reales:
python3 infra/lectura/validar_codigo.py --conexiones-reales
python3 infra/lectura/comprobar_permisos.py
# Reversión exclusiva de API, si se decide:
docker compose --env-file .env.example -f compose.yaml -f compose.api-anterior.yaml up -d --no-deps api
```

El override anterior usa tickets-api:antes-fase12-3 y el montaje original conservado por compose.yaml. La configuración activa nueva está en secrets-lectura-escritura.json externo; secrets.json original permanece intacto. Copias privadas de HBA/configuración y snapshots de contenedores: /var/lib/mobile-support-tickets/prueba_docker/fase12_3_20261020_225933. No mostrar esas copias ni copiarlas a Git.

Para revertir solo rutas de lectura, preparar LecturasEnPrimario=true en la configuración externa, validar y recrear únicamente API; no cambiar cuentas o promover standby. No retirar HBA mientras el exporter o la API lo usan. Conservar roles, slots y volúmenes. El warning Compose de servicios “orphan” al usar complementos parciales no autoriza --remove-orphans.

## SSH diferido

Por instrucción explícita del usuario no se inventó servidor/puerto/usuario ni se habilitó SSH. Scripts sintácticamente validados en [../acceso_ssh/README.md](../acceso_ssh/README.md); claves privadas se generarían fuera de Git y con frase de paso. No se abrieron puertos ni se cambió firewall. API conserva su publicación previa5263 en interfaces WSL; no se certifica aislamiento LAN ni acceso SSH real. Grafana sigue privada y su proxy Windows13000 sigue siendo bajo demanda. No sustituir USB hasta validar conectividad real de Android.

## Archivos de esta continuación

```text
compose.api-lectura.yaml
compose.api-anterior.yaml
api/Program.cs
api/Data/Connections/Conexion.cs
api/Data/AccesoTicketsPostgres.cs
api/Data/AccesoEventosPostgres.cs
api/Data/AccesoSolicitudesPostgres.cs
api/Data/AccesoCoordinacionPostgres.cs
api/Services/ContinuidadConsultas.cs
api/Controllers/Health/ControladorDisponibilidad.cs
tests/api/Program.cs
tests/api/PruebasSeparacion.cs
tests/api/PruebasContinuidad.cs
tests/api/PruebasConexionLectura.cs
infra/lectura/README.md
infra/lectura/FASE12_3.md
infra/lectura/comprobar_api.py
infra/replicacion/README.md
infra/replicacion/pg_hba_standby.conf
infra/monitoring/README.md
infra/monitoring/ACCESO_PRIVADO.md
infra/monitoring/comprobar.py
infra/monitoring/grafana/dashboards/replica.json
infra/monitoring/prometheus/reglas.yaml
infra/monitoring/prometheus/targets/postgres_replica.json
infra/acceso_ssh/README.md
infra/acceso_ssh/preparar_clave.ps1
infra/acceso_ssh/tunel_windows.ps1
mobile/lib/app/services/servicio_sincronizacion.dart
mobile/lib/app/network/rutas_api.dart
mobile/lib/app/network/respuesta_api.dart
mobile/lib/app/network/cliente_api.dart
mobile/lib/app/constants/textos_app.dart
mobile/lib/modules/home/controlador_inicio.dart
mobile/lib/app/database/repositorio_tickets.dart
mobile/lib/app/database/repositorio_evidencias.dart
mobile/test/services/sincronizacion_test.dart
mobile/test/services/continuidad_consultas_test.dart
mobile/test/modules/flujo_mvp_test.dart
mobile/test/roles/roles_asignacion_test.dart
mobile/test/tickets/sincronizacion_tickets_test.dart
mobile/test/tickets/sqlite_tickets_test.dart
```

Los archivos preparados previamente en12.2 también forman parte de la imagen desplegada; su inventario está en README.md. No se editaron compose.yaml, compose.monitoring.yaml, compose.replica.yaml, SQL de aplicación, Dockerfile ni configuración WAL. No se detuvieron bases para simular fallos. No se realizaron commits/push ni limpieza de recursos ajenos.
