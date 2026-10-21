> Estado vigente: **tickets-supervisor.service instalado y habilitado**, MainPID310723 al migrar. Ver [MIGRACION_SYSTEMD.md](MIGRACION_SYSTEMD.md); las notas de preparacion/ejecucion manual siguientes son historicas.

# Persistencia supervisor en systemd WSL: preparada, NO instalada

Auditoria2026-10-21: PID1=systemd, systemd245.4-4ubuntu3.24, systemctl running. Docker27.3.1 operativo. tickets-supervisor.service LoadState=not-found. Instancia manual PID200243 modo vigilar continua activa; no se detuvo ni reinicio. No acciones Windows, WSL, Docker o contenedores.

## Archivos y diseno

- tickets-supervisor.service: unidad propuesta, User/Group econt, SupplementaryGroups docker (pertenencia ya existente), WorkingDirectory absoluto y python3/script/estado explicitos. No root para el proceso; instalacion futura requiere sudo solo para unidad/manager.
- verificar_unidad.py: comprobacion previa sin escrituras ni acceso Docker: identidad/permisos, estado persistente valido, activacion permitida ({} respeta suspension) y ausencia de instancias observar/vigilar. No crea estado, arma IDs ni levanta Docker. Unidades con condiciones inexistentes no inicializan otro estado silenciosamente.
- pruebas_unidad.py: fixtures comprueban presupuesto intacto, suspension, rechazo de estado/roles no autorizados y procesos exactos; junto a pruebas previas29aprobadas.

ExecStart ejecuta directamente supervisor.py vigilar --estado /home/econt/.local/state/tickets-supervision. Type=simple conserva PIDprincipal real y stdout/stderr a journald. Restart=on-failure, RestartSec15s, limite3arranques/300s y TimeoutStopSec45s. Es limite de reinicios del PROCESO supervisor, independiente de presupuesto3/hora/servicio y restartDocker unless-stopped. Stop solicitado a systemd no reactiva el servicio por on-failure.

After=docker.service ordena arranque si ambos se inician en el boot, pero NO hay Wants/Requires/BindsTo: el supervisor no inicia/reinicia Docker ni desaparece automaticamente si el motor cae. La logica existente registra fallo de motor y no intenta acciones inseguras. No ExecStartPre docker info que impida observar Engine caido. systemd no garantiza la disponibilidad de dependencias: pruebas HTTP/SQL y gracia/cooldown siguen vigentes.

NoNewPrivileges, PrivateTmp, ProtectSystem=strict y ProtectHome=read-only; solo ReadWritePaths del directorio persistente. UMask0022 permite que metricas publicas sean legibles por UID65534 del servidor; el directorio base0700 sigue privado para estado/activacion. No se cambia ownership/permisos de archivos existentes. La capacidad Docker existente sigue siendo privilegiada: estas restricciones no convierten acceso Engine en aislamiento fuerte.

process.lock del supervisor dura toda su vida; ExecStartPre rechaza instancia manual activa. Si alguien intentara arrancar una segunda, fallaria sin reiniciar contenedores y systemd agotaria su limite. No usar reset-failed para ocultar duplicacion. El proceso manual actual aun no usa esta unidad: por eso el rechazo en auditoria es el resultado esperado.

systemd-analyze verify retorno0. Sus advertencias de RestartMode/ConditionEnvironment/LoadCredential corresponden a otras unidades de snapd/cloud-init/WSL en systemd245; no se editaron. Tambien hubo advertencias propias del entorno WSL al verificar, sin error de la unidad. La compatibilidad real de hardening y del servicio bajo systemd se verificara solo despues de autorizar instalacion: verificacion estatica no equivale a prueba runtime.

## Migracion propuesta: ejecutar SOLO tras autorizacion

En Ubuntu como econt, misma terminal para conservar variables; detener ante cualquier fallo. Antes, confirmar saludables los servicios y conservar baseline de IDs/StartedAt/RestartCount. No inducir otra prueba Blackbox.

```sh
cd /home/econt/practica/mobile-support-tickets
estado=/home/econt/.local/state/tickets-supervision
mantenimiento_previo=0
[ ! -e "$estado/mantenimiento" ] || mantenimiento_previo=1
# Adquirir mantenimiento sin ocultar lock ocupado: si falla, esperar fin de ciclo y reintentar.
python3 infra/supervision/supervisor.py mantenimiento
# Exigir salida0 antes de continuar; con lock obtenido se completo el ciclo previo.
respaldo="$estado/migracion_systemd_$(date -u +%Y%m%d_%H%M%S)"
mkdir -m 700 "$respaldo"
cp -p "$estado/estado.json" "$estado/activacion.json" "$respaldo/"
printf '%s
' "$mantenimiento_previo" > "$respaldo/mantenimiento_previo"
python3 infra/supervision/control_supervision.py detener
python3 infra/supervision/verificar_unidad.py
```

El controlador valida PID/script/start ticks antes de SIGTERM y espera salida. Se detiene unicamente el supervisor, no contenedores. No detener mediante pkill ni PID tomado sin verificar. Un reinicio que ya hubiera sido entregado al Engine no se cancela matando el CLI: mantenimiento y confirmacion de ciclo previo son necesarios para migracion ordenada.

