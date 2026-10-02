Nota: documento histórico. La nomenclatura y separación SQL actuales están en modularizacion.md.

> Registro histórico: la instalación vigente está en [README](../README.md) y en `database/PostgreSQL/v1/BD_COMPLETA.sql`. Los instaladores y migraciones anteriores se conservan en Git; no seguir sus instrucciones como instalación actual.

# Línea base definitiva

Este reporte corresponde a la reorganización anterior. Los Controllers fueron
separados posteriormente y se incorporó infraestructura HTTP Flutter; consultar
infraestructura.md y README para la ubicación y validaciones actuales.

## Estructura y ubicación de responsabilidades

```text
/
  mobile/
    lib/
      main.dart
      app/routes/app_routes.dart
      app/routes/app_pages.dart
      app/database/
      models/
      controllers/
      services/
      views/initial_view.dart
      widgets/
    test/widget_test.dart
    android/ ios/ web/ windows/ linux/ macos/
  api/
    Controllers/
    DTOs/
    Models/
    Data/
    Services/
    Properties/
    Program.cs
    appsettings.json
    appsettings.Development.json
    Tickets.Api.csproj
  database/PostgreSQL/v1/DATABASE.sql
  docs/linea-base.md
  README.md
  .gitignore
```

Rutas Flutter en app/routes, pantalla neutra en views y arranque en main.dart. Las carpetas Flutter de modelos, controllers, servicios y base local son únicamente espacio preparado para etapas posteriores. No se agregan capas nuevas.

## Archivos eliminados

- Los cinco scripts de `api/Data/Scripts/PostgreSql/`: creación de base, schema, seed, funciones y archivo vacío de views. Se verificó que la API no los lee ni necesita para arrancar.
- `docs/etapa-2.md` y `docs/ajuste-arquitectura.md`: documentación de estados anteriores, reemplazada por este reporte y DATABASE.md.
- `.gitkeep` de routes y views, que ahora contienen código.
- Capturas locales antiguas de Swagger, incluidas las que mostraban identidad/datos de prueba. No eran archivos versionados.

No se eliminó ninguna entidad ni la abstracción de acceso a usuarios. TicketHistory no existía y no se añadió.

## Archivos creados

- `database/PostgreSQL/v1/DATABASE.sql`.
- `mobile/lib/app/routes/app_routes.dart`.
- `mobile/lib/app/routes/app_pages.dart`.
- `mobile/lib/views/initial_view.dart`.
- `docs/linea-base.md`.

## Archivos modificados

- `mobile/lib/main.dart`: usa la ruta inicial y páginas centralizadas; pantalla trasladada a InitialView.
- `mobile/test/widget_test.dart`: comprueba resolución de ruta, vista inicial y texto; limpia GetX.
- `api/Program.cs`: comentarios de intención para el arranque, conexión y configuración JWT/Swagger.
- `api/Controllers/AuthController.cs`: documentación de clase y ambos endpoints existentes.
- `api/Services/AuthService.cs`, `JwtOptions.cs`, `BearerSecurityOperationFilter.cs`: documentación de responsabilidades, verificación y descripción OpenAPI.
- `api/Data/AppDbContext.cs`, `IUserDataAccess.cs`, `PostgresUserDataAccess.cs`: documentación del mapeo, contrato y consulta parametrizada.
- `api/DTOs/LoginRequest.cs`, `LoginResponse.cs`, `UserResponse.cs`: documentación del contrato público y protección del hash.
- `api/Models/User.cs`, `Branch.cs`, `Ticket.cs`, `TicketStatus.cs`, `Evidence.cs`: documentación de modelos y alcance.
- `README.md`: instrucciones y estado vigente, sin cuentas ni datos de prueba.

Paquetes, .NET 10 y la configuración de conexión existente se conservaron. No se añadieron dependencias.

## Flutter y GetX

GetMaterialApp toma AppPages.initial y AppPages.pages. Routes contiene únicamente `/`; AppPages lo relaciona con InitialView mediante GetPage. Las rutas y pantallas futuras no existen todavía. No hay formularios, controllers de negocio, SQLite, llamadas API ni navegación adicional.

La prueba de widget no replica solamente una constante: monta la aplicación real, espera la resolución de GetX y verifica ruta y vista, para detectar una configuración de páginas rota.

## API y PostgreSQL externo

