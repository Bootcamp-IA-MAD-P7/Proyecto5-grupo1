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
  String get loginTitle;
  String get email;
  String get password;
  String get login;
  String get logout;
  String get demoAccounts;
  String get roleCaregiver;
  String get roleMonitored;
  String get roleItAdmin;
  String get monitoredTitle;
  String get caregiverTitle;
  String get itAdminTitle;
  String get persons;
  String get alerts;
  String get history;
  String get export;
  String get users;
  String get lastEvaluation;
  String get noEvaluationYet;
  String lastWindowAt(String timestamp);
  String get modelVersion;
  String get noPersonsYet;
  String get addPerson;
  String get fullName;
  String get birthDate;
  String get sex;
  String get weightKg;
  String get heightCm;
  String get emergencyContact;
  String get save;
  String get age;
  String get consent;
  String get monitoringStatus;
  String get noAlerts;
  String get alertDetail;
  String get comment;
  String get confirmFall;
  String get dismissAlert;
  String get status;
  String get exportDescription;
  String get exportDataset;
  String get exportReady;
  String get consentTitle;
  String get consentBody;
  String get acceptConsent;
  String get decline;
  String get dataTransparency;
  String get transparencyBody;

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
