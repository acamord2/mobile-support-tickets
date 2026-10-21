> Actualizacion Fase13: acceso SSH **local temporal** para pgAdmin implementado; ver [FASE13.md](FASE13.md). Las referencias a servidor pendiente de este documento describen la auditoria anterior o acceso externo/Android, que sigue sin habilitarse.

# Acceso pgAdmin por SSH: auditoría y preparación, 2026-10-21

Nada de este documento habilita un servidor ni publica PostgreSQL. No se modificó API, Android, HBA, roles, WAL, firewall ni servicios. ADB reverse5263 permanece. No utilizar los PostgreSQL ajenos publicados en5432/5433.

## Estado verificado

pgAdmin9.4 instalado en Windows; ejecutable C:\Program Files\pgAdmin 4\runtime\pgAdmin4.exe. SUPPORT_SSH_TUNNEL=True. Existe OpenSSH cliente Windows y binario sshd WSL, pero no listener SSH ni proceso servidor. sshd -T falla: Missing privilege separation directory: /run/sshd. No se creó ese directorio. Configuración visible: PasswordAuthentication no, ChallengeResponseAuthentication no, UsePAM yes, X11Forwarding yes; no es prueba de configuración efectiva de un servidor activo. Hay claves de host públicas existentes, sin leer claves privadas.

Red Docker privada base_datos:172.27.0.0/16. IP actuales primario172.27.0.5 y standby172.27.0.6;5432 sin publicación en ambos. WSL conecta a ambas con origen172.27.0.1. postgres/postgres_lectura NO resuelven en el host WSL. IP eth0 WSL actual172.18.203.157: es dinámica, no una dirección SSH autorizada ni un destino para publicar.

Se autenticó consultor_api por TCP desde la red del host WSL con contraseña externa en memoria, usando psql en el namespace de archivos del contenedor sin entrar en su red. Primario recovery=false; standby=true. Ambas sesiones transaction_read_only=on (el primario sigue siendo capaz de escribir para los otros roles autorizados). CONNECT=true; CREATE en base/public=false; cero tablas con escritura por tabla o columna; PasswordHash=false. TEMP=true heredado de PUBLIC; no se cambió. SELECT por columna en siete tablas; Roles/objetos no necesarios restringidos. Por ello pgAdmin puede mostrar errores en paneles administrativos o SELECT * de Users: no ampliar permisos para ocultarlos. Usar verificar_pgadmin.sql y columnas explícitas.

## Decisión de túnel

El código instalado web/pgadmin/utils/driver/psycopg3/server_manager.py crea SSHTunnelForwarder sin ssh_host_key ni local_bind_address. La librería instalada documenta bind por defecto0.0.0.0 y puerto aleatorio. No se acredita pinning de host con ese camino. Se prefiere UN proceso OpenSSH externo con dos forwards127.0.0.1 y verificación estricta, sin duplicar túneles integrados. No editar código de pgAdmin.

Arquitectura: pgAdmin Windows ->127.0.0.1:15432/15433 -> OpenSSH Windows -> servidor SSH loopback WSL por habilitar -> IP privadas Docker:5432. El túnel SSH exige autorización aparte. Hoy no puede abrirse.

## Servidor propuesto; NO aplicado

Proponer sshd dedicado, configuración externa, foreground/bajo demanda, solo127.0.0.1:2222, sin instalar ni habilitar servicio persistente. Puerto2222 es propuesta, no listener existente. Usar cuenta Linux econt existente, sin crear administradores, sin añadir grupos sudo/docker. Clave Ed25519 con frase de paso fuera de Git. Revisar ACL Windows y permisos de authorized_keys. Configurar AllowUsers econt, PermitRootLogin no, PubkeyAuthentication yes, PasswordAuthentication no, KbdInteractiveAuthentication no, X11Forwarding no, AllowAgentForwarding no, AllowTcpForwarding local, GatewayPorts no, PermitTunnel no, PermitTTY no y MaxSessions0. Validar directivas soportadas con sshd -t/-T antes de arrancar. PermitOpen debe limitarse a172.27.0.5:5432 y172.27.0.6:5432 vigentes. Restringir también la clave en authorized_keys: restrict,port-forwarding y permitopen de ambos destinos; no from hasta comprobar el origen real de Windows/WSL.

MaxSessions0 impide sesiones de shell/subsistema pero permite forwarding; claves robadas aún permiten acceso a ambos destinos con autenticación SQL adicional. No autorizar forwarding remoto ni otros puertos. Si cambian IP Docker, detener túnel y revisar PermitOpen; no automatizar ampliación. Necesita permisos elevados para el proceso sshd y sus archivos host externos, con autorización específica. No cambiar sshd_config global ni habilitar una cuenta nueva.

