import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Guarda en build las capturas públicas enviadas por la prueba Android.
/// Utiliza el driver oficial del SDK y omite respuestas adicionales para no
/// persistir credenciales ni JWT; los artefactos quedan excluidos de Git.
Future<void> main() async {
  await integrationDriver(
    responseDataCallback: null,
    onScreenshot:
        (
          String nombre,
          List<int> bytes, [
          Map<String, Object?>? argumentos,
        ]) async {
          final carpeta = Directory('build/pruebas-integracion');
          await carpeta.create(recursive: true);
          await File('${carpeta.path}/$nombre.png').writeAsBytes(bytes);
          return true;
        },
  );
}
