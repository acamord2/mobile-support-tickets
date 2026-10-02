import '../../models/sucursal_local.dart';
import 'operaciones_sqlite.dart';

/// Mantiene catálogo local por usuario mediante OperacionesSqlite; permite formularios sin conexión y evita que el widget dependa de información HTTP descargada.
class RepositorioSucursales {
  final OperacionesSqlite sql;
  RepositorioSucursales(this.sql);

  /// Consulta solo el catálogo previamente disponible para la cuenta autenticada.
  Future<List<SucursalLocal>> obtener(int usuario) async =>
      OperacionesSqlite.exigir(
        await sql.seleccionar(
          'sucursales',
          donde: 'usuario_id = ?',
          argumentos: [usuario],
          orden: 'nombre, id',
        ),
      ).map(SucursalLocal.desdeFila).toList();

  /// Actualiza las sucursales en transacción sin eliminar referencias de tickets locales.
  Future<void> guardar(int usuario, List<dynamic> remotas) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        for (final r in remotas) {
          final datos = {
            'id': r['id'] as int,
            'nombre': r['name'] as String,
            'direccion': r['address'] as String,
            'usuario_id': usuario,
          };
          final existentes = OperacionesSqlite.exigir(
            await tx.seleccionar(
              'sucursales',
              donde: 'id = ? AND usuario_id = ?',
              argumentos: [r['id'], usuario],
            ),
          );
          if (existentes.isEmpty) {
            OperacionesSqlite.exigir(await tx.insertar('sucursales', datos));
          } else {
            OperacionesSqlite.exigir(
              await tx.actualizar(
                'sucursales',
                datos,
                donde: 'id = ? AND usuario_id = ?',
                argumentos: [r['id'], usuario],
              ),
            );
          }
        }
      }),
    );
  }
}
