Nota: documento histórico. La nomenclatura y separación SQL actuales están en modularizacion.md.

> Registro histórico: la instalación vigente está en [README](../README.md) y en `database/PostgreSQL/v1/BD_COMPLETA.sql`. Los instaladores y migraciones anteriores se conservan en Git; no seguir sus instrucciones como instalación actual.

# Conexión global, configuración local y versionado

## Puntos centrales

API: Data/Connections/IConexion.cs conserva OpenConnectionAsync y DbConnection. Data/Connections/Conexion.cs implementa el contrato y es el único componente activo que conoce Npgsql y lee ConnectionStrings:DefaultConnection. PostgresUserDataAccess y DatabaseHealthService consumen IConexion. Program registra una sola selección scoped IConexion → Conexion. No se usa herencia de conexión en controllers, servicios o DataAccess.

Flutter: app/network/conexion.dart reemplaza HttpApiConnection. Conexion implementa ApiConnection y compone ApiClient para GET, POST, PUT, PATCH, DELETE y cierre. AppBindings registra ApiConnection → Conexion; el cliente se crea centralmente y onClose lo libera. ApiClient conserva URL, headers, JSON, Bearer, timeout, transporte e interpretación de errores. ApiConfig concentra URL y timeout; ApiRoutes conserva las rutas existentes.

HTTP y HTTPS se seleccionan cambiando API_BASE_URL. No se crea HttpsConexion. Configuraciones especiales de certificados podrían justificar otra implementación en el futuro. Proveedores externos como Google Auth utilizarían contratos propios, por ejemplo AuthProvider, sin mezclarse con Conexion. No se implementa esa integración.

## Secrets y limpieza

La ConnectionString real de desarrollo y una clave JWT aleatoria nueva se guardan exclusivamente en .NET User Secrets, fuera del repositorio. appsettings.json y appsettings.Development.json contienen valores sensibles vacíos. No se publica password, clave JWT local ni identificador de secrets en este reporte. UserSecretsId en el csproj es metadata necesaria para localizar configuración local, no una credencial.

En Development, el host ASP.NET Core carga User Secrets después de appsettings. Se comprobó health 200 con appsettings vacío y configuración local externa. Variables de entorno pueden sobrescribir esa configuración. Linux usaría ConnectionStrings__DefaultConnection y Jwt__Key; no se configura un servidor real. README incluye comandos con placeholders y explica que User Secrets no es almacenamiento cifrado.

El usuario autorizó retirar los secrets del repositorio y de objetos anteriores. No existían commits. Se encontró una credencial en un blob de configuración previo; se retiró ese blob, seis árboles asociados y dos referencias internas de snapshots. También se retiraron dos blobs antiguos de configuración con la clave JWT demo y sus ocho árboles asociados. Se conservaron los objetos ajenos a secrets. git fsck confirmó integridad; los objetos no referenciados restantes no son historial publicado.

La revisión automática rechazó inicialmente una limpieza general mediante git gc --prune=now porque eliminaría otros objetos. Esa operación no se ejecutó; se sustituyó por la limpieza específica descrita arriba. No se modificó la contraseña del servidor PostgreSQL ni se eliminaron credenciales de otras aplicaciones.

Antes de versionar/publicar se revisan todos los archivos candidatos y objetos Git por coincidencias con la conexión, password y JWT locales, además de patrones de tokens, claves privadas, .env y rutas personales. Las coincidencias de documentación/test son placeholders o nombres de campos; no se registran valores privados. El objeto real detectado se eliminó antes del push.

.gitignore excluye artefactos Flutter/Dart/.NET, builds, IDE, .local, .env, configuración local, secrets.json, logs y archivos de claves/certificados privados. Código, DATABASE.md y documentación permanecen versionados.

## Decisiones de arquitectura

DbConnection se acepta para código interno confiable; su propiedad ConnectionString no representa una frontera de seguridad entre componentes. Los consumidores no leen ni registran esa propiedad. PersistSecurityInfo=false oculta el password después de abrir. Controllers y AuthService no reciben conexiones. DatabaseHealthService conserva acceso directo al contrato como diagnóstico de infraestructura sin consultas; DataAccess lo utiliza para lecturas funcionales.

EF Core/AppDbContext permanece sin uso, registro, migraciones, materialización o funcionalidades activas. Se recomienda eliminarlo tras aprobación explícita. No se elimina en esta etapa.

## Validaciones

| Validación | Resultado |
|---|---|
| dotnet build | 0 errores, 0 advertencias |
| GET /api/health/database con User Secrets | 200, status ok y database connected |
| Swagger | Funciona; mismos tres endpoints; health anónimo |
| flutter analyze | Sin problemas |
| flutter test | 15 aprobadas y 1 externa omitida por defecto |
| flutter build apk --debug | APK generado correctamente |
| DATABASE.md | Hash SHA-256 conservado |

El primer build encontró el ejecutable ocupado por la API de la etapa anterior. Se detuvo ese proceso y el build final pasó limpio. No se modificaron BD, funciones, datos, rutas o UI; no se implementaron nuevas funcionalidades.

## GitHub y commits

El repositorio https://github.com/acamord2/mobile-support-tickets ya existía vacío y público bajo la cuenta autenticada; se reutiliza y no se crea uno duplicado. No se sobrescribe contenido remoto existente. La rama principal es main, sin Git Flow.

La primera publicación agrupa la línea base acumulada que aún no tenía commits en cambios lógicos: API/configuración segura, infraestructura Flutter y documentación/definición manual de BD. Los futuros cambios usan chore, refactor, feat, fix, test o docs. Antes de cada commit/push se valida lo correspondiente, se revisa staged y se comprueba ausencia de secretos. Solo se publica main compilable; nunca refs internas de snapshots mediante push --mirror.

## Archivos y documentación

Renombrados: IDatabaseConnection.cs → IConexion.cs, PostgresDatabaseConnection.cs → Conexion.cs y http_api_connection.dart → conexion.dart. Referencias actualizadas en Program, PostgresUserDataAccess, DatabaseHealthService, AppDbContext, ApiClient, AppBindings y pruebas de conexión Flutter.

Configuración/documentación modificada: Tickets.Api.csproj (UserSecretsId), ambos appsettings, .gitignore, README y prefijos de reportes históricos. Se crea este reporte. No se modifica DATABASE.md.

Documentación del código: revisada. Clases y métodos propios usan XML en C# y /// en Dart para explicar qué hacen, cómo y por qué. No se comentan archivos generados automáticamente.

Pendiente únicamente de decisión arquitectónica posterior: eliminación de EF Core inactivo. La etapa se detiene antes de Login Flutter.
