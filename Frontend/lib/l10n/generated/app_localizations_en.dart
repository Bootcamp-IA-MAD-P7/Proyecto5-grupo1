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
}
