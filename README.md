# Gestión de incidencias técnicas

Repositorio público: [mobile-support-tickets](https://github.com/acamord2/mobile-support-tickets).

Prueba técnica con login Flutter/GetX funcional, API ASP.NET Core .NET 10, JWT y PostgreSQL instalado manualmente. Flutter está organizado en módulos y dispone de infraestructura SQLite, cola local e indicador offline. La sesión pública persiste en SQLite y el JWT en almacenamiento seguro; Home muestra agenda desde SQLite, crea tickets offline y sincroniza tickets y evidencias con autoría e idempotencia.

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
    app/database/      # SQLite real, operaciones comunes y cola técnica
    app/services/      # sesión, conectividad y base de sincronización
    models/
    modules/
      arranque/        # restauración mínima y resolución de ruta
      login/           # main_login.dart, controller, servicio y widgets_login
      home/            # main_home.dart, controller y widgets_home
    widgets/apartada/   # indicador transversal de desconexión
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
  PostgreSQL/v1/       # seis scripts SQL autocontenidos
  SQLServer/v1/        # equivalencia documental
docs/
  linea-base.md
```

Las vistas principales de cada módulo componen sus widgets internos. Ningún módulo importa widgets internos de otro; comparte rutas, modelos y servicios globales. El código nativo generado por Flutter permanece en mobile. La estructura completa está en [arquitectura-local-first.md](docs/arquitectura-local-first.md).

## Requisitos

- Flutter 3.41.9 con Dart 3.11.5 (versiones utilizadas).
- SDK Android para compilar el APK.
- SDK .NET 10.
- PostgreSQL instalado y ejecutándose previamente y pgAdmin para crear la estructura manualmente.

## Crear manualmente la BD

Crear una base vacía llamada `tickets_db` con pgAdmin (o ejecutar `CREATE DATABASE tickets_db;` fuera de una transacción). Conectar Query Tool a esa base y ejecutar el contenido completo de [database/PostgreSQL/v1/BD_COMPLETA.sql](database/PostgreSQL/v1/BD_COMPLETA.sql). También puede ejecutarse con `psql -v ON_ERROR_STOP=1 -d tickets_db -f database/PostgreSQL/v1/BD_COMPLETA.sql`, proporcionando la conexión fuera del repositorio.

PostgreSQL está probado desde cero en una base temporal independiente. El instalador representa el esquema final; no requiere migraciones anteriores y no debe ejecutarse para actualizar una base existente. La API no instala esquema ni datos.

SQL Server es un equivalente documental, sin prueba en instancia real: [database/SQLServer/v1/BD_COMPLETA.sql](database/SQLServer/v1/BD_COMPLETA.sql). Crear una base vacía, seleccionarla en SSMS y ejecutar el archivo; `GO` separa sus lotes.

Cada motor tiene seis scripts: `DATABASE.sql`, `DATOS_PRUEBA.sql`, `STORED_PROCEDURES.sql`, `VISTAS.sql`, `TRIGGERS.sql` y `BD_COMPLETA.sql`. El archivo completo concatena estructura, función/SP, vista, triggers y datos demo, en ese orden. No se utilizan extensiones ni triggers.

Los datos demo incluyen cuatro usuarios activos, una sucursal, tres tickets, la relación Coordinador–Técnico, una evidencia descriptiva y siete eventos. Las credenciales exclusivamente DEMO aparecen en `DATOS_PRUEBA.sql`; solo se almacenan hashes de PasswordHasher. El Usuario ve sus reportes, el Técnico sus dos tickets asignados, el Coordinador su equipo y el ticket sin asignar, y el Administrador el conjunto completo.

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

La autenticación existente usa JWT, PasswordHasher, DTOs, servicio y acceso de usuarios, sin crear cuentas automáticamente. Con los datos demo cargados manualmente, POST /api/auth/login devuelve token e identidad pública; GET /api/auth/me requiere Bearer. Swagger permite comprobar login correcto (200), contraseña incorrecta (401), campos vacíos (400) e identidad autenticada (200).

La conexión se obtiene exclusivamente de ConnectionStrings:DefaultConnection. JWT conserva Issuer, Audience y ExpirationMinutes en appsettings.json; Key se obtiene de User Secrets en desarrollo. Ambas configuraciones pueden sobrescribirse mediante variables de entorno de ASP.NET Core. Fuera de Development debe proporcionarse la conexión correspondiente.

Cada endpoint existente tiene su propio Controller. Login conserva ServicioAutenticacion compartido; Me comprueba identidad activa y rol público mediante IAccesoUsuarios; SaludBaseDatos utiliza IServicioSaludBaseDatos y CanConnectAsync sin consultar tablas. GET /api/health/database es anónimo y devuelve 200/connected o 503/unavailable, sin información sensible.

PostgreSQL fue seleccionado para esta implementación. IAccesoUsuarios separa a la autenticación de AccesoUsuariosPostgres, de modo que otro proveedor relacional podría sustituirse adaptando el acceso y los objetos de BD sin cambiar el contrato HTTP. SQL Server se documenta para portabilidad; todavía no hay proveedor runtime conectado.

IConexion centraliza la apertura mediante Conexion. AccesoUsuariosPostgres utiliza DbCommand parametrizado y ServicioSaludBaseDatos comprueba únicamente la apertura. EF Core y ContextoBaseDatos se conservan sin uso ni registro activo, pendientes de una decisión posterior sobre su eliminación.

## Ejecutar Flutter

Desde mobile/:

```sh
flutter pub get
flutter run
```

main.dart inicia GetMaterialApp con DependenciasApp y PaginasApp. La ruta inicial /arranque restaura almacenamiento local antes de resolver /login o /inicio, sin mostrar Login fugazmente. El login guarda identidad pública en SQLite y JWT en almacenamiento seguro antes de mostrar Home. Cerrar sesión elimina usuario/token y sustituye el historial por un formulario vacío; el botón atrás no recupera la pantalla autenticada.

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

Para el dispositivo físico en la misma LAN, configurar API_BASE_URL externamente y ejecutar desde mobile/ (PowerShell):

```powershell
flutter run "--dart-define=API_BASE_URL=$env:API_BASE_URL"
```

Ejecutar la API con el perfil lan y configurar API_BASE_URL como http://IP_DEL_EQUIPO:5263 fuera del repositorio. Este acceso fue validado manualmente sin USB. adb reverse puede utilizarse opcionalmente para localhost por USB, pero el APK LAN no lo necesita. HTTPS se selecciona mediante la misma variable para un servidor real.

Android tiene permiso INTERNET. Solo el manifiesto debug permite HTTP sin cifrar para la API local; las compilaciones release conservan la restricción predeterminada y deben utilizar HTTPS. No se agregó una pantalla para probar conectividad.

La suite habitual usa MockClient (incluido en http). La prueba real es opt-in y requiere API/PostgreSQL ejecutándose:

```sh
flutter test test/network/cliente_api_real_test.dart --dart-define=RUN_API_TEST=true --dart-define=API_BASE_URL=http://localhost:5263
```

TextosApp, ColoresApp y FuentesApp centralizan los textos y estilos utilizados por login, bienvenida y errores. Las rutas GetX permanecen separadas de las rutas de la API.

Referencias de configuración: [red del emulador Android](https://developer.android.com/studio/run/emulator-networking-address), [tráfico HTTP en Android](https://developer.android.com/guide/topics/manifest/application-element#usesCleartextTraffic) y [cliente http de Dart](https://pub.dev/packages/http).

## Flujo de autenticación y pruebas

VistaLogin → ControladorLogin → ServicioAutenticacion → IConexionApi → Conexion → ClienteApi → POST /api/auth/login. La API reutiliza ServicioAutenticacion → IAccesoUsuarios → PostgreSQL. No se modificaron API ni database/ para esta etapa.

Usuario contiene id, username, name y rol público (roleId/role), opcional para sesiones anteriores. SesionUsuario contiene token e identidad; ResultadoAutenticacion entrega sesión o un mensaje controlado. ServicioSesion persiste mediante RepositorioSesionLocal: identidad pública en SQLite y JWT en flutter_secure_storage. Reiniciar restaura Home, incluso offline o con JWT expirado; en ese caso se requiere reautenticación para futuros accesos remotos. La contraseña no se conserva después del login y el JWT no se imprime ni aparece en las vistas.

La vista valida campos vacíos y oculta contraseña; durante la petición deshabilita campos/botón y muestra progreso. EstadoApi controla 200/400/401/500/503 y ausencia de respuesta. JSON inesperado y fallos de red producen mensajes públicos, sin cuerpos ni excepciones técnicas.

Prueba manual: cargar DATOS_PRUEBA.sql, iniciar API y Flutter, introducir su cuenta demo, comprobar bienvenida y cerrar sesión. Las pruebas aisladas usan IConexionApi simulado. Las pruebas reales reciben credenciales externamente: en PowerShell, asignar DEMO_USERNAME y DEMO_PASSWORD desde DATOS_PRUEBA.sql sin incorporarlas al código.

```powershell
flutter test test/auth/autenticacion_real_test.dart --dart-define=RUN_AUTH_TEST=true --dart-define=API_BASE_URL=http://localhost:5263 "--dart-define=DEMO_USERNAME=$env:DEMO_USERNAME" "--dart-define=DEMO_PASSWORD=$env:DEMO_PASSWORD"
adb reverse tcp:5263 tcp:5263
flutter drive --driver=test_driver/prueba_autenticacion.dart --target=integration_test/login_real_test.dart -d ID_DISPOSITIVO --dart-define=API_BASE_URL=http://127.0.0.1:5263 "--dart-define=DEMO_USERNAME=$env:DEMO_USERNAME" "--dart-define=DEMO_PASSWORD=$env:DEMO_PASSWORD"
```

La integración Android comprueba login, identidad pública, historial y logout. Las capturas quedan en build/pruebas-integracion, excluidas de Git. Los dart-define de credenciales se utilizan solo para la ejecución de pruebas; el APK normal se compila sin ellos. El reporte está en [docs/autenticacion.md](docs/autenticacion.md).

## Home principal

Después del login, Home muestra Mi agenda, fecha, identidad, resumen real por estado y tickets programados. main_home.dart compone cabecera, resumen y tarjetas desde ControladorInicio, sin consultar API directamente.

Sincronizar ejecuta subida y descarga reales mediante ServicioSincronizacion. La acción + abre NuevoTicket; el formulario guarda primero SQLite y cola, incluso sin red. No hay datos ficticios ni catálogo de sucursales hardcodeado.

Home sigue disponible offline: IndicadorDesconexion aparece en la esquina superior derecha cuando el servicio global confirma ausencia de red, sin bloquear o redirigir la pantalla. Cerrar sesión reutiliza la limpieza e historial existentes. El contenido tiene scroll, textos flexibles y semántica accesible para las tarjetas. Responsabilidad, estructura y pruebas: [docs/home.md](docs/home.md).

## Dependencias

Flutter: GetX 4.7.3, http 1.6.0, flutter_secure_storage 11.2.0 para JWT, Flutter Test y Flutter Lints 6.0.0. integration_test pertenece al SDK y se usa únicamente como dependencia de desarrollo para validar el dispositivo físico y capturar pantallas públicas.

Infraestructura local: sqflite 2.4.2+1, path 1.9.1 y connectivity_plus 6.1.5. Se conserva una versión de conectividad compatible con Gradle actual. Para pruebas normales de SQLite real se utiliza sqflite_common_ffi 2.3.7+1 únicamente en desarrollo, sin añadir FFI al código de ejecución Android. pubspec.lock fija las versiones resueltas.

En Windows, Flutter puede pedir Developer Mode para generar enlaces de plugins de escritorio. No se cambió esta configuración del equipo; con las dependencias ya resueltas se validaron Android, análisis y tests usando --no-pub. No se habilita soporte SQLite de escritorio para la app mediante la dependencia de pruebas.

API: Npgsql.EntityFrameworkCore.PostgreSQL 10.0.3, Microsoft.AspNetCore.Authentication.JwtBearer 10.0.12 y Swashbuckle.AspNetCore 10.2.3. EF Core y Npgsql son dependencias transitivas; PasswordHasher proviene del framework ASP.NET Core.

## Documentación y alcance

El código específico de la solución se documenta en español: XML en C# y comentarios /// en Dart, explicando intención, funcionamiento y decisión. Los documentos database/ separan estructura, datos y objetos SQL. El boilerplate de las plantillas no necesita comentarios añadidos.

Login consume la API existente como excepción explícita al flujo local-first. El negocio persistente se lee exclusivamente desde SQLite mediante repositorios; sincronización escribe SQLite antes de refrescar UI. Las vistas/widgets no ejecutan HTTP, SQL, JSON, sincronización ni reglas de negocio.

ConexionSqlite abre incidencias_tecnicas.db versión 3 y migra desde v2 conservando sesión/cola. Añade sucursales, tickets, evidencias y autoría. OperacionesSqlite mantiene SQL fuera de UI. JWT continúa en almacenamiento seguro. Sincronización escribe SQLite antes de refrescar agenda y distingue red disponible de API sana.

La cola pertenece a usuario_id; logout conserva pendientes y otra cuenta no los procesa. Ticket conserva id_local, id_remoto nullable y client_request_id inmutable. Las descargas respetan pending. Fotografías se comprimen a JPEG antes de Base64. No hay resolución avanzada de conflictos ni polling. Detalles actuales: [tickets-agenda.md](docs/tickets-agenda.md) y [evidencias.md](docs/evidencias.md).

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

## Sesión persistente y teléfono físico en LAN

Ejecutar `dotnet run --launch-profile lan` desde api/ para escuchar en interfaces de desarrollo (HTTP 5263, Development). Compilar desde mobile/ con `flutter build apk --debug "--dart-define=API_BASE_URL=$env:API_BASE_URL"`, donde API_BASE_URL se configura externamente como `http://IP_DEL_EQUIPO:5263`. El teléfono y equipo deben compartir LAN. No requiere USB ni adb reverse; no usar localhost del teléfono para llegar al equipo. Producción necesita HTTPS y configuración propia.

El arranque restaura Home sin API. JWT expirado o 401 conserva identidad y pendientes pero bloquea acceso remoto hasta nueva autenticación. Logout comprueba pendientes y borra solamente identidad/JWT; cada operación de Tickets/evidencias conserva ahora su usuario propietario. Android deshabilita backup para evitar restauraciones de sesión y claves cifradas incompatibles tras reinstalación. Detalles, comandos, limitaciones y resultados: [sesion-persistente.md](docs/sesion-persistente.md).

## Bases de datos soportadas/documentadas

PostgreSQL es el motor runtime probado. Su instalación completa está en [database/PostgreSQL/v1/BD_COMPLETA.sql](database/PostgreSQL/v1/BD_COMPLETA.sql).

SQL Server conserva únicamente la equivalencia documental en [database/SQLServer/v1/BD_COMPLETA.sql](database/SQLServer/v1/BD_COMPLETA.sql); no se ejecutó en instancia real ni existe proveedor runtime conectado. Las decisiones de portabilidad se explican en [docs/portabilidad-base-datos.md](docs/portabilidad-base-datos.md).

## Agenda y tickets implementados

Flujo MVP: crear → detalle → editar → comenzar atención → agregar seguimiento → resolver → sincronizar. Editar conserva sucursal, IDs, UUID, autoría y estado; permite título, descripción y programación. Solo Pending pasa a InProgress y solo InProgress pasa a Resolved. TicketEvents registra CREADO, PROGRAMADO, REPROGRAMADO, EN_ATENCION, SEGUIMIENTO y RESUELTO. Resolver exige al menos un SEGUIMIENTO manual previo; admite texto, foto o ambos. Resolved permite consultar la línea de tiempo e imágenes y no editar ni reabrir.

Todas estas acciones guardan en SQLite y la cola antes de volver; abrir detalle y volver no hacen HTTP. Home recarga SQLite conservando filtros. GET /api/tickets incluye `evidences` públicas del técnico; GET y POST /api/tickets/{id}/events permiten descargar y subir los eventos. El evento enlaza opcionalmente una evidencia del mismo ticket y conserva su UUID para reintentos. La foto se previsualiza antes de guardar y luego aparece en detalle; Base64 permanece exclusivamente en Evidences.

La configuración normal de conexión permanece estable. Compilar el APK físico con `flutter build apk --debug "--dart-define=API_BASE_URL=$env:API_BASE_URL"`, con la variable LAN configurada externamente. Un build sin ese argumento utiliza el fallback de emulador y no es adecuado para este teléfono. Instalar mediante `adb install -r build/app/outputs/flutter-apk/app-debug.apk` desde mobile, sin desinstalar ni borrar datos. No utilizar flutter drive ni adb reverse para la ejecución normal. Las pruebas usan transporte simulado o argumentos temporales; no editan configuración.

[docs/tickets-agenda.md](docs/tickets-agenda.md) documenta SQLite v4, migración aditiva, cronología con autor persistido, claves local/remota/UUID, subida/descarga, protección pending y endpoints separados. [docs/evidencias.md](docs/evidencias.md) documenta cámara/galería, previsualización del JPEG procesado, Base64 y límites. La actualización autorizada de TicketEvents se aplicó en PostgreSQL local; la equivalente SQL Server sigue únicamente documentada.

Dependencias adicionales: image 4.10.1 e image_picker 1.2.1 (versiones resueltas en pubspec.lock). No se añadió provider SQL Server, arquitectura nueva ni almacenamiento externo.

API nueva: GET/POST /api/tickets, PUT /api/tickets/{id}, GET /api/branches y POST /api/tickets/{id}/evidence. Todos requieren JWT y cuenta activa. Swagger presenta los endpoints aunque comparten ruta cuando el verbo cambia. La vista se instala manualmente desde database/PostgreSQL/v1/VISTAS.sql; OBJETOS_TICKETS_POSTGRESQL.md referencia esa única fuente. No hay funciones ni triggers nuevos.

Validación del MVP: dotnet build sin errores/advertencias y flutter analyze sin incidencias. La suite final tuvo 81 pruebas aprobadas, 2 opt-in omitidas y un test antiguo de logout desactualizado; se corrigió y su repetición específica junto con el flujo MVP aprobó 6 pruebas. APK final debug compilado para LAN e instalado por reemplazo; SQLite y almacén seguro conservaron sus hashes. Swagger incluye evidencias y GET tickets anónimo devuelve 401. El resultado físico del flujo completo se registra en [tickets-agenda.md](docs/tickets-agenda.md). No se usaron emuladores ni flutter drive en esta entrega. BD_COMPLETA_POSTGRESQL.md se conserva local, sin versionar ni actualizar automáticamente.
