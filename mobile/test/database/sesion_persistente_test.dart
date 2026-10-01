import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/esquema_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_sesion_local.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/operacion_pendiente.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/models/sesion_usuario.dart';
import '../soporte/sesion_simulada.dart';

/// Comprueba persistencia SQLite real y token ficticio protegido sin API o PostgreSQL.
/// Verifica migración, reinicio, caducidad, 401 y logout sin eliminar pendientes.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite conexion;
  late OperacionesSqlite sql;
  late TokenSimulado tokens;
  late RepositorioSesionLocal repositorio;
  late ServicioSesion sesion;
  setUp(() {
    conexion = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    sql = OperacionesSqlite(conexion);
    tokens = TokenSimulado();
    repositorio = RepositorioSesionLocal(sql, tokens);
    sesion = ServicioSesion(repositorio);
  });
  tearDown(() => conexion.cerrar());

  /// Genera un JWT sin firma real ni credenciales para probar solo lectura de exp.
  SesionUsuario ejemplo({bool expirado = false}) => SesionUsuario.fromJson({
    'token':
        'prueba.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().toUtc().add(Duration(hours: expirado ? -1 : 1)).millisecondsSinceEpoch ~/ 1000})))}.sin-firma',
    'user': {'id': 4, 'username': 'prueba', 'name': 'Persona de prueba'},
  });

  test(
    'Persiste identidad, restaura sin red y nunca almacena JWT en SQLite',
    () async {
      final original = ejemplo();
      expect(await sesion.establecer(original), isTrue);
      final filas = OperacionesSqlite.exigir(
        await sql.seleccionar(EsquemaSqlite.sesion),
      );
      expect(jsonEncode(filas).contains(original.token), isFalse);
      expect(
        filas.single.keys,
        unorderedEquals([
          'id',
          'id_usuario',
          'username',
          'nombre',
          'autenticado_en',
          'expira_en',
        ]),
      );
      expect(tokens.valor == original.token, isTrue);
      final restaurada = ServicioSesion(repositorio);
      expect(await restaurada.restaurar(), isTrue);
      expect(restaurada.usuario?.id, 4);
      expect(restaurada.token != null, isTrue);
    },
  );

  test(
    'Instalación nueva no restaura sesión y elimina un token huérfano',
    () async {
      tokens.valor = 'token-huerfano-ficticio';
      expect(await sesion.restaurar(), isTrue);
      expect(sesion.existeSesion, isFalse);
      expect(tokens.valor, isNull);
    },
  );

  test('Otra fachada restaura identidad sin ninguna llamada remota', () async {
    await sesion.establecer(ejemplo());
    final otra = ServicioSesion(repositorio);
    expect(await otra.restaurar(), isTrue);
    expect(otra.usuario?.username, 'prueba');
    expect(otra.token != null, isTrue);
    expect(otra.requiereReautenticacion, isFalse);
  });

  test(
    'JWT expirado o 401 conserva identidad y cola pero exige autenticación remota',
    () async {
      await sesion.establecer(ejemplo(expirado: true));
      final otra = ServicioSesion(repositorio);
      await otra.restaurar();
      expect(otra.existeSesion, isTrue);
      expect(otra.requiereReautenticacion, isTrue);
      expect(otra.token, isNull);
      await sesion.establecer(ejemplo());
      await sesion.marcarReautenticacion();
      await otra.restaurar();
      expect(otra.existeSesion, isTrue);
      expect(otra.requiereReautenticacion, isTrue);
      expect(tokens.valor, isNull);
    },
  );

  test(
    'Logout comprueba pendientes y elimina sesión sin borrar operaciones',
    () async {
      final cola = RepositorioCola(sql);
      await cola.agregarPendiente(
        recurso: 'prueba',
        operacion: TipoOperacionLocal.crear,
        payload: {'descripcion': 'pendiente'},
      );
      await sesion.establecer(ejemplo());
      expect(await sesion.limpiar(), isTrue);
      expect(sesion.pendientesAlCerrar, isTrue);
      expect(tokens.valor, isNull);
      expect(sesion.usuario, isNull);
      final otra = ServicioSesion(repositorio);
      expect(await otra.restaurar(), isTrue);
      expect(otra.existeSesion, isFalse);
      expect(
        OperacionesSqlite.exigir(await cola.obtenerPendientes()),
        hasLength(1),
      );
    },
  );

  test(
    'Fallo del almacén seguro no publica sesión ni escribe JWT en SQLite',
    () async {
      tokens.fallar = true;
      expect(await sesion.establecer(ejemplo()), isFalse);
      expect(sesion.existeSesion, isFalse);
      expect(
        OperacionesSqlite.exigir(await sql.seleccionar(EsquemaSqlite.sesion)),
        isEmpty,
      );
    },
  );

  test(
    'Migración v1 a v2 preserva registros y sesión sobrevive cierre real de archivo',
    () async {
      final directorio = await Directory.systemTemp.createTemp(
        'sesion_sqlite_',
      );
      final archivo = File('${directorio.path}/prueba.db');
      final vieja = await databaseFactoryFfi.openDatabase(
        archivo.path,
        options: OpenDatabaseOptions(version: 1, onCreate: EsquemaSqlite.crear),
      );
      await vieja.insert(EsquemaSqlite.cola, {
        'recurso': 'prueba',
        'operacion': 'crear',
        'payload': '{"id":1}',
        'creado_en': DateTime.now().toUtc().toIso8601String(),
        'estado': 'pendiente',
      });
      await vieja.close();
      final nueva = ConexionSqlite(
        fabrica: databaseFactoryFfi,
        ruta: archivo.path,
      );
      try {
        final operaciones = OperacionesSqlite(nueva);
        final persistencia = RepositorioSesionLocal(operaciones, tokens);
        final primera = ServicioSesion(persistencia);
        expect(await primera.restaurar(), isTrue);
        expect(
          OperacionesSqlite.exigir(
            await operaciones.seleccionar(EsquemaSqlite.cola),
          ),
          hasLength(1),
        );
        expect(
          (await nueva.ejecutar(
            (db) => db.rawQuery('PRAGMA user_version'),
          )).single['user_version'],
          2,
        );
        await primera.establecer(ejemplo());
        await nueva.cerrar();
        final reiniciada = ServicioSesion(persistencia);
        expect(await reiniciada.restaurar(), isTrue);
        expect(reiniciada.usuario?.id, 4);
        expect(reiniciada.existeSesion, isTrue);
      } finally {
        await nueva.cerrar();
        await archivo.delete();
        await directorio.delete();
      }
    },
  );
}