Instalacion futura si no existe unidad ajena con ese nombre:

```sh
sudo test ! -e /etc/systemd/system/tickets-supervisor.service
sudo install -m 0644 infra/supervision/tickets-supervisor.service /etc/systemd/system/tickets-supervisor.service
sudo systemctl daemon-reload
sudo systemctl enable --now tickets-supervisor.service
systemctl is-active tickets-supervisor.service
systemctl show tickets-supervisor.service -p MainPID -p NRestarts -p User -p Group -p ExecMainStatus
sudo journalctl -u tickets-supervisor.service -n 50 --no-pager
```

Esta es la unica habilitacion prevista: arranque cuando Ubuntu WSL ya inicia. No inicia Windows ni la distro al encender Windows. No hay tareas Windows ni cambios de inicio WSL/Windows.

Validar un solo PIDvigilar, log de ciclos en journal, estado/cooldown/intentos acumulados y metricas mantenimiento1. El archivo observador.json contiene PID de instancia manual anterior; systemd MainPID pasa a ser autoridad de proceso. No usar control_supervision.py estado/detener para manejar la unidad: su metadata manual puede estar obsoleta. Su scanner/lock impediran iniciar un bucle manual mientras la unidad viva.

No ejecutar habilitar ni limpiar activacion.json: si estaba suspendido, permanece suspendido; si estaba armado, conservar IDs. Restaurar mantenimiento solo si no existia antes:

```sh
if [ "$mantenimiento_previo" = 0 ]; then
  python3 infra/supervision/supervisor.py reanudar
fi
```

Comparar presupuesto/reintentos_total/intentos/ultimo contra snapshot; estado healthy/mantenimiento y timestamps de observacion pueden cambiar normalmente. No restaurar ciegamente estado.json antiguo para hacer coincidir hashes. Probar API200, SQL/WAL,10targets,50paneles y ausencia de reinicios de contenedores; valor autorreparacion esperado1 solo si estaba armado y sin mantenimiento, en otro caso0. No simular fallos reales como parte de esta instalacion.

## Operacion futura

```sh
systemctl status tickets-supervisor.service --no-pager
sudo journalctl -u tickets-supervisor.service -f
python3 infra/supervision/supervisor.py mantenimiento
python3 infra/supervision/supervisor.py suspender
# No detener servicio para una pausa breve de autorreparacion; mantener observacion.
```

suspender vacia lista de IDs activos, pero conserva cooldown/presupuesto. No modificar ese estado ahora: estos comandos son para uso deliberado del operador. Para detener unidad, usar mantenimiento primero y confirmar fin de ciclo; despues sudo systemctl stop tickets-supervisor.service. Para reiniciar SOLO supervisor: sudo systemctl restart tickets-supervisor.service, igualmente sin accion en curso y conservando estado. No invocar restart Docker/WSL.

Journald recoge salida; duracion/retencion dependen de la configuracion existente y de /var/log/journal. No se modifica journald global ni se garantiza retencion ilimitada. Los incidentes JSONL y presupuestos conservan el almacenamiento externo persistente de antes. stdout del nuevo servicio va a journal; observador.log manual queda como historico.

## Reversion a proceso manual (solo si se instalo)

Primero mantenimiento y snapshot de sus condiciones actuales, no borrar estado. Luego:

```sh
sudo systemctl disable --now tickets-supervisor.service
systemctl is-active tickets-supervisor.service
# Esperar inactive y verificar que no queda proceso vigilar de la unidad.
python3 infra/supervision/verificar_unidad.py
python3 infra/supervision/control_supervision.py iniciar --modo vigilar
```

El controlador exige IDs vigentes y actualiza metadata manual, sin reiniciar presupuesto. Reanudar mantenimiento solo si procede segun estado anterior. Si se desea retirar archivo instalado, comprobar que pertenece a esta instalacion y coincide con copia revisada; eliminar unicamente /etc/systemd/system/tickets-supervisor.service y ejecutar daemon-reload. No borrar directorio de estado, archivos de evidencia, lockfiles para eludir exclusión, contenedores o volumenes. No restaurar backups de presupuesto obsoletos. Si unidad falla inicialmente, diagnosticar journal; no dejar corriendo dos gestores ni resetear limites repetidamente.

## Alternativa si systemd no estuviera disponible

No instalar ni habilitar la unidad. El controlador manual existente ya crea un proceso Ubuntu separado de la terminal mediante start_new_session; puede mantenerse como alternativa nativa bajo demanda, con sus locks y estado. No sobrevive a apagar WSL ni equivale a arranque al iniciar Ubuntu. Un init/gestor alternativo exigiria revisar requisitos y autorizacion; no instalar tecnologias ni tareas Windows automaticamente. En esta distribucion systemd SI esta disponible, por lo que no hace falta esa alternativa.

## Estado al entregar

Solo archivos nuevos en repositorio; unidad no instalada/habilitada. Instancia manual200243 continua, estado y marcadores no modificados por esta preparacion. No se reinicio ningun servicio de aplicacion, Docker, SSH, WSL o Windows. Pendiente autorizacion expresa para instalar/habilitar y sustituir ese proceso.
