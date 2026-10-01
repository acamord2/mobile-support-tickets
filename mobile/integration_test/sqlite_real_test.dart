import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/operacion_pendiente.dart';

/// Comprueba sqflite nativo en el dispositivo físico usando una base efímera.
/// No modifica datos persistentes, red o PostgreSQL; valida el adaptador Android
/// además de los tests SQLite FFI ejecutados en el equipo de desarrollo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SQLite Android crea cola y conserva pendiente hasta confirmar', (
    tester,
  ) async {
    final conexion = ConexionSqlite(ruta: inMemoryDatabasePath);
    try {
      final cola = RepositorioCola(OperacionesSqlite(conexion));
      final id = OperacionesSqlite.exigir(
        await cola.agregarPendiente(
          recurso: 'prueba_infraestructura',
          operacion: TipoOperacionLocal.crear,
          payload: {'descripcion': 'solo local'},
        ),
      );
      expect(
        OperacionesSqlite.exigir(await cola.obtenerPendientes()).single.id,
        id,
      );
      expect((await cola.marcarProcesando(id)).exitoso, isTrue);
      expect((await cola.devolverPendiente(id)).exitoso, isTrue);
      expect(
        OperacionesSqlite.exigir(
          await cola.obtenerPendientes(),
        ).single.intentos,
        1,
      );
      await cola.marcarProcesando(id);
      expect((await cola.marcarSincronizado(id)).exitoso, isTrue);
      expect(OperacionesSqlite.exigir(await cola.obtenerPendientes()), isEmpty);
    } finally {
      await conexion.cerrar();
    }
  });
}
