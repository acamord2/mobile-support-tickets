import '../soporte/sesion_simulada.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/operacion_pendiente.dart';
import 'package:tikets/app/database/estado_sincronizacion.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/conexion.dart';
import 'package:tikets/app/network/rutas_api.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sincronizacion.dart';

/// Verifica la base de sincronización sin envíos de negocio ni dependencia de API.
/// Combina SQLite real y HTTP simulado para probar pendientes y disponibilidad.
void main() {
  sqfliteFfiInit();
  test(
    'Red no garantiza API; health explícito no envía JWT ni altera la cola',
    () async {
      final local = ConexionSqlite(
        fabrica: databaseFactoryFfi,
        ruta: inMemoryDatabasePath,
      );
      addTearDown(local.cerrar);
      final cola = RepositorioCola(OperacionesSqlite(local));
      await cola.agregarPendiente(
        recurso: 'prueba',
        operacion: TipoOperacionLocal.crear,
        payload: {'descripcion': 'local'},
      );
      var peticiones = 0;
      var responde = false;
      final api = Conexion(
        ClienteApi(
          client: MockClient((request) async {
            peticiones++;
            expect(request.url.path, RutasApi.healthDatabase);
            expect(request.headers.containsKey('Authorization'), isFalse);
            return http.Response(
              responde ? '{"status":"ok","database":"connected"}' : '{}',
              responde ? 200 : 503,
            );
          }),
        ),
      );
      addTearDown(api.close);
      final red = ServicioConectividad(
        consultar: () async => [ConnectivityResult.wifi],
        cambios: const Stream.empty(),
      );
      await red.refrescar();
      final servicio = ServicioSincronizacion(
        red,
        api,
        cola,
        crearSesionSimulada(),
      );
      expect(servicio.apiDisponible.value, isNull);
      expect(servicio.puedeIntentarEnvio, isFalse);
      expect(await servicio.comprobarDisponibilidadApi(), isFalse);
      expect(red.redDisponible.value, isTrue);
      responde = true;
      expect(await servicio.comprobarDisponibilidadApi(), isTrue);
      red.redDisponible.value = false;
      expect(await servicio.comprobarDisponibilidadApi(), isFalse);
      expect(peticiones, 2);
      final pendiente = OperacionesSqlite.exigir(
        await servicio.consultarPendientes(),
      ).single;
      expect(pendiente.estado, EstadoSincronizacion.pendiente);
      expect(pendiente.intentos, 0);
    },
  );
}
