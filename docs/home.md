# Home principal de la aplicación

## Responsabilidad y estructura

Home es la pantalla principal después del login. Identifica al técnico, presenta accesos futuros y permite cerrar sesión, manteniéndose utilizable sin conexión. No ejecuta API, SQLite, sincronización, JSON o procesos de Tickets.

```text
modules/home/
  main_home.dart                       # VistaInicio, composición principal
  controlador_inicio.dart              # identidad y logout existente
  widgets_home/
    cabecera_inicio.dart               # app, saludo, técnico e indicador global
    cuerpo_inicio.dart                 # accesos Mis tickets y Sincronizar
    tarjeta_modulo.dart                # presentación reutilizable de acceso
    pie_inicio.dart                    # acción Cerrar sesión
```

Se reutilizaron los nombres españoles existentes donde correspondía. CabeceraInicio equivale a HeaderHome, CuerpoInicio a BodyHome y PieInicio a FooterHome. ContenidoInicio fue sustituido por cuerpo/pie sin conservar widgets duplicados.

## Composición y dependencias

VistaInicio obtiene ControladorInicio con GetView. Entrega nombreTecnico a CabeceraInicio y el callback cerrarSesion a PieInicio. CuerpoInicio compone dos TarjetaModulo con textos centralizados. El contenido se desplaza cuando necesita más altura y el pie conserva un botón de al menos 48 puntos; SafeArea y ancho flexible evitan overflow.

El nombre proviene de ServicioSesion a través del controller, sin consultar API o PostgreSQL ni leer JWT desde la vista. No existe un nombre de técnico hardcodeado en la UI. Las vistas/widgets solo representan estado y enlazan eventos; disponibilidad según callback y semántica son decisiones visuales, sin reglas de negocio.

TarjetaModulo recibe icono, título, descripción, acción opcional y habilitado. Solo responde si está habilitada y tiene callback. Comunica disponibilidad mediante semántica y el texto Todavía no disponible, sin depender únicamente del color. La tarjeta completa es superficie táctil cuando tenga una acción. Cada widget relevante tiene clase/archivo propio.

## Accesos disponibles en esta etapa

| Acceso | Descripción | Estado |
|---|---|---|
| Mis tickets | Consulta y atiende tus tickets asignados. | Deshabilitado: el módulo todavía no existe |
| Sincronizar | Actualiza la información disponible en el dispositivo. | Deshabilitado: no hay sincronización de negocio |

No se invoca health desde Sincronizar ni se muestra un mensaje falso de sincronización completada. No se crean rutas inexistentes, tickets, estadísticas o registros de muestra para Home.

CuerpoInicio acepta callbacks futuros. La etapa de Tickets podrá crear el módulo/ruta y conectar la acción desde el controller sin rediseñar cabecera, tarjeta o pie. La acción de sincronización se conectará cuando exista un proceso real definido.

## Online, offline y logout

IndicadorDesconexion continúa en widgets/apartada/ y se reutiliza desde CabeceraInicio. ServicioConectividad conserva la detección: online no muestra icono, offline confirmado lo muestra arriba a la derecha y estado desconocido no afirma una desconexión. No hay diálogos invasivos, pantallas de error o redirección por perder red.

Home sigue abierto sin red y el cierre de sesión sigue disponible. PieInicio llama al mismo cerrarSesion de ControladorInicio: limpia token/usuario en memoria y Get.offAllNamed lleva a Login sin recuperar Home con atrás. No se duplicó la implementación ni se modificó funcionalmente Login. /login y /inicio permanecen registradas en Rutas/PaginasApp.

## Textos y estilos

- TextosApp: misTickets, descripcionTickets, sincronizar, descripcionSincronizar y moduloNoDisponible. Se reutilizan appName, bienvenida y cerrarSesion.
- ColoresApp: tarjeta, borde y deshabilitado. Los widgets reutilizan colores existentes sin valores nuevos dispersos.
- FuentesApp: tituloTarjeta y estadoModulo; título y cuerpo existentes se reutilizan.
- No se agregaron dependencias ni se cambiaron tecnologías, API, PostgreSQL, esquema SQLite o servicios de sincronización.

## Pruebas y validación

home_test.dart añade cinco pruebas para identidad/cabecera, presencia y bloqueo de tarjetas, semántica/acción reutilizable, offline/logout y renderizado con nombre largo/texto al doble de tamaño en 320×568 y 360×640. modulos_test.dart se ajustó al nuevo CuerpoInicio. Las pruebas anteriores conservan Login → Home, carga, errores y limpieza de sesión/historial.

Resultados:

- flutter analyze --no-pub: sin incidencias.
- flutter test --no-pub: 41 aprobadas, 2 opt-in omitidas por defecto.
- dotnet build: 0 errores y 0 advertencias; API sin cambios.
- GET /api/health/database y POST /api/auth/login: HTTP 200.
- Integración en dispositivo Android físico: Login real → Home, identidad, tarjetas, indicador y logout aprobados. El estado visual offline se simula mediante ServicioConectividad sin cambiar la red del teléfono; no representa una prueba con modo avión real.
- Capturas inicio.png e inicio_sin_red.png inspeccionadas visualmente, sin overflow. Se conservan en mobile/build/pruebas-integracion y no se versionan.
- APK normal compilado sin credenciales de prueba, configurado para API local por USB, instalado y abierto en el dispositivo físico. La prueba utiliza credenciales externas exclusivamente de DATOS_PRUEBA.md; nunca persiste JWT.

Se corrigió la agrupación de semántica de tarjetas durante pruebas y el cierre del handle de accesibilidad del test. El primer intento físico encontró la API detenida: se reinició en segundo plano y se validó el flujo correcto, sin modificar Login para compensarlo. Las advertencias de rendimiento/teclado de Android debug no produjeron fallos funcionales.

Documentación del código: revisada, mediante /// en español. Antes de cada commit se revisan cambios/status y valores privados en archivos/objetos Git. Los commits lógicos, push y comprobación final local/remoto se informan al cerrar la etapa.

No hay problemas funcionales o decisiones pendientes para completar Home. Conectar Tickets y sincronización permanece fuera de alcance hasta recibir instrucciones nuevas.
