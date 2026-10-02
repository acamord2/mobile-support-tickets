import 'package:flutter/material.dart';
import '../../app/constants/textos_app.dart';
import 'widgets_nuevo_ticket/formulario_nuevo_ticket.dart';

/// Compone la pantalla de creación sin lógica de negocio y permite desplazamiento cuando aparece el teclado, manteniendo un formulario pequeño para trabajo offline.
class VistaNuevoTicket extends StatelessWidget {
  const VistaNuevoTicket({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(TextosApp.nuevoTicket)),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: FormularioNuevoTicket(),
      ),
    ),
  );
}
