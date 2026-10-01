import 'package:flutter/material.dart';
import '../../app/theme/colores_app.dart';
import 'widgets_home/cabecera_inicio.dart';
import 'widgets_home/contenido_inicio.dart';

/// Compone Home con cabecera y contenido neutral sin anticipar Tickets.
/// Mantiene presentación, sesión y acciones separadas usando widgets del módulo.
class VistaInicio extends StatelessWidget {
  /// Crea la composición sin leer API ni SQLite desde la vista.
  const VistaInicio({super.key});

  /// Distribuye cabecera y bienvenida en un Scaffold con estilo centralizado.
  /// Sus widgets únicamente muestran estado y enlazan acciones al controller.
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ColoresApp.background,
    appBar: const CabeceraInicio(),
    body: const SafeArea(
      child: Center(
        child: Padding(padding: EdgeInsets.all(24), child: ContenidoInicio()),
      ),
    ),
  );
}