Verificar primero ruta Windows127.0.0.1:2222 hacia el listener WSL; no presuponer funcionamiento del forwarding localhost WSL. Si falla, detenerse: no netsh, binds LAN ni firewall como alternativa automática. Verificar listeners en Windows y WSL y no afirmar aislamiento LAN sin una prueba desde otro equipo. Docker27 tiene riesgo documentado de puertos publicados a loopback accesibles desde el mismo segmento L2; por eso no se usa docker -p ni se publica5432. OpenSSH -L no usa ese NAT, pero tampoco prueba por sí solo el aislamiento de toda la topología.

## Identidad del host, antes de conectar

Leer por canal local WSL la clave PÚBLICA /etc/ssh/ssh_host_ed25519_key.pub, contrastar ssh-keygen -lf con SHA256:TPgGoA39/LRlSzwkwNRtC7VxOIAVcR3i/ZQ+OStInEg (auditoría de hoy), y volver a verificar si cambia. Guardar la línea pública con alias tickets-wsl-pgadmin en un known_hosts dedicado fuera de Git: $HOME/.ssh/known_hosts_tickets. No almacenar claves privadas en el servidor o repositorio, no confiar automáticamente en ssh-keyscan y no usar StrictHostKeyChecking=no. No se generaron claves ni se editaron authorized_keys/known_hosts en esta etapa.

## Inicio futuro desde PowerShell, tras autorización y validación SSH

Definir $UsuarioSsh con la cuenta aprobada, $PuertoSsh y $ServidorSsh con el endpoint ya comprobado, y $Clave con la ruta externa existente. No son credenciales SQL. Redescubrir destinos antes de cada inicio:

```powershell
$Primario = (wsl -d Ubuntu-20.04 -- docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mobile-support-tickets-prueba-docker-postgres-1).Trim()
$Replica = (wsl -d Ubuntu-20.04 -- docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mobile-support-tickets-prueba-docker-postgres_lectura-1).Trim()
# Confirmar que coinciden con PermitOpen y la red172.27.0.0/16; no continuar si cambian.
ssh -N -T -p $PuertoSsh -i $Clave -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=tickets-wsl-pgadmin -o "UserKnownHostsFile=$HOME/.ssh/known_hosts_tickets" -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L "127.0.0.1:15432:${Primario}:5432" -L "127.0.0.1:15433:${Replica}:5432" "$UsuarioSsh@$ServidorSsh"
```

No ejecutar con variables sin definir. Mantener consola abierta; Ctrl+C cierra solo ambos túneles. En otra consola:

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 15432,15433 | Select-Object LocalAddress,LocalPort
Test-NetConnection 127.0.0.1 -Port 15432
Test-NetConnection 127.0.0.1 -Port 15433
& 'C:\Program Files\pgAdmin 4\runtime\pgAdmin4.exe'
```

Exigir LocalAddress127.0.0.1 en ambos; no aceptar0.0.0.0/:: como resultado. TCP abierto no sustituye validación SQL. Tras cerrar túnel, verificar que ya no hay listeners15432/15433.

## Perfiles preparados sin contraseñas

Importar perfiles_pgadmin.json mediante Tools/Import Export Servers (sin reemplazar servidores existentes), o crear manualmente:

| Nombre | Host Windows | Puerto | Base | Usuario SQL | SSH integrado |
|---|---|---|---|---|---|
| Tickets17 Primario consulta |127.0.0.1|15432|tickets_db|consultor_api|No|
| Tickets17 Standby consulta |127.0.0.1|15433|tickets_db|consultor_api|No|

SSL prefer no afirma TLS en Docker: SSH cifra Windows->WSL; el último tramo privado usa la configuración actual PostgreSQL. Introducir contraseña SQL desde el almacén externo autorizado en el diálogo, nunca en JSON, línea de comandos ni Git. No se importaron perfiles en la base interna de pgAdmin ni se copiaron secretos.

Ejecutar verificar_pgadmin.sql. Esperado: primario recovery=false, réplica=true; read_only=on para consultor en ambos, escritura=false, hash=false. No ejecutar escrituras para probar permisos. No usar el superusuario para desbloquear paneles.

## Autorización y reversión

Pendiente: aprobar creación de configuración SSH dedicada y authorized_keys externo, preparación de clave y arranque bajo demanda con alcance loopback/PermitOpen anterior. Sin cambios HBA/roles necesarios con la ruta ya comprobada. Después validar clave/Windows/LAN y abrir pgAdmin. Para revertir: Ctrl+C del cliente; cerrar el proceso sshd dedicado únicamente tras identificar su PID/config, retirar solo sus archivos/clave autorizada si se aprueba; conservar SSH ajeno, PostgreSQL, volúmenes, respaldos y ADB. Nunca borrar claves host globales.

Riesgo ajeno preservado: API5263 sigue publicada en WSL; otros proyectos5432/5433 también. Este diseño no asegura ni modifica esas publicaciones.
