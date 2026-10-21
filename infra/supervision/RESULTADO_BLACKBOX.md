# Prueba Blackbox real: resultados (2026-10-21)

Autorizacion exclusiva Blackbox. El supervisor vigilar estaba activo, mantenimiento desactivado, blackbox healthy, politica unless-stopped, ID8fb336223f2b69e1285dba5a6a52a3a1375feb27d923d4917b2e327fa6c9fdbf, inicio2026-10-21T15:22:43.567722192Z, PIDhost1941 y RestartCount0. Sin intentos previos del supervisor. No se modificaron configuracion, healthcheck ni limites.

## Fallo funcional real

SIGSTOP al PIDhost validado de /bin/blackbox_exporter (PID1 de su namespace). Se verificaron ID/nombre/labels/PID/exe antes de senalizar; reversion SIGCONT preparada si mismo proceso seguia suspendido. API/SQL no se interrumpieron. Sondas dependientes de Blackbox fallaron temporalmente, efecto esperado.

Transiciones persistidas desde inyeccion:

| Segundos | Supervisor | Fallos | Solicitudes | PID | Docker health |
|---|---|---|---|---|---|
|1.86|healthy|0|0|1941|healthy|
|23.13|unhealthy|1|0|1941|healthy|
|49.89|unhealthy|2|0|1941|healthy|
|70.97|recovering|0|1|1941|healthy|
|81.49|recovering|0|1|220195|starting|
|86.76|recovering|0|1|220195|healthy|
|102.68|healthy|0|1|220195|healthy|

La solicitud se dispara al tercer fallo segun politica3; la maquina reinicia contador fallos al entrar recovering. No se observo un sample fallos3: se observaron1,2 y luego la solicitud. Incidentes del supervisor registran unhealthy/recovering/healthy. Tiempo total102.68s; metrica recuperacion83.913429s desde primera deteccion. Un solo restart solicitado; Docker RestartCount permanecio0 (no confundir DockerRestartCount con acciones manuales/solicitadas al Engine).

El healthcheck Docker REAL NO alcanzo unhealthy: tiene5reintentos, y el supervisor actuo antes. Se verifico unhealthy funcional real del supervisor, no se afirma unhealthy Docker real. No se modifico healthcheck ni recreo Blackbox para forzarlo.

## Cooldown: limite de esta prueba

Se preparo segunda suspension breve dentro de cooldown300s, despues de gracia120s. La precondicion conservadora exigia menos230s desde solicitud para dejar margen de reversion. La ventana ya habia expirado al intentarlo: script aborto ANTES de emitir senal, sin otra suspension/reinicio. La terminacion encadenada tampoco se ejecuto en ese intento. No se modificaron timestamps/politica ni se indujo otro reinicio para fingir prueba de cooldown. Cooldown,3/hora y mantenimiento siguen cubiertos por pruebas simuladas, no por segunda inyeccion real.

## Terminacion inesperada real

Ensayo independiente despues de volver a healthy y verificar diez targetsUP. Se envio SIGKILL directamente al PIDhost verificado (no docker stop ni docker kill con semantica de parada manual). unless-stopped recupero el proceso, mismo ID de contenedor, PIDnuevo231725:

- 2.20s: Dockerstarting, RestartCount1; supervisor solicitudes1 (sin incremento).
- 7.53s: Dockerhealthy, supervisorhealthy, RestartCount1.
- Eventos observados: die exit137, start y health_status healthy. No nuevo restart del supervisor.

El fallo fue mas rapido que el intervalo del supervisor, por lo que su contador de incidentes siguio1 y recuperacion_segundos conserva83.91 del primer ensayo; no presentar esa metrica como tiempo de recuperacion de la terminacion. Su evidencia especifica es tiempo7.53s, eventosDocker y RestartCount0->1. La primera consulta de eventos los capturo; una posterior perdio eventos por buffer limitado de Docker. Se conserva transcripcion explicita de esa primera observacion, sin atribuir eventos de otra ventana al primer ensayo. Para ensayos futuros conviene recolector de eventos en vivo antes de inyectar; no atribuir ausencia en buffer a ausencia de incidente.

## Variante ficticia aislada

Canario temporal BusyBox: rednone, sin puertos ni volumenes, UID65534, filesystemRO y tmpfs; healthcheck con marcador solo en tmpfs. Healthy->unhealthy->healthy con proceso running y RestartCount0. Se retiro solo su ID tras verificar nombre/label propio y ausencia de proyecto Compose. No se altero Blackbox real para esta variante. Evidencia en ~/.local/state/tickets-supervision/canario_blackbox.json. Esta es prueba real del mecanismo healthcheck en servicio ficticio, NO un incidente adicional del Blackbox productivo.

## Estado final y evidencia

Otros10servicios del proyecto conservaron ID/StartedAt/RestartCount, incluyendo API y ambas bases. Blackbox mismoID, healthy, RestartCount1. Supervisor solicitudesBlackbox1, incidente1, autorreparacion1. Diez targetsUP,14reglas cargadas,5dashboards/50paneles con datos; datasource Grafana correcto y WALstreaming1. La verificacion final se repite con comprobar_fase14.py --autorreparacion1. No se instalaron tareas Windows; sigue ejecucion dentroWSL. No HBA/SQL/WAL/slots/volumenes/firewall ni tuneles/ADB modificados.

Evidencias externas, root0700:

- /var/lib/mobile-support-tickets/prueba_docker/prueba_blackbox/funcional_20261021_123029/: baseline,inyeccion,transiciones,resultado,eventos_supervisor.
- /var/lib/mobile-support-tickets/prueba_docker/prueba_blackbox/terminacion_20261021_123834/: mismos archivos y eventos_observados_validacion.json.

El script prueba_blackbox_real.py queda como herramienta de ensayo explicitamente autorizada, NO como tarea automatica. Requiere root para senalizar PIDhost y confirmacion del nombre exacto. No volver a ejecutarlo sin nueva ventana de prueba revisada; precondiciones de presupuesto/RestartCount impiden reutilizacion ciega. Cooldown abortado no dejo datos ni senales pendientes. No se probaron limites agotados o mantenimiento en servicios reales; siguen simulados.
