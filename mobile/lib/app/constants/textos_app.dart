/// Centraliza los textos utilizados por Login, Home y su infraestructura HTTP.
/// Permite reutilizar mensajes sin duplicarlos ni anticipar textos de pantallas
/// futuras; los errores técnicos no se muestran mediante excepciones sin procesar.
abstract class TextosApp {
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
