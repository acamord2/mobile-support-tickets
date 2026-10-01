import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/database/configuracion_sqlite.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/esquema_sqlite.dart';
import 'package:tikets/app/database/estado_sincronizacion.dart';
import 'package:tikets/app/database/operacion_pendiente.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';

/// Prueba SQLite real mediante FFI sin emulador, API ni PostgreSQL.
/// Verifica persistencia, parámetros, rollback, estados y exclusión de secretos
/// para demostrar la infraestructura local en vez de simular sus consultas.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite conexion;
  late OperacionesSqlite operaciones;
  late RepositorioCola cola;
  setUp(() {
    conexion = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    operaciones = OperacionesSqlite(conexion);
    cola = RepositorioCola(operaciones);
  });
  tearDown(() => conexion.cerrar());

  test(
    'Apertura concurrente crea una sola cola con versión explícita',
    () async {
      final resultados = await Future.wait([
        operaciones.seleccionar(EsquemaSqlite.cola),
        operaciones.seleccionar(EsquemaSqlite.cola),
      ]);
      expect(resultados.every((r) => r.exitoso && r.datos!.isEmpty), isTrue);
      final version = await conexion.ejecutar(
        (db) => db.rawQuery('PRAGMA user_version'),
      );
      expect(version.single['user_version'], ConfiguracionSqlite.version);
    },
  );

  test(
    'CRUD parametrizado conserva texto con comillas y elimina solo su fila',
    () async {
      final id = OperacionesSqlite.exigir(
        await cola.agregarPendiente(
          recurso: 'prueba',
          operacion: TipoOperacionLocal.actualizar,
          payload: {'descripcion': "O'Brien; DROP TABLE prueba"},
        ),
      );
      final pendientes = OperacionesSqlite.exigir(
        await cola.obtenerPendientes(),
      );
      expect(
        pendientes.single.payload['descripcion'],
        "O'Brien; DROP TABLE prueba",
      );
      expect(pendientes.single.creadoEn.isUtc, isTrue);
      expect(
        OperacionesSqlite.exigir(
          await operaciones.actualizar(
            EsquemaSqlite.cola,
            {'recurso': 'modificado'},
            donde: 'id = ?',
            argumentos: [id],
          ),
        ),
        1,
      );
      expect(
        OperacionesSqlite.exigir(
          await operaciones.seleccionar(
            EsquemaSqlite.cola,
            donde: 'id = ?',
            argumentos: [id],
          ),
        ).single['recurso'],
        'modificado',
      );
      expect(
        OperacionesSqlite.exigir(
          await operaciones.eliminar(
            EsquemaSqlite.cola,
            donde: 'id = ?',
            argumentos: [id],
          ),
        ),
        1,
      );
      expect(OperacionesSqlite.exigir(await cola.obtenerPendientes()), isEmpty);
    },
  );

  test(
    'Estados, intentos y red fallida conservan payload hasta confirmación',
    () async {
      final id = OperacionesSqlite.exigir(
        await cola.agregarPendiente(
          recurso: 'prueba',
          operacion: TipoOperacionLocal.crear,
          payload: {'id': 4},
        ),
      );
      expect((await cola.marcarSincronizado(id)).exitoso, isFalse);
      expect((await cola.marcarProcesando(id)).exitoso, isTrue);
      expect(OperacionesSqlite.exigir(await cola.obtenerPendientes()), isEmpty);
      expect((await cola.devolverPendiente(id)).exitoso, isTrue);
      var pendiente = OperacionesSqlite.exigir(
        await cola.obtenerPendientes(),
      ).single;
      expect(pendiente.estado, EstadoSincronizacion.pendiente);
      expect(pendiente.intentos, 1);
      expect(pendiente.ultimoError, ErrorSincronizacion.red.name);
      await cola.marcarProcesando(id);
      await cola.marcarError(id, ErrorSincronizacion.servidor);
      pendiente = OperacionesSqlite.exigir(
        await cola.obtenerPendientes(),
      ).single;
      expect(pendiente.estado, EstadoSincronizacion.error);
      expect(pendiente.payload, {'id': 4});
      await cola.marcarProcesando(id);
      await cola.marcarSincronizado(id);
      expect(OperacionesSqlite.exigir(await cola.obtenerPendientes()), isEmpty);
      final fila = OperacionesSqlite.exigir(
        await operaciones.seleccionar(EsquemaSqlite.cola),
      ).single;
      expect(fila['intentos'], 3);
      expect(fila['estado'], EstadoSincronizacion.sincronizado.name);
      expect(fila['ultimo_error'], isNull);
      expect((await cola.marcarProcesando(id)).exitoso, isFalse);
    },
  );

  test(
    'Fallo de una operación revierte toda la transacción y su cola',
    () async {
      final resultado = await operaciones.transaccion((transaccion) async {
        final id = OperacionesSqlite.exigir(
          await RepositorioCola(transaccion).agregarPendiente(
            recurso: 'prueba',
            operacion: TipoOperacionLocal.crear,
            payload: {'valor': 1},
          ),
        );
        OperacionesSqlite.exigir(
          await transaccion.insertar('tabla_inexistente', {'valor': 2}),
        );
        return id;
      });
      expect(resultado.exitoso, isFalse);
      expect(resultado.mensaje, TextosApp.errorSqlite);
      expect(OperacionesSqlite.exigir(await cola.obtenerPendientes()), isEmpty);
    },
  );

  test(
    'Cola rechaza secretos anidados y objetos no serializables sin escribir',
    () async {
      final payloads = <Map<String, Object?>>[
        {'password': 'valor-de-prueba'},
        {
          'interno': [
            {'PasswordHash': 'valor-de-prueba'},
          ],
        },
        {
          'interno': {'access_token': 'valor-de-prueba'},
        },
        {'descripcion': 'Bearer valor-de-prueba'},
        {'ConnectionString': 'valor-de-prueba'},
        {'valor': () {}},
      ];
      for (final payload in payloads) {
        final resultado = await cola.agregarPendiente(
          recurso: 'prueba',
          operacion: TipoOperacionLocal.crear,
          payload: payload,
        );
        expect(resultado.exitoso, isFalse);
        expect(resultado.mensaje, TextosApp.errorSqlite);
      }
      expect(OperacionesSqlite.exigir(await cola.obtenerPendientes()), isEmpty);
    },
  );

  test(
    'Cerrar y reabrir el archivo conserva pendientes sin recrear la base',
    () async {
      final temporal = await Directory.systemTemp.createTemp(
        'incidencias_sqlite_',
      );
      final archivo = File('${temporal.path}/${ConfiguracionSqlite.nombre}');
      final persistente = ConexionSqlite(
        fabrica: databaseFactoryFfi,
        ruta: archivo.path,
      );
      try {
        final repositorio = RepositorioCola(OperacionesSqlite(persistente));
        OperacionesSqlite.exigir(
          await repositorio.agregarPendiente(
            recurso: 'prueba',
            operacion: TipoOperacionLocal.crear,
            payload: {'descripcion': 'conservada'},
          ),
        );
        await persistente.cerrar();
        expect(
          OperacionesSqlite.exigir(
            await repositorio.obtenerPendientes(),
          ).single.payload,
          {'descripcion': 'conservada'},
        );
      } finally {
        await persistente.cerrar();
        await archivo.delete();
        await temporal.delete();
      }
    },
  );
}
