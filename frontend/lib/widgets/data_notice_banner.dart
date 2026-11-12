// ============================================================
// Solar-Grow - Aviso de datos de ejemplo o sin conexión
// ============================================================
import 'package:flutter/material.dart';
import '../config/demo_messages.dart';
import '../config/theme.dart';

/// Aviso de ancho completo. El texto hace salto de línea y, si hay
/// `onRetry`, el botón «Reintentar» va debajo del texto.
class DataNoticeBanner extends StatelessWidget {
  const DataNoticeBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.showRetry = false,
  });

  final String message;

  /// Acción de «Reintentar». Con `showRetry` y `onRetry` nulo, el botón
  /// aparece desactivado.
  final VoidCallback? onRetry;

  /// Muestra el botón aunque `onRetry` sea nulo (desactivado).
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: SolarColors.warning.withValues(alpha: 0.15),
        border: Border.all(color: SolarColors.warning),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline,
                  color: SolarColors.secondaryDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SolarColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null || showRetry)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text(DemoMessages.retry),
              ),
            ),
        ],
      ),
    );
  }
}
