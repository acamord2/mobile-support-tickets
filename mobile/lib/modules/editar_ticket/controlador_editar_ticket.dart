import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/database/repositorio_tickets.dart';
import '../../app/services/servicio_sesion.dart';

/// Edita únicamente título, descripción y programación propios desde SQLite.
/// Relee estado al guardar para conservar identidad y bloquear tickets resueltos.
class ControladorEditarTicket extends GetxController {
  final RepositorioTickets tickets;
  final ServicioSesion sesion;
  final titulo = TextEditingController(), descripcion = TextEditingController();
  final programado = DateTime.now().obs;
  final ocupado = false.obs, disponible = false.obs;
  final error = ''.obs;
  int? _id;
  ControladorEditarTicket(this.tickets, this.sesion);

  @override
  void onReady() {
    super.onReady();
    final id = Get.arguments;
    if (id is int) cargar(id);
  }

  /// Carga campos editables del propietario, sin consultar API ni cambiar estado.
  Future<void> cargar(int id) async {
    _id = id;
    try {
      final usuario = sesion.usuario?.id;
      final t = usuario == null ? null : await tickets.obtener(id, usuario);
      if (t == null || t.estado == 'Resolved') {
        error.value = TextosApp.ticketNoDisponible;
        return;
      }
      titulo.text = t.titulo;
      descripcion.text = t.descripcion;
      programado.value = t.programado.toLocal();
      disponible.value = true;
    } catch (_) {
      error.value = TextosApp.errorSqlite;
    }
  }

  /// Conserva hora al elegir fecha y fecha al elegir hora del dispositivo.
  Future<void> fecha(BuildContext contexto) async {
    final actual = programado.value;
    final elegida = await showDatePicker(
      context: contexto,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (elegida != null) {
      programado.value = DateTime(
        elegida.year,
        elegida.month,
        elegida.day,
        actual.hour,
        actual.minute,
      );
    }
  }

  /// Selecciona hora local; el repositorio convierte programación a UTC al persistir.
  Future<void> hora(BuildContext contexto) async {
    final actual = programado.value;
    final elegida = await showTimePicker(
      context: contexto,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (elegida != null) {
      programado.value = DateTime(
        actual.year,
        actual.month,
        actual.day,
        elegida.hour,
        elegida.minute,
      );
    }
  }

  /// Valida negocio y utiliza la transacción de actualización/cola antes de volver.
  Future<bool> guardar({bool volver = true}) async {
    if (ocupado.value || !disponible.value) return false;
    if (titulo.text.trim().isEmpty ||
        descripcion.text.trim().isEmpty ||
        titulo.text.trim().length > 200 ||
        descripcion.text.trim().length > 10000) {
      error.value = TextosApp.datosTicketInvalidos;
      return false;
    }
    ocupado.value = true;
    error.value = '';
    try {
      final usuario = sesion.usuario?.id;
      final t = usuario == null ? null : await tickets.obtener(_id!, usuario);
      if (t == null ||
          t.estado == 'Resolved' ||
          sesion.usuario?.id != usuario) {
        error.value = TextosApp.ticketNoDisponible;
        return false;
      }
      await tickets.actualizar(
        t.idLocal,
        usuario!,
        titulo: titulo.text,
        descripcion: descripcion.text,
        estado: t.estado,
        programado: programado.value,
        autorNombre: sesion.usuario!.name,
      );
      if (volver) Get.back(result: true);
      return true;
    } catch (_) {
      error.value = TextosApp.errorSqlite;
      return false;
    } finally {
      ocupado.value = false;
    }
  }

  @override
  void onClose() {
    titulo.dispose();
    descripcion.dispose();
    super.onClose();
  }
}
