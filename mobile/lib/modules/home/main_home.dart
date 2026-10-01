import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/colores_app.dart';
import 'controlador_inicio.dart';
import 'widgets_home/cabecera_inicio.dart';
import 'widgets_home/cuerpo_inicio.dart';
import 'widgets_home/pie_inicio.dart';

/// Compone el Home principal con identidad, accesos y logout independientes.
/// Obtiene el controller mediante GetX y entrega solo estado público y eventos;
/// no realiza consultas y mantiene utilizable la pantalla offline.
class VistaInicio extends GetView<ControladorInicio> {
  /// Crea la composición sin leer API ni SQLite desde la vista.
  const VistaInicio({super.key});

  /// Distribuye contenido desplazable y logout visible con estilos centrales.
  /// El ancho flexible y el scroll evitan overflow en teléfonos y textos grandes.
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ColoresApp.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CabeceraInicio(nombreTecnico: controller.nombreTecnico),
                      const SizedBox(height: 32),
                      const CuerpoInicio(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: PieInicio(alCerrarSesion: controller.cerrarSesion),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
