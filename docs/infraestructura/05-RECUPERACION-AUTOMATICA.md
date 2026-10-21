# Recuperación automática dentro de Ubuntu WSL

## Capas de salud y recuperación

Running significa proceso activo; healthy/unhealthy procede de healthcheck Docker; disponibilidad funcional exige HTTP/SQL correcto. API no tiene healthcheck Docker y se comprueba por HTTP. Target UP acredita scraping; Blackbox necesita probe_success.

Once contenedores tienen restart: unless-stopped. Recupera salida inesperada con Engine operativo; no repara unhealthy con PID vivo ni inicia Windows/WSL. docker stop es detención manual, no simulación SIGKILL. RestartCount Docker y solicitudes supervisor son métricas distintas. Recursos insuficientes pueden producir bucles; no hay garantía de recuperación de host roto.

[supervisor.py](../../infra/supervision/supervisor.py) corre como econt bajo tickets-supervisor.service. [politica.json](../../infra/supervision/politica.json): intervalo15s, gracia120s, tres fallos funcionales consecutivos, cooldown300s y máximo tres solicitudes por servicio/3600s. Acción única: docker restart de ID fijado y revalidado por nombre/proyecto/servicio. Presupuesto se guarda ANTES de actuar. No borrar contadores para desbloquear.

| Política funcional | Servicios |
|---|---|
| Autorreparación habilitada | api, grafana, blackbox, postgres_exporter, postgres_exporter_lectura |
| Alerta/diagnóstico, sin autoheal SQL | postgres, postgres_lectura |
| Observación | prometheus, cadvisor, docker_socket_proxy |
| Solo política Docker | supervision_metricas; fuera del conjunto autohealable |

Fallo de dependencia, OOM, detención, ID distinto o motor caído no autoriza reiniciar API para probar. PostgreSQL conserva recuperación Docker del proceso pero no autoheal funcional ni promoción automática: reinicios repetidos pueden agravar una recuperación.

## Persistencia y exclusión

/home/econt/.local/state/tickets-supervision contiene estado.json, activacion.json, latido.json, incidentes.jsonl, locks y metricas/supervisor.prom. Fuera de Git; no distribuir IDs/cooldowns del host como plantilla. Un contenedor recreado requiere revisión/rearmado explícito. Bloqueo de vida completa impide dos bucles y lock de ciclo serializa acciones de control. systemctl es autoridad actual, no el estado histórico de control_supervision.py.

```sh
systemctl is-active tickets-supervisor.service
systemctl is-enabled tickets-supervisor.service
systemctl show tickets-supervisor.service -p MainPID -p NRestarts -p User -p ExecMainStatus
sudo journalctl -u tickets-supervisor.service -n 50 --no-pager
sudo journalctl -u tickets-supervisor.service -f
```

## Mantenimiento y suspensión

Como econt desde raíz:

```sh
python3 infra/supervision/supervisor.py mantenimiento
# Trabajo autorizado y validaciones, conservando estado.
python3 infra/supervision/supervisor.py reanudar
# Suspender sin borrar presupuesto/historial:
python3 infra/supervision/supervisor.py suspender
```

Si lock ocupado, esperar al fin del ciclo y reintentar acotadamente; no borrar locks. Suspender vacía activación, no historial; reanudar mantenimiento no rearma. Solo con aprobación y validación de IDs:

```sh
python3 infra/supervision/supervisor.py habilitar --confirmar-proyecto mobile-support-tickets-prueba-docker
```

## Instalación systemd reproducible

Requiere PID1systemd, usuario/grupos existentes, permiso Docker y rutas absolutas adaptadas en unidad/verificador. En instalación NUEVA y sin otro proceso/estado previo: una-vez obtiene observación real sin reinicios; suspender crea activación vacía. No inicializar encima de estado existente ni copiar contadores del servidor anterior.

```sh
# SOLO nuevo estado, tras comprobar ausencia de instancia y datos anteriores:
python3 infra/supervision/supervisor.py una-vez
python3 infra/supervision/supervisor.py suspender
python3 infra/supervision/verificar_unidad.py
sudo systemd-analyze verify infra/supervision/tickets-supervisor.service
sudo install -m 0644 infra/supervision/tickets-supervisor.service /etc/systemd/system/tickets-supervisor.service
sudo systemctl daemon-reload
sudo systemctl enable --now tickets-supervisor.service
```

Revisar observación antes de habilitar IDs explícitamente. Estado actual instalado/habilitado, User/Group econt y SupplementaryGroups docker; ExecStart absoluto, Restart=on-failure/15s, StartLimit3/300s, journald, escritura limitada al directorio externo. After=docker.service ordena pero no arranca Docker por sí mismo. No instalar otra unidad para documentar.

Migración manual→systemd requiere mantenimiento y detener ordenadamente solo PID verificado antes de arrancar unidad. Reversión de gestión, no ejecutada aquí: mantenimiento; sudo systemctl disable --now tickets-supervisor.service; confirmar ausencia de proceso; conservar estado; python3 infra/supervision/control_supervision.py iniciar --modo vigilar, una sola instancia. No borrar estado ni reiniciar contenedores. [Migración histórica](../../infra/supervision/MIGRACION_SYSTEMD.md).

## Pruebas y límites acreditados

- SIGSTOP Blackbox real: recuperación supervisor102,68s de prueba. La detección funcional no implica que Docker healthcheck alcanzara unhealthy antes de recuperarlo.
- SIGKILL Blackbox real: recuperación Docker7,53s, semántica distinta de stop.
- Suite simulada cubre dependencias, fallos consecutivos, cooldown, presupuesto, mantenimiento e identidad; canario aislado cubrió healthchecks.
- No se acredita ensayo real de agotamiento del presupuesto, segundo fallo dentro de cooldown, reinicio completo WSL ni fallo provocado del supervisor recuperado por systemd. Un arranque observado tras reboot no sustituye ensayo controlado.

No ejecutar prueba_blackbox_real.py para publicar docs: interrumpe un servicio y requiere aprobación separada. No hay tareas de Windows ni garantía de arranque autónomo de la distribución.
