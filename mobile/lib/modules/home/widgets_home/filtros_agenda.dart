import 'package:flutter/material.dart';
import '../../../app/theme/colores_app.dart';
import '../filtro_agenda.dart';

class FiltrosAgenda extends StatelessWidget {
  final Map<String, int> conteos;
  final Set<FiltroAgenda> seleccionados;
  final ValueChanged<FiltroAgenda> alSeleccionar;
  const FiltrosAgenda({
    super.key,
    required this.conteos,
    required this.seleccionados,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, medidas) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: FiltroAgenda.values.map((filtro) {
          final seleccionado = seleccionados.contains(filtro);
          return SizedBox(
            width: (medidas.maxWidth - 16) / 3,
            child: Semantics(
              selected: seleccionado,
              button: true,
              child: OutlinedButton(
                onPressed: () => alSeleccionar(filtro),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  foregroundColor: ColoresApp.text,
                  backgroundColor: seleccionado
                      ? ColoresApp.seleccion.withValues(alpha: .12)
                      : ColoresApp.tarjeta,
                  side: BorderSide(
                    color: seleccionado
                        ? ColoresApp.seleccion
                        : ColoresApp.borde,
                    width: seleccionado ? 2 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      filtro.texto,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: seleccionado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${conteos[filtro.estado] ?? 0}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}
