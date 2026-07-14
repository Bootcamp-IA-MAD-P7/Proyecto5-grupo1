import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'SentiLife'**
  String get appTitle;

  /// No description provided for @fallDetectorTester.
  ///
  /// In es, this message translates to:
  /// **'Probador del detector de caídas'**
  String get fallDetectorTester;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @spanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get spanish;

  /// No description provided for @english.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get english;

  /// No description provided for @monitoringActive.
  ///
  /// In es, this message translates to:
  /// **'Monitorizando...'**
  String get monitoringActive;

  /// No description provided for @monitoringInactive.
  ///
  /// In es, this message translates to:
  /// **'Inactivo'**
  String get monitoringInactive;

  /// No description provided for @sensorReadings.
  ///
  /// In es, this message translates to:
  /// **'Lecturas de sensores'**
  String get sensorReadings;

  /// No description provided for @startMonitoringHint.
  ///
  /// In es, this message translates to:
  /// **'Inicia el monitoreo para ver\nlos datos de los sensores'**
  String get startMonitoringHint;

  /// No description provided for @actions.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get actions;

  /// No description provided for @startMonitoring.
  ///
  /// In es, this message translates to:
  /// **'Iniciar monitoreo'**
  String get startMonitoring;

  /// No description provided for @stopMonitoring.
  ///
  /// In es, this message translates to:
  /// **'Detener monitoreo'**
  String get stopMonitoring;

  /// No description provided for @analyzeReading.
  ///
  /// In es, this message translates to:
  /// **'Analizar lectura'**
  String get analyzeReading;

  /// No description provided for @simulateFall.
  ///
  /// In es, this message translates to:
  /// **'Simular caída'**
  String get simulateFall;

  /// No description provided for @accelerometer.
  ///
  /// In es, this message translates to:
  /// **'Acelerómetro'**
  String get accelerometer;

  /// No description provided for @gyroscope.
  ///
  /// In es, this message translates to:
  /// **'Giroscopio'**
  String get gyroscope;

  /// No description provided for @heartRate.
  ///
  /// In es, this message translates to:
  /// **'Frec. cardíaca'**
  String get heartRate;

  /// No description provided for @temperature.
  ///
  /// In es, this message translates to:
  /// **'Temperatura'**
  String get temperature;

  /// No description provided for @roomTemperature.
  ///
  /// In es, this message translates to:
  /// **'Temperatura sala'**
  String get roomTemperature;

  /// No description provided for @light.
  ///
  /// In es, this message translates to:
  /// **'Luz'**
  String get light;

  /// No description provided for @roomLight.
  ///
  /// In es, this message translates to:
  /// **'Luz sala'**
  String get roomLight;

  /// No description provided for @result.
  ///
  /// In es, this message translates to:
  /// **'Resultado'**
  String get result;

  /// No description provided for @fallDetected.
  ///
  /// In es, this message translates to:
  /// **'¡CAÍDA DETECTADA!'**
  String get fallDetected;

  /// No description provided for @noFall.
  ///
  /// In es, this message translates to:
  /// **'Sin caída'**
  String get noFall;

  /// No description provided for @confidence.
  ///
  /// In es, this message translates to:
  /// **'Confianza: {percentage}%'**
  String confidence(String percentage);

  /// No description provided for @emergencyAlert.
  ///
  /// In es, this message translates to:
  /// **'Alerta de emergencia'**
  String get emergencyAlert;

  /// No description provided for @emergencyAlertDescription.
  ///
  /// In es, this message translates to:
  /// **'En producción se notificaría al contacto de emergencia.'**
  String get emergencyAlertDescription;

  /// No description provided for @sensorReading.
  ///
  /// In es, this message translates to:
  /// **'LECTURA DEL SENSOR'**
  String get sensorReading;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @updateAvailable.
  ///
  /// In es, this message translates to:
  /// **'Actualización disponible'**
  String get updateAvailable;

  /// No description provided for @version.
  ///
  /// In es, this message translates to:
  /// **'Versión {versionName}'**
  String version(String versionName);

  /// No description provided for @whatsNew.
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get whatsNew;

  /// No description provided for @downloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando…'**
  String get downloading;

  /// No description provided for @openingInstaller.
  ///
  /// In es, this message translates to:
  /// **'Abriendo el instalador…'**
  String get openingInstaller;

  /// No description provided for @unknownError.
  ///
  /// In es, this message translates to:
  /// **'Error desconocido.'**
  String get unknownError;

  /// No description provided for @noInternetError.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión a internet.'**
  String get noInternetError;

  /// No description provided for @timeoutError.
  ///
  /// In es, this message translates to:
  /// **'La operación ha tardado demasiado.'**
  String get timeoutError;

  /// No description provided for @installPermissionError.
  ///
  /// In es, this message translates to:
  /// **'No se ha concedido permiso para instalar aplicaciones.'**
  String get installPermissionError;

  /// No description provided for @insufficientStorageError.
  ///
  /// In es, this message translates to:
  /// **'No hay espacio suficiente para descargar la actualización.'**
  String get insufficientStorageError;

  /// No description provided for @signatureMismatchError.
  ///
  /// In es, this message translates to:
  /// **'La firma de la actualización no coincide con la app instalada.'**
  String get signatureMismatchError;

  /// No description provided for @downloadInterruptedError.
  ///
  /// In es, this message translates to:
  /// **'La descarga se ha interrumpido.'**
  String get downloadInterruptedError;

  /// No description provided for @cancelDownload.
  ///
  /// In es, this message translates to:
  /// **'Cancelar descarga'**
  String get cancelDownload;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @updateNow.
  ///
  /// In es, this message translates to:
  /// **'Actualizar ahora'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In es, this message translates to:
  /// **'Más tarde'**
  String get later;

  /// No description provided for @incompatibleSignature.
  ///
  /// In es, this message translates to:
  /// **'Firma incompatible'**
  String get incompatibleSignature;

  /// No description provided for @incompatibleSignatureDescription.
  ///
  /// In es, this message translates to:
  /// **'El APK descargado está firmado con una clave diferente a la versión instalada. Esto impide actualizar directamente.\n\nPara solucionar el problema:\n1. Desinstala la app manualmente.\n2. Vuelve a abrir este enlace de descarga e instala la nueva versión.'**
  String get incompatibleSignatureDescription;

  /// No description provided for @understood.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get understood;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @login.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @demoAccounts.
  ///
  /// In es, this message translates to:
  /// **'Cuentas de demostración'**
  String get demoAccounts;

  /// No description provided for @registrationRolePrompt.
  ///
  /// In es, this message translates to:
  /// **'Tipo de perfil'**
  String get registrationRolePrompt;

  /// No description provided for @roleCaregiver.
  ///
  /// In es, this message translates to:
  /// **'Cuidador'**
  String get roleCaregiver;

  /// No description provided for @roleMonitored.
  ///
  /// In es, this message translates to:
  /// **'Persona monitorizada'**
  String get roleMonitored;

  /// No description provided for @roleItAdmin.
  ///
  /// In es, this message translates to:
  /// **'Administrador IT'**
  String get roleItAdmin;

  /// No description provided for @monitoredTitle.
  ///
  /// In es, this message translates to:
  /// **'Mi monitorización'**
  String get monitoredTitle;

  /// No description provided for @caregiverTitle.
  ///
  /// In es, this message translates to:
  /// **'Panel del cuidador'**
  String get caregiverTitle;

  /// No description provided for @itAdminTitle.
  ///
  /// In es, this message translates to:
  /// **'Administración IT'**
  String get itAdminTitle;

  /// No description provided for @persons.
  ///
  /// In es, this message translates to:
  /// **'Personas'**
  String get persons;

  /// No description provided for @alerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get alerts;

  /// No description provided for @history.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get history;

  /// No description provided for @export.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get export;

  /// No description provided for @users.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get users;

  /// No description provided for @lastEvaluation.
  ///
  /// In es, this message translates to:
  /// **'Última evaluación'**
  String get lastEvaluation;

  /// No description provided for @noEvaluationYet.
  ///
  /// In es, this message translates to:
  /// **'Sin evaluaciones todavía'**
  String get noEvaluationYet;

  /// No description provided for @lastWindowAt.
  ///
  /// In es, this message translates to:
  /// **'Última ventana: {timestamp}'**
  String lastWindowAt(String timestamp);

  /// No description provided for @modelVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión del modelo'**
  String get modelVersion;

  /// No description provided for @noPersonsYet.
  ///
  /// In es, this message translates to:
  /// **'No hay personas registradas'**
  String get noPersonsYet;

  /// No description provided for @addPerson.
  ///
  /// In es, this message translates to:
  /// **'Registrar persona'**
  String get addPerson;

  /// No description provided for @fullName.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get fullName;

  /// No description provided for @birthDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get birthDate;

  /// No description provided for @sex.
  ///
  /// In es, this message translates to:
  /// **'Sexo'**
  String get sex;

  /// No description provided for @weightKg.
  ///
  /// In es, this message translates to:
  /// **'Peso (kg)'**
  String get weightKg;

  /// No description provided for @heightCm.
  ///
  /// In es, this message translates to:
  /// **'Altura (cm)'**
  String get heightCm;

  /// No description provided for @emergencyContact.
  ///
  /// In es, this message translates to:
  /// **'Contacto de emergencia'**
  String get emergencyContact;

  /// No description provided for @monitoredUserEmail.
  ///
  /// In es, this message translates to:
  /// **'Email de la cuenta monitorizada'**
  String get monitoredUserEmail;

  /// No description provided for @monitoredUserEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce el email de una cuenta MONITORED existente.'**
  String get monitoredUserEmailRequired;

  /// No description provided for @pendingLinkStatus.
  ///
  /// In es, this message translates to:
  /// **'PENDING_LINK'**
  String get pendingLinkStatus;

  /// No description provided for @pendingLinkTitle.
  ///
  /// In es, this message translates to:
  /// **'Vinculación pendiente'**
  String get pendingLinkTitle;

  /// No description provided for @pendingLinkBody.
  ///
  /// In es, this message translates to:
  /// **'Tu cuidador debe registrar tu ficha con el email de esta cuenta antes de vincular el dispositivo.'**
  String get pendingLinkBody;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @age.
  ///
  /// In es, this message translates to:
  /// **'Edad'**
  String get age;

  /// No description provided for @consent.
  ///
  /// In es, this message translates to:
  /// **'Consentimiento'**
  String get consent;

  /// No description provided for @monitoringStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado de monitorización'**
  String get monitoringStatus;

  /// No description provided for @noAlerts.
  ///
  /// In es, this message translates to:
  /// **'No hay alertas'**
  String get noAlerts;

  /// No description provided for @alertDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle de alerta'**
  String get alertDetail;

  /// No description provided for @comment.
  ///
  /// In es, this message translates to:
  /// **'Comentario'**
  String get comment;

  /// No description provided for @confirmFall.
  ///
  /// In es, this message translates to:
  /// **'Confirmar caída'**
  String get confirmFall;

  /// No description provided for @dismissAlert.
  ///
  /// In es, this message translates to:
  /// **'Descartar alerta'**
  String get dismissAlert;

  /// No description provided for @status.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get status;

  /// No description provided for @exportDescription.
  ///
  /// In es, this message translates to:
  /// **'Exporta el dataset etiquetado con feedback del cuidador para reentrenar el modelo.'**
  String get exportDescription;

  /// No description provided for @exportDataset.
  ///
  /// In es, this message translates to:
  /// **'Exportar dataset'**
  String get exportDataset;

  /// No description provided for @exportReady.
  ///
  /// In es, this message translates to:
  /// **'Export listo'**
  String get exportReady;

  /// No description provided for @consentTitle.
  ///
  /// In es, this message translates to:
  /// **'Consentimiento de monitorización'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In es, this message translates to:
  /// **'Autorizo el uso de mis datos de sensores para detectar caídas y mejorar el modelo de SentiLife. Puedo revocar este consentimiento en cualquier momento desde Ajustes.'**
  String get consentBody;

  /// No description provided for @consentSaved.
  ///
  /// In es, this message translates to:
  /// **'Consentimiento registrado correctamente.'**
  String get consentSaved;

  /// No description provided for @consentError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo registrar el consentimiento. Inténtalo de nuevo.'**
  String get consentError;

  /// No description provided for @consentRequired.
  ///
  /// In es, this message translates to:
  /// **'Se requiere consentimiento activo para enviar datos de sensores.'**
  String get consentRequired;

  /// No description provided for @pairingRequired.
  ///
  /// In es, this message translates to:
  /// **'Vincula el dispositivo con el código del cuidador antes de aceptar el consentimiento.'**
  String get pairingRequired;

  /// No description provided for @pairingTitle.
  ///
  /// In es, this message translates to:
  /// **'Vincular dispositivo'**
  String get pairingTitle;

  /// No description provided for @pairingCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código del cuidador'**
  String get pairingCodeLabel;

  /// No description provided for @pairingCodeHint.
  ///
  /// In es, this message translates to:
  /// **'SL-XXXXXX'**
  String get pairingCodeHint;

  /// No description provided for @pairDevice.
  ///
  /// In es, this message translates to:
  /// **'Vincular'**
  String get pairDevice;

  /// No description provided for @pairingSuccess.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo vinculado correctamente.'**
  String get pairingSuccess;

  /// No description provided for @pairingError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo vincular el dispositivo. Inténtalo de nuevo.'**
  String get pairingError;

  /// No description provided for @deviceLinked.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo vinculado'**
  String get deviceLinked;

  /// No description provided for @deviceLinkedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Este móvil está asociado a tu perfil monitorizado.'**
  String get deviceLinkedSubtitle;

  /// No description provided for @acceptConsent.
  ///
  /// In es, this message translates to:
  /// **'Acepto'**
  String get acceptConsent;

  /// No description provided for @decline.
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get decline;

  /// No description provided for @dataTransparency.
  ///
  /// In es, this message translates to:
  /// **'Transparencia de datos'**
  String get dataTransparency;

  /// No description provided for @transparencyBody.
  ///
  /// In es, this message translates to:
  /// **'Tus predicciones y el feedback que proporciones se utilizan para reentrenar y mejorar el modelo de detección de caídas. Los datos se procesan de forma segura y solo con tu consentimiento activo.'**
  String get transparencyBody;

  /// No description provided for @revokeConsent.
  ///
  /// In es, this message translates to:
  /// **'Revocar consentimiento'**
  String get revokeConsent;

  /// No description provided for @revokeConsentConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que quieres revocar el consentimiento? Se detendrá la monitorización y no se enviarán más datos.'**
  String get revokeConsentConfirm;

  /// No description provided for @consentRevoked.
  ///
  /// In es, this message translates to:
  /// **'Consentimiento revocado.'**
  String get consentRevoked;

  /// No description provided for @consentRevokeError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo revocar el consentimiento. Inténtalo de nuevo.'**
  String get consentRevokeError;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @pairingCodeShare.
  ///
  /// In es, this message translates to:
  /// **'Código de vinculación'**
  String get pairingCodeShare;

  /// No description provided for @userActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get userActive;

  /// No description provided for @userInactive.
  ///
  /// In es, this message translates to:
  /// **'Inactivo'**
  String get userInactive;

  /// No description provided for @userStatusUpdated.
  ///
  /// In es, this message translates to:
  /// **'Estado del usuario actualizado.'**
  String get userStatusUpdated;

  /// No description provided for @userStatusError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar el estado del usuario.'**
  String get userStatusError;

  /// No description provided for @pairingCredentialMissing.
  ///
  /// In es, this message translates to:
  /// **'El vínculo guardado pertenece a una versión anterior. Vuelve a emparejar el dispositivo para continuar.'**
  String get pairingCredentialMissing;

  /// No description provided for @lastEvaluationLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la última evaluación. El dispositivo continúa vinculado.'**
  String get lastEvaluationLoadError;

  /// No description provided for @sensorStartError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron iniciar el acelerómetro y el giroscopio.'**
  String get sensorStartError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
