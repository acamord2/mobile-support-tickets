import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/constants/textos_app.dart';
import '../../app/database/repositorio_tickets.dart';
import '../../app/database/repositorio_evidencias.dart';
import '../../app/services/servicio_sesion.dart';
import '../../app/services/servicio_imagen.dart';

/// Registra trabajo descriptivo con foto opcional usando evidencia y cola existentes.
/// La compresión pertenece a ServicioImagen; ninguna acción depende de conectividad.
class ControladorSeguimiento extends GetxController {
  final RepositorioTickets tickets;
  final RepositorioEvidencias evidencias;
  final ServicioSesion sesion;
  final ServicioImagen imagen;
  final ImagePicker selector;
  final descripcion = TextEditingController();
  final foto = Rxn<ImagenProcesada>();
  final ocupado = false.obs;
  final error = ''.obs;
  int? idTicket;
  ControladorSeguimiento(
    this.tickets,
    this.evidencias,
    this.sesion,
    this.imagen, {
    ImagePicker? selector,
  }) : selector = selector ?? ImagePicker();

  @override
  void onReady() {
    super.onReady();
    final id = Get.arguments;
    if (id is int) idTicket = id;
  }

  /// Selecciona cámara/galería y conserva solo JPEG comprimido, con límite existente.
  Future<void> seleccionar(ImageSource origen) async {
    if (ocupado.value) return;
    ocupado.value = true;
    error.value = '';
    try {
      final archivo = await selector.pickImage(source: origen);
      if (archivo != null) {
        foto.value = await imagen.procesar(await archivo.readAsBytes());
      }
    } catch (_) {
      error.value = TextosApp.errorImagen;
    } finally {
      ocupado.value = false;
    }
  }

  /// Exige descripción y ticket propio En atención; guarda evidencia+cola sin API.
  Future<bool> guardar({bool volver = true}) async {
    if (ocupado.value) return false;
    if (descripcion.text.trim().isEmpty ||
        descripcion.text.trim().length > 10000) {
      error.value = TextosApp.faltaSeguimiento;
      return false;
    }
    ocupado.value = true;
    error.value = '';
    try {
      final usuario = sesion.usuario?.id;
      final t = usuario == null || idTicket == null
          ? null
          : await tickets.obtener(idTicket!, usuario);
      if (t == null ||
          t.estado != 'InProgress' ||
          sesion.usuario?.id != usuario) {
        error.value = TextosApp.ticketNoDisponible;
        return false;
      }
      await evidencias.crear(
        t.idLocal,
        usuario!,
        descripcion.text,
        base64: foto.value?.base64,
        mime: foto.value?.mime,
      );
      if (volver) Get.back(result: true);
      return true;
    } catch (_) {
      error.value = TextosApp.errorSeguimiento;
      return false;
    } finally {
      ocupado.value = false;
    }
  }

  @override
  void onClose() {
    descripcion.dispose();
    super.onClose();
  }
}
