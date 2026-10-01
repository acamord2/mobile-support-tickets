# Gestión de incidencias técnicas

Repositorio público: [mobile-support-tickets](https://github.com/acamord2/mobile-support-tickets).

Línea base para una prueba técnica: plantilla Flutter con GetX, API ASP.NET Core .NET 10, Swagger y definición manual de PostgreSQL externo. No hay datos demo ni pantallas o endpoints de atención de incidencias.

## Estructura

```text
mobile/
  lib/
    main.dart
    app/routes/app_routes.dart
    app/routes/app_pages.dart
    app/network/       # HTTP, respuestas, códigos, rutas API y configuración
    app/constants/     # textos utilizados
    app/theme/         # colores y tipografía utilizados
    app/database/     # futura base local
    models/
    controllers/
    services/
    views/initial_view.dart
    widgets/
  test/
api/
  Controllers/
    Auth/LoginController.cs
    Auth/MeController.cs
    Health/DatabaseHealthController.cs
  DTOs/
  Models/
  Data/
  Services/
  Properties/
  Program.cs
  appsettings.json
  appsettings.Development.json
database/
  DATABASE.md
docs/
  linea-base.md
```

Las carpetas Flutter de modelos, controllers, servicios y base local todavía no tienen implementación. El código nativo generado por Flutter permanece en mobile. No se agregan capas adicionales.

## Requisitos

- Flutter 3.41.9 con Dart 3.11.5 (versiones utilizadas).
- SDK Android para compilar el APK.
- SDK .NET 10.
- PostgreSQL instalado y ejecutándose previamente y pgAdmin para crear la estructura manualmente.

## Crear manualmente la BD

Abrir `database/DATABASE.md` y seguir los bloques completos de SQL:

1. Query Tool conectado a postgres: crear tickets_db con autocommit, fuera de transacción.
2. Query Tool conectado a tickets_db: crear las cuatro tablas y sus constraints e índices.
3. Crear la función de consulta de usuarios ya existente.
4. Verificar mediante las consultas de lectura que una instalación nueva tiene cero filas.

DATABASE.md es la única definición SQL entregable. No hay scripts duplicados ni seed. La API no ejecuta ese documento ni crea bases, tablas o datos.

## Configurar y ejecutar la API

En desarrollo la conexión y la clave JWT se guardan en .NET User Secrets, fuera del repositorio. Los appsettings versionados contienen valores vacíos. Desde api/:

```sh
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=tickets_db;Username=postgres;Password=TU_PASSWORD"
dotnet user-secrets set "Jwt:Key" "TU_CLAVE_ALEATORIA_DE_AL_MENOS_32_BYTES"
```

Los valores TU_PASSWORD y TU_CLAVE_ALEATORIA_DE_AL_MENOS_32_BYTES son placeholders; deben sustituirse solo en la configuración local. User Secrets sirve para desarrollo y no es un almacén cifrado. No copiar secrets.json al repositorio.

ASP.NET Core carga User Secrets en Development después de appsettings; las variables de entorno pueden sobrescribir ambos. Para un futuro servidor Linux se usarían `ConnectionStrings__DefaultConnection` y `Jwt__Key` con valores provistos fuera del repositorio. No se configura ni despliega un servidor en esta etapa.

Desde api/:

```sh
dotnet restore
dotnet build
dotnet run --launch-profile http
```

Abrir [Swagger](http://localhost:5263/swagger). Se mantienen los perfiles originales: HTTP 5263 y HTTPS 7127. Swagger solo se habilita en Development y puede cargar sin usuarios o sin una conexión de BD disponible, porque el arranque no consulta PostgreSQL.

Se conserva la infraestructura de autenticación existente (JWT, PasswordHasher, DTOs, servicio y acceso de usuarios) sin ampliarla ni crear cuentas. Swagger muestra los endpoints anteriores; no se ofrece login demo ni se requiere comprobar un login exitoso en esta reorganización. Flutter no tiene login funcional.

La conexión se obtiene exclusivamente de ConnectionStrings:DefaultConnection. JWT conserva Issuer, Audience y ExpirationMinutes en appsettings.json; Key se obtiene de User Secrets en desarrollo. Ambas configuraciones pueden sobrescribirse mediante variables de entorno de ASP.NET Core. Fuera de Development debe proporcionarse la conexión correspondiente.

Cada endpoint existente tiene su propio Controller. Login conserva AuthService compartido; Me lee la identidad del JWT; DatabaseHealth utiliza IDatabaseHealthService y CanConnectAsync sin consultar tablas. GET /api/health/database es anónimo y devuelve 200/connected o 503/unavailable, sin información sensible.

PostgreSQL fue seleccionado para esta implementación. IUserDataAccess separa a la autenticación de PostgresUserDataAccess, de modo que otro proveedor relacional podría sustituirse adaptando el acceso y los objetos de BD sin cambiar el contrato HTTP. No se implementa SQL Server.

IConexion centraliza la apertura mediante Conexion. PostgresUserDataAccess utiliza DbCommand parametrizado y DatabaseHealthService comprueba únicamente la apertura. EF Core y AppDbContext se conservan sin uso ni registro activo, pendientes de una decisión posterior sobre su eliminación.

## Ejecutar Flutter

Desde mobile/:

```sh
flutter pub get
flutter run
```

main.dart inicia GetMaterialApp utilizando AppPages. Routes centraliza el único nombre de ruta y AppPages lo relaciona con InitialView. No hay rutas de pantallas futuras ni navegación funcional adicional.

Validaciones:

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## Infraestructura HTTP Flutter

Los futuros servicios dependerán de ApiConnection, registrado como Conexion mediante AppBindings de GetX. ApiClient conserva el transporte de bajo nivel para GET, POST, PUT, PATCH y DELETE. El consumidor elige una ruta de ApiRoutes, construye el payload JSON y aporta un token opcional. El cliente centraliza URL, headers, Bearer, serialización, timeout de 15 segundos y lectura de la respuesta. No guarda tokens ni implementa reintentos o sincronización. Las vistas y controllers no utilizan http directamente.

ApiResponse contiene statusCode, data, message y success. statusCode es null si no hubo respuesta HTTP; data es el JSON decodificado sin convertirlo a un modelo de negocio. Los 2xx son exitosos, incluidos cuerpos vacíos; un cuerpo no JSON produce un error explícito. Los errores HTTP conservan su código y datos. Timeout, API inaccesible y errores inesperados producen mensajes controlados. El consumidor debe cerrar ApiClient cuando deje de usarlo; el timeout limita la espera, pero no cancela automáticamente el transporte subyacente.

ApiConfig centraliza la URL mediante API_BASE_URL. Android Emulator usa por defecto `http://10.0.2.2:5263`, que permite alcanzar el host; Windows/local puede configurarse así:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:5263
```

Para un dispositivo físico, proporcionar en API_BASE_URL una URL de la API accesible desde su red. No usar localhost, que en ese caso identifica al propio teléfono. No se configuró acceso por LAN ni se probó un dispositivo físico.

Android tiene permiso INTERNET. Solo el manifiesto debug permite HTTP sin cifrar para la API local; las compilaciones release conservan la restricción predeterminada y deben utilizar HTTPS. No se agregó una pantalla para probar conectividad.

La suite habitual usa MockClient (incluido en http). La prueba real es opt-in y requiere API/PostgreSQL ejecutándose:

```sh
flutter test test/network/api_client_live_test.dart --dart-define=RUN_API_TEST=true --dart-define=API_BASE_URL=http://localhost:5263
```

AppTexts, AppColors y AppFonts centralizan únicamente los textos y estilos utilizados por la plantilla y sus mensajes HTTP. Las rutas GetX permanecen separadas de las rutas de la API.

Referencias de configuración: [red del emulador Android](https://developer.android.com/studio/run/emulator-networking-address), [tráfico HTTP en Android](https://developer.android.com/guide/topics/manifest/application-element#usesCleartextTraffic) y [cliente http de Dart](https://pub.dev/packages/http).

## Dependencias existentes

Flutter: GetX 4.7.3, http 1.6.0, Flutter Test y Flutter Lints 6.0.0.

API: Npgsql.EntityFrameworkCore.PostgreSQL 10.0.3, Microsoft.AspNetCore.Authentication.JwtBearer 10.0.12 y Swashbuckle.AspNetCore 10.2.3. EF Core y Npgsql son dependencias transitivas; PasswordHasher proviene del framework ASP.NET Core.

## Documentación y alcance

El código específico de la solución se documenta en español: XML en C# y comentarios /// en Dart, explicando intención, funcionamiento y decisión. DATABASE.md explica el SQL y sus restricciones. El boilerplate de las plantillas no necesita comentarios añadidos.

No se implementan login Flutter, tickets, historial, SQLite, fotografías ni sincronización. ApiClient está preparado y probado con health, pero ninguna pantalla consume la API todavía. La base local futura contendrá únicamente datos necesarios para offline y tendrá su propia abstracción; sus controllers no accederán directamente a SQLite. Estas decisiones todavía no constituyen funcionalidades.

La línea base anterior está registrada en docs/linea-base.md. El estado posterior y las validaciones de infraestructura reutilizable están en docs/infraestructura.md. El README final se ampliará conforme avance el proyecto.

La abstracción anterior está documentada en docs/conexiones.md; el estado actual, secrets y versionado se describen en docs/conexion-global.md.


## Versionado

La rama principal es main. Cada cambio lógico usa un commit claro con chore, refactor, feat, fix, test o docs. Antes de commit y push: ejecutar las validaciones correspondientes, revisar git status y diff staged, comprobar ausencia de secretos y publicar solo código compilable. No se utiliza Git Flow ni se crean ramas innecesarias.

## Decisiones de conexión

La clase Conexion de cada aplicación concentra el canal actual. Los consumidores usan IConexion en API y ApiConnection en Flutter; ApiConfig conserva URL y timeout. HTTP/HTTPS se selecciona con API_BASE_URL; configuración especial de certificados podría justificar otra implementación futura. Los proveedores externos tendrán contratos específicos, como AuthProvider, sin mezclarse con Conexion.

DbConnection se utiliza en código interno confiable. Su propiedad ConnectionString es estándar; los consumidores no la leen ni registran. PersistSecurityInfo=false oculta el password tras abrir. No se introduce una envoltura adicional para ocultar metadatos. Controllers y AuthService no reciben conexiones; DatabaseHealthService es la excepción de infraestructura, necesaria para validar la apertura sin consultas.

EF Core/AppDbContext no está registrado ni usado, no crea migraciones ni materializa datos. Se recomienda eliminarlo en una etapa posterior, previa aprobación explícita.
