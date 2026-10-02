import 'package:tikets/app/database/repositorio_solicitudes.dart';
import 'package:tikets/models/tipo_solicitud_estado.dart';
import 'package:tikets/app/database/repositorio_eventos.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/conexion.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sincronizacion.dart';
import 'package:tikets/app/services/servicio_imagen.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/modules/detalle_ticket/controlador_detalle_ticket.dart';
import 'package:tikets/modules/editar_ticket/controlador_editar_ticket.dart';
import 'package:tikets/modules/seguimiento/controlador_seguimiento.dart';
import '../soporte/sesion_simulada.dart';

/// Verifica el flujo completo con SQLite real y transporte en memoria aislado de LAN.
/// Comprueba trabajo descriptivo obligatorio, foto opcional y ausencia de duplicados.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite cn;
  late RepositorioTickets tickets;
  late RepositorioEvidencias evidencias;
  late RepositorioSucursales sucursales;
  late RepositorioCola cola;
  late ServicioSesion sesion;
  late ControladorDetalleTicket detalle;
  late ControladorEditarTicket editar;
  late ControladorSeguimiento seguir;
  setUp(() async {
    cn = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    final sql = OperacionesSqlite(cn);
    tickets = RepositorioTickets(sql);
    evidencias = RepositorioEvidencias(sql);
    sucursales = RepositorioSucursales(sql);
    cola = RepositorioCola(sql);
    sesion = crearSesionSimulada();
    await sesion.establecer(
      SesionUsuario.fromJson({
        'token':
            'prueba.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.firma',
        'user': {
          'id': 1,
          'username': 'prueba',
          'name': 'Prueba',
          'roleId': 1,
          'role': 'Administrador',
        },
      }),
    );
    detalle = ControladorDetalleTicket(tickets, sucursales, sesion, evidencias);
    editar = ControladorEditarTicket(tickets, sesion);
    seguir = ControladorSeguimiento(
      tickets,
      evidencias,
      sesion,
      ServicioImagen(),
    );
  });
  tearDown(() async {
    editar.onClose();
    seguir.onClose();
    Get.reset();
    await cn.cerrar();
  });
  Future<int> crear() => tickets.crear(
    usuario: 1,
    sucursal: 10,
    titulo: 'MVP local',
    descripcion: 'Problema inicial',
    programado: DateTime.utc(2026, 10, 2),
  );

  test(
    'Crear, editar y resolver offline requiere texto, conserva identidad y no permite reabrir',
    () async {
      final id = await crear();
      final original = (await tickets.obtener(id, 1))!;
      await editar.cargar(id);
      editar.titulo.text = 'Problema editado';
      editar.descripcion.text = 'Descripción actualizada';
      editar.programado.value = DateTime.utc(2026, 10, 3);
      expect(await editar.guardar(volver: false), isTrue);
      await detalle.cargar(id);
      expect(detalle.ticket.value!.estado, 'Pending');
      await detalle.comenzarAtencion();
      expect(detalle.puedeSolicitar, isTrue);
      expect(detalle.ticket.value!.estado, 'InProgress');
      seguir.idTicket = id;
      expect(await seguir.guardar(volver: false), isFalse);
      seguir.descripcion.text =
          'Se reemplazó el cable y se comprobó funcionamiento.';
      final guardados = await Future.wait([
        seguir.guardar(volver: false),
        seguir.guardar(volver: false),
      ]);
      expect(guardados.where((v) => v), hasLength(1));
      final registros = (await RepositorioEventos(
        tickets.sql,
      ).listar(id, 1)).where((e) => e['tipo_evento'] == 'SEGUIMIENTO').toList();
      expect(registros, hasLength(1));
      expect(registros.single['photo_base64'], isNull);
      final solicitud = await RepositorioSolicitudes(
        tickets.sql,
      ).crear(id, 1, 1, 'Prueba', TipoSolicitudEstado.resolucion, null);
      expect((await tickets.obtener(id, 1))!.estado, 'InProgress');
      await RepositorioSolicitudes(
        tickets.sql,
      ).revisar(solicitud, 1, 1, 'Prueba', true);
      await detalle.cargar(id);
      final finalizado = (await tickets.obtener(id, 1))!;
      expect(finalizado.estado, 'Resolved');
      expect(finalizado.syncStatus, 'pending');
      expect(finalizado.clientRequestId, original.clientRequestId);
      expect(finalizado.creado, original.creado);
      expect(finalizado.idLocal, original.idLocal);
      expect(detalle.puedeEditar, isFalse);
      expect(detalle.puedeSeguir, isFalse);
      expect(detalle.seguimientos, hasLength(8));
      expect(await editar.guardar(volver: false), isFalse);
      expect(await seguir.guardar(volver: false), isFalse);
      await detalle.comenzarAtencion();
      expect((await tickets.obtener(id, 1))!.estado, 'Resolved');
      expect(
        OperacionesSqlite.exigir(await cola.obtenerPendientes(usuarioId: 1)),
        hasLength(10),
      );
      expect(await evidencias.listar(id, 2), isEmpty);
    },
  );

  test(
    'Foto real comprimida, envío ordenado, descarga y reintento no duplican ticket/evidencia',
    () async {
      final id = await crear();
      await detalle.cargar(id);
      await detalle.comenzarAtencion();
      seguir.idTicket = id;
      seguir.descripcion.text = 'Trabajo con fotografía';
      seguir.foto.value = comprimirImagen(
        img.encodePng(img.Image(width: 10, height: 10)),
      );
      expect(await seguir.guardar(volver: false), isTrue);
      final red = ServicioConectividad(
        consultar: () async => [ConnectivityResult.none],
        cambios: const Stream.empty(),
      );
      await red.refrescar();
      var postTickets = 0, postFotos = 0;
      final rutas = <String>[];
      Map<String, dynamic>? remoto;
      final eventosRemotos = <Map<String, dynamic>>[];
      final api = Conexion(
        ClienteApi(
          baseUrl: 'http://api.example.test',
          client: MockClient((r) async {
            rutas.add('${r.method} ${r.url.path}');
            if (r.url.path == '/api/ticket-status-requests' ||
                r.url.path == '/api/technicians') {
              return http.Response('[]', 200);
            }
            if (r.url.path == '/api/health/database') {
              return http.Response(
                '{"status":"ok","database":"connected"}',
                200,
              );
            }
            if (r.method == 'POST' && r.url.path == '/api/tickets') {
              postTickets++;
              remoto = {
                ...jsonDecode(r.body) as Map<String, dynamic>,
                'id': 50,
                'technicianId': 1,
                'status': 'Pending',
                'reporterUserId': 1,
              };
              return http.Response('{"id":50}', 200);
            }
            if (r.url.path.endsWith('/events')) {
              if (r.method == 'POST') {
                final e = jsonDecode(r.body) as Map<String, dynamic>;
                final previo = eventosRemotos
                    .where((x) => x['clientRequestId'] == e['clientRequestId'])
                    .toList();
                if (previo.isEmpty) {
                  eventosRemotos.add({
                    ...e,
                    'id': 80 + eventosRemotos.length,
                    'userId': 1,
                    'userName': 'Prueba',
                  });
                }
                final existente = eventosRemotos.firstWhere(
                  (x) => x['clientRequestId'] == e['clientRequestId'],
                );
                return http.Response(jsonEncode({'id': existente['id']}), 200);
              }
              return http.Response(
                jsonEncode(eventosRemotos),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (r.method == 'PUT') {
              remoto!.addAll(jsonDecode(r.body) as Map<String, dynamic>);
              return http.Response('{"id":50}', 200);
            }
            if (r.method == 'POST' &&
                r.url.path == '/api/tickets/50/evidence') {
              postFotos++;
              final e = jsonDecode(r.body) as Map<String, dynamic>;
              expect(e['photoBase64'], seguir.foto.value!.base64);
              remoto!['evidences'] = [
                {
                  ...e,
                  'id': 70,
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                },
              ];
              return http.Response('{"id":70}', postFotos == 1 ? 503 : 200);
            }
            if (r.url.path == '/api/branches') return http.Response('[]', 200);
            if (r.url.path == '/api/tickets') {
              return http.Response(
                jsonEncode([remoto]),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response('{}', 404);
          }),
        ),
      );
      addTearDown(api.close);
      final sync = ServicioSincronizacion(
        red,
        api,
        cola,
        sesion,
        tickets: tickets,
        sucursales: sucursales,
        evidencias: evidencias,
      );
      await sync.sincronizar();
      expect(rutas, isEmpty);
      red.redDisponible.value = true;
      await sync.sincronizar();
      expect(sync.estado.value, EstadoSincronizacionActual.error);
      expect(postTickets, 1);
      expect(eventosRemotos, hasLength(3));
      await sync.sincronizar();
      expect(
        sync.estado.value,
        EstadoSincronizacionActual.actualizado,
        reason: rutas.join(', '),
      );
      expect((await tickets.obtener(id, 1))!.estado, 'InProgress');
      expect((await tickets.obtener(id, 1))!.idRemoto, 50);
      expect((await evidencias.listar(id, 1)).single['sync_status'], 'synced');
      expect(
        rutas.indexOf('POST /api/tickets'),
        lessThan(rutas.indexOf('POST /api/tickets/50/evidence')),
      );
      await sync.sincronizar();
      expect(eventosRemotos, hasLength(4));
      expect(await RepositorioEventos(tickets.sql).listar(id, 1), hasLength(4));
      expect(postTickets, 1);
      expect(postFotos, 2);
      expect(await tickets.agenda(1), hasLength(1));
      expect(await evidencias.listar(id, 1), hasLength(1));
      expect(
        OperacionesSqlite.exigir(await cola.obtenerPendientes(usuarioId: 1)),
        isEmpty,
      );
    },
  );

  test(
    'Descarga seguimiento remoto propio sin duplicar ni sobrescribir evidencia pendiente',
    () async {
      final id = await crear();
      await evidencias.crear(id, 1, 'Local sin enviar');
      final datos = [
        {
          'id': 80,
          'description': 'Trabajo remoto',
          'photoBase64': null,
          'createdAt': '2026-10-01T10:00:00Z',
        },
      ];
      await evidencias.descargar(id, 1, datos);
      await evidencias.descargar(id, 1, datos);
      final registros = await evidencias.listar(id, 1);
      expect(registros, hasLength(2));
      expect(
        registros.where((e) => e['sync_status'] == 'pending'),
        hasLength(1),
      );
      expect(await evidencias.listar(id, 2), isEmpty);
    },
  );
}
