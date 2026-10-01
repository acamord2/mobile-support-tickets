/// Centraliza los textos utilizados por Login, Home y su infraestructura HTTP.
/// Permite reutilizar mensajes sin duplicarlos ni anticipar textos de pantallas
/// futuras; los errores técnicos no se muestran mediante excepciones sin procesar.
abstract class TextosApp {
  static const tecnicos = 'Técnicos';
  static const tecnicosACargo = 'Técnicos a mi cargo';
  static const ticketsSinAsignar = 'Tickets sin asignar';
  static const todosLosTickets = 'Todos los tickets';
  static const volverAlEquipo = 'Volver al equipo';
  static const misReportes = 'Mis reportes';
  static const ticketSinAsignar = 'Sin técnico asignado';
  static const tecnicoAsignado = 'Técnico asignado';
  static const seleccionarTecnico = 'Seleccionar técnico';
  static const asignarTecnico = 'Asignar técnico';
  static const reasignarTecnico = 'Reasignar técnico';
  static const errorAsignacion = 'No se pudo guardar la asignación.';
  static const eventoAsignado = 'Ticket asignado';
  static const eventoReasignado = 'Ticket reasignado';
  static const evidenciasDisponibles = 'Evidencias disponibles';
  static const quitarFoto = 'Quitar foto';
  static const previewFoto = 'Previsualización de la fotografía';
  static const eventoCreado = 'Ticket registrado';
  static const eventoProgramado = 'Atención programada';
  static const eventoReprogramado = 'Atención reprogramada';
  static const eventoEnAtencion = 'Atención iniciada';
  static const eventoResuelto = 'Ticket resuelto';
  static const programacionAnterior = 'Anterior';
  static const programacionNueva = 'Nueva';
  static const autorEvento = 'Usuario';
  static const editarTicket = 'Editar ticket';
  static const agregarSeguimiento = 'Agregar seguimiento';
  static const seguimiento = 'Seguimiento';
  static const trabajoRealizado = 'Descripción del trabajo realizado';
  static const resolverTicket = 'Resolver ticket';
  static const faltaSeguimiento =
      'Registra qué trabajo realizaste antes de resolver el ticket.';
  static const sinSeguimiento = 'Sin seguimiento registrado.';
  static const errorSeguimiento = 'No se pudo guardar el seguimiento.';
  static const errorResolver = 'No se pudo resolver el ticket.';
  static const imagenNoDisponible = 'No se pudo mostrar la fotografía.';
  static const detalleTicket = 'Detalle del ticket';
  static const identificadorTicket = 'Ticket';
  static const identificadorLocal = 'Identificador local';
  static const problemaTicket = 'Problema';
  static const atencionProgramada = 'Atención programada';
  static const ticketPendiente = 'Pendiente';
  static const ticketResuelto = 'Resuelto';
  static const comenzarAtencion = 'Comenzar atención';
  static const ticketNoDisponible =
      'El ticket no está disponible en este dispositivo para tu usuario.';
  static const errorComenzarAtencion =
      'No se pudo guardar el inicio de atención. Intenta nuevamente.';
  static const soporteTecnico = 'Soporte Técnico';
  static const buenosDias = 'Buenos días';
  static const buenasTardes = 'Buenas tardes';
  static const buenasNoches = 'Buenas noches';
  static const sinTicketsFiltrados =
      'No hay tickets con los filtros seleccionados.';
  static const agenda = 'Mi agenda';
  static const nuevoTicket = 'Nuevo ticket';
  static const sucursal = 'Sucursal';
  static const titulo = 'Problema / título';
  static const descripcion = 'Descripción';
  static const fecha = 'Fecha programada';
  static const hora = 'Hora programada';
  static const guardar = 'Guardar';
  static const pendientes = 'Pendientes';
  static const enAtencion = 'En atención';
  static const resueltos = 'Resueltos';
  static const sinTickets = 'No hay tickets disponibles en este dispositivo.';
  static const sinSucursales =
      'Sincroniza primero para descargar las sucursales.';
  static const datosTicketInvalidos =
      'Selecciona sucursal y completa título y descripción.';
  static const foto = 'Fotografía';
  static const camara = 'Tomar fotografía';
  static const galeria = 'Seleccionar fotografía';
  static const fotoPreparada = 'Fotografía preparada';
  static const errorImagen = 'No se pudo preparar la fotografía.';
  static const guardando = 'Guardando';
  static const actualizado = 'Actualizado';
  static const sincronizando = 'Sincronizando';
  static const reautenticacion = 'Inicia sesión nuevamente para sincronizar.';
  static const pendienteLocal = 'Pendiente de sincronizar';
  static const cargandoSesion = 'Restaurando sesión';
  static const errorSesion =
      'No se pudo completar el almacenamiento de la sesión.';
  static const reintentar = 'Reintentar';
  static const loginRequiereConexion =
      'Necesitas conexión de red para iniciar sesión.';
  static const appName = 'Incidencias técnicas';
  static const requestTimeout = 'La petición excedió el tiempo de espera.';
  static const apiUnavailable = 'No se pudo conectar con la API.';
  static const invalidResponse =
      'La API devolvió una respuesta que no es JSON válido.';
  static const communicationError = 'Ocurrió un error al realizar la petición.';
  static const requestFailed = 'La API rechazó la petición.';
  static const usuario = 'Usuario';
  static const contrasena = 'Contraseña';
  static const iniciarSesion = 'Iniciar sesión';
  static const autenticando = 'Iniciando sesión';
  static const bienvenida = 'Bienvenido';
  static const cerrarSesion = 'Cerrar sesión';
  static const misTickets = 'Mis tickets';
  static const descripcionTickets = 'Consulta y atiende tus tickets asignados.';
  static const sincronizar = 'Sincronizar';
  static const descripcionSincronizar =
      'Actualiza la información disponible en el dispositivo.';
  static const moduloNoDisponible = 'Todavía no disponible';
  static const sinConexion = 'Sin conexión de red';
  static const errorSqlite = 'No se pudo completar la operación local.';
  static const camposLoginRequeridos = 'Escribe tu usuario y contraseña.';
  static const datosLoginInvalidos =
      'Revisa los datos de usuario y contraseña.';
  static const credencialesIncorrectas = 'Usuario o contraseña incorrectos.';
  static const errorServidor =
      'El servidor no está disponible. Intenta más tarde.';
  static const errorConexionLogin =
      'No se pudo conectar. Revisa la conexión e inténtalo de nuevo.';
  static const respuestaLoginInvalida =
      'No se pudo validar la respuesta de autenticación.';
  static const errorLogin = 'No se pudo iniciar sesión. Inténtalo de nuevo.';
}
