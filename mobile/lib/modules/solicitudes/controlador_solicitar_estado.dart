import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/tipo_solicitud_estado.dart';
import '../../app/database/repositorio_solicitudes.dart';
import '../../app/services/servicio_sesion.dart';
import '../../app/services/servicio_sincronizacion.dart';

/// Gestiona motivo y guardado local de solicitudes; no modifica estados finales ni espera HTTP.
class ControladorSolicitarEstado extends GetxController {
  final RepositorioSolicitudes repositorio;
  final ServicioSesion sesion;
  final motivo = TextEditingController();
  final ocupado = false.obs, error = ''.obs;
  late final int ticket;
  late final TipoSolicitudEstado tipo;
  ControladorSolicitarEstado(this.repositorio, this.sesion);
  @override
  void onInit() {
    super.onInit();
    final argumentos = Get.arguments as Map;
    ticket = argumentos['ticket'] as int;
    tipo = argumentos['tipo'] as TipoSolicitudEstado;
  }

  /// Exige motivo únicamente para cancelar; confirma SQLite antes de volver y solicitar envío automático.
  Future<void> guardar() async {
    if (ocupado.value) return;
    if (tipo == TipoSolicitudEstado.cancelacion && motivo.text.trim().isEmpty) {
      error.value = 'Escribe el motivo de cancelación.';
      return;
    }
    ocupado.value = true;
    error.value = '';
    try {
      final usuario = sesion.usuario!;
      await repositorio.crear(
        ticket,
        usuario.id,
        usuario.roleId!,
        usuario.name,
        tipo,
        motivo.text.trim().isEmpty ? null : motivo.text.trim(),
      );
      Get.back(result: true);
      if (Get.isRegistered<ServicioSincronizacion>()) {
        Get.find<ServicioSincronizacion>().solicitarAutomatica();
      }
    } catch (_) {
      error.value =
          'No se pudo guardar: revisa si ya existe una solicitud pendiente.';
    } finally {
      ocupado.value = false;
    }
  }

  @override
  void onClose() {
    motivo.dispose();
    super.onClose();
  }
}
