# Migracion systemd completada (2026-10-21)

Unidad /etc/systemd/system/tickets-supervisor.service instalada desde fuente validada, root0644. enabled/active/running; MainPID310723, User=econt, NRestarts0, ControlGroup/system.slice/tickets-supervisor.service. Existe una sola instancia supervisor.py vigilar. systemd245 funciona comoPID1 en Ubuntu20.04WSL2.

Se revalido manualPID200243 por cmdline/script/modo/startticks/uid1000, no solo numero. Mantenimiento activado antes de detenerlo con el controlador que verifica identidad. Se respaldo estado y baseline. La unidad paso preflight y produjo ciclos reales de Docker/SQL/HTTP en mantenimiento; segunda instancia vigilar rechazada por lock. Despues de comparar cooldown/presupuesto/intentos/ultimo, activacion e historial se retiro SOLO mantenimiento temporal (no existia previamente). No se ejecuto habilitar ni se regeneraron IDs/contadores. Historial JSONL conservado como prefijo y agregado con transiciones de mantenimiento/salud.

El primer check Prometheus tras retirar mantenimiento aun vio muestra0 anterior; se espero propagacion del ciclo/scrape y se confirmo1. No fue fallo de unidad ni motivo de reinstalacion.

Resultado: APIHTTP200connected, PG/standbyhealthy y WALstreaming1;10targetsUP,14reglas,5dashboards/50paneles con datos. Todos los contenedores del proyecto conservanID/StartedAt/RestartCount. SSH y tuneles Windows mantienen listeners loopback y PIDs anteriores; ADB/Flutter no se modificaron. Sin reinicio de Docker/WSL/Windows o contenedores. No se instalaron tareas Windows.

Evidencia externa: /home/econt/.local/state/tickets-supervision/migracion_systemd_20261021_131624/ (previo.json,contenedores.json,estado.json,activacion.json,latido.json,incidentes.jsonl,resultado.json). Estos archivos no van a Git ni se restauran ciegamente para resetear limites.

## Operacion vigente

```sh
systemctl is-active tickets-supervisor.service
systemctl is-enabled tickets-supervisor.service
systemctl show tickets-supervisor.service -p MainPID -p NRestarts -p User
sudo journalctl -u tickets-supervisor.service -n 50 --no-pager
sudo journalctl -u tickets-supervisor.service -f
```

Usar systemctl como autoridad de proceso. observador.json sigue siendo metadata historica de la instancia manual200243; no usar control_supervision.py estado/detener para gestionar la unidad. No se reescribe esa metadata para fingir un proceso manual. El bloqueo y scanner impiden que un controlador manual cree una segunda instancia mientras la unidad funciona.

Mantenimiento/suspension conservan comandos existentes como econt:

```sh
cd /home/econt/practica/mobile-support-tickets
python3 infra/supervision/supervisor.py mantenimiento
python3 infra/supervision/supervisor.py suspender
```

Si hay BlockingIOError, esperar fin de ciclo y reintentar; exigir salida0. Mantenimiento conserva IDs/presupuesto; suspender retira IDs activos deliberadamente pero no borra historial/cooldown. Para pausa de acciones mantener observacion. Para parar proceso completo, primero mantenimiento y confirmar fin de ciclo, despues sudo systemctl stop tickets-supervisor.service. on-failure no reinicia una parada manual hecha con systemctl. RestartSec15s y limite3arranques/300s protegen el proceso supervisor; sus reinicios no resetean presupuesto3/hora por contenedor.

Arrancara al iniciar UbuntuWSL segun multi-user.target, NO inicia la distro con Windows. No se hizo prueba real de reboot porque estaba prohibida. Journald recoge stdout/stderr; hay /var/log/journal existente, sin cambiar retencion global. El JSONL/estado permanece en su ruta externa original.

## Reversion a manual, solo cuando se solicite

Registrar si mantenimiento estaba activo y activacion vigente. Activar mantenimiento y exigir salida0 antes de intervenir. Despues:

```sh
sudo systemctl disable --now tickets-supervisor.service
# Confirmar inactive antes de continuar:
systemctl show tickets-supervisor.service -p ActiveState -p MainPID
python3 infra/supervision/verificar_unidad.py
python3 infra/supervision/control_supervision.py iniciar --modo vigilar
```

El preflight exige ausencia de bucles, mismo usuario y estado valido. El controlador revalida IDs armados sin regenerarlos y actualiza metadata manual. Si estaba suspendido, iniciar --modo observar en vez de rearmar. Retirar mantenimiento solo si no existia previamente y la nueva instancia/estado estan verificados. No borrar ni sustituir estado.json/activacion con copias viejas. No usar pkill ni git restore/reset, no ejecutar compose up/down ni tocar contenedores.

Si unidad falla en futuro: conservar mantenimiento, consultar status/journal y no iniciar manual hasta confirmar servicio detenido/deshabilitado. No reset-failed repetidamente ni dejar dos gestores. El archivo unit puede conservarse deshabilitado para revision; si se desea retirarlo, verificar propiedad y contenido de esta instalacion antes de eliminar unicamente ese archivo y hacer daemon-reload. No borrar configuraciones del sistema ni directorio de estado.

No se necesito rollback durante esta migracion. Instalacion y guardas validadas con servicio real; recuperacion de systemd tras un crash del supervisor y arranque de WSL tras reboot no se indujeron, siguen sin ensayo real.
