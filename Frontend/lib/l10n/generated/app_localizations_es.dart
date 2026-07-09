// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'SentiLife';

  @override
  String get fallDetectorTester => 'Probador del detector de caídas';

  @override
  String get language => 'Idioma';

  @override
  String get spanish => 'Español';

  @override
  String get english => 'Inglés';

  @override
  String get monitoringActive => 'Monitorizando...';

  @override
  String get monitoringInactive => 'Inactivo';

  @override
  String get sensorReadings => 'Lecturas de sensores';

  @override
  String get startMonitoringHint =>
      'Inicia el monitoreo para ver\nlos datos de los sensores';

  @override
  String get actions => 'Acciones';

  @override
  String get startMonitoring => 'Iniciar monitoreo';

  @override
  String get stopMonitoring => 'Detener monitoreo';

  @override
  String get analyzeReading => 'Analizar lectura';

  @override
  String get simulateFall => 'Simular caída';

  @override
  String get accelerometer => 'Acelerómetro';

  @override
  String get gyroscope => 'Giroscopio';

  @override
  String get heartRate => 'Frec. cardíaca';

  @override
  String get temperature => 'Temperatura';

  @override
  String get roomTemperature => 'Temperatura sala';

  @override
  String get light => 'Luz';

  @override
  String get roomLight => 'Luz sala';

  @override
  String get result => 'Resultado';

  @override
  String get fallDetected => '¡CAÍDA DETECTADA!';

  @override
  String get noFall => 'Sin caída';

  @override
  String confidence(String percentage) {
    return 'Confianza: $percentage%';
  }

  @override
  String get emergencyAlert => 'Alerta de emergencia';

  @override
  String get emergencyAlertDescription =>
      'En producción se notificaría al contacto de emergencia.';

  @override
  String get sensorReading => 'LECTURA DEL SENSOR';

  @override
  String get back => 'Volver';

  @override
  String get updateAvailable => 'Actualización disponible';

  @override
  String version(String versionName) {
    return 'Versión $versionName';
  }

  @override
  String get whatsNew => 'Novedades';

  @override
  String get downloading => 'Descargando…';

  @override
  String get openingInstaller => 'Abriendo el instalador…';

  @override
  String get unknownError => 'Error desconocido.';

  @override
  String get noInternetError => 'No hay conexión a internet.';

  @override
  String get timeoutError => 'La operación ha tardado demasiado.';

  @override
  String get installPermissionError =>
      'No se ha concedido permiso para instalar aplicaciones.';

  @override
  String get insufficientStorageError =>
      'No hay espacio suficiente para descargar la actualización.';

  @override
  String get signatureMismatchError =>
      'La firma de la actualización no coincide con la app instalada.';

  @override
  String get downloadInterruptedError => 'La descarga se ha interrumpido.';

  @override
  String get cancelDownload => 'Cancelar descarga';

  @override
  String get retry => 'Reintentar';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get later => 'Más tarde';

  @override
  String get incompatibleSignature => 'Firma incompatible';

  @override
  String get incompatibleSignatureDescription =>
      'El APK descargado está firmado con una clave diferente a la versión instalada. Esto impide actualizar directamente.\n\nPara solucionar el problema:\n1. Desinstala la app manualmente.\n2. Vuelve a abrir este enlace de descarga e instala la nueva versión.';

  @override
  String get understood => 'Entendido';
}
