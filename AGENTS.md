# Reglas del proyecto

- Mantener el alcance incremental solicitado; detenerse al terminar cada etapa.
- Usar español para clases, interfaces y archivos propios cuando exista un nombre claro. No traducir tipos de frameworks o paquetes externos.
- Conservar nombres de objetos SQL, URLs y campos de contratos HTTP existentes salvo autorización expresa. Program.cs, main.dart y archivos de configuración del framework conservan sus nombres convencionales.
- Documentar código propio en español explicando qué hace, cómo y por qué: XML en C# y /// en Dart. No comentar boilerplate generado.
- Mantener la arquitectura simple existente. No introducir capas, patrones, tecnologías o funcionalidades fuera de la etapa.
- PostgreSQL se instala manualmente mediante los documentos database/. La API no instala esquema, funciones, vistas, triggers ni datos demo.
- Cada tipo de SQL tiene una única fuente documental: DATABASE.md, DATOS_PRUEBA.md, FUNCIONES_SP.md, VISTAS.md o TRIGGERS.md.
- Mantener credenciales de desarrollo en User Secrets, fuera del repositorio. No exponer ni modificar secrets sin autorización.
- Las pruebas no pueden modificar persistentemente la configuración normal de conexión de la aplicación. Cualquier endpoint alternativo debe inyectarse exclusivamente en el entorno de prueba. El APK físico debe conservar su configuración LAN normal. No cambiar archivos de URL, perfiles de escucha ni puertos para pruebas; usar mocks, dependencias en memoria o argumentos temporales del proceso.
- Antes de commit/push: ejecutar las validaciones correspondientes, revisar staged y git status, y comprobar ausencia de secrets en archivos e historial. Usar commits por cambio lógico y mantener main compilable.
