# Sesión persistente y dispositivo físico en LAN

## Problemas y diagnóstico previo

El APK de la validación anterior utilizaba `API_BASE_URL=http://127.0.0.1:5263` y un puente `adb reverse tcp:5263 tcp:5263`. Esa dirección apunta al teléfono; el puente ADB la llevaba al equipo únicamente mientras existía conexión USB. La API escuchaba en loopback (`127.0.0.1`/`::1`) mediante el perfil `http`, por lo que tampoco era accesible directamente desde la LAN. Al comenzar esta etapa no quedaban redirecciones ADB activas.

La pérdida de sesión era independiente: ServicioSesion conservaba identidad/JWT únicamente en memoria. El cierre del proceso Android eliminaba ambos.

Android ya tenía permiso INTERNET y cleartext HTTP únicamente en debug. No se modificó esta política ni la autenticación API. No se ejecutaron emuladores ni cambios PostgreSQL.

## Desarrollo LAN

Desde `api/`:

```powershell
dotnet build
dotnet run --launch-profile lan
```

El nuevo perfil `lan` escucha en `http://0.0.0.0:5263` exclusivamente con ASPNETCORE_ENVIRONMENT=Development. Los perfiles http/https anteriores se conservan. No configura producción; HTTP LAN se utiliza solamente en debug y una red de desarrollo confiable. El JWT viaja por HTTP en este escenario; producción debe usar HTTPS.

Obtener la IP IPv4 LAN del equipo y configurar externamente, desde `mobile/`:

```powershell
$env:API_BASE_URL = 'http://IP_DEL_EQUIPO:5263'
flutter build apk --debug "--dart-define=API_BASE_URL=$env:API_BASE_URL"
adb -s ID_DISPOSITIVO install -r build/app/outputs/flutter-apk/app-debug.apk
```

Sustituir el placeholder únicamente en la configuración local. La IP efectiva no se guarda en código, tests ni Git. Teléfono y equipo deben compartir LAN y la API estar ejecutándose. Un cambio de IP requiere recompilar con el nuevo dart-define. ConfiguracionApi permanece centralizada: localhost para Windows, 10.0.2.2 para un emulador si se utilizase fuera de estas pruebas, IP_DEL_EQUIPO para teléfono físico, y HTTPS del servidor posteriormente.

ADB reverse sigue siendo una opción de desarrollo por USB, pero este APK LAN no lo requiere. La instalación por USB tampoco implica que la conexión REST utilice USB.

### Firewall

La red del equipo era privada y el firewall estaba activo. No se añadió, eliminó o deshabilitó ninguna regla. La prueba manual confirmó acceso LAN sin USB.

Si posteriormente una red privada bloquea el puerto, revisar primero escucha de Kestrel y dirección del equipo. Solo con autorización administrativa explícita se podría crear una regla limitada a TCP 5263, perfil Private y LocalSubnet:

```powershell
New-NetFirewallRule -DisplayName 'Tickets API LAN desarrollo' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5263 -Profile Private -RemoteAddress LocalSubnet
```

Este comando se documenta; no se ejecutó. No deshabilitar Windows Firewall ni abrir indiscriminadamente perfiles públicos.

## Persistencia y responsabilidades

ServicioAutenticacion recibe la respuesta HTTP existente. ControladorLogin coordina ServicioSesion y espera persistencia exitosa antes de navegar a Home; elimina el campo de contraseña después del intento. No escribe SQLite, no accede al plugin y no decodifica JWT.

ServicioSesion es la fachada única: usuario, existeSesion, token para consumidores autorizados, requiereReautenticacion, establecer, restaurar, limpiar y marcarReautenticacion. RepositorioSesionLocal realiza almacenamiento mediante OperacionesSqlite y AlmacenamientoTokenSeguro. La abstracción pequeña AlmacenamientoToken permite sustituir el plugin en pruebas.

| Almacenamiento | Contenido |
|---|---|
| SQLite `sesion_local` | Una fila fija `id=1`, `id_usuario`, `username`, `nombre`, `autenticado_en` UTC, `expira_en` UTC opcional |
| flutter_secure_storage | JWT exclusivamente, bajo la clave propia `token_sesion` |
| Memoria | Identidad restaurada, JWT recuperado, estado de acceso remoto y resultado de comprobación de pendientes al salir |

