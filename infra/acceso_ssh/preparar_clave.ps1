<# Genera una clave en el perfil del usuario, fuera del repositorio, sin sobrescribir archivos. Ejecutar cuando se acuerde el acceso SSH. #>
param([string]$RutaClave=(Join-Path $HOME '.ssh/tickets_tunel_ed25519'))
$ErrorActionPreference='Stop'
$raizRepositorio=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$rutaAbsoluta=[System.IO.Path]::GetFullPath($RutaClave)
if ($rutaAbsoluta.StartsWith($raizRepositorio,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'La clave privada debe estar fuera del repositorio.' }
if (Test-Path -LiteralPath $RutaClave) { throw 'La clave ya existe; no se sobrescribe.' }
if (Test-Path -LiteralPath ($RutaClave+'.pub')) { throw 'La clave pública ya existe; no se sobrescribe.' }
$carpetaClave=Split-Path -Parent $RutaClave
if (-not (Test-Path -LiteralPath $carpetaClave)) { New-Item -ItemType Directory -Path $carpetaClave | Out-Null }
Write-Host 'Introduce una frase de paso segura cuando ssh-keygen la solicite. No guardarla en el repositorio.'
& ssh-keygen -t ed25519 -a 100 -f $RutaClave -C 'tickets-tunel'
exit $LASTEXITCODE
