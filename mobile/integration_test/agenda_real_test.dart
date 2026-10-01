import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/app/network/i_conexion_api.dart';
import 'package:tikets/app/network/rutas_api.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/services/almacenamiento_token.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/app/services/servicio_sincronizacion.dart';
import 'package:tikets/app/services/servicio_imagen.dart';
import 'package:tikets/modules/home/controlador_inicio.dart';
import 'package:tikets/modules/nuevo_ticket/controlador_nuevo_ticket.dart';

/// Aísla JWT de integración en memoria para no cambiar el almacén seguro normal del usuario.
class TokenPruebaFisica implements AlmacenamientoToken {
  String? _token;
  @override
  Future<String?> leer() async => _token;
  @override
  Future<void> guardar(String token) async {
    _token = token;
  }

  @override
  Future<void> eliminar() async {
    _token = null;
  }
}

/// Espera IO real del teléfono sin interpretar ausencia de animaciones como navegación concluida.
Future<void> esperar(WidgetTester tester, bool Function() listo) async {
  for (var intento = 0; intento < 400; intento++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (listo()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('No concluyó la operación física esperada.');
}

/// Prueba autorizada: base nativa separada, desconexión de servicio simulada y
/// API real por LAN. Conserva datos normales y añade un ticket/foto sintética remotos.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const username = String.fromEnvironment('DEMO_USERNAME');
  const password = String.fromEnvironment('DEMO_PASSWORD');
  testWidgets('Agenda física crea offline, persiste UUID y sincroniza fotografía', (
    tester,
  ) async {
    expect(username, isNotEmpty);
    expect(password, isNotEmpty);
    final ruta =
        '${await getDatabasesPath()}/agenda_prueba_${DateTime.now().millisecondsSinceEpoch}.db';
    final sqlite = Get.put(ConexionSqlite(ruta: ruta), permanent: true);
    Get.put<AlmacenamientoToken>(TokenPruebaFisica(), permanent: true);
    await tester.pumpWidget(const AppTickets());
    await esperar(tester, () => Get.currentRoute == Rutas.login);
    await tester.enterText(find.byType(TextField).first, username);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.ensureVisible(find.text(TextosApp.iniciarSesion));
    await tester.tap(find.text(TextosApp.iniciarSesion));
    await esperar(tester, () => Get.currentRoute == Rutas.inicio);
    final sesion = Get.find<ServicioSesion>();
    final sync = Get.find<ServicioSincronizacion>();
    await sync.sincronizar();
    if (sync.estado.value == EstadoSincronizacionActual.error) {
      final api = Get.find<IConexionApi>();
      final ramas = await api.get(RutasApi.sucursales, token: sesion.token);
      final agenda = await api.get(RutasApi.tickets, token: sesion.token);
      expect(ramas.statusCode, 200, reason: 'Descarga de sucursales');
      expect(agenda.statusCode, 200, reason: 'Descarga de agenda');
      await Get.find<RepositorioSucursales>().guardar(
        sesion.usuario!.id,
        ramas.data as List,
      );
      await Get.find<RepositorioTickets>().descargar(
        sesion.usuario!.id,
        agenda.data as List,
      );
    }
    expect(sync.estado.value, EstadoSincronizacionActual.actualizado);
    final home = Get.find<ControladorInicio>();
    await home.cargar();
    expect(home.catalogo, isNotEmpty);
    final red = Get.find<ServicioConectividad>();
    red.redDisponible.value = false;
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await esperar(tester, () => Get.currentRoute == Rutas.nuevoTicket);
    final formulario = Get.find<ControladorNuevoTicket>();
    await formulario.cargar();
    formulario.sucursal.value = home.catalogo.first.id;
    final titulo =
        'Prueba física: ticket offline ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(find.byType(TextField).first, titulo);
    await tester.enterText(
      find.byType(TextField).last,
      'Imagen sintética y persistencia autorizadas para validar la etapa.',
    );
    final procesada = await ServicioImagen().procesar(
      img.encodePng(img.Image(width: 80, height: 60)),
    );
    formulario.foto.value = procesada;
    await tester.pump();
    await tester.ensureVisible(find.text(TextosApp.guardar));
    await tester.tap(find.text(TextosApp.guardar));
    await esperar(tester, () => Get.currentRoute == Rutas.inicio);
    await home.cargar();
    await tester.pumpAndSettle();
    expect(find.text(titulo), findsOneWidget);
    final repositorio = Get.find<RepositorioTickets>();
    final usuario = sesion.usuario!.id;
    var local = (await repositorio.agenda(
      usuario,
    )).singleWhere((t) => t.titulo == titulo);
    final idLocal = local.idLocal, clave = local.clientRequestId;
    expect(local.idRemoto, isNull);
    expect(local.syncStatus, 'pending');
    final filas = OperacionesSqlite.exigir(
      await Get.find<OperacionesSqlite>().seleccionar(
        'evidencias',
        donde: 'ticket_id_local = ?',
        argumentos: [idLocal],
      ),
    );
    final evidenciaLocal = filas.single['id_local'] as int;
    expect(
      img.decodeJpg(base64Decode(filas.single['photo_base64'] as String)),
      isNotNull,
    );
    await sqlite.cerrar();
    local = (await repositorio.obtener(idLocal, usuario))!;
    expect(local.clientRequestId, clave);
    expect(local.idRemoto, isNull);
    red.redDisponible.value = true;
    await sync.sincronizar();
    expect(sync.estado.value, EstadoSincronizacionActual.actualizado);
    local = (await repositorio.obtener(idLocal, usuario))!;
    expect(local.idLocal, idLocal);
    expect(local.clientRequestId, clave);
    expect(local.idRemoto, isNotNull);
    final evidencia = (await Get.find<RepositorioEvidencias>().obtener(
      evidenciaLocal,
      usuario,
    ))!;
    expect(evidencia['id_remoto'], isNotNull);
    expect(evidencia['sync_status'], 'synced');
    expect(
      OperacionesSqlite.exigir(
        await Get.find<RepositorioCola>().obtenerPendientes(usuarioId: usuario),
      ),
      isEmpty,
    );
    await home.cargar();
    await tester.pumpAndSettle();
    expect(find.text(titulo), findsOneWidget);
    // Solo imprime identificadores públicos; jamás credenciales, fotografías ni JWT.
    debugPrint(
      'PRUEBA_FISICA_OK local=$idLocal remoto=${local.idRemoto} evidencia=${evidencia['id_remoto']} bytes=${procesada.comprimidoBytes}',
    );
    await sqlite.cerrar();
  });
}
