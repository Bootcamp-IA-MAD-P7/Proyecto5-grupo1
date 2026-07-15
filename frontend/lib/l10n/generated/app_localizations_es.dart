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
  String get loginSubtitle => 'Inicia sesión para continuar';

  @override
  String get registerSubtitle => 'Crea tu cuenta';

  @override
  String get requiredField => 'Obligatorio';

  @override
  String get invalidEmail => 'Email inválido';

  @override
  String get passwordMinLength => 'Mín. 8 caracteres';

  @override
  String get connectionError => 'Error de conexión. ¿Está el backend activo?';

  @override
  String get register => 'Registrarse';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get noAccountRegister => '¿No tienes cuenta? Regístrate';

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
  String get registrationRolePrompt => 'Tipo de perfil';

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
  String lastWindowAt(String timestamp) {
    return 'Última ventana: $timestamp';
  }

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
  String get monitoredUserEmail => 'Email de la cuenta monitorizada';

  @override
  String get monitoredUserEmailRequired =>
      'Introduce el email de una cuenta MONITORED existente.';

  @override
  String get pendingLinkStatus => 'PENDING_LINK';

  @override
  String get pendingLinkTitle => 'Vinculación pendiente';

  @override
  String get pendingLinkBody =>
      'Tu cuidador debe registrar tu ficha con el email de esta cuenta antes de vincular el dispositivo.';

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
  String get exportDescription =>
      'Exporta el dataset etiquetado con feedback del cuidador para reentrenar el modelo.';

  @override
  String get exportDataset => 'Exportar dataset';

  @override
  String get exportReady => 'Export listo';

  @override
  String get exportDownloadSuccess => 'Dataset descargado correctamente.';

  @override
  String get exportDownloadError =>
      'No se pudo descargar el dataset. Inténtalo de nuevo.';

  @override
  String get monitoredTabStatus => 'Estado';

  @override
  String get monitoredTabSensors => 'Sensores';

  @override
  String get liveSensorsCaption =>
      'Esto es lo que el móvil está midiendo ahora.';

  @override
  String get sensorsPausedMessage =>
      'La monitorización está detenida. Inicia el monitoreo para ver las señales en vivo.';

  @override
  String get viewLiveSensorsLink => 'Ver sensores en vivo';

  @override
  String get consentTitle => 'Consentimiento de monitorización';

  @override
  String get consentBody =>
      'Autorizo el uso de mis datos de sensores para detectar caídas y mejorar el modelo de SentiLife. Puedo revocar este consentimiento en cualquier momento desde Ajustes.';

  @override
  String get consentSaved => 'Consentimiento registrado correctamente.';

  @override
  String get consentError =>
      'No se pudo registrar el consentimiento. Inténtalo de nuevo.';

  @override
  String get consentRequired =>
      'Se requiere consentimiento activo para enviar datos de sensores.';

  @override
  String get pairingRequired =>
      'Vincula el dispositivo con el código del cuidador antes de aceptar el consentimiento.';

  @override
  String get pairingTitle => 'Vincular dispositivo';

  @override
  String get pairingCodeLabel => 'Código del cuidador';

  @override
  String get pairingCodeHint => 'SL-XXXXXX';

  @override
  String get pairDevice => 'Vincular';

  @override
  String get pairingSuccess => 'Dispositivo vinculado correctamente.';

  @override
  String get pairingError =>
      'No se pudo vincular el dispositivo. Inténtalo de nuevo.';

  @override
  String get deviceLinked => 'Dispositivo vinculado';

  @override
  String get deviceLinkedSubtitle =>
      'Este móvil está asociado a tu perfil monitorizado.';

  @override
  String get acceptConsent => 'Acepto';

  @override
  String get decline => 'Rechazar';

  @override
  String get dataTransparency => 'Transparencia de datos';

  @override
  String get transparencyBody =>
      'Tus predicciones y el feedback que proporciones se utilizan para reentrenar y mejorar el modelo de detección de caídas. Los datos se procesan de forma segura y solo con tu consentimiento activo.';

  @override
  String get revokeConsent => 'Revocar consentimiento';

  @override
  String get revokeConsentConfirm =>
      '¿Seguro que quieres revocar el consentimiento? Se detendrá la monitorización y no se enviarán más datos.';

  @override
  String get consentRevoked => 'Consentimiento revocado.';

  @override
  String get consentRevokeError =>
      'No se pudo revocar el consentimiento. Inténtalo de nuevo.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get pairingCodeShare => 'Código de vinculación';

  @override
  String get userActive => 'Activo';

  @override
  String get userInactive => 'Inactivo';

  @override
  String get userStatusUpdated => 'Estado del usuario actualizado.';

  @override
  String get userStatusError => 'No se pudo actualizar el estado del usuario.';

  @override
  String get pairingCredentialMissing =>
      'El vínculo guardado pertenece a una versión anterior. Vuelve a emparejar el dispositivo para continuar.';

  @override
  String get lastEvaluationLoadError =>
      'No se pudo cargar la última evaluación. El dispositivo continúa vinculado.';

  @override
  String get sensorStartError =>
      'No se pudieron iniciar el acelerómetro y el giroscopio.';

  @override
  String get sensorUnavailableTitle => 'Sensores no disponibles';

  @override
  String get sensorUnavailableBody =>
      'Este dispositivo no tiene los sensores inerciales necesarios para monitorizar caídas. Usa un móvil con acelerómetro y giroscopio.';

  @override
  String get sensorUnavailableRetry => 'Comprobar de nuevo';

  @override
  String get sensorAvailable => 'Disponible';

  @override
  String get sensorMissing => 'No disponible';

  @override
  String get updateNoRemoteVersion =>
      'No hay versión remota cargada. Llama a checkForUpdate() primero.';

  @override
  String get updateVersionCheckUnexpected =>
      'Error inesperado al comprobar la versión.';

  @override
  String get updateDownloadUnexpected =>
      'Error inesperado durante la descarga.';

  @override
  String get updatePhaseVersionCheck => 'comprobación de versión';

  @override
  String get updatePhaseApkDownload => 'descarga del APK';

  @override
  String updateTimeout(String phase) {
    return 'La $phase tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.';
  }

  @override
  String updateServerError(String code) {
    return 'El servidor devolvió un error (código $code). Inténtalo más tarde.';
  }

  @override
  String get updateInstallPermissionDetail =>
      'No tienes permiso para instalar apps de fuentes desconocidas.\nVe a Ajustes > Aplicaciones > esta app > Instalar apps desconocidas y actívalo.';

  @override
  String updateApkNotFound(String path) {
    return 'El archivo APK no se encontró en \"$path\". Intenta descargar de nuevo.';
  }

  @override
  String get updateNoPackageManager =>
      'No se encontró ningún gestor de paquetes para instalar el APK.';

  @override
  String updateInstallerError(String message) {
    return 'Error al abrir el instalador: $message';
  }

  @override
  String get updateSignatureMismatchDetail =>
      'La firma del APK no coincide con la versión instalada.\nDesinstala la app manualmente e instala la nueva versión.';

  @override
  String get mlops => 'MLOps';

  @override
  String get mlopsTitle => 'Reentrenamiento del modelo';

  @override
  String get mlopsDescription =>
      'Lanza un job de reentrenamiento con feedback de producción. El pipeline evalúa drift, entrena y decide si promover el nuevo modelo.';

  @override
  String get mlopsStartRetrain => 'Iniciar reentrenamiento';

  @override
  String get mlopsRetrainRunning => 'Reentrenamiento en curso…';

  @override
  String get mlopsPhase => 'Fase';

  @override
  String get mlopsDecision => 'Decisión';

  @override
  String get mlopsRecall => 'Recall (test)';

  @override
  String get mlopsCurrentRecall => 'Recall actual';

  @override
  String get mlopsOverfitting => 'Overfitting';

  @override
  String get mlopsModelVersion => 'Versión candidata';

  @override
  String get mlopsRetrainStarted => 'Job de reentrenamiento iniciado.';

  @override
  String get mlopsRetrainError => 'No se pudo iniciar el reentrenamiento.';

  @override
  String get mlopsDecisionPromoted => 'Promovido a ACTIVE';

  @override
  String get mlopsDecisionCandidate => 'Candidato (sin promover)';

  @override
  String get mlopsDecisionDiscarded => 'Descartado';

  @override
  String get mlopsDecisionPending => 'Pendiente';

  @override
  String get mlopsFeedbackRecords => 'Registros de feedback';

  @override
  String get mlopsAugmentedWindows => 'Ventanas augmentadas';
}
