import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Centraliza límites antes de Base64; 1 MiB corresponde a bytes JPEG comprimidos.
abstract class ConfiguracionImagen {
  static const maximoBytes = 1024 * 1024;
  static const dimensionMaxima = 1600;
}

/// Conserva metadatos del resultado JPEG sin rutas personales ni formato data URI.
class ImagenProcesada {
  final String base64, mime;
  final int originalBytes, comprimidoBytes, ancho, alto;
  const ImagenProcesada(
    this.base64,
    this.mime,
    this.originalBytes,
    this.comprimidoBytes,
    this.ancho,
    this.alto,
  );
}

/// Redimensiona, comprime y valida fuera del hilo de interfaz para mantener captura
/// independiente de widgets, SQLite y transporte. Nunca recorta cadenas Base64.
class ServicioImagen {
  Future<ImagenProcesada> procesar(Uint8List bytes) =>
      compute(comprimirImagen, bytes);
}

/// Ejecuta compresión JPEG progresiva en isolate y mide bytes antes de codificar.
/// Rechaza imágenes inválidas o imposibles de ajustar; conserva una imagen decodificable.
ImagenProcesada comprimirImagen(Uint8List bytes) {
  img.Image? decodificada;
  try {
    decodificada = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('Imagen inválida.');
  }
  if (decodificada == null) throw const FormatException('Imagen inválida.');
  var imagen = img.bakeOrientation(decodificada);
  if (imagen.width > ConfiguracionImagen.dimensionMaxima ||
      imagen.height > ConfiguracionImagen.dimensionMaxima) {
    imagen = img.copyResize(
      imagen,
      width: imagen.width >= imagen.height
          ? ConfiguracionImagen.dimensionMaxima
          : null,
      height: imagen.height > imagen.width
          ? ConfiguracionImagen.dimensionMaxima
          : null,
    );
  }
  for (var vuelta = 0; vuelta < 5; vuelta++) {
    for (final calidad in [85, 70, 55, 40]) {
      final jpeg = img.encodeJpg(imagen, quality: calidad);
      if (jpeg.length <= ConfiguracionImagen.maximoBytes) {
        return ImagenProcesada(
          base64Encode(jpeg),
          'image/jpeg',
          bytes.length,
          jpeg.length,
          imagen.width,
          imagen.height,
        );
      }
    }
    imagen = img.copyResize(
      imagen,
      width: (imagen.width * 0.75).round().clamp(1, 1600),
    );
  }
  throw const FormatException('La imagen supera el límite permitido.');
}
