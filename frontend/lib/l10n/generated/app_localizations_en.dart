// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SentiLife';

  @override
  String get fallDetectorTester => 'Fall detector tester';

  @override
  String get language => 'Language';

  @override
  String get spanish => 'Spanish';

  @override
  String get english => 'English';

  @override
  String get monitoringActive => 'Monitoring...';

  @override
  String get monitoringInactive => 'Inactive';

  @override
  String get sensorReadings => 'Sensor readings';

  @override
  String get startMonitoringHint => 'Start monitoring to see\nsensor data';

  @override
  String get actions => 'Actions';

  @override
  String get startMonitoring => 'Start monitoring';

  @override
  String get stopMonitoring => 'Stop monitoring';

  @override
  String get analyzeReading => 'Analyze reading';

  @override
  String get simulateFall => 'Simulate fall';

  @override
  String get accelerometer => 'Accelerometer';

  @override
  String get gyroscope => 'Gyroscope';

  @override
  String get heartRate => 'Heart rate';

  @override
  String get temperature => 'Temperature';

  @override
  String get roomTemperature => 'Room temperature';

  @override
  String get light => 'Light';

  @override
  String get roomLight => 'Room light';

  @override
  String get result => 'Result';

  @override
  String get fallDetected => 'FALL DETECTED!';

  @override
  String get noFall => 'No fall';

  @override
  String confidence(String percentage) {
    return 'Confidence: $percentage%';
  }

  @override
  String get emergencyAlert => 'Emergency alert';

  @override
  String get emergencyAlertDescription =>
      'In production, the emergency contact would be notified.';

  @override
  String get sensorReading => 'SENSOR READING';

  @override
  String get back => 'Back';

  @override
  String get updateAvailable => 'Update available';

  @override
  String version(String versionName) {
    return 'Version $versionName';
  }

  @override
  String get whatsNew => 'What\'s new';

  @override
  String get downloading => 'Downloading…';

  @override
  String get openingInstaller => 'Opening installer…';

  @override
  String get unknownError => 'Unknown error.';

  @override
  String get noInternetError => 'There is no internet connection.';

  @override
  String get timeoutError => 'The operation took too long.';

  @override
  String get installPermissionError =>
      'Permission to install apps has not been granted.';

  @override
  String get insufficientStorageError =>
      'There is not enough space to download the update.';

  @override
  String get signatureMismatchError =>
      'The update signature does not match the installed app.';

  @override
  String get downloadInterruptedError => 'The download was interrupted.';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get retry => 'Retry';

  @override
  String get updateNow => 'Update now';

  @override
  String get later => 'Later';

  @override
  String get incompatibleSignature => 'Incompatible signature';

  @override
  String get incompatibleSignatureDescription =>
      'The downloaded APK is signed with a different key from the installed version, so it cannot be updated directly.\n\nTo resolve the issue:\n1. Uninstall the app manually.\n2. Open this download link again and install the new version.';

  @override
  String get understood => 'Got it';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Sign in';

  @override
  String get logout => 'Sign out';

  @override
  String get demoAccounts => 'Demo accounts';

  @override
  String get roleCaregiver => 'Caregiver';

  @override
  String get roleMonitored => 'Monitored person';

  @override
  String get roleItAdmin => 'IT Admin';

  @override
  String get monitoredTitle => 'My monitoring';

  @override
  String get caregiverTitle => 'Caregiver dashboard';

  @override
  String get itAdminTitle => 'IT administration';

  @override
  String get persons => 'Persons';

  @override
  String get alerts => 'Alerts';

  @override
  String get history => 'History';

  @override
  String get export => 'Export';

  @override
  String get users => 'Users';

  @override
  String get lastEvaluation => 'Last evaluation';

  @override
  String get noEvaluationYet => 'No evaluations yet';

  @override
  String lastWindowAt(String timestamp) {
    return 'Last window: $timestamp';
  }

  @override
  String get modelVersion => 'Model version';

  @override
  String get noPersonsYet => 'No persons registered';

  @override
  String get addPerson => 'Register person';

  @override
  String get fullName => 'Full name';

  @override
  String get birthDate => 'Birth date';

  @override
  String get sex => 'Sex';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get emergencyContact => 'Emergency contact';

  @override
  String get save => 'Save';

  @override
  String get age => 'Age';

  @override
  String get consent => 'Consent';

  @override
  String get monitoringStatus => 'Monitoring status';

  @override
  String get noAlerts => 'No alerts';

  @override
  String get alertDetail => 'Alert detail';

  @override
  String get comment => 'Comment';

  @override
  String get confirmFall => 'Confirm fall';

  @override
  String get dismissAlert => 'Dismiss alert';

  @override
  String get status => 'Status';

  @override
  String get exportDescription =>
      'Export the labeled dataset with caregiver feedback to retrain the model.';

  @override
  String get exportDataset => 'Export dataset';

  @override
  String get exportReady => 'Export ready';

  @override
  String get consentTitle => 'Monitoring consent';

  @override
  String get consentBody =>
      'I authorize the use of my sensor data to detect falls and improve the SentiLife model. I can revoke this consent at any time from Settings.';

  @override
  String get consentSaved => 'Consent recorded successfully.';

  @override
  String get consentError => 'Could not record consent. Please try again.';

  @override
  String get consentRequired =>
      'Active consent is required to send sensor data.';

  @override
  String get pairingRequired =>
      'Pair the device with the caregiver code before accepting consent.';

  @override
  String get pairingTitle => 'Pair device';

  @override
  String get pairingCodeLabel => 'Caregiver code';

  @override
  String get pairingCodeHint => 'SL-XXXXXX';

  @override
  String get pairDevice => 'Pair';

  @override
  String get pairingSuccess => 'Device paired successfully.';

  @override
  String get pairingError => 'Could not pair the device. Please try again.';

  @override
  String get deviceLinked => 'Device linked';

  @override
  String get deviceLinkedSubtitle =>
      'This phone is linked to your monitored profile.';

  @override
  String get acceptConsent => 'I accept';

  @override
  String get decline => 'Decline';

  @override
  String get dataTransparency => 'Data transparency';

  @override
  String get transparencyBody =>
      'Your predictions and feedback are used to retrain and improve the fall detection model. Data is processed securely and only with your active consent.';
}
