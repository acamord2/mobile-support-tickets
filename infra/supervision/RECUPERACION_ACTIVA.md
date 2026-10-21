> Prueba real Blackbox completada; ver [RESULTADO_BLACKBOX.md](RESULTADO_BLACKBOX.md). Las referencias a prueba pendiente siguientes son historicas; no autorizan repetirla.

# Recuperacion automatica activada (2026-10-21)

## Estado efectivo

API, postgres y postgres_lectura pasaron de restart no a unless-stopped usando docker update sobre sus IDs existentes. IDs, StartedAt y RestartCount no cambiaron. Los otros ocho contenedores del proyecto conservan unless-stopped. compose.yaml (api/postgres) y compose.replica.yaml (standby) ahora incluyen esa politica, sin otros cambios semanticos ni normalizar finales de linea. La configuracion sobrevive al daemon restart en el contenedor existente; una recreacion debe usar los Compose actualizados y todos los overrides correctos (especialmente compose.api-lectura.yaml). No se ejecuto compose up ni se recreo API/DB.

La validacion inicial de encabezados confundio el nombre de una dependencia con el encabezado; rechazo el cambio antes de escribir Compose/Docker. El supervisor alcanzo a iniciarse, se detuvo solo ese proceso, se corrigio el reconocimiento por inicio de linea y se aplicaron las tres politicas. Cero reinicios de contenedores durante toda la operacion.

Un unico proceso supervisor.py vigilar con IDs fijados para api/grafana/blackbox/postgres_exporter/postgres_exporter_lectura. PostgreSQL primario/standby, Prometheus/cAdvisor/SocketProxy siguen exclusivamente observados por el supervisor. supervision_metricas conserva su politica previa y queda fuera de acciones del supervisor. La exclusión proceso.lock dura toda la vida del bucle (antes solo se bloqueaba el ciclo), evitando dos procesos observar/vigilar incompatibles. No se arman IDs al iniciar el controlador: requiere habilitar explicito.

## Limites y eventos

3fallos funcionales consecutivos, gracia120s, cooldown300s, presupuesto3reinicios/hora/servicio persistente en estado.json. IDs, proyecto, servicio y estado running se revalidan inmediatamente antes de restart del ID. Incidentes en ~/.local/state/tickets-supervision/incidentes.jsonl; proceso y PID/inicio en observador.json; metricas expuestas por supervision_metricas. No hay nueva cuenta/permiso Engine: se conserva riesgo privilegiado del cliente Docker del usuario existente.

| Situacion | Docker unless-stopped | Supervisor |
|---|---|---|
| Proceso termina/crashea | Puede reiniciarlo | No hace start de detenidos |
| Running unhealthy | No reinicia por healthcheck solo | Solo5candidatos y fallo funcional probado, no dependencia |
| Detencion manual | Se respeta, incluso tras daemon restart | No arranca detenidos; usar mantenimiento antes de intervencion |
| Docker/WSL caido | No puede actuar hasta volver motor | Registra fallo si WSL vive; no puede revivir WSL/Engine |
| SQL/WAL/red de DB falla | No reinicia un postgres que sigue running por esa causa | Solo alerta/diagnostico; no promocion/reconstruccion |
| API solo consultas | Sigue running | No reinicio por primario caido; capacidades lectura/escritura separadas |

Importante: unless-stopped NO tiene limite3/hora. Ese limite aplica a acciones del supervisor; Docker puede reintentar un proceso fatal repetidamente. Se conserva alerta por reinicios frecuentes y se requiere diagnostico si sucede; no prometer limite global ni detener DB automaticamente para imponerlo. Arranque standby existente valida volumen/identidad/standby.signal y solo hace backup si vacio; no se modifico. Si desaparecen credenciales/marca externa o hay corrupcion, puede salir y Docker reintentara: suspender intervenciones automaticas, informar y solicitar decision, nunca regenerar PGDATA. Actualmente no hay bucles ni reinicios en ningun contenedor del proyecto.

MongoDB de proyecto ajeno ya estaba restarting con always y170reinicios en baseline; siguio aumentando independientemente. Politica sin cambios, ningun ID ajeno en activacion y todos los reintentos_total del supervisor0. No se diagnostica ni repara ese proyecto bajo este alcance.

## Pruebas y comprobaciones

24pruebas simuladas aprobadas: incluyen HTTPficticio, recuperacion, estado unhealthy vs proceso, parada manual, motor caido, dependencias, APIdegradada, OOM, limites, cooldown, mantenimiento, IDs/proyectos ajenos, persistencia de presupuesto y exclusion de dos bucles. No se provoco un crash real ni se reinicio Docker/WSL: interrumpiria servicios sin autorizacion. La semantica restart se contrasta con politica inspect y documentacion oficial Docker, no se presenta como ensayo real.

Validacion final:10targetsUP,14reglas cargadas,5dashboards/50paneles con samples; autorreparacion_activa1, reinicios_solicitados_total0. Todos los containers del proyecto con IDs/StartedAt/RestartCount previos. API HTTP200; PG/standby sanos y WALstreaming. Sin tocar HBA, SQL, WAL, slots, volumenes, secretos, Flutter, SSH ni ADB. Notificaciones externas siguen sin configuracion nueva; reglas cargadas no equivalen a avisos entregados.

