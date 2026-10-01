import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/esquema_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_eventos.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/services/servicio_imagen.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/modules/seguimiento/controlador_seguimiento.dart';
import 'package:tikets/modules/seguimiento/main_seguimiento.dart';
import 'package:tikets/app/constants/textos_app.dart';
import '../soporte/sesion_simulada.dart';

/// Comprueba migración conservadora, foto opcional y previsualización del JPEG final.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite cn;
  late RepositorioTickets tickets;
  late RepositorioEventos eventos;
  late RepositorioEvidencias evidencias;
  late ServicioSesion sesion;
  setUp(() async {
    cn = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    final sql = OperacionesSqlite(cn);
    tickets = RepositorioTickets(sql);
    eventos = RepositorioEventos(sql);
    evidencias = RepositorioEvidencias(sql);
    sesion = crearSesionSimulada();
    await sesion.establecer(
      SesionUsuario.fromJson({
        'token': 'simulado',
        'user': {'id': 1, 'username': 'prueba', 'name': 'Autor inicial'},
      }),
    );
  });
  tearDown(() async {
    Get.reset();
    await cn.cerrar();
  });
  Future<int> iniciar() async {
    final id = await tickets.crear(
      usuario: 1,
      sucursal: 10,
      titulo: 'Prueba',
      descripcion: 'Problema',
      programado: DateTime.utc(2026, 10, 2),
      autorNombre: 'Autor inicial',
    );
    await tickets.actualizar(
      id,
      1,
      titulo: 'Prueba',
      descripcion: 'Problema',
      estado: 'InProgress',
      programado: DateTime.utc(2026, 10, 2),
      autorNombre: 'Autor inicial',
    );
    return id;
  }

  test(
    'Solo foto es válido; vacío no guarda; autor y UUID sobreviven sin sesión',
    () async {
      final id = await iniciar();
      expect(() => eventos.guardarSeguimiento(id, 1, ''), throwsStateError);
      final foto = comprimirImagen(
        img.encodePng(img.Image(width: 8, height: 8)),
      );
      await eventos.guardarSeguimiento(
        id,
        1,
        '',
        autor: 'Responsable persistido',
        base64: foto.base64,
        mime: foto.mime,
      );
      final filas = await eventos.listar(id, 1);
      expect(filas.map((e) => e['tipo_evento']), [
        'CREADO',
        'PROGRAMADO',
        'EN_ATENCION',
        'SEGUIMIENTO',
      ]);
      final ultimo = filas.last;
      expect(ultimo['descripcion'], '');
      expect(ultimo['photo_base64'], foto.base64);
      expect(ultimo['usuario_nombre'], 'Responsable persistido');
      expect(ultimo['autor_id'], 1);
      expect(ultimo['client_request_id'], isNotEmpty);
      await sesion.limpiar();
      expect(
        (await eventos.listar(id, 1)).last['usuario_nombre'],
        'Responsable persistido',
      );
      expect(await eventos.listar(id, 2), isEmpty);
    },
  );
  test(
    'v3→v5 conserva todos los campos existentes y no inventa eventos',
    () async {
      final carpeta = await Directory.systemTemp.createTemp('eventos-v4-');
      final ruta = '${carpeta.path}/base.db';
      final db = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(version: 3, onCreate: EsquemaSqlite.crear),
      );
      await db.insert('sesion_local', {
        'id': 1,
        'id_usuario': 1,
        'username': 'prueba',
        'nombre': 'Autor',
        'autenticado_en': '2026-10-01T00:00:00Z',
      });
      await db.insert('sucursales', {
        'id': 10,
        'usuario_id': 1,
        'nombre': 'Sucursal',
        'direccion': 'Dirección',
      });
      await db.insert('tickets', {
        'id_local': 1,
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
      await db.insert('evidencias', {
        'ticket_id_local': 1,
        'usuario_id': 1,
        'descripcion': 'Anterior',
        'created_at': '2026-10-01T00:00:00Z',
        'sync_status': 'pending',
      });
      await db.insert('cola_sincronizacion', {
        'usuario_id': 1,
        'recurso': 'tickets',
        'operacion': 'actualizar',
        'payload': '{"id_local":1}',
        'creado_en': '2026-10-01T00:00:00Z',
        'estado': 'pendiente',
      });
      final anteriores = <String, List<Map<String, Object?>>>{};
      for (final tabla in [
        'sesion_local',
        'sucursales',
        'tickets',
        'evidencias',
        'cola_sincronizacion',
      ]) {
        anteriores[tabla] = await db.query(tabla);
      }
      await db.close();
      final migrada = ConexionSqlite(fabrica: databaseFactoryFfi, ruta: ruta);
      try {
        for (final entrada in anteriores.entries) {
          expect(
            await migrada.ejecutar(
              (d) => d.query(
                entrada.key,
                columns: entrada.value.isEmpty
                    ? null
                    : entrada.value.first.keys.toList(),
              ),
            ),
            entrada.value,
          );
        }
        expect(
          await migrada.ejecutar((d) => d.query('ticket_eventos')),
          isEmpty,
        );
        expect(
          (await migrada.ejecutar(
            (d) => d.rawQuery('PRAGMA user_version'),
          )).single['user_version'],
          5,
        );
      } finally {
        await migrada.cerrar();
        for (final archivo in carpeta.listSync().whereType<File>()) {
          await archivo.delete();
        }
        await carpeta.delete();
      }
    },
  );
  testWidgets(
    'Previsualiza bytes procesados; quitar/reemplazar no persiste nada',
    (tester) async {
      final controlador = Get.put(
        ControladorSeguimiento(tickets, evidencias, sesion, ServicioImagen()),
      );
      final foto = comprimirImagen(
        img.encodePng(img.Image(width: 8, height: 8)),
      );
      controlador.foto.value = foto;
      await tester.pumpWidget(const GetMaterialApp(home: VistaSeguimiento()));
      await tester.pumpAndSettle();
      final vista = tester.widget<Image>(find.byType(Image));
      expect((vista.image as MemoryImage).bytes, base64Decode(foto.base64));
      await tester.ensureVisible(find.text(TextosApp.quitarFoto));
      await tester.tap(find.text(TextosApp.quitarFoto));
      await tester.pumpAndSettle();
      expect(controlador.foto.value, isNull);
      expect(find.byType(Image), findsNothing);
      controlador.foto.value = foto;
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      final filas = await tester.runAsync(
        () => evidencias.sql.seleccionar('evidencias'),
      );
      expect(OperacionesSqlite.exigir(filas!), isEmpty);
    },
  );
}
