import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/esquema_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/repositorio_coordinacion.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/database/repositorio_eventos.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/conexion.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_imagen.dart';
import 'package:tikets/app/services/servicio_sincronizacion.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/models/tipo_evento_ticket.dart';
import 'package:tikets/modules/detalle_ticket/controlador_detalle_ticket.dart';
import 'package:tikets/modules/home/controlador_inicio.dart';
import 'package:tikets/modules/seguimiento/controlador_seguimiento.dart';
import '../soporte/sesion_simulada.dart';

/// Comprueba alcance local, migración íntegra y envío oportunista sin depender de PostgreSQL ni LAN.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite cn;
  late OperacionesSqlite sql;
  late RepositorioTickets tickets;
  late RepositorioCoordinacion equipo;
  setUp(() {
    Get.testMode = true;
    cn = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    sql = OperacionesSqlite(cn);
    tickets = RepositorioTickets(sql);
    equipo = RepositorioCoordinacion(sql);
  });
  tearDown(() async {
    Get.reset();
    await cn.cerrar();
  });
  Future<int> crear(int usuario, int rol) => tickets.crear(
    usuario: usuario,
    rol: rol,
    sucursal: 10,
    titulo: 'Prueba',
    descripcion: 'Incidencia',
    programado: DateTime.utc(2026, 10, 1),
    autorNombre: 'Reportante',
  );

  test(
    'Usuario crea sin técnico; coordinación asigna/reasigna conservando UUID y autor',
    () async {
      final id = await crear(6, 4);
      final original = (await tickets.obtener(id, 6))!;
      expect(original.tecnicoId, isNull);
      expect(original.reportanteId, 6);
      await tickets.descargar(5, [
        {
          ...original.paraCrear(),
          'id': 70,
          'technicianId': null,
          'reporterUserId': 6,
          'status': 'Pending',
        },
      ], rol: 3);
      final local = (await tickets.agenda(5)).single;
      await equipo.guardar(5, [
        {'id': 1, 'name': 'Técnico A', 'coordinatorUserId': 5},
        {'id': 2, 'name': 'Técnico B', 'coordinatorUserId': 5},
      ]);
      await expectLater(
        equipo.asignar(local.idLocal, 5, 3, 9, 'Coordinador'),
        throwsStateError,
      );
      await equipo.asignar(local.idLocal, 5, 3, 1, 'Coordinador');
      await equipo.asignar(local.idLocal, 5, 3, 2, 'Coordinador');
      await equipo.asignar(local.idLocal, 5, 3, 2, 'Coordinador');
      final actualizado = (await tickets.obtener(local.idLocal, 5))!;
      expect(actualizado.clientRequestId, original.clientRequestId);
      expect(actualizado.tecnicoId, 2);
      expect(actualizado.reportanteId, 6);
      final eventos = await RepositorioEventos(sql).listar(local.idLocal, 5);
      expect(eventos.map((e) => e['tipo_evento']), ['ASIGNADO', 'REASIGNADO']);
      expect(eventos.last['descripcion'], contains('Técnico A'));
      expect(eventos.last['descripcion'], contains('Técnico B'));
      expect(eventos.last['autor_id'], 5);
      expect(eventos.last['usuario_nombre'], 'Coordinador');
      expect((await tickets.obtener(id, 6))!.tecnicoId, isNull);
      OperacionesSqlite.exigir(
        await sql.actualizar(
          'tickets',
          {'estado': 'Resolved'},
          donde: 'id_local = ?',
          argumentos: [local.idLocal],
        ),
      );
      await expectLater(
        equipo.asignar(local.idLocal, 5, 3, 1, 'Coordinador'),
        throwsStateError,
      );
    },
  );

  test(
    'Homes y detalle derivan capacidades del rol; Usuario no atiende ni resuelve',
    () async {
      final sesion = crearSesionSimulada();
      await sesion.establecer(
        SesionUsuario.fromJson({
          'token': 'prueba',
          'user': {
            'id': 6,
            'username': 'prueba',
            'name': 'Reportante',
            'roleId': 4,
            'role': 'Usuario',
          },
        }),
      );
      final id = await crear(6, 4);
      final detalle = ControladorDetalleTicket(
        tickets,
        RepositorioSucursales(sql),
        sesion,
        RepositorioEvidencias(sql),
      );
      await detalle.cargar(id);
      expect(detalle.puedeComenzar, isFalse);
      expect(detalle.puedeSeguir, isFalse);
      expect(detalle.puedeEditar, isFalse);
      expect(detalle.puedeAsignar, isFalse);
      final home = ControladorInicio(
        sesion,
        repositorio: tickets,
        sucursales: RepositorioSucursales(sql),
      );
      await home.cargar();
      expect(home.puedeCrear, isTrue);
      expect(home.esCoordinacion, isFalse);
      expect(home.ticketsVisibles, hasLength(1));
      detalle.onClose();
      home.onClose();
    },
  );

  test(
    'Guardado devuelve antes de HTTP; autoenvío serializa y deja pendientes si API falla',
    () async {
      final sesion = crearSesionSimulada();
      final exp =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      await sesion.establecer(
        SesionUsuario.fromJson({
          'token':
              'prueba.${base64Url.encode(utf8.encode(jsonEncode({'exp': exp})))}.firma',
          'user': {
            'id': 1,
            'username': 'prueba',
            'name': 'Técnico',
            'roleId': 2,
            'role': 'Técnico',
          },
        }),
      );
      final id = await crear(1, 2);
      await tickets.actualizar(
        id,
        1,
        titulo: 'Prueba',
        descripcion: 'Incidencia',
        estado: 'InProgress',
        programado: DateTime.utc(2026, 10, 1),
      );
      final gate = Completer<void>();
      var llamadasHealth = 0;
      var evento = 100;
      var disponible = true;
      final estadosEnviados = <String>[];
      final api = Conexion(
        ClienteApi(
          client: MockClient((r) async {
            if (r.url.path == '/api/ticket-status-requests') {
              return http.Response('[]', 200);
            }
            if (r.url.path == '/api/health/database') {
              llamadasHealth++;
              await gate.future;
              return http.Response(
                disponible ? '{"status":"ok","database":"connected"}' : '{}',
                disponible ? 200 : 503,
              );
            }
            if (r.url.path.endsWith('/events')) {
              return http.Response(
                r.method == 'POST' ? '{"id":${evento++}}' : '[]',
                200,
              );
            }
            if (r.method == 'POST') return http.Response('{"id":70}', 200);
            if (r.method == 'PUT') {
              estadosEnviados.add(
                (jsonDecode(r.body) as Map)['status'] as String,
              );
              return http.Response('{"id":70}', 200);
            }
            if (r.url.path == '/api/branches') return http.Response('[]', 200);
            final t = (await tickets.obtener(id, 1))!;
            return http.Response(
              jsonEncode([
                {
                  ...t.paraCrear(),
                  'id': 70,
                  'technicianId': 1,
                  'reporterUserId': 1,
                  'status': t.estado,
                },
              ]),
              200,
            );
          }),
        ),
      );
      final red = ServicioConectividad(
        consultar: () async => [ConnectivityResult.wifi],
        cambios: const Stream.empty(),
      );
      await red.refrescar();
      final sync = Get.put(
        ServicioSincronizacion(
          red,
          api,
          RepositorioCola(sql),
          sesion,
          tickets: tickets,
          sucursales: RepositorioSucursales(sql),
          evidencias: RepositorioEvidencias(sql),
        ),
      );
      final controlador = ControladorSeguimiento(
        tickets,
        RepositorioEvidencias(sql),
        sesion,
        ServicioImagen(),
      )..idTicket = id;
      controlador.descripcion.text = 'Trabajo realizado';
      expect(await controlador.guardar(volver: false), isTrue);
      expect(
        (await RepositorioEventos(sql).listar(id, 1)).last['sync_status'],
        'pending',
      );
      expect(llamadasHealth, 1);
      final ciclo = sync.sincronizar();
      expect(identical(ciclo, sync.sincronizar()), isTrue);
      gate.complete();
      await ciclo;
      expect(estadosEnviados, ['InProgress']);
      expect(
        OperacionesSqlite.exigir(
          await RepositorioCola(sql).obtenerPendientes(usuarioId: 1),
        ),
        isEmpty,
      );
      disponible = false;
      controlador.descripcion.text = 'Otro trabajo';
      expect(await controlador.guardar(volver: false), isTrue);
      await sync.sincronizar();
      expect(
        (await RepositorioEventos(sql).listar(id, 1)).last['sync_status'],
        'pending',
      );
      expect(sync.estado.value, EstadoSincronizacionActual.error);
      red.redDisponible.value = false;
      controlador.descripcion.text = 'Trabajo offline';
      expect(await controlador.guardar(volver: false), isTrue);
      await sync.sincronizar();
      expect(sync.estado.value, EstadoSincronizacionActual.offline);
      disponible = true;
      red.redDisponible.value = true;
      await sync.sincronizar();
      expect(
        OperacionesSqlite.exigir(
          await RepositorioCola(sql).obtenerPendientes(usuarioId: 1),
        ),
        isEmpty,
      );
      controlador.onClose();
      api.close();
    },
  );

  test(
    'Migración v4→v5 conserva cada campo previo y permite ASIGNADO',
    () async {
      final carpeta = await Directory.systemTemp.createTemp('roles-v5-');
      final ruta = '${carpeta.path}/base.db';
      final anterior = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(version: 4, onCreate: EsquemaSqlite.crear),
      );
      await anterior.insert('tickets', {
        'id_local': 9,
        'usuario_id': 1,
        'sucursal_id': 10,
        'titulo': 'Anterior',
        'descripcion': 'Problema',
        'estado': 'InProgress',
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
        'scheduled_at': '2026-10-01T10:00:00Z',
        'sync_status': 'pending',
      });
      await anterior.insert('ticket_eventos', {
        'id_local': 7,
        'ticket_id_local': 9,
        'usuario_id': 1,
        'autor_id': 1,
        'tipo_evento': 'SEGUIMIENTO',
        'descripcion': 'Trabajo previo',
        'created_at': '2026-10-01T00:00:00Z',
        'client_request_id': 'uuid-previo',
        'sync_status': 'pending',
      });
      final tablas = [
        'sesion_local',
        'tickets',
        'ticket_eventos',
        'evidencias',
        'cola_sincronizacion',
      ];
      final originales = <String, List<Map<String, Object?>>>{};
      for (final tabla in tablas) {
        originales[tabla] = await anterior.query(tabla);
      }
      await anterior.close();
      final migrada = ConexionSqlite(fabrica: databaseFactoryFfi, ruta: ruta);
      try {
        for (final entrada in originales.entries) {
          final nuevas = await migrada.ejecutar((db) => db.query(entrada.key));
          expect(nuevas.length, entrada.value.length);
          for (var i = 0; i < nuevas.length; i++) {
            for (final campo in entrada.value[i].entries) {
              expect(nuevas[i][campo.key], campo.value);
            }
          }
        }
        expect(
          (await migrada.ejecutar(
            (db) => db.rawQuery('PRAGMA user_version'),
          )).single['user_version'],
          6,
        );
        expect(
          (await migrada.ejecutar(
            (db) => db.query('tickets'),
          )).single['reportante_id'],
          isNull,
        );
        await RepositorioEventos(
          OperacionesSqlite(migrada),
        ).agregar(9, 1, TipoEventoTicket.asignado, 'Técnico destino #1');
      } finally {
        await migrada.cerrar();
        for (final archivo in carpeta.listSync().whereType<File>()) {
          await archivo.delete();
        }
        await carpeta.delete();
      }
    },
  );
}
