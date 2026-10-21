param([ValidateSet('Iniciar','Estado','Detener')][string]$Accion='Estado')
$ErrorActionPreference='Stop'
# Gestiona solo el proceso OpenSSH propio; no instala servicios ni modifica firewall.
$directorio=Join-Path $HOME '.ssh\tickets_pgadmin_fase13'
$estadoArchivo=Join-Path $directorio 'tunel.json'
function ObtenerProcesoPropio($estado) {
    $proceso=Get-CimInstance Win32_Process -Filter "ProcessId=$($estado.Pid)"
    if(!$proceso){return $null}
    if($proceso.Name -ne 'ssh.exe' -or !$proceso.CommandLine.Contains('tickets-wsl-pgadmin') -or !$proceso.CommandLine.Contains((Join-Path $directorio 'id_ed25519')) -or $proceso.CreationDate.ToUniversalTime().Ticks -ne ([datetime]$estado.Creado).ToUniversalTime().Ticks){throw 'PID no corresponde al tunel propio; no modificarlo.'}
    return $proceso
}
$estado=if(Test-Path $estadoArchivo){Get-Content $estadoArchivo -Raw | ConvertFrom-Json}else{$null}
if($Accion -eq 'Estado') {
    if($estado){$proceso=ObtenerProcesoPropio $estado; [pscustomobject]@{Activo=[bool]$proceso;Pid=$estado.Pid;Primario=$estado.Primario;Replica=$estado.Replica}}
    else{'No iniciado.'};return
}
if($Accion -eq 'Detener') {
    if(!$estado){throw 'No hay estado propio; no se detiene ningun proceso.'}
    $proceso=ObtenerProcesoPropio $estado
    if(!$proceso){throw 'El proceso propio ya no existe.'}
    Stop-Process -Id $estado.Pid
    'Tunel propio detenido; PostgreSQL/sshd/ADB permanecen.';return
}
if($estado -and (ObtenerProcesoPropio $estado)){throw 'Tunel ya activo.'}
foreach($puerto in @(15432,15433)) {
    if(Get-NetTCPConnection -State Listen -LocalPort $puerto -ErrorAction SilentlyContinue){throw "Puerto $puerto ocupado; no tocar proceso ajeno."}
}
$clave=Join-Path $directorio 'id_ed25519'
$conocidos=Join-Path $directorio 'known_hosts'
if(!(Test-Path $clave) -or !(Test-Path $conocidos)){throw 'Falta identidad o known_hosts verificado; no generar ni aceptar claves automaticamente.'}
$servidor=wsl -d Ubuntu-20.04 -u root -- python3 /home/econt/practica/mobile-support-tickets/infra/acceso_ssh/sshd_pgadmin_temporal.py estado
if($LASTEXITCODE -ne 0){throw 'No se pudo consultar sshd dedicado.'}
$servidor=$servidor | ConvertFrom-Json
if(!$servidor.activo){throw 'Iniciar primero sshd dedicado.'}
$ips=@()
foreach($servicio in @('postgres','postgres_lectura')) {
    $datos=wsl -d Ubuntu-20.04 -- docker inspect "mobile-support-tickets-prueba-docker-$servicio-1"
    if($LASTEXITCODE -ne 0){throw 'Contenedor no encontrado.'}
    $datos=($datos | ConvertFrom-Json)[0]
    if($datos.Config.Labels.'com.docker.compose.project' -ne 'mobile-support-tickets-prueba-docker' -or $datos.Config.Labels.'com.docker.compose.service' -ne $servicio -or $datos.State.Health.Status -ne 'healthy'){throw 'Identidad o salud PostgreSQL inesperada.'}
    $ip=$datos.NetworkSettings.Networks.'mobile-support-tickets-prueba-docker_base_datos'.IPAddress
    if($ip -notin $servidor.destinos){throw 'IP no coincide con PermitOpen; revisar antes de reiniciar SSH.'}
    $ips+=$ip
}
$argumentos=@('-N','-T','-p','2222','-i',('"'+$clave+'"'),'-o','IdentitiesOnly=yes','-o','StrictHostKeyChecking=yes','-o','HostKeyAlias=tickets-wsl-pgadmin','-o',('"UserKnownHostsFile='+$conocidos+'"'),'-o','BatchMode=yes','-o','ConnectTimeout=5','-o','ExitOnForwardFailure=yes','-o','ServerAliveInterval=15','-o','ServerAliveCountMax=3','-L',"127.0.0.1:15432:$($ips[0]):5432",'-L',"127.0.0.1:15433:$($ips[1]):5432",'econt@127.0.0.1')
$marca=Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$proceso=Start-Process -FilePath "$env:WINDIR\System32\OpenSSH\ssh.exe" -ArgumentList $argumentos -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $directorio "tunel_$marca.out") -RedirectStandardError (Join-Path $directorio "tunel_$marca.err")
Start-Sleep -Seconds 2
if($proceso.HasExited){throw "SSH termino; revisar log dedicado tunel_$marca.err; no cambiar red."}
$cim=Get-CimInstance Win32_Process -Filter "ProcessId=$($proceso.Id)"
[pscustomobject]@{Pid=$proceso.Id;Creado=$cim.CreationDate.ToUniversalTime().ToString('o');Primario=$ips[0];Replica=$ips[1]} | ConvertTo-Json | Set-Content $estadoArchivo
foreach($puerto in @(15432,15433)) {
    $listeners=@(Get-NetTCPConnection -State Listen -LocalPort $puerto)
    if(!$listeners.Count -or @($listeners | Where-Object {$_.LocalAddress -ne '127.0.0.1' -or $_.OwningProcess -ne $proceso.Id}).Count){
        Stop-Process -Id $proceso.Id
        throw 'Listener inesperado: se detuvo exclusivamente el tunel creado.'
    }
}
"Tunel propio activo PID $($proceso.Id):127.0.0.1:15432 y127.0.0.1:15433."
