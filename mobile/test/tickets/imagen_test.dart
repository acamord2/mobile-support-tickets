import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tikets/app/services/servicio_imagen.dart';

/// Genera imágenes sintéticas para comprobar JPEG válido sin versionar fotografías personales.
void main() {
  test(
    'Imagen pequeña conserva metadatos, Base64 completo y bytes decodificables',
    () {
      final png = img.encodePng(img.Image(width: 32, height: 24));
      final r = comprimirImagen(png);
      final bytes = base64Decode(r.base64);
      expect(r.mime, 'image/jpeg');
      expect(r.originalBytes, png.length);
      expect(bytes.length, r.comprimidoBytes);
      expect(img.decodeJpg(bytes), isNotNull);
      expect(r.base64.startsWith('data:'), isFalse);
    },
  );
  test('Imagen grande redimensiona y comprime por debajo de 1 MB', () {
    final imagen = img.Image(width: 2400, height: 1800);
    final r = comprimirImagen(img.encodePng(imagen));
    expect(r.ancho, lessThanOrEqualTo(1600));
    expect(
      r.comprimidoBytes,
      lessThanOrEqualTo(ConfiguracionImagen.maximoBytes),
    );
    expect(img.decodeJpg(base64Decode(r.base64))!.width, r.ancho);
  });
  test('Contenido inválido devuelve un fallo controlado', () {
    expect(
      () => comprimirImagen(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
  test('Servicio procesa fuera del hilo y devuelve resultado válido', () async {
    final r = await ServicioImagen().procesar(
      img.encodePng(img.Image(width: 10, height: 10)),
    );
    expect(img.decodeJpg(base64Decode(r.base64)), isNotNull);
  });
}
