import 'package:flutter/material.dart';
import '../../app/theme/colores_app.dart';
import 'widgets_login/cabecera_login.dart';
import 'widgets_login/formulario_login.dart';

/// Compone la pantalla de login con cabecera y formulario independientes.
/// Delega eventos al controller desde sus widgets, conservando autenticación
/// fuera de la vista y la excepción online de login al flujo local-first.
class VistaLogin extends StatelessWidget {
  /// Crea la composición sin abrir conexiones ni administrar la sesión.
  const VistaLogin({super.key});

  /// Organiza los widgets del módulo y adapta el contenido al teclado.
  /// La cabecera muestra estado global sin detectar conectividad por sí misma.
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
