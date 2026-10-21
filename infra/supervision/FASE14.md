# Fase14: observabilidad desplegada, autorreparacion DESACTIVADA

2026-10-21, rama prueba_docker. Se inicio solo supervision_metricas y un proceso Python local en modo observar. No se ejecutaron habilitar/vigilar ni se creo activacion.json. Ningun contenedor existente fue reiniciado o recreado; se verificaron ID, StartedAt y RestartCount contra baseline externo.

## Imagen/aislamiento

BusyBox oficial1.37.0, linux/amd64, digest sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e. Verificacion registrada en imagen_metricas.json; httpd/wget/sh probados como UID65534 en contenedor efimero sin red. compose.supervision.yaml ahora fija el digest, pull_policy never, red interna monitoreo, sin puertos host, sin socket/privilegios, filesystem RO y directorio externo de metricas RO. Limites32MiB/0.10CPU. No se agregaron politicas a contenedores existentes.

## Integracion aplicada

Prometheus conserva sus9targets y6reglas; se incorporaron job supervision y8reglas de infra/monitoring/prometheus/supervision.yaml. Total10targets UP y14reglas cargadas. Configuracion completa validada con promtool antes de reload por SIGHUP; no hubo recreacion ni interrupcion deliberada de Prometheus, y su volumen/ID/StartedAt siguen intactos.

Primer scrape fallo: non-compliant scrape target sending blank Content-Type and no fallback_scrape_protocol specified for target. BusyBox no emite Content-Type para .prom. Se agrego fallback_scrape_protocol: PrometheusText0.0.4 SOLO al job supervision; promtool valido y segundo reload resolvio el fallo. No se ocultaron errores de targets anteriores.

Grafana detecto supervision.json mediante provisioning30s, sin restart. Se conservan docker_local12paneles, disponibilidad_local14, plataforma_local4 y replica_local8; nuevo supervision_local12: total5dashboards/50paneles. Todas las consultas devolvieron series reales, no solo JSON de dashboard valido. Ceros en reinicios/recuperacion no significan que se haya probado una recuperacion real: no se indujeron fallos.

Reglas nuevas: SupervisorSinLatido, SupervisionNoDisponible, RecuperacionBloqueada, ServicioFuncionalNoDisponible, ApiSoloConsultas, MotorDockerNoDisponible, WalSinStreamingSupervisado, ReiniciosDockerFrecuentes. Reglas cargadas no equivalen a notificaciones entregadas: no se configuro canal externo/Alertmanager. Se mantienen las seis alertas anteriores.

## Observador y evidencia externa

Proceso Python como econt, exclusivamente supervisor.py observar. Estado/log/metricas/identidad del proceso en /home/econt/.local/state/tickets-supervision. control_observador.py comprueba PID, script, modo y start ticks antes de detener solo ese proceso. No tareas Windows, systemd ni arranque persistente. El observador no incluye el nuevo servidor en su lista de autorreparacion; Prometheus supervisa su target, Docker su healthcheck.

Backup de configuracion y baseline: el archivo externo fase14_actual.txt apunta al directorio fase14 correspondiente. Contiene prometheus.yaml y reglas.yaml previos, contenedores.json y recursos_finales.json; no contiene claves/passwords. El latido registra una brecha previa correspondiente al periodo entre preparacion y arranque de observacion, no se presenta como caida de los servicios.

## Uso diario y comprobacion

Desde Ubuntu como econt:

```sh
cd /home/econt/practica/mobile-support-tickets
python3 infra/supervision/control_observador.py estado
python3 infra/supervision/comprobar_latido.py
# Solo si esta detenido:
python3 infra/supervision/control_observador.py iniciar
```

El control inicia siempre observar y rechaza activacion inesperada. NO habilitar ni ejecutar vigilar. Para comprobar paneles/reglas en lectura (root solo para leer credencial Grafana externa, sin imprimirla):

```powershell
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/supervision/comprobar_fase14.py
```

Acceso con proxy Windows ya existente: http://127.0.0.1:13000/d/supervision_local . Este despliegue no arranca ni modifica el proxy, SSH o ADB. Los tres listeners SSH Windows2222/15432/15433 conservan loopback. La ultima comprobacion ADB no detecto telefono; no se modifico ni retiro reverse5263 y no se puede acreditar su estado mientras no aparezca el dispositivo.

## Recursos observados (muestra puntual, no tendencia)

Servidor metricas0.00%CPU/996KiB de32MiB; observador0.3%CPU/RSS17868KiB. Prometheus0.27%/56.61MiB; Grafana1.80%/326.9MiB. Baseline externo guarda el snapshot completo. Primary11.09% y exporters4.59%/2.51% coinciden con muestreo SQL/scrapes: no asumir consumo sostenido a partir de una muestra.

## Validaciones finales

Compose sin publicaciones nuevas, servidor healthy, metrics HTTP accesible y samples frescos. tickets_supervisor_autorreparacion_activa=0 y todos los reinicios_solicitados_total=0; no activacion.json. SQL/HTTP funcionales en10servicios observados, WALstreaming1. API HTTP200 database=connected, primaria streaming async hacia postgres_lectura, slot_postgres_lectura activo/reserved. PostgreSQL, standby, Prometheus, Grafana y exporters healthy. Quinto dashboard y anteriores con datos; prom_config_last_reload_successful1. No hay prueba real de interrupcion autorizada ni realizada.

## Reversion sin tocar aplicacion/BD

Para detener solo observacion:

```sh
python3 infra/supervision/control_observador.py detener
```

El target seguira respondiendo con ultimo archivo, pero el latido envejecera y alertara: no confundir endpoint HTTPup con observacion fresca. Para retirar todo el bloque bajo autorizacion: eliminar solo job supervision y referencia rule_files supervision.yaml de Prometheus, validar promtool y reload HUP; retirar solo nuevo dashboard supervision.json; detener/eliminar solo contenedor supervision_metricas por su ID validado, sin down ni volumenes. Preservar archivos externos/evidencias y no retirar reglas/jobs anteriores. No restaurar ciegamente baseline si hubo cambios posteriores: aplicar diff limitado. No ejecutar aqui esos pasos: son procedimiento de reversion, despliegue queda activo.

Arranque tras reboot sigue manual: WSL/motor no son activados por esta fase. Una vez Docker funcione, verificar estado actual; el servidor nuevo unless-stopped puede volver salvo parada manual; iniciar observador con control_observador.py iniciar. No tocar API/DB, tuneles o politicas para resolver arranque de Windows.
