import 'sesion_usuario.dart';

/// Entrega sesión o error público sin exponer detalles de transporte.
class ResultadoAutenticacion {
  final SesionUsuario? sesion;
  final String? mensaje;

  const ResultadoAutenticacion({this.sesion, this.mensaje});

  bool get exito => sesion != null;
}
