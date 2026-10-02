import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/routes/rutas.dart';
import 'servicio_autenticacion.dart';
import '../../app/services/servicio_sesion.dart';

/// Mantiene HTTP y JSON fuera de la presentación, valida campos localmente y protege contra peticiones simultáneas mientras espera la autenticación.
class ControladorLogin extends GetxController {
  final ServicioAutenticacion _autenticacion;
  final ServicioSesion _sesion;
  final usuario = TextEditingController();
  final contrasena = TextEditingController();
  final cargando = false.obs;
  final mostrarContrasena = false.obs;
  final error = ''.obs;

  ControladorLogin(this._autenticacion, this._sesion);

  /// Valida campos, solicita login y sustituye el historial al autenticar.
  Future<void> iniciarSesion() async {
    if (cargando.value) return;
    error.value = '';
    if (usuario.text.trim().isEmpty || contrasena.text.trim().isEmpty) {
      error.value = TextosApp.camposLoginRequeridos;
      return;
    }
    cargando.value = true;
    try {
      final resultado = await _autenticacion.iniciarSesion(
        usuario.text.trim(),
        contrasena.text,
      );
      if (isClosed) return;
      final sesion = resultado.sesion;
      if (sesion == null) {
        error.value = resultado.mensaje ?? TextosApp.errorLogin;
        return;
      }
      contrasena.clear();
      if (!await _sesion.establecer(sesion)) {
        if (!isClosed) error.value = TextosApp.errorSesion;
        return;
      }
      if (isClosed) return;
      Get.offAllNamed<void>(Rutas.inicio);
    } finally {
      if (!isClosed) {
        contrasena.clear();
        cargando.value = false;
      }
    }
  }

  /// Libera ambos campos al retirar la ruta para no conservar recursos ni contraseña.
  @override
  void onClose() {
    usuario.dispose();
    contrasena.dispose();
    super.onClose();
  }
}
