import 'dart:math';

/// Genera UUID v4 una sola vez al insertar localmente usando aleatoriedad del sistema.
/// No se invoca durante sincronización para conservar la identidad entre reintentos.
abstract class IdentificadorCliente {
  static String crear() {
    final azar = Random.secure();
    final bytes = List<int>.generate(16, (_) => azar.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
