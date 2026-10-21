> Estado consolidado vigente: [manual de infraestructura](../../docs/infraestructura/README.md). Esta nota conserva antecedentes y propuestas de su fase; revisar el manual actual antes de operar.

> Actualizacion Fase13: acceso SSH **local temporal** para pgAdmin implementado; ver [FASE13.md](FASE13.md). Las referencias a servidor pendiente de este documento describen la auditoria anterior o acceso externo/Android, que sigue sin habilitarse.

# Acceso SSH pendiente de servidor verificado

No existe un servidor confirmado desde Android ni desde otra red. Por instrucción del usuario se conserva USB/ADB reverse. No se instaló/habilitó SSH, no se generaron claves todavía y no se modificó firewall ni se abrieron puertos. Hay cliente OpenSSH en Windows y binario sshd en WSL, pero no se observó listener22. Eso no acredita acceso remoto. No inventar host, puerto, usuario ni fingerprint.

## Auditoría de exposición actual

La API conserva publicación Docker5263:8080 en todas las direcciones WSL (IPv4/IPv6). No se amplió ni restringió para evitar perder acceso USB. No afirmar que está protegida por SSH o inaccesible desde LAN; eso requiere verificar Windows/WSL/Hyper-V y rutas desde otro equipo. Ningún PostgreSQL del proyecto publica puertos. Hay otras instancias ajenas con5432/5433; no tocarlas ni confundirlas con el proyecto.

Grafana no publica puertos Docker. acceso_local.py sigue disponible, bajo demanda, en Windows127.0.0.1:13000; no se observó listener13000 durante la auditoría. El túnel SSH no debe intentar ocupar13000 mientras ese proxy esté abierto. No usar docker -p, netsh ni cambios de firewall como parte de estos scripts.

## Preparación de clave, cuando se acuerde el servidor

Desde PowerShell, ejecutar preparar_clave.ps1. Solicita frase de paso mediante ssh-keygen y crea Ed25519 fuera de Git, en el perfil .ssh del usuario. No sobrescribe claves existentes. Distribuir únicamente el archivo .pub mediante un canal verificado; nunca copiar la clave privada al servidor, Git, chat ni logs. Revisar ACL del archivo privado y cargarlo en un agente SSH si procede. No almacenar la frase de paso en scripts.

Verificar fingerprint del servidor por un canal independiente antes de aceptar su clave en known_hosts. El túnel exige StrictHostKeyChecking=yes y no desactiva verificaciones. Un ssh-keyscan sin comprobación independiente no acredita identidad.

## Túnel Windows preparado

Definir los valores reales verificados antes de ejecutar; no se proporcionan valores ficticios utilizables:

```powershell
./infra/acceso_ssh/tunel_windows.ps1 -Servidor $ServidorSsh -Usuario $UsuarioSsh -Puerto $PuertoSsh -DestinoGrafana $IpPrivadaGrafana -ClavePrivada $RutaClaveExterna
```

El servidor SSH debe poder alcanzar API127.0.0.1:5263 y la IP Docker privada de Grafana:3000. Este diseño corresponde a un servidor en el host WSL/Docker; un bastión externo sin ruta a esos destinos no sirve automáticamente. Resolver la IP actual de Grafana en el host con docker inspect y verificar su red; puede cambiar al recrearla. Si SSH termina en Windows u otra máquina, revisar el destino y las rutas antes de usar el script.

El script abre solo127.0.0.1:15263 para API y127.0.0.1:13000 para Grafana. Ctrl+C cierra ambos. No usa -g ni binds0.0.0.0. Verificar listeners Windows y rechazo desde otro equipo mientras el túnel esté operativo. El túnel protege el transporte que lo cruza; no cierra por sí mismo la publicación existente5263.

Servidor futuro: preferir cuenta dedicada sin root, claves, sin autenticación por contraseña, sin agent/X11 forwarding y con PermitOpen limitado a los dos destinos comprobados. Son requisitos a revisar, no una configuración aplicada. Instalar/habilitar sshd o hacer cambios de firewall requiere aprobación y validación aparte.

## Android y conservación de USB

Cuando exista servidor accesible desde Android, usar un cliente SSH confiable con túnel local. Con OpenSSH, los argumentos son equivalentes a:

```sh
ssh -N -T -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=yes -i "$CLAVE_EXTERNA" -p "$PUERTO_SSH" -L 127.0.0.1:15263:127.0.0.1:5263 "$USUARIO_SSH@$SERVIDOR_SSH"
```

Verificar primero desde Android HTTP127.0.0.1:15263/api/health/database, login y lecturas. Ese túnel no cambia por sí solo la URL de Flutter: el APK actual conserva su configuración y el ADB reverse existente. Acordar la configuración definitiva de API_BASE_URL y probar el transporte antes de sustituirlo; no editar URLs ni recompilar un APK de prueba que reemplace su configuración normal silenciosamente. No ejecutar adb reverse --remove mientras la conexión SSH real no esté validada.

Durante esta ejecución adb devices no detectó teléfono; no se instaló APK ni se modificó ADB reverse. Las pruebas Flutter usaron HTTP simulado y SQLite en memoria.
