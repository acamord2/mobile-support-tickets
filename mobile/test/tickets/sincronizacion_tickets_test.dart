import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/database/repositorio_sesion_local.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/conexion.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sincronizacion.dart';
import 'package:tikets/models/sesion_usuario.dart';
import '../soporte/sesion_simulada.dart';

/// Combina HTTP simulado y SQLite real para probar subida/reintento sin alterar PostgreSQL.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite local;
  late OperacionesSqlite sql;
  late RepositorioTickets tickets;
  late RepositorioCola cola;
  late ServicioSesion sesion;
  late ServicioConectividad red;
  late ServicioSincronizacion sync;
  late Conexion api;
  var posts = 0;
  var codigo = 200;
  var idEvento = 300;
  var disponible = true;
  final claves = <String>[];
  final rutas = <String>[];
  Future<void> autenticar(int id) => sesion.establecer(
    SesionUsuario.fromJson({
      'token':
          'prueba.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.firma',
      'user': {
        'id': id,
        'username': 'prueba$id',
        'name': 'Prueba',
        'roleId': 2,
        'role': 'Técnico',
      },
    }),
  );
  setUp(() async {
    posts = 0;
    codigo = 200;
    disponible = true;
    claves.clear();
    rutas.clear();
    local = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    sql = OperacionesSqlite(local);
    tickets = RepositorioTickets(sql);
    cola = RepositorioCola(sql);
    sesion = ServicioSesion(RepositorioSesionLocal(sql, TokenSimulado()));
    await autenticar(1);
    red = ServicioConectividad(
      consultar: () async => [ConnectivityResult.wifi],
      cambios: const Stream.empty(),
    );
    await red.refrescar();
    api = Conexion(
      ClienteApi(
        client: MockClient((req) async {
          if(req.url.path=='/api/ticket-status-requests') return http.Response('[]',200);
          rutas.add(req.url.path);
          if (req.url.path == '/api/health/database') {
            return http.Response(disponible ? '"invalid"' : '{}', 503);
          }
          return http.Response('{}', 500);
        }),
      ),
    );
  });
  tearDown(() async {
    api.close();
    await local.cerrar();
  });
  void configurar() {
    api.close();
    api = Conexion(
      ClienteApi(
        client: MockClient((req) async {
          if(req.url.path=='/api/ticket-status-requests') return http.Response('[]',200);
          rutas.add(req.url.path);
          if (req.url.path == '/api/health/database') {
            return http.Response(
              disponible ? ' {"status":"ok","database":"connected"}' : '{}',
              disponible ? 200 : 503,
            );
          }
          if (req.url.path.endsWith('/events')) {
            return http.Response(
              req.method == 'POST' ? '{"id":${idEvento++}}' : '[]',
              200,
            );
          }
          if (req.method == 'PUT') {
            return http.Response('{"id":105}', 200);
          }
          if (req.method == 'POST') {
            posts++;
            final payload = jsonDecode(req.body) as Map;
            if (payload['clientRequestId'] is String) {
              claves.add(payload['clientRequestId'] as String);
            }
            return http.Response(codigo == 200 ? ' {"id":105}' : '{}', codigo);
          }
          if (req.url.path == '/api/branches') {
            return http.Response(
              '[{"id":10,"name":"Centro","address":"Direccion"}]',
              200,
            );
          }
          if (req.url.path == '/api/tickets') {
            final locales = await tickets.agenda(1);
            return http.Response(
              jsonEncode(
                locales
                    .map(
                      (t) => {
                        ...t.paraCrear(),
                        'id': 105,
                        'technicianId': 1,
                        'reporterUserId': 1,
                        'status': t.estado,
                      },
                    )
                    .toList(),
              ),
              200,
            );
          }
          return http.Response('{}', 500);
        }),
      ),
    );
    sync = ServicioSincronizacion(
      red,
      api,
      cola,
      sesion,
      tickets: tickets,
      sucursales: RepositorioSucursales(sql),
      evidencias: RepositorioEvidencias(sql),
    );
  }

  Future<int> crear() => tickets.crear(
    usuario: 1,
    sucursal: 10,
    titulo: 'Local',
    descripcion: 'Sin red',
    programado: DateTime.utc(2026, 10, 1),
  );
  test('Offline no hace HTTP y conserva ticket pendiente', () async {
    final id = await crear();
    configurar();
    red.redDisponible.value = false;
    await sync.sincronizar();
    expect(rutas, isEmpty);
    expect((await tickets.obtener(id, 1))!.idRemoto, isNull);
    expect(sync.estado.value, EstadoSincronizacionActual.offline);
  });
  test('API inaccesible no confirma ni sube operaciones', () async {
    final id = await crear();
    configurar();
    disponible = false;
    await sync.sincronizar();
    expect(posts, 0);
    expect((await tickets.obtener(id, 1))!.syncStatus, 'pending');
    expect(sync.estado.value, EstadoSincronizacionActual.error);
  });
  test(
    'Subida y descarga conservan Id local, guardan remoto y catálogo SQLite',
    () async {
      final id = await crear();
      final clave = (await tickets.obtener(id, 1))!.clientRequestId;
      configurar();
      await Future.wait([sync.sincronizar(), sync.sincronizar()]);
      expect(
        sync.estado.value,
        EstadoSincronizacionActual.actualizado,
        reason: rutas.join(','),
      );
      expect(posts, 1);
      expect(claves, [clave]);
      expect((await tickets.obtener(id, 1))!.idRemoto, 105);
      expect(await RepositorioSucursales(sql).obtener(1), hasLength(1));
      expect(sync.estado.value, EstadoSincronizacionActual.actualizado);
    },
  );
  test('Error seguido de reintento reutiliza UUID original', () async {
    final id = await crear();
    configurar();
    codigo = 503;
    await sync.sincronizar();
    expect((await tickets.obtener(id, 1))!.idRemoto, isNull);
    codigo = 200;
    await sync.sincronizar();
    expect(claves, hasLength(2));
    expect(claves[0], claves[1]);
    expect((await tickets.obtener(id, 1))!.idRemoto, 105);
  });
  test('Cambio de ticket remoto usa PUT sin generar nueva clave', () async {
    final id = await crear();
    configurar();
    await sync.sincronizar();
    final clave = (await tickets.obtener(id, 1))!.clientRequestId;
    await tickets.actualizar(
      id,
      1,
      titulo: 'Trabajo nuevo',
      descripcion: 'Actualizado',
      estado: 'InProgress',
      programado: DateTime.utc(2026, 10, 3),
    );
    await sync.sincronizar();
    expect(posts, 1);
    expect((await tickets.obtener(id, 1))!.clientRequestId, clave);
    expect((await tickets.obtener(id, 1))!.syncStatus, 'synced');
    expect(rutas, contains('/api/tickets/105'));
  });
  test('401 conserva trabajo y exige reautenticación', () async {
    final id = await crear();
    configurar();
    codigo = 401;
    await sync.sincronizar();
    expect(sesion.requiereReautenticacion, isTrue);
    expect(sesion.usuario?.id, 1);
    expect((await tickets.obtener(id, 1))!.syncStatus, 'pending');
    expect(sync.estado.value, EstadoSincronizacionActual.reautenticacion);
  });
  test('Logout conserva pendientes A; usuario B no los envía', () async {
    final id = await crear();
    expect(await sesion.limpiar(), isTrue);
    await autenticar(2);
    configurar();
    await sync.sincronizar();
    expect(posts, 0);
    expect((await tickets.obtener(id, 1))!.syncStatus, 'pending');
    expect(
      OperacionesSqlite.exigir(await cola.obtenerPendientes(usuarioId: 1)),
      hasLength(3),
    );
  });
  test(
    'Ticket precede evidencia y un fallo de foto no recrea ticket',
    () async {
      final id = await crear();
      final ev = RepositorioEvidencias(sql);
      final foto = await ev.crear(id, 1, 'Diagnóstico');
      configurar();
      await sync.sincronizar();
      final envios = rutas
          .where((r) => r == '/api/tickets' || r.endsWith('/evidence'))
          .toList();
      expect(envios.take(2), ['/api/tickets', '/api/tickets/105/evidence']);
      expect((await ev.obtener(foto, 1))!['id_remoto'], 105);
      expect(posts, 2);
      await sync.sincronizar();
      expect(posts, 2);
    },
  );
}
