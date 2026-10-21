# CPU, RAM, swap y OOM

[Inventario](09-INVENTARIO-DOCKER.md) y JSON registran límites efectivos de todos los servicios. API/ambos PostgreSQL siguen Memory=0/NanoCpus=0, sin límites específicos, sujetos al host WSL. No se aplicó compose.recursos.yaml.

Grafana: RAM768MiB, reserva256MiB, **RAM+swap total1024MiB**, CPU1. Swap adicional máximo256MiB, no1GiB. Aplicado en Fase15 por docker update sin recreación y persistido en compose.monitoring.yaml. No se ajustan recursos en esta documentación.

## Medidas

Docker stats Linux descuenta caché inactiva; working_set=uso menos inactive_file, incluye caché activa. RSS representa principalmente residente anónimo, no todo el coste. memory.current incluye anónimo/archivos/kernel; comparar con memory.max. memory.swap.current es aparte y no se vacía automáticamente al ampliar RAM. OOMKilled refleja estado del contenedor; revisar memory.events/eventos Docker. memory.events max acumulado no equivale a OOM.

MiB=2^20bytes/GiB=2^30. Sufijos Docker m/g son binarios. Reserva blanda no garantiza disponibilidad; CPU1 es cuota equivalente a núcleo lógico, no núcleo exclusivo ni afinidad.

```sh
docker stats --no-stream $(docker ps -q --filter label=com.docker.compose.project=mobile-support-tickets-prueba-docker)
docker inspect mobile-support-tickets-prueba-docker-grafana-1 --format '{{.HostConfig.Memory}} {{.HostConfig.MemoryReservation}} {{.HostConfig.MemorySwap}} {{.HostConfig.NanoCpus}}'
```

Para ruta cgroup real obtener PID y /proc/PID/cgroup, no asumir siempre system.slice. Medir memory.current/stat/events/pressure, memory.swap.current/max y cpu.max antes/después. Comparar deltas de contadores acumulados sin restablecer.

## Ajuste reversible completo

Requiere autorización por servicio: comprobar identidad/proyecto/ID, soporte cgroups/swap, memoria disponible/swap usado, salud, PID/StartedAt y contadores. No mantenimiento rutinario para ampliación segura.

```sh
# Ejemplo ya aplicado a Grafana; no repetir para documentar:
docker update --memory 768m --memory-reservation 256m --memory-swap 1024m --cpus 1 ID_GRAFANA_VERIFICADO
```

Verificar Memory805306368, Reservation268435456, MemorySwap1073741824 y NanoCpus1000000000; cgroupv2 memory.max805306368, memory.low268435456, memory.swap.max268435456 y cpu.max100000/100000. Compose persiste mem_limit/mem_reservation/memswap_limit/cpus; docker update solo modifica contenedor existente. En entorno comprobado no requiere recreación; imagen/mounts/env normalmente sí.

Reversión NO ejecutada; antes exigir total memory.current con margen bajo512MiB y ausencia de presión:

```sh
docker update --memory 512m --memory-reservation 0 --memory-swap 1024m --cpus 1 ID_GRAFANA_VERIFICADO
```

Revertir solo los tres campos de Grafana Compose, no restaurar archivo entero sobre cambios posteriores. Reducir puede provocar reclaim/OOM aunque working set parezca bajo.

## Historia, riesgos y propuestas

Fase15:16CPU lógicas,7,40GiB RAM/2GiB swap; historia disponible unas23,5h, no siete días. Pico Grafana working set510,61MiB bajo antiguo límite512; caché no demuestra fuga. [Informe histórico](../../infra/recursos/INFORME_FASE15.md) conserva medición previa.

Propuestas NO aplicadas: API512MiB/CPU1; primario1GiB/CPU1,5; standby1GiB/CPU1; Prometheus768MiB con reserva pendiente. compose.recursos.yaml contiene también propuestas de reservas/swap y se excluye del wrapper. Grafana ya está en archivo activo.

PostgreSQL: shared_buffers128MiB/work_mem4MiB/max_connections100; work_mem por operación/proceso no por servidor.1GiB no garantiza cien conexiones con hashes paralelos. .NET ServerGC interpreta cgroups, pero actualización kernel en caliente no acredita reajuste de decisiones de arranque: no aplicar API sin plan específico.

OOM puede activar restart Docker y generar bucles; supervisor lo clasifica diagnóstico, no autoheal funcional. No deshabilitar OOM killer. [Alertas propuestas](../../infra/recursos/alertas_propuestas.yaml) no cargadas: ratios memoria/límite, throttlingCPU, swap y eventos requieren series reales/filtros de límites no nulos. CPU elevada por sí sola no prueba fallo. No se hicieron pruebas de estrés.

[Semántica oficial recursos](https://docs.docker.com/engine/containers/resource_constraints/).
