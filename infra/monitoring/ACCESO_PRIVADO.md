# Monitoreo privado, sin publicaciones Docker

Procedimiento único de acceso de navegador para el monitoreo privado. El estado, arranque, validaciones y recuperación se documentan en [README.md](README.md); este documento concentra el acceso temporal desde Windows.

## Diseño y límites

compose.monitoring.yaml no publica ningún puerto, tampoco en IPv6. Grafana y Prometheus conservan datos_grafana y datos_prometheus; retención 7 días y scrape 15 segundos. No se cambia compose.yaml, API, primario ni réplica. Las imágenes, secretos externos de solo lectura y healthchecks se conservan. unhealthy no provoca por sí solo un reinicio en Compose.

Red monitoreo (internal): Grafana -> Prometheus; Prometheus -> cAdvisor, Blackbox y PostgreSQL Exporter. Red motor_docker (internal): cAdvisor/Blackbox -> Socket Proxy. Red base_datos existente (internal): exporter -> postgres y Blackbox -> API:8080. Grafana no recibe acceso al socket ni a base_datos. El perfil monitoreo_replica está activo, también sin puertos publicados. Las redes internal impiden conectividad externa normal, pero no protegen frente al administrador del host o un contenedor comprometido en las mismas redes. Se verificó la ausencia de publicaciones Docker; eso no sustituye una prueba LAN del proxy temporal. No se afirma haber realizado esa prueba desde un equipo externo.

El socket Docker sigue siendo sensible incluso montado ro: HAProxy limita métodos y rutas. cAdvisor conserva PID/cgroup del host, capacidades y montajes ro previamente preparados. No introducir nuevos proxies Docker con -p.

## Acceso Windows recomendado: proxy temporal por stdio

Requisitos: Python 3 en Windows (py -3), python3 en Ubuntu-20.04, usuario econt con acceso a Docker. Acceso Docker equivale a privilegios elevados sobre ese host; no requiere sudo nuevo ni firewall. No se necesita un listener de acceso en WSL, cambios de red ni publicaciones Docker. Se abre únicamente un socket IPv4 127.0.0.1:13000 en Windows mientras el proceso permanece activo, y cada conexión cruza wsl.exe por stdin/stdout hacia la IP actual de Grafana. No registra peticiones ni secretos. Admite HTTP/WebSocket por transporte TCP, con timeout de inactividad de 120 segundos; reconectar si expira. No utilizar como servicio permanente ni para tráfico intensivo.

En PowerShell de Windows:

```powershell
py -3 "\\wsl$\Ubuntu-20.04\home\econt\practica\mobile-support-tickets\infra\monitoring\acceso_local.py"
# En otra terminal:
Start-Process 'http://127.0.0.1:13000'
# Comprobar listener IPv4 si CIM está disponible:
Get-NetTCPConnection -State Listen -LocalPort 13000 | Select-Object LocalAddress,LocalPort
# Alternativa sin CIM:
netstat -ano -p tcp | Select-String ':13000'
```

Debe aparecer exclusivamente 127.0.0.1, nunca 0.0.0.0, IP LAN o [::]. Desde otro equipo LAN comprobar que http://IP_LAN_WINDOWS:13000 no conecta; repetir con IP WSL si es enrutable. Un fallo por ausencia de servicio no demuestra aislamiento: probar mientras el proxy y Grafana estén operativos y localhost funcione. No se ha registrado una prueba desde un equipo externo; sigue siendo una comprobación del primer uso controlado. Si aparece acceso LAN, cerrar Ctrl+C y detener el acceso; no añadir reglas automáticamente. No abrir ni reenviar 13000 en router/Windows. Cerrar con Ctrl+C y confirmar que desapareció el listener. La sesión web usa admin_monitoreo y la contraseña externa mediante un canal privado; no copiarla a comandos o Git.

Este método evita la publicación localhost Docker afectada en versiones anteriores a 28. No constituye una prueba universal frente a proxies preexistentes, rutas especiales o software privilegiado de Windows; comprobar el listener y la LAN durante el primer uso.

## Reversión

Cerrar primero el proxy con Ctrl+C y confirmar que desapareció el listener 13000. Para detener únicamente monitoreo conservando volúmenes:

```sh
docker compose --env-file .env.example -f compose.yaml -f compose.monitoring.yaml --profile monitoreo stop grafana prometheus postgres_exporter blackbox cadvisor docker_socket_proxy
```

No borrar volúmenes ni retirar recursos externos. No retirar roles ni borrar volúmenes automáticamente. La variante previa de puertos publicados no debe recuperarse para acceder.

Referencia de seguridad de publicación Docker: https://docs.docker.com/engine/network/port-publishing/

El acceso SSH externo está pendiente de servidor confirmado: [../acceso_ssh/README.md](../acceso_ssh/README.md). No sustituye todavía el proxy local ni USB/ADB reverse.
