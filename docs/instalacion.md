# Instalación local: PostgreSQL, API y aplicación Android

Esta guía utiliza PowerShell en Windows. Ejecuta los comandos desde la raíz del repositorio, salvo cuando se indique `mobile/`. Sustituye los valores de ejemplo por los de tu equipo; no copies contraseñas reales a archivos versionados.

## 1. Herramientas necesarias

Instala y agrega al PATH:

- Git.
- .NET SDK 10.
- PostgreSQL 17, con pgAdmin o `psql`.
- Flutter; versión usada en el proyecto: 3.41.9, con Dart 3.11.5.
- Android Studio y Android SDK. Completa la instalación de SDK y herramientas que solicite Flutter; el proyecto compila Java/Kotlin con nivel 17.

Comprueba las instalaciones:

```powershell
git --version
dotnet --version
psql --version
flutter --version
flutter doctor
flutter doctor --android-licenses
```

Resuelve los problemas de la sección Android de `flutter doctor`. No necesitas iniciar un emulador. Para instalar en un teléfono, habilita Opciones de desarrollador y Depuración USB y autoriza el equipo en el dispositivo.

Si todavía no tienes el repositorio:

```powershell
git clone https://github.com/acamord2/mobile-support-tickets.git
Set-Location mobile-support-tickets
```

## 2. Crear la base PostgreSQL local

La base remota de la app es PostgreSQL. SQLite pertenece al teléfono y la aplicación la crea automáticamente; no debes crearla manualmente.

Elige un nombre para tu nueva base, por ejemplo `tickets_db`. Si eliges `tickets`, utiliza ese nombre también en la conexión del apartado siguiente.

### Opción A: pgAdmin

1. Conecta a tu servidor PostgreSQL local.
2. En Databases, selecciona Create → Database.
3. Escribe `tickets_db` y selecciona como propietario el usuario PostgreSQL que usarás para instalar y ejecutar la API.
4. Abre Query Tool conectado específicamente a esa base nueva y vacía.
5. Abre y ejecuta `database/PostgreSQL/v1/BD_COMPLETA.sql`.

El archivo completo instala estructura, función, vista y datos demo. No ejecutes después los archivos individuales, porque ya están incluidos. Es un instalador para una base vacía, no una migración para actualizar una base existente. La API no crea ni migra PostgreSQL.

### Opción B: terminal

Desde la raíz, usando un usuario con permiso para crear bases:

```powershell
psql -h localhost -p 5432 -U postgres -d postgres -W -c 'CREATE DATABASE tickets_db;'
psql -h localhost -p 5432 -U postgres -d tickets_db -W -v ON_ERROR_STOP=1 -f database/PostgreSQL/v1/BD_COMPLETA.sql
```

`-W` solicita la contraseña sin incluirla en el comando. Sustituye `postgres`, el puerto y el nombre de la base cuando corresponda. Si `psql` no está en PATH, utiliza su ruta dentro de la instalación de PostgreSQL.

Los usuarios de la aplicación son distintos del usuario de conexión PostgreSQL. Consulta las credenciales demo en `database/PostgreSQL/v1/DATOS_PRUEBA.sql` o en la tabla del README.

## 3. Crear los User Secrets de la API

`api/Tickets.Api.csproj` ya tiene un `UserSecretsId`, por lo que no necesitas ejecutar `dotnet user-secrets init`.

Guarda la conexión fuera del repositorio. Reemplaza TODOS los placeholders; la base debe ser la creada en el paso anterior:

```powershell
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=tickets_db;Username=TU_USUARIO_POSTGRESQL;Password=TU_PASSWORD_POSTGRESQL" --project api/Tickets.Api.csproj
```

Para crear una clave JWT aleatoria sin escribirla en archivos del repositorio ni mostrarla en la consola:

```powershell
$bytesClaveJwt = New-Object byte[] 48
$generadorJwt = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$generadorJwt.GetBytes($bytesClaveJwt)
$generadorJwt.Dispose()
$claveJwtLocal = [Convert]::ToBase64String($bytesClaveJwt)
dotnet user-secrets set "Jwt:Key" $claveJwtLocal 
Remove-Variable claveJwtLocal, bytesClaveJwt, generadorJwt
```

La clave debe cumplir al menos 32 caracteres y 32 bytes UTF-8. Cambiar su valor invalida los JWT firmados con la clave anterior y requiere volver a iniciar sesión para operar remotamente. User Secrets es almacenamiento local de desarrollo, no un almacén cifrado para producción. No publiques su archivo ni su contenido.

