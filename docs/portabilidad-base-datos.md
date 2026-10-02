# Portabilidad de base de datos

PostgreSQL es el motor conectado y probado desde cero. SQL Server es un equivalente documental revisado estáticamente, sin ejecución en instancia real ni proveedor runtime.

Los instaladores actuales son `database/PostgreSQL/v1/BD_COMPLETA.sql` y `database/SQLServer/v1/BD_COMPLETA.sql`. Ambos representan el esquema final y se ejecutan en una base vacía; no requieren migraciones históricas. El procedimiento de instalación está en [README](../README.md).

Cada versión tiene exactamente seis scripts. `DATABASE.sql` contiene ocho tablas con claves, restricciones e índices; `DATOS_PRUEBA.sql` aporta los cuatro roles y sus usuarios demo; `STORED_PROCEDURES.sql` contiene `get_user_by_username` / `GetUserByUsername`; `VISTAS.sql` contiene `agenda_tickets`. No hay triggers. `BD_COMPLETA.sql` concatena las cinco fuentes en orden de dependencias.

PostgreSQL usa identity, timestamptz, UUID, texto y FK RESTRICT. SQL Server usa IDENTITY, datetimeoffset, uniqueidentifier, NVARCHAR y FK NO ACTION; el índice UUID filtrado permite varios NULL y las comparaciones binarias conservan mayúsculas. Los hashes demo de PasswordHasher son iguales en ambos motores.

La consulta de usuario excluye cuentas inactivas y mantiene el hash dentro del acceso a datos. La API aplica permisos, transacciones e idempotencia; instalar estos scripts no agrega proveedor SQL Server ni cambia contratos HTTP.
