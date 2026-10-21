# Fase13: SSH temporal pgAdmin implementado (2026-10-21)

Servidor dedicado /run/tickets-pgadmin-ssh/sshd_config, root, sin Include de configuracion SSH general. Solo127.0.0.1:2222, AddressFamily inet, claves, AllowUsers econt, AuthenticationMethods publickey, sin password/root login, AllowTcpForwarding local, PermitOpen solo IP actuales PostgreSQL:5432, sin forwarding de sockets Unix, GatewayPorts no, X11/agent/tunnel/TTY/userRC deshabilitados, MaxSessions0 y ForceCommand/bin/false. No se habilito ssh.service. Se creo /run/sshd porque OpenSSH8.2 requiere separacion de privilegios; no es un servicio y no se elimina automaticamente por poder ser compartido.

## Identidades y archivos externos

Host dedicado /run/tickets-pgadmin-ssh/ssh_host_ed25519_key (root0600), publico y authorized_keys root0644; directorio0755, config/estado0600. UsuarioSSH econt existente: no se modificaron grupos ni cuenta. La clave lleva restrict,port-forwarding y permitopen de ambos destinos. Las pertenencias locales previas sudo/docker no se modificaron; SSH no permite abrir sesiones de comandos/shell.

Windows: C:\Users\corre\.ssh\tickets_pgadmin_fase13\id_ed25519, ACL de lectura solo del usuario actual, sin herencia. Identidad temporal sin frase de paso para el proceso bajo demanda: debe tratarse como credencial sensible, no compartir/copiar a Git; su alcance limitado no sustituye proteger el perfil Windows. No se guardo password SQL. Clave host dedicada fijada por canal WSL local confiable en known_hosts del mismo directorio, HostKeyAlias tickets-wsl-pgadmin y StrictHostKeyChecking=yes. Huella host dedicada SHA256:UeveV9iYIyYCdwmqp896/V81SkDDkhcrdlNdognPBjU (diferente de la clave host global del documento de auditoria). No modificar claves globales. El servidor no recibe la clave privada Windows.

Logs/estado de cliente quedan en el mismo directorio externo; estado servidor y log en /run/tickets-pgadmin-ssh. Ni SQLpassword ni JWT aparecen en logs/comandos. Archivos de /run desaparecen al reiniciar WSL; una nueva clave host exige otra verificacion local explicita, nunca aceptar automaticamente una distinta.

## Inicio diario desde PowerShell

```powershell
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/acceso_ssh/sshd_pgadmin_temporal.py iniciar
$repo = '\\wsl$\Ubuntu-20.04\home\econt\practica\mobile-support-tickets'
& "$repo\infra\acceso_ssh\tuneles_pgadmin.ps1" -Accion Iniciar
& "$repo\infra\acceso_ssh\tuneles_pgadmin.ps1" -Accion Estado
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 2222,15432,15433 | Select-Object LocalAddress,LocalPort,OwningProcess
& 'C:\Program Files\pgAdmin 4\runtime\pgAdmin4.exe'
```

Los scripts rechazan un proceso activo propio duplicado, puertos ocupados y contenedores incorrectos/no healthy. El inicio del servidor descubre IPs en Docker y verifica labels, ausencia de publicaciones y pertenencia a base_datos interna; el cliente vuelve a descubrirlas y exige coincidencia con PermitOpen. Si cambian con SSH activo, cerrar primero tuneles/sshd y revisar antes de reiniciar. Nada amplia destinos automaticamente a otra red.

Si falla la conectividad loopback Windows2222, detenerse sin publicar0.0.0.0, netsh o firewall. Si cambia la clave host despues de reboot, comparar clave publica local y huella antes de actualizar el archivo dedicado. Comandos de lectura:

```powershell
wsl -d Ubuntu-20.04 -u root -- ssh-keygen -lf /run/tickets-pgadmin-ssh/ssh_host_ed25519_key.pub
wsl -d Ubuntu-20.04 -u root -- cat /run/tickets-pgadmin-ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf "$HOME\.ssh\tickets_pgadmin_fase13\known_hosts"
```