## 4. Seleccionar otros nombres de secrets

Hay dos conceptos diferentes: el identificador del almacén y las claves dentro de ese almacén.

### Cambiar las claves de conexión y JWT

La selección está en `api/appsettings.json`:

```json
"SecretsApi": {
  "ClaveConexionBaseDatos": "ConnectionStrings:DefaultConnection",
  "ClaveJwt": "Jwt:Key"
}
```

Estos son nombres públicos de claves, no sus valores. `ConfiguracionSecretsApi` los lee y la API busca los valores correspondientes en su configuración.

Por ejemplo, para seleccionar `ConnectionStrings:ApiPruebas` y `Jwt:ApiPruebas`:

1. Crea esas dos claves en el mismo almacén:

```powershell
dotnet user-secrets set "ConnectionStrings:ApiPruebas" "Host=localhost;Port=5432;Database=tickets_db;Username=TU_USUARIO_POSTGRESQL;Password=TU_PASSWORD_POSTGRESQL" --project api/Tickets.Api.csproj
```

2. Para la clave JWT, repite el bloque de generación del apartado 3 sustituyendo solamente `"Jwt:Key"` por `"Jwt:ApiPruebas"`.
3. Cambia únicamente la sección de selección:

```json
"SecretsApi": {
  "ClaveConexionBaseDatos": "ConnectionStrings:ApiPruebas",
  "ClaveJwt": "Jwt:ApiPruebas"
}
```

4. Reinicia la API. No necesitas cambiar C# ni eliminar las claves anteriores. Puedes conservar varias conexiones y elegir la que corresponda.

Cambiar `Database=...`, servidor, usuario o contraseña requiere actualizar el VALOR de la conexión seleccionada con `dotnet user-secrets set`; no implica cambiar su nombre. La API no crea una base porque cambies ese valor.

### Cambiar el almacén completo

En `api/Tickets.Api.csproj`, `IdentificadorAlmacenSecrets` define el identificador local y `UserSecretsId` utiliza esa propiedad:

```xml
<IdentificadorAlmacenSecrets>IDENTIFICADOR_DEL_ALMACEN</IdentificadorAlmacenSecrets>
<UserSecretsId>$(IdentificadorAlmacenSecrets)</UserSecretsId>
```

Modifica `IdentificadorAlmacenSecrets` solo si deseas usar otro almacén completo. Después vuelve a guardar las claves usando `--project api/Tickets.Api.csproj`: los comandos apuntarán al nuevo almacén. Los valores del almacén anterior no se copian automáticamente. Para elegir otras claves dentro del mismo almacén basta con cambiar `SecretsApi`.

### Variables de entorno

También puedes proporcionar configuración mediante variables de entorno. En sus nombres, `__` equivale a `:`. Para seleccionar las claves alternativas en la terminal actual:

```powershell
$env:SecretsApi__ClaveConexionBaseDatos = "ConnectionStrings:ApiPruebas"
$env:SecretsApi__ClaveJwt = "Jwt:ApiPruebas"
```

Sus valores pueden existir en User Secrets o en las variables `ConnectionStrings__ApiPruebas` y `Jwt__ApiPruebas`. Las variables de entorno tienen prioridad sobre User Secrets y `appsettings.json`; revisa posibles valores heredados si la API utiliza una configuración inesperada. User Secrets se carga automáticamente con el entorno `Development` usado por los perfiles siguientes.

## 5. Restaurar dependencias, compilar y arrancar la API

Desde la raíz del repositorio:

```powershell
dotnet restore api/Tickets.Api.csproj
dotnet build api/Tickets.Api.csproj --no-restore
dotnet run --project api/Tickets.Api.csproj --launch-profile lan --no-build
```

Deja esa terminal abierta. `lan` establece `Development` y escucha en `http://0.0.0.0:5263`; `0.0.0.0` indica todas las interfaces, no es una dirección para escribir en el navegador o en el teléfono.

Desde el equipo abre:

- Swagger: <http://localhost:5263/swagger>.
- Conectividad PostgreSQL: <http://localhost:5263/api/health/database>.

El health es anónimo: `200` con `database: connected` indica conexión; `503` con `database: unavailable` indica que debes revisar servidor, puerto, base y credenciales. No crea tablas. Si falla el arranque por configuración, revisa los nombres seleccionados, sus valores y la longitud JWT.

