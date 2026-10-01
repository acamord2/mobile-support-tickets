import '../../app/services/servicio_sincronizacion.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/constants/textos_app.dart';
import '../../app/database/repositorio_sucursales.dart';
import '../../app/services/servicio_sesion.dart';
import '../../app/services/servicio_imagen.dart';
import '../../models/sucursal_local.dart';
import 'servicio_nuevo_ticket.dart';

/// Mantiene formulario y eventos; obtiene catálogo desde SQLite y guarda sin API.
/// Controla navegación y errores públicos sin introducir SQL ni procesamiento de fotos.
class ControladorNuevoTicket extends GetxController {
  final ServicioNuevoTicket servicio;
  final RepositorioSucursales repositorio;
  final ServicioSesion sesion;
  final titulo = TextEditingController(), descripcion = TextEditingController();
  final sucursales = <SucursalLocal>[].obs;
  final sucursal = Rxn<int>();
  final programado = DateTime.now().obs;
  final foto = Rxn<ImagenProcesada>();
  final ocupado = false.obs;
  final error = ''.obs;
  ControladorNuevoTicket(this.servicio, this.repositorio, this.sesion);
  @override
  void onReady() {
    super.onReady();
    cargar();
  }

  /// Lee sucursales propias locales y explica cuando todavía no hay catálogo descargado.
  Future<void> cargar() async {
    try {
      sucursales.assignAll(await repositorio.obtener(sesion.usuario!.id));
    } catch (_) {
      error.value = TextosApp.errorSqlite;
    }
  }

  /// Actualiza solo programación; fecha de creación se asignará al persistir.
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

  /// Prepara la foto con bloqueo de doble captura y errores sin rutas personales.
  Future<void> seleccionar(ImageSource origen) async {
    if (ocupado.value) return;
    ocupado.value = true;
    error.value = '';
    try {
      foto.value = await servicio.seleccionar(origen);
    } catch (_) {
      error.value = TextosApp.errorImagen;
    } finally {
      ocupado.value = false;
    }
  }

  /// Valida campos y persiste localmente antes de volver; permite crear sin JWT vigente.
  Future<void> guardar() async {
    if (ocupado.value) return;
    if (sesion.usuario?.roleId == 3) {
      error.value = TextosApp.ticketNoDisponible;
      return;
    }
    if (sesion.usuario == null ||
        sucursal.value == null ||
        titulo.text.trim().isEmpty ||
        descripcion.text.trim().isEmpty) {
      error.value = TextosApp.datosTicketInvalidos;
      return;
    }
    ocupado.value = true;
    error.value = '';
    try {
      await servicio.crear(
        sesion.usuario!.id,
        sucursal.value!,
        titulo.text,
        descripcion.text,
        programado.value,
        foto.value,
        autorNombre: sesion.usuario!.name,
        rol: sesion.usuario!.roleId ?? 2,
      );
      Get.back(result: true);
      if (Get.isRegistered<ServicioSincronizacion>()) {
        Get.find<ServicioSincronizacion>().solicitarAutomatica();
      }
    } catch (_) {
      error.value = TextosApp.errorSqlite;
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
