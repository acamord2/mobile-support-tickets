# Validación y límites de reproducibilidad

Fecha de auditoría: 2026-10-21, America/Mexico_City. No se ejecutó una instalación limpia ni pruebas de estrés o caída real. No se reinició/recreó ningún contenedor por esta fase; no se modificó estado de systemd/supervisor, SQL, HBA, WAL, credenciales, SSH, ADB ni recursos.

## Evidencias realizadas

- Inventario de once contenedores por labels/proyecto, imágenes/tags/RepoDigests, mounts no secretos, comandos, puertos, redes, healthchecks y HostConfig real.
- PostgreSQL17.11 en ambos nodos, primario recoveryfalse/read_onlyoff, standbytrue/on, WALstreamingasync y retención1GB.
- Prometheus10/10targetsUP,14reglas; datasourceGrafana correcto y cinco dashboards/50paneles con series reales. Estado funcional se comprueba por probes, no solo scraping.
- API compiló con SDKWindows sobre fuentes WSL: cero errores/advertencias. Pruebas --separacion y --configuracion aprobadas: continuidad simulada120s, rutas y HTTP aislado,18casos configuración; ninguna base real detenida.
-29pruebas simuladas supervisor/systemd aprobadas. Mensajes motor_no_disponible/recuperacion_fallida en esa suite son fixtures, no incidentes reales.
- Validador monitoring: imágenes/digests/config/redes, cinco dashboards/50paneles, Blackbox, HAProxy, reglas y pruebas PromQL válidos. Preparación de réplica: imagen idéntica, red privada y volumen separado.
- Promtool activo validó prometheus.yaml, reglas.yaml(6) y supervision.yaml(8). Mermaid11.12.1 parseó arquitectura.mmd con NodeWindows y jsdom26.1.0 instalados solo en /tmp; Node10WSL no es compatible con ese parser moderno. XMLdrawio y referencias/celdas/parents/edges se validan estructuralmente; no se acredita apertura interactiva en diagrams.net.
- [Validador reproducible](../../infra/operacion/validar_documentacion.py): diez manuales, enlaces relativos, XML/JSON/YAML, ASTPython, sintaxis shell y Compose; no ejecuta scripts operativos.

## Lo que un clon NO contiene

Credenciales reales, claves SSH, archivo known_hosts verificado, dumps/globales/configuraciones privadas del servidor, marca auténtica de restauración, archivos/colas SQLite de teléfonos, volúmenes Docker y estado/cooldown/presupuesto del supervisor. Son deliberadamente externos. [Plantillas](plantillas/README.md) sustituyen estructuras, no evidencias ni secretos.

La imagen local tickets-api:fase12-3 debe reconstruirse; no tiene RepoDigest de registro. Imagen de reversión tickets-api:antes-fase12-3 no se distribuye ni se puede recrear por asumir que la fuente actual es anterior. Capturar una imagen/config previa real antes de futuros despliegues.

Ubuntu20.04/Engine27 no se equipara a instalación soportada actual. Tags de .NET y postgres:17 son móviles; comprobar digest/versión antes de usar otro host. No se aplican propuestas compose.recursos.yaml. No hay migrador automático de secretos/HBA/roles ni backup/MinIO/arranqueWindows.

## Dependencias de rutas locales

Ruta del clon /home/econt/practica/mobile-support-tickets, usuarioecont y distroUbuntu-20.04 aparecen en unidad systemd, verificar_unidad.py, acceso_local.py, scripts SSH y algunos validadores. Cambiar ubicación exige adaptar una copia revisada antes de instalar; no basta git clone a cualquier directorio. Wrapper Compose calcula raíz relativa. Rutas externas de Compose pueden reemplazarse mediante variables de .env.example.

HBAstandby contiene CIDRde la instalación; generar desde red real antes de arrancar otro entorno. No copiar un HBA/hostkey/slot de esta práctica como configuración universal. Permisos por columna deben compararse con consultas y catálogo; TEMP heredado de PUBLIC se documenta, no se revoca globalmente para aparentar aislamiento.

## Revalidar sin afectar servicios

```sh
python3 infra/operacion/validar_documentacion.py
python3 -m unittest discover -s infra/supervision -p 'pruebas_*.py'
python3 infra/monitoring/validar.py
python3 infra/replicacion/validar_preparacion.py
sudo python3 infra/supervision/comprobar_fase14.py --autorreparacion 1
```

No ejecutar pruebas --real, prueba_blackbox_real.py, SQLde creación ni scripts de recuperación para validar un commit. Las simulaciones no prueban caída real de primaria, agotamiento de presupuesto ni rebootWSL. Inventario y salud son una instantánea, no garantía futura.

## Validaciones adicionales de publicación

Flutter se copió desde las fuentes WSL a un directorio temporal Windows nuevo (lib/test/config); flutter analyze no encontró incidencias y flutter test aprobó98pruebas, con2integraciones optativas omitidas. No se tocó Android/APK/SQLite ni la copia de compilación anterior. El SDK Windows volvió a resolver cuatro dependencias de test en esa copia y ajustó analysis_options temporal: no se versionó ese lockfile ni se presenta como reproducción byte a byte del lock original.

Siete combinaciones Compose de todos los archivos existentes pasaron config --quiet, incluida propuesta recursos solo para validación estática. No se aplicó ninguna. Auditoría de437candidatos y849objetos históricos contra siete valores externos privados más indicadores de tokens/claves/JWT: sin hallazgos. Es un control de patrones/coincidencias, no una prueba matemática de ausencia de secretos desconocidos. Se repite sobre el índice final antes de publicar.

La utilidad nueva de generación externa se revisó estáticamente, no se ejecutó: por diseño rechaza el directorio existente y nunca cambia SQL. No se probó su instalación completa en un host limpio.

## Integridad Git y publicación

Se separaron251archivos cuyo contenido solo difería por CRLF/LF. No se normalizó el worktree. La revisión bruta diff --check refleja ese ruido y un espacio final preexistente de docs/instalacion.md; ese archivo no se incluyó. La selección explícita usa representación LF del índice y diff --cached --check con la misma política core.autocrlf por comando; sin cambiar configuración Git global.

Primer commit funcional: dd547fe (API/Flutter/pruebas de continuidad); segundo commit agrupa infraestructura, manuales y diagramas. La rama remota prueba_docker no existía en la comprobación previa; main permanece intacta. El resultado efectivo del push se entrega aparte, sin presumir éxito antes de ejecutarlo.

Una repetición del validador fue bloqueada inicialmente por revisión automática al interpretar --autorreparacion1 como activación. Se leyó su código y se acreditó que solo compara una métrica mediante assert, docker inspect y HTTPGET; la validación de solo lectura fue autorizada después y pasó. No se modificó la política ni el proceso supervisor.
