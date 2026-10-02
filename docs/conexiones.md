Nota: documento histórico. La nomenclatura y separación SQL actuales están en modularizacion.md.

> Registro histórico: la instalación vigente está en [README](../README.md) y en `database/PostgreSQL/v1/BD_COMPLETA.sql`. Los instaladores y migraciones anteriores se conservan en Git; no seguir sus instrucciones como instalación actual.

Nota: reporte histórico de una etapa anterior. Los nombres actuales y la configuración segura están en conexion-global.md.

# Abstracción de conexiones

## API

El flujo activo es Controller → Service → DataAccess → IDatabaseConnection → PostgresDatabaseConnection. Health consume directamente el contrato desde DatabaseHealthService porque solo abre y cierra una conexión, sin consultar tablas.

- Data/Connections/IDatabaseConnection.cs define OpenConnectionAsync(CancellationToken) con retorno DbConnection abierto. El consumidor dispone la conexión con await using.
- PostgresDatabaseConnection es el único componente activo que lee ConnectionStrings:DefaultConnection, construye NpgsqlConnection y abre PostgreSQL. La cadena queda privada, no se registra ni se devuelve en endpoints. PersistSecurityInfo se fuerza a false para ocultar el password después de abrir. También dispone la conexión cuando falla la apertura.
- PostgresUserDataAccess recibe el contrato, invoca la función existente mediante un parámetro DbCommand y materializa User por nombres de columnas. Dispone comando, lector y conexión; conserva la comprobación de resultado único y no modifica datos.
- DatabaseHealthService solicita y dispone una conexión. Devuelve false ante DbException y propaga cancelación; no ejecuta SQL ni depende del esquema.
- Program registra scoped IDatabaseConnection → PostgresDatabaseConnection. No hay conexión EF paralela ni cambios en contratos de autenticación o endpoints.

DbConnection abstrae el proveedor, pero su API estándar incluye metadatos y la propiedad ConnectionString. Las capas consumidoras actuales no los leen y el password se oculta al abrir. Este contrato no constituye una frontera de seguridad frente a código arbitrario dentro del proceso. No se añaden propiedades de credenciales al contrato ni se expone configuración por HTTP.

EF Core no tiene responsabilidad activa después del refactor. AppDbContext conserva el mapeo previo sin registro DI ni consumidores. Sus paquetes se retienen según la instrucción de no eliminarlos sin aprobación; una eliminación posterior requiere decisión del usuario.

## Flutter

El flujo preparado es Service → ApiConnection → HttpApiConnection → ApiClient. No se crearon servicios de negocio.

- app/network/api_connection.dart define GET, POST, PUT, PATCH, DELETE y cierre con respuestas ApiResponse, token opcional y payload donde el cliente existente lo permite.
- http_api_connection.dart compone ApiClient y delega argumentos sin duplicar transporte. GetxController se utiliza para participar en el ciclo de vida GetX; onClose libera el cliente.
- app/bindings/app_bindings.dart centraliza lazyPut de ApiConnection → HttpApiConnection con fenix para reconstruir la dependencia. main conecta el registro mediante initialBinding.
- ApiClient conserva requests, headers, Bearer, JSON, timeout, interpretación de respuestas y errores. Solo cambia su documentación de consumidores.
- ApiConfig, ApiResponse, ApiStatus y ApiRoutes se conservan. HTTP/HTTPS se selecciona cambiando API_BASE_URL, sin otro transporte ni cambios en futuros servicios. No se configura pinning ni excepciones de certificados.

Un proveedor externo de identidad podría necesitar un contrato específico AuthProvider con implementaciones ApiAuthProvider o GoogleAuthProvider. No sería simplemente otro transporte ApiConnection. No se implementó ninguna integración externa.

## Validaciones

| Comprobación | Resultado |
|---|---|
| dotnet build | 0 errores, 0 advertencias |
| Swagger | Mismos tres endpoints; health ejecutable sin JWT |
| GET /api/health/database | 200, status ok y database connected en HTTP y Swagger |
| flutter analyze | Sin problemas |
| flutter test | 15 aprobadas, 1 externa omitida por defecto |
| flutter build apk --debug | APK generado |
| DATABASE.md | SHA-256 sin cambios |

Se mantienen las pruebas anteriores y se agregan pruebas de delegación por contrato y registro/ciclo de vida GetX sin red. No se crea código de prueba en producción ni se hace una llamada real en cada suite.

No se verificó login exitoso ni se crearon usuarios. No se modificaron esquema, funciones, datos, rutas funcionales o UI. No se implementaron Login Flutter, Tickets, SQLite ni sincronización. DATABASE.md conserva su referencia histórica a EF Core por prohibición expresa de modificarlo; el acceso actual se explica aquí.

## Archivos

Creados:

- api/Data/Connections/IDatabaseConnection.cs
- api/Data/Connections/PostgresDatabaseConnection.cs
- mobile/lib/app/network/api_connection.dart
- mobile/lib/app/network/http_api_connection.dart
- mobile/lib/app/bindings/app_bindings.dart
- mobile/test/network/api_connection_test.dart
- docs/conexiones.md

Modificados:

- api/Program.cs
- api/Data/PostgresUserDataAccess.cs
- api/Data/AppDbContext.cs (documentación del estado inactivo)
- api/Services/DatabaseHealthService.cs
- mobile/lib/main.dart
- mobile/lib/app/network/api_client.dart (documentación)
- README.md

Documentación del código: revisada. Clases y métodos propios nuevos/modificados explican qué hacen, cómo y por qué mediante XML en C# y /// en Dart. Program utiliza comentarios de contexto en sus sentencias de composición de nivel superior.

Se corrigió durante la edición un import Dart situado tras las declaraciones. No hay errores pendientes de compilación o pruebas. La eventual eliminación de EF Core queda para una decisión posterior; no se avanza al Login.