La API conserva Swagger, JWT, PasswordHasher, DTOs, los endpoints de autenticación previos y la abstracción de usuarios como infraestructura. No se amplió la autenticación ni se crearon cuentas; un login exitoso no forma parte de la validación de esta reorganización. No se implementó TicketsController.

La conexión se obtiene de ConnectionStrings:DefaultConnection en appsettings.Development.json:

```text
Host=localhost;Port=5432;Database=tickets_db;Username=postgres;Password=
```

La contraseña debe ajustarse localmente si PostgreSQL la requiere. No se documentan contraseñas reales ni se altera la autenticación del servidor. Fuera de Development debe proporcionarse la conexión correspondiente.

La API no administra PostgreSQL, no abre la BD durante el arranque y no ejecuta creación, migraciones ni seed. EF Core se mantiene para conexión, mapeo de las entidades y materialización de la consulta a get_user_by_username. Los controllers siguen sin SQL, Npgsql o ConnectionString.

## Definición manual de BD

DATABASE.md es la única fuente SQL entregable. Contiene requisitos, creación de tickets_db, DDL completo, explicación de campos y constraints, relaciones, función existente, estado de views y consultas de comprobación sin escrituras.

Tablas: Users, Branches, Tickets y Evidences. Relaciones: Tickets.BranchId → Branches.Id, Tickets.TechnicianId → Users.Id y Evidences.TicketId → Tickets.Id. Se mantienen PK identity, NOT NULL, UNIQUE de Username, CHECK de estados y fechas e índices existentes.

Función: public.get_user_by_username, documentada y de solo lectura. No hay procedimientos adicionales, funciones de tickets, views ni TicketHistory.

No hay INSERTs, hashes precargados o datos demo. Una instalación nueva realizada por el desarrollador queda vacía. No se ejecutó DATABASE.md ni se borraron datos de la instalación PostgreSQL externa; su estado real no se afirma como verificado.

## Documentación del código: revisada

Todos los métodos propios con nombre, constructores Dart, contratos de interfaz, endpoints y clases relevantes tienen documentación en español. Se revisaron qué hacen, cómo funcionan y por qué existen. La documentación XML C# también se compiló para comprobar su sintaxis.

Los callbacks anónimos breves de configuración, mapeo, creación de página y prueba se explican en su método/clase contenedor o bloque de intención; no se añaden comentarios que narren cada línea.

No se añadieron comentarios al código generado por Flutter: MainActivity Android, archivos de registro de plugins, runners nativos de escritorio, delegados Apple y sus pruebas de plantilla. Tampoco se documentan individualmente los accesores, constructores y métodos sintetizados por el compilador para records C#, que no contienen lógica escrita por nosotros. ASP.NET Core no conserva WeatherForecast ni otro Controller de ejemplo. Program.cs sí fue revisado porque incluye configuración específica de la solución.

## Validación

| Comprobación | Resultado |
| --- | --- |
| dotnet build | 0 errores y 0 advertencias |
| Sintaxis XML C# al generar documentación | 0 errores y 0 advertencias |
| Arranque API | Correcto, sin consultas ni modificaciones de BD |
| Swagger UI y OpenAPI | HTTP 200; cargan en navegador |
| flutter analyze | Sin problemas |
| flutter test | Prueba de ruta inicial aprobada |
| flutter build apk --debug | APK debug generado correctamente |
| Revisión de DATABASE.md | Cuatro CREATE TABLE, relaciones y función completas; cero INSERTs |
| Ejecución de SQL | No realizada, conforme al alcance manual |
| Limpieza | Sin referencias activas a instancia aislada, seed, credenciales de prueba o WeatherForecast |

## Problemas y decisiones

Se detuvo la API anterior antes de compilar para evitar el bloqueo del ejecutable en Windows. Los comandos de SDK/arranque utilizaron los permisos necesarios para acceder a sus cachés; no se cambiaron tecnologías ni permisos de PostgreSQL.

La contraseña de la instalación local no se conoce; esto no impide compilar o comprobar Swagger y no se intentó un login con datos de prueba. La conexión real se validará cuando el desarrollador cree la estructura y configure sus credenciales.

Se conservó la infraestructura de autenticación y EF Core ya existente en lugar de eliminar código utilizado. Se retiraron las fuentes SQL/documentales duplicadas y se mantuvo una sola ruta Flutter de plantilla. No hay decisiones pendientes de aprobación para esta reorganización.

No se avanzó a funcionalidades de login Flutter, tickets, SQLite, fotografías ni sincronización.
