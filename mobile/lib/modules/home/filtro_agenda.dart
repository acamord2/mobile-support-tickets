import '../../app/constants/textos_app.dart';

/// Relaciona los tres filtros locales con estados HTTP existentes y textos comunes.
/// Evita cadenas repetidas sin cambiar los estados persistidos de los tickets.
enum FiltroAgenda {
  pendiente('Pending', TextosApp.pendientes),
  enAtencion('InProgress', TextosApp.enAtencion),
  resuelto('Resolved', TextosApp.resueltos);

  final String estado;
  final String texto;
  const FiltroAgenda(this.estado, this.texto);
}
