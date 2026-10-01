import '../soporte/sesion_simulada.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/network/i_conexion_api.dart';
import 'package:tikets/app/network/respuesta_api.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/main.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/modules/home/main_home.dart';
import 'package:tikets/modules/home/widgets_home/cabecera_inicio.dart';
import 'package:tikets/modules/home/widgets_home/cuerpo_inicio.dart';
import 'package:tikets/modules/home/widgets_home/pie_inicio.dart';
import 'package:tikets/modules/home/widgets_home/tarjeta_modulo.dart';
import 'package:tikets/modules/login/main_login.dart';
import '../auth/conexion_simulada.dart';

/// Verifica Home con identidad y red simuladas sin consultar API o PostgreSQL.
/// Comprueba accesos deshabilitados, semántica, layout y logout para conservar
/// comportamiento útil offline sin afirmar funcionalidades todavía inexistentes.
void main() {
  setUp(() => Get.put(crearSesionSimulada(), permanent: true));
  tearDown(Get.reset);

  /// Monta el flujo real de rutas con una identidad pública exclusiva del test.
  /// Devuelve el fake para comprobar que Home no genera solicitudes de negocio.
  Future<ConexionSimulada> abrirHome(
    WidgetTester tester, {
    String nombre = 'Persona de prueba',
  }) async {
    final conexion = ConexionSimulada(
      () async => const RespuestaApi(success: false),
    );
    Get.put<IConexionApi>(conexion, permanent: true);
    Get.put(
      ServicioConectividad(
        consultar: () async => [ConnectivityResult.wifi],
        cambios: const Stream.empty(),
      ),
      permanent: true,
    );
    await tester.pumpWidget(const AppTickets());
    await tester.pumpAndSettle();
    await Get.find<ServicioSesion>().establecer(
      SesionUsuario.fromJson({
        'token': 'token-simulado',
        'user': {'id': 9, 'username': 'prueba', 'name': nombre},
      }),
    );
    Get.offAllNamed<void>(Rutas.inicio);
    await tester.pumpAndSettle();
    return conexion;
  }

  testWidgets(
    'Home identifica al usuario y muestra dos tarjetas sin ejecutar acciones',
    (tester) async {
      final conexion = await abrirHome(tester);
      expect(find.byType(VistaInicio), findsOneWidget);
      expect(find.byType(CabeceraInicio), findsOneWidget);
      expect(find.byType(CuerpoInicio), findsOneWidget);
      expect(find.byType(PieInicio), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CabeceraInicio),
          matching: find.text('Persona de prueba'),
        ),
        findsOneWidget,
      );
      expect(find.text(TextosApp.appName), findsOneWidget);
      expect(find.text(TextosApp.bienvenida), findsOneWidget);
      expect(find.byType(TarjetaModulo), findsNWidgets(2));
      expect(find.text(TextosApp.descripcionTickets), findsOneWidget);
      expect(find.text(TextosApp.descripcionSincronizar), findsOneWidget);
      expect(find.text(TextosApp.moduloNoDisponible), findsNWidgets(2));
      await tester.tap(find.text(TextosApp.misTickets));
      await tester.tap(find.text(TextosApp.sincronizar));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, Rutas.inicio);
      expect(conexion.peticiones, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Offline mantiene Home, muestra indicador superior y permite logout',
    (tester) async {
      await abrirHome(tester);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      Get.find<ServicioConectividad>().redDisponible.value = false;
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(Get.currentRoute, Rutas.inicio);
      final cabecera = tester.getRect(find.byType(CabeceraInicio));
      final indicador = tester.getRect(find.byIcon(Icons.cloud_off));
      expect(indicador.right, closeTo(cabecera.right, 1));
      expect(indicador.top, closeTo(cabecera.top, 1));
      expect(find.byType(Dialog), findsNothing);
      final sesion = Get.find<ServicioSesion>();
      await tester.tap(find.text(TextosApp.cerrarSesion));
      await tester.pumpAndSettle();
      expect(sesion.usuario, isNull);
      expect(sesion.token, isNull);
      expect(find.byType(VistaLogin), findsOneWidget);
      expect(Get.currentRoute, Rutas.login);
      expect(Get.key.currentState!.canPop(), isFalse);
    },
  );

  testWidgets(
    'Tarjeta reutilizable respeta acción, estado y semántica accesible',
    (tester) async {
      final semantica = tester.ensureSemantics();
      try {
        var acciones = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TarjetaModulo(
                icono: Icons.assignment_outlined,
                titulo: 'Módulo de prueba',
                descripcion: 'Descripción de prueba',
                accion: () => acciones++,
                habilitado: false,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Módulo de prueba'));
        expect(acciones, 0);
        expect(
          tester.getSemantics(find.byType(TarjetaModulo)),
          matchesSemantics(
            hasEnabledState: true,
            isEnabled: false,
            isButton: true,
            label:
                'Módulo de prueba\nDescripción de prueba\n${TextosApp.moduloNoDisponible}',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TarjetaModulo(
                icono: Icons.assignment_outlined,
                titulo: 'Módulo de prueba',
                descripcion: 'Descripción de prueba',
                accion: () => acciones++,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Módulo de prueba'));
        expect(acciones, 1);
        expect(find.text(TextosApp.moduloNoDisponible), findsNothing);
      } finally {
        semantica.dispose();
      }
    },
  );

  for (final tamano in [const Size(320, 568), const Size(360, 640)]) {
    testWidgets(
      'Home no desborda en $tamano con nombre largo y texto ampliado',
      (tester) async {
        await tester.binding.setSurfaceSize(tamano);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await abrirHome(
          tester,
          nombre: 'Nombre extenso del técnico para comprobar lectura accesible',
        );
        expect(tester.takeException(), isNull);
        expect(find.text(TextosApp.cerrarSesion).hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(TextosApp.sincronizar),
          200,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text(TextosApp.sincronizar).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
