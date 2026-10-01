/// Entrega datos o un mensaje público sin propagar SQL, payload ni excepciones.
/// Conserva un resultado común para operaciones locales de distintos módulos.
class ResultadoSqlite<T> {
  final T? datos;
  final String? mensaje;

  /// Crea un resultado exitoso después de completar la operación local.
  const ResultadoSqlite.exito(this.datos) : mensaje = null;

  /// Crea un fallo controlado sin incluir información técnica o sensible.
  const ResultadoSqlite.error(this.mensaje) : datos = null;

  /// Distingue éxito de error aunque el dato válido sea nullable.
  bool get exitoso => mensaje == null;
}
