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
  @override
  String get loginTitle => 'Iniciar sesión';
  @override
  String get email => 'Correo electrónico';
  @override
  String get password => 'Contraseña';
  @override
  String get login => 'Entrar';
  @override
  String get logout => 'Cerrar sesión';
  @override
  String get demoAccounts => 'Cuentas de demostración';
  @override
  String get roleCaregiver => 'Cuidador';
  @override
  String get roleMonitored => 'Persona monitorizada';
  @override
  String get roleItAdmin => 'Administrador IT';
  @override
  String get monitoredTitle => 'Mi monitorización';
  @override
  String get caregiverTitle => 'Panel del cuidador';
  @override
  String get itAdminTitle => 'Administración IT';
  @override
  String get persons => 'Personas';
  @override
  String get alerts => 'Alertas';
  @override
  String get history => 'Historial';
  @override
  String get export => 'Exportar';
  @override
  String get users => 'Usuarios';
  @override
  String get lastEvaluation => 'Última evaluación';
  @override
  String get noEvaluationYet => 'Sin evaluaciones todavía';
  @override
  String lastWindowAt(String timestamp) => 'Última ventana: $timestamp';
  @override
  String get modelVersion => 'Versión del modelo';
  @override
  String get noPersonsYet => 'No hay personas registradas';
  @override
  String get addPerson => 'Registrar persona';
  @override
  String get fullName => 'Nombre completo';
  @override
  String get birthDate => 'Fecha de nacimiento';
  @override
  String get sex => 'Sexo';
  @override
  String get weightKg => 'Peso (kg)';
  @override
  String get heightCm => 'Altura (cm)';
  @override
  String get emergencyContact => 'Contacto de emergencia';
  @override
  String get save => 'Guardar';
  @override
  String get age => 'Edad';
  @override
  String get consent => 'Consentimiento';
  @override
  String get monitoringStatus => 'Estado de monitorización';
  @override
  String get noAlerts => 'No hay alertas';
  @override
  String get alertDetail => 'Detalle de alerta';
  @override
  String get comment => 'Comentario';
  @override
  String get confirmFall => 'Confirmar caída';
  @override
  String get dismissAlert => 'Descartar alerta';
  @override
  String get status => 'Estado';
  @override
  String get exportDescription => 'Exporta el dataset etiquetado con feedback del cuidador para reentrenar el modelo.';
  @override
  String get exportDataset => 'Exportar dataset';
  @override
  String get exportReady => 'Export listo';
  @override
  String get consentTitle => 'Consentimiento de monitorización';
  @override
  String get consentBody => 'Autorizo el uso de mis datos de sensores para detectar caídas y mejorar el modelo de SentiLife. Puedo revocar este consentimiento en cualquier momento desde Ajustes.';
  @override
  String get acceptConsent => 'Acepto';
  @override
  String get decline => 'Rechazar';
  @override
  String get dataTransparency => 'Transparencia de datos';
  @override
  String get transparencyBody => 'Tus predicciones y el feedback que proporciones se utilizan para reentrenar y mejorar el modelo de detección de caídas. Los datos se procesan de forma segura y solo con tu consentimiento activo.';

}
