# SSH temporal y pgAdmin

Transporte local Windows→WSL, no SSH externo/LAN/Android. Fase16 observó sin listener2222; no lo inició. Scripts preparados y pruebas reales previas en [Fase13](../../infra/acceso_ssh/FASE13.md).

pgAdmin→Windows127.0.0.1:15432/15433→OpenSSH externo→sshdWSL127.0.0.1:2222→IP privadas PostgreSQL5432. PermitOpen y authorized_keys limitan ambos destinos reales. Nombres Docker no se suponen resolubles desde WSL/Windows.

SSH usa identidad de econt; SQL usa consultor_api/credencial externa distinta. [Perfiles sin password](../../infra/acceso_ssh/perfiles_pgadmin.json): SSH integrado pgAdmin desactivado para evitar duplicación.

| Perfil | Host | Puerto | DB/usuarioSQL |
|---|---|---:|---|
| Primario consulta |127.0.0.1|15432|tickets_db / consultor_api|
| Standby consulta |127.0.0.1|15433|tickets_db / consultor_api|

No usar5432/5433 de otros proyectos ni publicar PostgreSQL.

## Requisitos e identidad nueva

Cliente OpenSSH Windows, /usr/sbin/sshd existente WSL y privilegio root aprobado para proceso/config temporal. No instala/habilita ssh.service. Rutas/usuario/distro están fijados a la práctica: adaptar una copia revisada para otro clon.

```powershell
$repo = '\\wsl$\Ubuntu-20.04\home\econt\practica\mobile-support-tickets'
# Solo si no existe clave; solicita frase de paso:
& "$repo\infra\acceso_ssh\preparar_clave.ps1" -RutaClave "$HOME\.ssh\tickets_pgadmin_fase13\id_ed25519"
```

Proteger ACL privada fuera de Git. BatchMode requiere agente aprobado/desbloqueado si se usa frase; no retirarla para hacer funcionar el ejemplo. La práctica anterior usó identidad temporal sin frase y ACL estricta, no recomendación de credencial persistente. No copiar claves privadas ni passwords a perfiles.

## Inicio y host key

```powershell
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/acceso_ssh/sshd_pgadmin_temporal.py estado
# Solo si no está activo y se autorizó:
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/acceso_ssh/sshd_pgadmin_temporal.py iniciar
wsl -d Ubuntu-20.04 -u root -- ssh-keygen -lf /run/tickets-pgadmin-ssh/ssh_host_ed25519_key.pub
wsl -d Ubuntu-20.04 -u root -- cat /run/tickets-pgadmin-ssh/ssh_host_ed25519_key.pub
```

Comparar huella/clave pública obtenida por canal WSL confiable; registrar manualmente entrada `tickets-wsl-pgadmin TIPO_PUBLICO CLAVE_PUBLICA_VERIFICADA` en known_hosts dedicado de ese perfil. Nunca aceptar desconocidas automáticamente, StrictHostKeyChecking=no ni ssh-keyscan como única prueba. /run es efímero y una nueva host key tras reboot exige verificación local otra vez.

```powershell
& "$repo\infra\acceso_ssh\tuneles_pgadmin.ps1" -Accion Iniciar
& "$repo\infra\acceso_ssh\tuneles_pgadmin.ps1" -Accion Estado
Get-NetTCPConnection -State Listen -LocalPort 15432,15433 | Select-Object LocalAddress,LocalPort,OwningProcess
& 'C:\Program Files\pgAdmin 4\runtime\pgAdmin4.exe'
```

Esperado listeners solo127.0.0.1. Script resuelve IPs por labels/proyecto/servicio/red y exige coincidencia PermitOpen; no fija IPs de la documentación. OpenSSH -N/-T, IdentitiesOnly, StrictHostKeyChecking=yes, HostKeyAlias, BatchMode, ExitOnForwardFailure y keepalive. Si Windows no alcanza loopback WSL, detenerse sin cambiar bind0.0.0.0, netsh ni firewall.

sshd dedicado: PasswordAuthentication/PermitRootLogin no, AllowTcpForwarding local, GatewayPorts/X11Forwarding/AllowAgentForwarding/PermitTunnel/PermitTTY no, MaxSessions0, ForceCommand /bin/false. Solo túneles, no shell/comandos ni otros destinos. Fase13 probó rechazo shell/id/-R/API; no repetido en esta fase.

## Consultas y cierre

En ambos perfiles, autenticar SQL en diálogo privado:

```sql
SELECT current_user,current_database(),pg_is_in_recovery(),current_setting('transaction_read_only');
SELECT "Id","Name","Address" FROM public."Branches";
SELECT "Id","Title","Status" FROM public."Tickets" LIMIT 10;
```

Primario recoveryfalse, standbytrue; consultor read_onlyon en ambos por su ajuste de rol. [verificar_pgadmin.sql](../../infra/acceso_ssh/verificar_pgadmin.sql) comprueba permisos. SELECT*Users y paneles administrativos pueden fallar: no ampliar permisos; PasswordHash/Username no son columnas concedidas.

Cerrar sesiones pgAdmin, cliente y luego servidor:

```powershell
& "$repo\infra\acceso_ssh\tuneles_pgadmin.ps1" -Accion Detener
wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/acceso_ssh/sshd_pgadmin_temporal.py detener
```

Scripts verifican identidad PID/argumentos/fecha; servidor rechaza parada con hijos SSH. No killall ni borrar /run/sshd compartido, claves/logs/perfiles. No cambia ADB5263/API/SQL. No arranque persistente SSH ni tareas Windows.
