import 'package:flutter/material.dart';
import '../../app/theme/colores_app.dart';
import 'widgets_login/cabecera_login.dart';
import 'widgets_login/formulario_login.dart';

/// Delega eventos al controller desde sus widgets, conservando autenticación fuera de la vista y la excepción online de login al flujo local-first.
class VistaLogin extends StatelessWidget {
  const VistaLogin({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ColoresApp.background,
    appBar: const CabeceraLogin(),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: const FormularioLogin(),
          ),
        ),
      ),
    ),
  );
}