Para ejecutar exclusivamente en el equipo puedes usar `--launch-profile http` en lugar de `lan`. Para detener la API pulsa Ctrl+C.

## 6. Preparar Flutter y la conexión del teléfono

Abre otra terminal desde la raíz:

```powershell
Set-Location mobile
flutter pub get
flutter devices
```

Obtén la IPv4 del equipo con `ipconfig` y utiliza la interfaz de red que comparte conexión con el teléfono. Configura la URL solo en la terminal, sin cambiar archivos de la app:

```powershell
$env:API_BASE_URL = "http://IP_LAN_DE_TU_PC:5263"
```

Reemplaza `IP_LAN_DE_TU_PC` por la dirección real. El teléfono y la API deben tener acceso por red, y el firewall del equipo debe permitir el puerto TCP 5263 en esa red de desarrollo. Comprueba desde el navegador del teléfono `http://IP_LAN_DE_TU_PC:5263/api/health/database` antes de intentar login.

`localhost` en el teléfono apunta al teléfono. Conectar por USB no sustituye la conectividad LAN. La API debe seguir ejecutándose mientras utilizas funciones remotas. El primer login requiere conexión.

`API_BASE_URL` se incorpora al compilar; si cambia la IP/URL debes volver a generar e instalar el APK. No introduzcas conexión PostgreSQL ni clave JWT en esta variable.

## 7. Generar APK para 32 bits, 64 bits y universal

Ejecuta desde `mobile/`, después de configurar `API_BASE_URL`. Los comandos siguientes generan APK release para Android. El proyecto actualmente firma release con la clave debug: sirven para entrega/pruebas locales; no hay una firma de publicación configurada.

### ARM de 32 bits

```powershell
flutter build apk --release --target-platform android-arm --split-per-abi "--dart-define=API_BASE_URL=$env:API_BASE_URL"
```

Archivo: `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`.

### ARM de 64 bits

```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi "--dart-define=API_BASE_URL=$env:API_BASE_URL"
```

Archivo: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

### Todas las arquitecturas en un solo APK

```powershell
flutter build apk --release --target-platform android-arm,android-arm64,android-x64 "--dart-define=API_BASE_URL=$env:API_BASE_URL"
```

Archivo: `build/app/outputs/flutter-apk/app-release.apk`. Contiene ARM 32 bits, ARM 64 bits y x86_64; ocupa más espacio que los APK separados.

Aquí «multiplataforma» significa APK universal para varias arquitecturas Android. Un APK no se instala en iOS, Windows o macOS; esas plataformas requieren compilaciones independientes y no están validadas en este MVP.

### Generar los tres APK separados con un comando

```powershell
flutter build apk --release --split-per-abi "--dart-define=API_BASE_URL=$env:API_BASE_URL"
```

Genera `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk` y `app-x86_64-release.apk` en `build/app/outputs/flutter-apk/`. Detalle de arquitecturas y APK universal: [documentación oficial de Flutter](https://docs.flutter.dev/deployment/android#build-an-apk).

### APK debug para revisión física

```powershell
flutter build apk --debug "--dart-define=API_BASE_URL=$env:API_BASE_URL"
```

Archivo: `build/app/outputs/flutter-apk/app-debug.apk`.

## 8. Instalar conservando datos

Desde `mobile/`, con el dispositivo autorizado por USB:

```powershell
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Selecciona el nombre del APK generado si utilizas ARM específico o debug. Si hay varios dispositivos, usa `adb -s ID_DISPOSITIVO install -r RUTA_APK`. Abre la aplicación desde su icono.

`-r` reemplaza la app conservando datos cuando el identificador y la firma son compatibles. Si Android rechaza la firma o la actualización, detente y revisa el error; no desinstales ni borres almacenamiento para resolverlo. Autoriza la instalación USB cuando el teléfono la solicite.

## 9. Comprobación inicial

1. API ejecutándose y health conectado.
2. URL accesible desde el teléfono.
3. Login con una credencial demo de `DATOS_PRUEBA.sql`.
4. Home disponible y descarga inicial de datos.

SQLite y el almacén seguro se gestionan en el dispositivo. El trabajo offline necesita datos previamente descargados; los cambios pendientes se sincronizan cuando la app recupera conexión con una API accesible.

Esta guía documenta comandos; su creación no ejecuta instalaciones, modifica bases, cambia secrets ni genera APK.
