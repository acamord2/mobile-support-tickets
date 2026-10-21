# Manual de infraestructura

Auditoría del 21 de octubre de 2026, hora de Ciudad de México. Proyecto mobile-support-tickets-prueba-docker, rama prueba_docker. Se documenta el sistema observado; no se ensayó una instalación limpia ni se reiniciaron servicios.

1. [Arquitectura](01-ARQUITECTURA.md)
2. [Instalación Docker](02-INSTALACION-DOCKER.md)
3. [PostgreSQL y replicación](03-POSTGRESQL-REPLICACION.md)
4. [Monitoreo y Grafana](04-MONITOREO-GRAFANA.md)
5. [Recuperación automática](05-RECUPERACION-AUTOMATICA.md)
6. [CPU y memoria](06-RECURSOS-CPU-RAM.md)
7. [SSH y pgAdmin](07-ACCESO-SSH-PGADMIN.md)
8. [Operación y diagnóstico](08-OPERACION-Y-DIAGNOSTICO.md)
9. [Inventario Docker](09-INVENTARIO-DOCKER.md)
10. [Seguridad y secretos](10-SEGURIDAD-Y-SECRETOS.md)
11. [Validaciones y reproducibilidad](VALIDACION.md)

Diagramas: [draw.io editable](arquitectura.drawio), [Mermaid importable](arquitectura.mmd). Evidencia: [inventario verificado](inventario-verificado.json). Las notas anteriores en infra/ conservan antecedentes históricos; este manual consolida el estado vigente.

Los bloques con up, SQL, instalación systemd, claves o parada son procedimientos para un operador autorizado: no se ejecutaron durante esta documentación. compose.recursos.yaml sigue siendo propuesta y no se incluye en el arranque activo. MinIO, respaldos automáticos y arranque de Windows quedan pendientes.
