/// Modela la sucursal descargada a SQLite; evita datos fijos o respuestas API en UI.
class SucursalLocal {
  final int id;
  final String nombre, direccion;
  const SucursalLocal(this.id, this.nombre, this.direccion);
  SucursalLocal.desdeFila(Map<String, Object?> fila)
    : id = fila['id'] as int,
      nombre = fila['nombre'] as String,
      direccion = fila['direccion'] as String;
}
