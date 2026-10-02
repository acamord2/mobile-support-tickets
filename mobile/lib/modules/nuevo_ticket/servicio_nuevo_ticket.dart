import 'package:image_picker/image_picker.dart';
import '../../app/database/repositorio_tickets.dart';
import '../../app/database/repositorio_evidencias.dart';
import '../../app/services/servicio_imagen.dart';

/// Coordina captura y creación local sin consultar API.
class ServicioNuevoTicket {
  final RepositorioTickets tickets;
  final RepositorioEvidencias evidencias;
  final ServicioImagen imagen;
  final ImagePicker selector;
  ServicioNuevoTicket(
    this.tickets,
    this.evidencias,
    this.imagen, {
    ImagePicker? selector,
  }) : selector = selector ?? ImagePicker();

  /// Selecciona cámara/galería y delega compresión fuera de la presentación.
  Future<ImagenProcesada?> seleccionar(ImageSource origen) async {
    final archivo = await selector.pickImage(source: origen);
    return archivo == null
        ? null
        : await imagen.procesar(await archivo.readAsBytes());
  }

  /// Guarda solo localmente; evidencia opcional usa el Id local aun sin Id remoto.
  Future<int> crear(
    int usuario,
    int sucursal,
    String titulo,
    String descripcion,
    DateTime? programado,
    ImagenProcesada? foto, {
    String? autorNombre,
    int rol = 2,
  }) async {
    return tickets.crear(
      usuario: usuario,
      sucursal: sucursal,
      titulo: titulo,
      descripcion: descripcion,
      programado: programado,
      autorNombre: autorNombre,
      rol: rol,
      evidencia: foto == null
          ? null
          : {
              'descripcion': descripcion,
              'photo_base64': foto.base64,
              'mime': foto.mime,
            },
    );
  }
}