No se persisten contraseña, PasswordHash, ConnectionString, JWT secret ni credenciales PostgreSQL. SQLite normal no protege secretos; por esa razón no contiene Bearer token. La única dependencia directa nueva es [flutter_secure_storage 11.2.0](https://pub.dev/packages/flutter_secure_storage/versions/11.2.0), estable y compatible con esta compilación. Su implementación protege el JWT mediante almacenamiento del sistema operativo.

Android deshabilita backup de la aplicación para evitar restaurar sesión y datos cifrados sin la clave correspondiente después de reinstalar. Un token sin identidad SQLite nunca crea sesión; el repositorio elimina ese token huérfano. En plataformas cuyo almacén seguro pueda sobrevivir una desinstalación, sigue siendo imprescindible la identidad SQLite propia para restaurar Home. No se validaron físicamente esas plataformas.

### Escrituras y fallos

No existe transacción distribuida entre SQLite y almacenamiento seguro. Al guardar, se elimina primero la identidad anterior, se guarda JWT protegido y finalmente se inserta identidad. Un fallo de inserción intenta retirar JWT. Un cierre entre pasos puede exigir login de nuevo, pero impide asociar JWT nuevo a una identidad anterior. La cola nunca se modifica por este proceso.

Si almacenamiento falla, login no navega como si persistencia hubiera tenido éxito. Arranque muestra un mensaje genérico y Reintentar; no interpreta un fallo de lectura como sesión inexistente. Logout permite reintentar si no termina el borrado. No se muestran errores técnicos, cuerpos HTTP ni secretos.

## SQLite v2

ConfiguracionSqlite.version pasa de 1 a 2. onCreate crea cola técnica e identidad. La migración onUpgrade v1 → v2 crea únicamente `sesion_local`; no elimina tablas, no borra el archivo y no altera registros de `cola_sincronizacion`. Una migración desconocida sigue rechazándose sin recrear la base destructivamente.

La prueba de migración utiliza un archivo real v1 con una operación pendiente: abre en v2, comprueba versión/registro, persiste sesión, cierra la conexión y vuelve a abrirla conservando identidad.

## Arranque y offline

GetX inicia `/arranque`: VistaArranque muestra carga mínima mientras ControladorArranque solicita restauración exclusivamente a ServicioSesion. Después resuelve:

- Identidad local válida → `/inicio` (Home), sin petición HTTP.
- Sin identidad → `/login`, sin credenciales precargadas.
- Fallo de almacenamiento → mensaje controlado y reintento.

Login no aparece fugazmente antes de Home. Home mantiene su diseño y obtiene el usuario mediante ControladorInicio/ServicioSesion. Una sesión previamente autenticada restaura incluso sin red; IndicadorDesconexion conserva su comportamiento. Primera instalación sin sesión no autentica offline: se mantiene Login y se comunica que necesita conexión.

ServicioConectividad representa conectividad del dispositivo, no salud de la API. Wi-Fi con API apagada no se presenta como ausencia de red. ServicioSincronizacion conserva comprobación manual de health independiente.

## Caducidad, 401 y logout

El cliente lee únicamente `exp` para anticipar caducidad; no valida firma JWT ni utiliza claims como identidad. La API sigue siendo autoridad de autenticación. JWT ausente, expirado o de formato desconocido conserva identidad local pero requiere reautenticación remota; token no se entrega para peticiones protegidas.

ServicioSincronizacion.puedeIntentarEnvio requiere red y token disponible. registrarEstadoProtegido(401) prepara el tratamiento futuro: marca reautenticación y elimina JWT protegido, preservando identidad y cola. No se implementan envíos de negocio, refresh token, formulario adicional ni sincronización de Tickets.

Logout comprueba operaciones en cualquier estado distinto de sincronizado, incluidas pendiente, procesando y error. Expone pendientesAlCerrar y elimina solamente identidad/JWT/memoria. Después de cerrar/reabrir se obtiene Login. La cola permanece intacta.

La autoría de futuras operaciones sigue pendiente: antes de enviar Tickets habrá que asociar o restringir las operaciones al técnico que las creó. No debe enviarse la cola anterior bajo otro usuario ni borrarse al salir. En esta etapa no hay operaciones reales de Tickets ni envíos que puedan mezclar usuarios.

## Validación de esta etapa

- dotnet build: correcto, 0 warnings y 0 errores.
- API ejecutada con perfil lan, escucha comprobada en 0.0.0.0:5263.
- health, login y /me: HTTP 200; credencial demo leída únicamente desde DATOS_PRUEBA.md; JWT no impreso.
- Flutter analyze: sin incidencias.
- Flutter test: 50 pruebas correctas y 2 pruebas opt-in omitidas en la ejecución normal.
- Test opt-in Flutter real de autenticación: correcto; login y /me comprobados con la credencial pública externa. La integración Android automatizada se adaptó a IO persistente, pero no se volvió a ejecutar en esta etapa porque el dispositivo se desconectó para la prueba manual.
- APK debug LAN: compilado e instalado correctamente en dispositivo físico.
- Sin emuladores; sin redirecciones adb reverse activas para esta validación.

Se preparó el APK, se dejó API LAN ejecutándose y se solicitó al usuario realizar A/B/C/D con el cable desconectado. ADB dejó de listar el dispositivo. El usuario respondió «funciona bien». Esta confirmación se registra como validación manual del flujo solicitado:

| Prueba física solicitada | Resultado informado por el usuario |
|---|---|
| A: nuevo login con USB desconectado y misma LAN | Correcto |
| B: cerrar completamente y reabrir → Home | Correcto |
| C: desconectar red y reabrir → Home offline | Correcto |
| D: logout y reabrir → Login | Correcto |

Estos resultados provienen de la confirmación global del usuario, no de automatización ni capturas del teléfono mientras estaba desconectado. La desinstalación/reinstalación física no se realizó para conservar datos/evidencias. Se verifica una instalación nueva equivalente con almacenamiento vacío: no restaura identidad y elimina un token huérfano.

Las pruebas normales no dependen de PostgreSQL: SQLite real FFI, token protegido simulado y API simulada donde corresponde. Cubren identidad/JWT separados, restauración sin red, ausencia de sesión, caducidad, 401, logout con pendientes intactos, fallo del almacén seguro, migración con registros conservados, Home restaurado sin Login fugaz y rechazo de primer login sin conexión.

## Seguridad y límites

Se revisan archivos candidatos e historial contra secrets locales sin imprimirlos, además de patrones de tokens reales, claves privadas e IP LAN temporal. Los secretos no se modifican. Capturas, APK y configuración temporal permanecen fuera de Git. El APK normal no incluye credenciales demo mediante dart-define.

No hay protección completa frente a dispositivos comprometidos, revocación remota, refresh token ni bloqueo biométrico. No se agregó ninguna de esas funcionalidades. Windows conserva la limitación de symlinks de plugins: las dependencias se resolvieron y las validaciones Android/análisis/tests se ejecutan con --no-pub, sin cambiar Developer Mode.

Documentación del código: revisada en español. No se comentan archivos generados. Esta etapa termina antes de Tickets.
