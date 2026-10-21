<# Abre solo listeners Windows loopback hacia un servidor SSH previamente verificado. No instala servicios ni modifica firewall. #>
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9.:-]*$')][string]$Servidor,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9_.-]+$')][string]$Usuario,
    [Parameter(Mandatory)][ValidateRange(1,65535)][int]$Puerto,
    [Parameter(Mandatory)][ValidatePattern('^[0-9.]+$')][string]$DestinoGrafana,
    [Parameter(Mandatory)][string]$ClavePrivada,
    [ValidateRange(1024,65535)][int]$PuertoApiLocal=15263,
    [ValidateRange(1024,65535)][int]$PuertoGrafanaLocal=13000
)
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $ClavePrivada -PathType Leaf)) { throw 'No existe la clave privada externa.' }
$argumentosSsh=@('-N','-T','-o','ExitOnForwardFailure=yes','-o','StrictHostKeyChecking=yes','-o','IdentitiesOnly=yes','-o','ServerAliveInterval=30','-o','ServerAliveCountMax=3','-i',$ClavePrivada,'-p',"$Puerto",'-L',"127.0.0.1:${PuertoApiLocal}:127.0.0.1:5263",'-L',"127.0.0.1:${PuertoGrafanaLocal}:${DestinoGrafana}:3000","${Usuario}@${Servidor}")
& ssh @argumentosSsh
exit $LASTEXITCODE
