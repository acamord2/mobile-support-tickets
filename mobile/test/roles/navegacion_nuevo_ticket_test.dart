import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/routes/paginas_app.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/app/services/servicio_imagen.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/models/sesion_local.dart';
import 'package:tikets/models/usuario.dart';
import 'package:tikets/models/sucursal_local.dart';
import 'package:tikets/modules/home/controlador_inicio.dart';
import 'package:tikets/modules/home/main_home.dart';
import 'package:tikets/modules/nuevo_ticket/controlador_nuevo_ticket.dart';
import 'package:tikets/modules/nuevo_ticket/main_nuevo_ticket.dart';
import 'package:tikets/modules/nuevo_ticket/servicio_nuevo_ticket.dart';
import '../soporte/sesion_simulada.dart';

/// Aísla la navegación de la lectura asíncrona del catálogo; no necesita red ni IO.
class SucursalesNavegacion extends RepositorioSucursales {
  SucursalesNavegacion(super.operaciones);

  @override
  Future<List<SucursalLocal>> obtener(int usuario) async => [];
}

/// Reproduce el toque real del botón y usa la ruta registrada para detectar
/// conversiones incompatibles entre el resultado solicitado y GetPageRoute.
void main() {
  testWidgets('Usuario abre Nuevo ticket con + y vuelve a Home', (
    tester,
  ) async {
    sqfliteFfiInit();
    Get.put(
      ServicioConectividad(
        consultar: () async => [ConnectivityResult.wifi],
        cambios: const Stream<List<ConnectivityResult>>.empty(),
      ),
    );
    final cn = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    final sql = OperacionesSqlite(cn);
    final persistencia = RepositorioSesionSimulado();
    persistencia.local = SesionLocal(
      usuario: const Usuario(
        id: 6,
        username: 'reportante-prueba',
        name: 'Reportante',
        roleId: 4,
        role: 'Usuario',
      ),
      autenticadoEn: DateTime.now(),
    );
    final sesion = Get.put(ServicioSesion(persistencia));
    await sesion.restaurar();
    Get.put(ControladorInicio(sesion));
    Get.put(
      ControladorNuevoTicket(
        ServicioNuevoTicket(
          RepositorioTickets(sql),
          RepositorioEvidencias(sql),
          ServicioImagen(),
        ),
        SucursalesNavegacion(sql),
        sesion,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(initialRoute: Rutas.inicio, getPages: PaginasApp.pages),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(VistaNuevoTicket), findsOneWidget);
    Get.back(result: true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(VistaInicio), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    Get.reset();
    await cn.cerrar();
  });
}
