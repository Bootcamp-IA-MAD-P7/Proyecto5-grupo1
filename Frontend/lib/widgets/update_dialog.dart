import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// Diálogo de actualización disponible.
///
/// Muestra la versión nueva, las release notes si las hay,
/// una barra de progreso durante la descarga, y mensajes de error
/// con botón de reintentar.
///
/// Uso:
/// ```dart
/// UpdateDialog.show(context, updateService);
/// ```
class UpdateDialog extends StatelessWidget {
  final UpdateService service;
  final bool mandatory;

  const UpdateDialog({
    super.key,
    required this.service,
    this.mandatory = false,
  });

  /// Muestra el diálogo como bottom sheet modal.
  /// [mandatory] = true deshabilita el botón "Más tarde".
  static Future<void> show(
    BuildContext context,
    UpdateService service, {
    bool mandatory = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: !mandatory,
      enableDrag: !mandatory,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListenableBuilder(
        listenable: service,
        builder: (_, _) => UpdateDialog(
          service: service,
          mandatory: mandatory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remote = service.remoteVersion;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de arrastre
            if (!mandatory)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Icono + título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actualización disponible',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (remote != null)
                        Text(
                          'Versión ${remote.versionName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Release notes
            if (remote?.releaseNotes != null && remote!.releaseNotes!.isNotEmpty) ...[
              Text(
                'Novedades',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                remote.releaseNotes!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Contenido según estado
            _buildBody(context, theme),

            const SizedBox(height: 16),

            // Botones
            _buildActions(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    switch (service.status) {
      case UpdateStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Descargando…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${(service.downloadProgress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: service.downloadProgress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        );

      case UpdateStatus.installing:
        return Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(
              'Abriendo el instalador…',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        );

      case UpdateStatus.error:
        return _ErrorBanner(
          message: service.errorMessage ?? 'Error desconocido.',
          errorType: service.errorType,
        );

      default:
        // idle / updateAvailable / upToDate
        return const SizedBox.shrink();
    }
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    final isDownloading = service.status == UpdateStatus.downloading;
    final isInstalling = service.status == UpdateStatus.installing;
    final isError = service.status == UpdateStatus.error;
    final canCancel = isDownloading && !mandatory;

    if (isInstalling) {
      // Durante instalación no mostramos botones — el usuario ya tiene el
      // instalador nativo abierto.
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botón principal: Actualizar / Reintentar / Cancelar descarga
        if (isDownloading)
          OutlinedButton(
            onPressed: canCancel ? service.cancelDownload : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Cancelar descarga'),
          )
        else
          FilledButton.icon(
            onPressed: () => _onUpdatePressed(context),
            icon: Icon(isError ? Icons.refresh_rounded : Icons.download_rounded),
            label: Text(isError ? 'Reintentar' : 'Actualizar ahora'),
          ),

        // Botón secundario: Más tarde (solo si no es obligatoria)
        if (!mandatory && !isDownloading) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Más tarde'),
          ),
        ],
      ],
    );
  }

  Future<void> _onUpdatePressed(BuildContext context) async {
    try {
      await service.downloadAndInstall();
    } on UpdateException catch (e) {
      // Los errores ya están reflejados en service.errorMessage / service.errorType
      // gracias a que UpdateService notifica el estado.
      // Solo necesitamos manejar el caso especial de firma incorrecta,
      // donde el usuario debe desinstalar manualmente.
      if (e.type == UpdateErrorType.signatureMismatch && context.mounted) {
        _showSignatureMismatchDialog(context);
      }
    }
  }

  static void _showSignatureMismatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 40),
        title: const Text('Firma incompatible'),
        content: const Text(
          'El APK descargado está firmado con una clave diferente a la versión '
          'instalada. Esto impide actualizar directamente.\n\n'
          'Para solucionar el problema:\n'
          '1. Desinstala la app manualmente.\n'
          '2. Vuelve a abrir este enlace de descarga e instala la nueva versión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

/// Banner de error con icono y mensaje descriptivo.
class _ErrorBanner extends StatelessWidget {
  final String message;
  final UpdateErrorType? errorType;

  const _ErrorBanner({required this.message, this.errorType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconForError(errorType),
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForError(UpdateErrorType? type) {
    switch (type) {
      case UpdateErrorType.noInternet:
        return Icons.wifi_off_rounded;
      case UpdateErrorType.timeout:
        return Icons.timer_off_rounded;
      case UpdateErrorType.noInstallPermission:
        return Icons.block_rounded;
      case UpdateErrorType.insufficientStorage:
        return Icons.storage_rounded;
      case UpdateErrorType.signatureMismatch:
        return Icons.warning_amber_rounded;
      case UpdateErrorType.downloadInterrupted:
        return Icons.cloud_off_rounded;
      default:
        return Icons.error_outline_rounded;
    }
  }
}