La entrada conocida tiene formato tickets-wsl-pgadmin seguido de la clave publica obtenida por WSL. Actualizarla manualmente solo tras verificar su origen. No usar ssh-keyscan como unica prueba ni desactivar StrictHostKeyChecking.

## Conexion pgAdmin

Perfiles preparados en perfiles_pgadmin.json, sin contraseñas y SSH integrado deshabilitado. Importar sin reemplazar otros perfiles o registrar manualmente:

| Perfil | Host | Puerto | DB | SQL usuario | SSH integrado |
|---|---|---|---|---|---|
| Primario consulta |127.0.0.1|15432|tickets_db|consultor_api|No|
| Standby consulta |127.0.0.1|15433|tickets_db|consultor_api|No|

Ingresar password SQL externo en el dialogo (no en JSON/argumentos). Ejecutar verificar_pgadmin.sql en Query Tool. No se modifico la base interna de pgAdmin ni se importaron perfiles automaticamente. Se probo el transporte real con psycopg del Python incluido en pgAdmin9.4: login consultor_api, SELECT sucursales/tickets y recovery falso/verdadero por15432/15433. Consultor devuelve transaction_read_only=on en ambos (no implica que el primario sea globalmente read-only). CONNECT si, SELECT limitado por columnas, sin DML, sin CREATE en base/public, PasswordHash denegado; TEMP de PUBLIC permanece. Algunos dialogos administrativos/SELECT* de Users podran fallar: no ampliar permisos.

## Pruebas realizadas

- Listener WSL127.0.0.1:2222; Windows lo alcanza sin reglas nuevas.
- Cliente autenticado con clave; pinning a clave host obtenida por canal local.
- Shell sin comando y comando id rechazados por MaxSessions0.
- Forward directo a127.0.0.1:5263 rechazado administrativamente.
- Forward remoto -R rechazado (AllowTcpForwarding local).
- Tuneles permitidos15432/15433 funcionan con SQL real y origen PostgreSQL172.27.0.1.
- Listeners Windows15432/15433 limitados a127.0.0.1; no0.0.0.0 ni:: en esos puertos. La exposicion LAN de toda la topologia no se declara certificada por falta de prueba desde otro equipo; no hay publicacion Docker PostgreSQL.
- Parada de proceso cliente propio y listener dedicada probada; reiniciados despues con misma huella. El guard Windows comparaba fecha serializada con DateTime: se corrigio a ticks UTC, manteniendo PID, nombre y argumentos; no se detuvo ningun proceso ajeno.

## Cierre y reversion exclusiva

Cerrar conexiones pgAdmin. Primero cerrar cliente, despues servidor:

```powershell
$repo = '\\wsl$\Ubuntu-20.04\home\econt\practica\mobile-support-tickets'
& "$repo\infra\acceso_ssh\tuneles_pgadmin.ps1" -Accion Detener
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/acceso_ssh/sshd_pgadmin_temporal.py detener
```

El cliente comprueba PID/nombre/argumentos y fecha de creacion UTC antes de Stop-Process. El servidor comprueba ejecutable/configuracion y rechaza detener si quedan procesos hijos: cerrar primero clientes, no matar procesos ajenos. Estado:

```powershell
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/acceso_ssh/sshd_pgadmin_temporal.py estado
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object LocalPort -in 15432,15433
wsl -d Ubuntu-20.04 -- ss -lnt
```

No borra claves, perfiles, logs, /run/sshd ni archivos existentes del sistema; solo detiene recursos propios. No down/prune/volumenes ni cambios SQL. Flutter, ADB5263, API, PostgreSQL, WAL, HBA, monitoreo y otros proyectos quedan intactos. Los tuneles quedan activos al entregar; volver a iniciarlos tras cerrar/reiniciar es manual.
