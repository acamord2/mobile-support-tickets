# Gestión de incidencias técnicas

Repositorio público: [mobile-support-tickets](https://github.com/acamord2/mobile-support-tickets).

Línea base para una prueba técnica: plantilla Flutter con GetX, API ASP.NET Core .NET 10, Swagger y definición manual de PostgreSQL externo. Los datos demo opcionales se entregan como SQL manual; no hay pantallas o endpoints de atención de incidencias.

## Estructura

```text
mobile/
  lib/
    main.dart
    app/routes/rutas.dart
    app/routes/paginas_app.dart
    app/network/       # HTTP, respuestas, códigos, rutas API y configuración
    app/constants/     # textos utilizados
    app/theme/         # colores y tipografía utilizados
    app/database/     # futura base local
    models/
    controllers/
    services/
    views/vista_inicial.dart
    widgets/
  test/
api/
  Controllers/
    Auth/ControladorLogin.cs
    Auth/ControladorIdentidad.cs
    Health/ControladorSaludBaseDatos.cs
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
  DATOS_PRUEBA.md
  FUNCIONES_SP.md
  VISTAS.md
  TRIGGERS.md
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

La instalación se realiza manualmente mediante pgAdmin Query Tool. La API no instala ni ejecuta automáticamente ninguno de estos documentos:

1. [DATABASE.md](database/DATABASE.md): crear tickets_db y las tablas, restricciones e índices.
2. [FUNCIONES_SP.md](database/FUNCIONES_SP.md): instalar get_user_by_username.
3. [VISTAS.md](database/VISTAS.md): actualmente no hay SQL que ejecutar.
4. [TRIGGERS.md](database/TRIGGERS.md): actualmente no hay SQL que ejecutar.
5. [DATOS_PRUEBA.md](database/DATOS_PRUEBA.md): carga opcional solo para desarrollo/demo.

Para una BD funcional limpia, realizar los pasos 1–4, sin datos demo. Para desarrollar con una muestra, ejecutar además el paso 5. Cada tipo de objeto tiene una sola fuente SQL documental.

La muestra contiene un técnico, dos sucursales, dos tickets y una evidencia descriptiva. Usuario público demo: tecnico1; contraseña de desarrollo: Demo123*. La tabla almacena únicamente el hash verificado por PasswordHasher<Usuario>. No usar esta cuenta o contraseña en producción. Esta etapa documenta la carga y no la ejecuta sobre la base local.

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

Se conserva la infraestructura de autenticación existente (JWT, PasswordHasher, DTOs, servicio y acceso de usuarios) sin ampliarla ni crear cuentas automáticamente. Swagger muestra los endpoints anteriores; la cuenta demo puede cargarse manualmente siguiendo DATOS_PRUEBA.md; no se requiere comprobar un login exitoso en esta reorganización. Flutter no tiene login funcional.

La conexión se obtiene exclusivamente de ConnectionStrings:DefaultConnection. JWT conserva Issuer, Audience y ExpirationMinutes en appsettings.json; Key se obtiene de User Secrets en desarrollo. Ambas configuraciones pueden sobrescribirse mediante variables de entorno de ASP.NET Core. Fuera de Development debe proporcionarse la conexión correspondiente.

Cada endpoint existente tiene su propio Controller. Login conserva ServicioAutenticacion compartido; Me lee la identidad del JWT; SaludBaseDatos utiliza IServicioSaludBaseDatos y CanConnectAsync sin consultar tablas. GET /api/health/database es anónimo y devuelve 200/connected o 503/unavailable, sin información sensible.

PostgreSQL fue seleccionado para esta implementación. IAccesoUsuarios separa a la autenticación de AccesoUsuariosPostgres, de modo que otro proveedor relacional podría sustituirse adaptando el acceso y los objetos de BD sin cambiar el contrato HTTP. No se implementa SQL Server.

IConexion centraliza la apertura mediante Conexion. AccesoUsuariosPostgres utiliza DbCommand parametrizado y ServicioSaludBaseDatos comprueba únicamente la apertura. EF Core y ContextoBaseDatos se conservan sin uso ni registro activo, pendientes de una decisión posterior sobre su eliminación.

## Ejecutar Flutter

Desde mobile/:

```sh
flutter pub get
flutter run
```

main.dart inicia GetMaterialApp utilizando PaginasApp. Rutas centraliza el único nombre de ruta y PaginasApp lo relaciona con VistaInicial. No hay rutas de pantallas futuras ni navegación funcional adicional.

Validaciones:

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## Infraestructura HTTP Flutter

Los futuros servicios dependerán de IConexionApi, registrado como Conexion mediante DependenciasApp de GetX. ClienteApi conserva el transporte de bajo nivel para GET, POST, PUT, PATCH y DELETE. El consumidor elige una ruta de RutasApi, construye el payload JSON y aporta un token opcional. El cliente centraliza URL, headers, Bearer, serialización, timeout de 15 segundos y lectura de la respuesta. No guarda tokens ni implementa reintentos o sincronización. Las vistas y controllers no utilizan http directamente.

RespuestaApi contiene statusCode, data, message y success. statusCode es null si no hubo respuesta HTTP; data es el JSON decodificado sin convertirlo a un modelo de negocio. Los 2xx son exitosos, incluidos cuerpos vacíos; un cuerpo no JSON produce un error explícito. Los errores HTTP conservan su código y datos. Timeout, API inaccesible y errores inesperados producen mensajes controlados. El consumidor debe cerrar ClienteApi cuando deje de usarlo; el timeout limita la espera, pero no cancela automáticamente el transporte subyacente.

ConfiguracionApi centraliza la URL mediante API_BASE_URL. Android Emulator usa por defecto `http://10.0.2.2:5263`, que permite alcanzar el host; Windows/local puede configurarse así:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:5263
```

Para un dispositivo físico, proporcionar en API_BASE_URL una URL de la API accesible desde su red. No usar localhost, que en ese caso identifica al propio teléfono. No se configuró acceso por LAN ni se probó un dispositivo físico.

Android tiene permiso INTERNET. Solo el manifiesto debug permite HTTP sin cifrar para la API local; las compilaciones release conservan la restricción predeterminada y deben utilizar HTTPS. No se agregó una pantalla para probar conectividad.

La suite habitual usa MockClient (incluido en http). La prueba real es opt-in y requiere API/PostgreSQL ejecutándose:

```sh
flutter test test/network/cliente_api_real_test.dart --dart-define=RUN_API_TEST=true --dart-define=API_BASE_URL=http://localhost:5263
```

TextosApp, ColoresApp y FuentesApp centralizan únicamente los textos y estilos utilizados por la plantilla y sus mensajes HTTP. Las rutas GetX permanecen separadas de las rutas de la API.

Referencias de configuración: [red del emulador Android](https://developer.android.com/studio/run/emulator-networking-address), [tráfico HTTP en Android](https://developer.android.com/guide/topics/manifest/application-element#usesCleartextTraffic) y [cliente http de Dart](https://pub.dev/packages/http).

## Dependencias existentes

Flutter: GetX 4.7.3, http 1.6.0, Flutter Test y Flutter Lints 6.0.0.

API: Npgsql.EntityFrameworkCore.PostgreSQL 10.0.3, Microsoft.AspNetCore.Authentication.JwtBearer 10.0.12 y Swashbuckle.AspNetCore 10.2.3. EF Core y Npgsql son dependencias transitivas; PasswordHasher proviene del framework ASP.NET Core.

## Documentación y alcance

El código específico de la solución se documenta en español: XML en C# y comentarios /// en Dart, explicando intención, funcionamiento y decisión. Los documentos database/ separan estructura, datos y objetos SQL. El boilerplate de las plantillas no necesita comentarios añadidos.

No se implementan login Flutter, tickets, historial, SQLite, fotografías ni sincronización. ClienteApi está preparado y probado con health, pero ninguna pantalla consume la API todavía. La base local futura contendrá únicamente datos necesarios para offline y tendrá su propia abstracción; sus controllers no accederán directamente a SQLite. Estas decisiones todavía no constituyen funcionalidades.

La línea base anterior está registrada en docs/linea-base.md. El estado posterior y las validaciones de infraestructura reutilizable están en docs/infraestructura.md. El README final se ampliará conforme avance el proyecto.

La abstracción anterior está documentada en docs/conexiones.md; el estado actual, secrets y versionado se describen en docs/conexion-global.md.


## Versionado

La rama principal es main. Cada cambio lógico usa un commit claro con chore, refactor, feat, fix, test o docs. Antes de commit y push: ejecutar las validaciones correspondientes, revisar git status y diff staged, comprobar ausencia de secretos y publicar solo código compilable. No se utiliza Git Flow ni se crean ramas innecesarias.

## Decisiones de conexión

La clase Conexion de cada aplicación concentra el canal actual. Los consumidores usan IConexion en API y IConexionApi en Flutter; ConfiguracionApi conserva URL y timeout. HTTP/HTTPS se selecciona con API_BASE_URL; configuración especial de certificados podría justificar otra implementación futura. Los proveedores externos tendrán contratos específicos, como AuthProvider, sin mezclarse con Conexion.

DbConnection se utiliza en código interno confiable. Su propiedad ConnectionString es estándar; los consumidores no la leen ni registran. PersistSecurityInfo=false oculta el password tras abrir. No se introduce una envoltura adicional para ocultar metadatos. Controllers y ServicioAutenticacion no reciben conexiones; ServicioSaludBaseDatos es la excepción de infraestructura, necesaria para validar la apertura sin consultas.

EF Core/ContextoBaseDatos no está registrado ni usado, no crea migraciones ni materializa datos. Se recomienda eliminarlo en una etapa posterior, previa aprobación explícita.


## Nomenclatura

Las clases, interfaces y archivos propios se nombran en español; los tipos de frameworks, los entrypoints main.dart/Program.cs, propiedades de contratos JSON y los objetos SQL existentes conservan sus nombres. Ticket, Login, API, JWT y Bearer son términos técnicos deliberadamente conservados. El reporte de esta etapa y la tabla completa de renombres están en docs/modularizacion.md.
