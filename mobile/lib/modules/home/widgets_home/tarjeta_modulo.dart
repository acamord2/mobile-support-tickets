import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/colores_app.dart';
import '../../../app/theme/fuentes_app.dart';

/// Representa un acceso con icono, título, descripción, acción y disponibilidad.
/// Reutiliza estilo y semántica; deshabilitado no responde y muestra texto explícito
/// para que su estado no dependa únicamente del color.
class TarjetaModulo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback? accion;
  final bool habilitado;

  /// Recibe contenido y evento desde composición sin decidir reglas de negocio.
  const TarjetaModulo({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.accion,
    this.habilitado = true,
  });

  /// Hace interactiva toda la superficie solo cuando hay una acción habilitada.
  /// Los textos crecen sin altura fija y la semántica comunica disponibilidad.
  @override
  Widget build(BuildContext context) {
    final disponible = habilitado && accion != null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: disponible,
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: ColoresApp.tarjeta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: ColoresApp.borde),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disponible ? accion : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icono,
                        size: 28,
                        color: disponible
                            ? ColoresApp.primary
                            : ColoresApp.deshabilitado,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(titulo, style: FuentesApp.tituloTarjeta),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(descripcion, style: FuentesApp.body),
                  if (!disponible) ...[
                    const SizedBox(height: 12),
                    const Text(
                      TextosApp.moduloNoDisponible,
                      style: FuentesApp.estadoModulo,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