## Control y suspension

Como econt, desde repositorio:

```sh
python3 infra/supervision/control_supervision.py estado
python3 infra/supervision/supervisor.py mantenimiento
# Con lock ocupado reintentar despues del ciclo; confirmar salida0 y metrica mantenimiento1.
python3 infra/supervision/supervisor.py suspender
# suspender vacia IDs activos sin borrar presupuesto; no cambia restart de Docker.
```

Mantenimiento conserva IDs y cooldown/presupuesto, impide acciones en siguientes ciclos; un ciclo ya en marcha puede terminar antes de adquirir lock. Antes de una parada manual, confirmar mantenimiento y ausencia de accion pendiente. Reanudar mantenimiento conserva armando:

```sh
python3 infra/supervision/supervisor.py reanudar
```

Tras suspender, rearmar solo con IDs y autorizacion revisados:

```sh
python3 infra/supervision/supervisor.py habilitar --confirmar-proyecto mobile-support-tickets-prueba-docker
```

Cambiar a observacion exclusivamente:

```sh
python3 infra/supervision/supervisor.py suspender
python3 infra/supervision/control_supervision.py detener
python3 infra/supervision/control_supervision.py iniciar --modo observar
```

Para volver a vigilar (si sigue autorizado y servicios correctos): detener unico proceso, habilitar IDs y control_supervision.py iniciar --modo vigilar. No ejecutar ambos controladores; control_observador.py queda como herramienta historica para observar, utilizar ahora control_supervision.py. Todos verifican PID/script/inicio antes de detener. No usar kill de nombres globales ni borrar estado para saltarse limites.

## Reversion de politicas

Baseline externo indicado por ~/.local/state/tickets-supervision/activacion_actual.txt contiene baseline.json y copias previas de Compose/supervisor. Suspender y pasar a observar primero. Para los tres contenedores concretos, despues de validar ID/proyecto/servicio:

```sh
docker update --restart no mobile-support-tickets-prueba-docker-api-1
docker update --restart no mobile-support-tickets-prueba-docker-postgres-1
docker update --restart no mobile-support-tickets-prueba-docker-postgres_lectura-1
```

Eso no requiere restart/recreacion. Revertir solo las tres lineas restart de Compose mediante edicion revisada; no git restore/reset ni reemplazar ciegamente archivos si hubo cambios posteriores. Los otros servicios mantienen sus politicas originales. No se ejecutaron comandos de reversion de Docker en esta fase.

## Prueba Blackbox pendiente: NO ejecutada

Solicitar autorizacion separada para una ventana breve de perdida de sondas Blackbox. Baseline de ID/imagen/StartedAt/restarts/health; confirmar todos los demas sanos y mantenimiento levantado solo cuando corresponda. Suspender PIDprincipal con SIGSTOP del IDexacto (no docker pause, que debe respetarse como manual). Esperar tres fallos funcionales y un unico restart permitido, observar recovering->healthy, presupuesto/eventos/tiempo y recuperacion de targets. No activar fallos de API, Grafana o bases.

Si no hubo reinicio y sigue siendo el mismo contenedor/proceso suspendido, SIGCONT al mismo ID sirve como reversion. Ante identidad/circunstancia distinta, no enviar señales; suspender watchdog y diagnosticar. No repetir ensayo para forzar exito. Docker restart puede usar SIGKILL tras10s si el proceso no procesa SIGTERM; aceptarlo solo dentro de la autorizacion especifica para Blackbox. No se ejecutaron STOP/CONT en esta etapa.

## Recuperacion Windows/WSL

No se habilitaron tareas ni servicios nuevos. systemd/Docker ya estaban enabled dentro de WSL, pero Windows no inicia necesariamente la distro. Tras iniciar manualmente Ubuntu, comprobar Engine y politicas; unless-stopped intentara levantar contenedores antes running, respetando paradas manuales. dependencies de Compose no se reevalúan como orquestador al reiniciar daemon: PostgreSQL puede tardar y la API transitoriamente503. Verificar SQL/read-only/streaming y HTTP antes de usar app; startupgrace120s evita acciones prematuras, dependencias bloquean autoheal.

Estado de supervisor no inicia solo tras reboot: comprobar IDs contra activacion y arrancar control_supervision.py iniciar --modo observar primero si hay dudas, o vigilar con autorizacion vigente e IDs coincidentes. No rearmar automaticamente nuevos IDs. Restaurar SSH/proxy segun procedimientos existentes, no cambiar ADB. Un arranque automatico Windows/WSL requeriria autorizacion independiente. No se realizaron pruebas reales de reboot.

Validador actual:

```powershell
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/supervision/comprobar_fase14.py --autorreparacion 1
```

El valor esperado es explicito; tras suspension/mantenimiento usar0. No exigir siempre contador reinicios0 despues de un incidente real autorizado: revisar baseline/eventos y presupuesto.
