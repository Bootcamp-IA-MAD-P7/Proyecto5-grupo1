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
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get registerSubtitle => 'Create your account';

  @override
  String get requiredField => 'Required';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get passwordMinLength => 'Min. 8 characters';

  @override
  String get connectionError => 'Connection error. Is the backend running?';

  @override
  String get register => 'Register';

  @override
  String get signIn => 'Sign in';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register';

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
  String get registrationRolePrompt => 'Profile type';

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
  String get monitoredUserEmail => 'Monitored account email';

  @override
  String get monitoredUserEmailRequired =>
      'Enter the email of an existing MONITORED account.';

  @override
  String get pendingLinkStatus => 'PENDING_LINK';

  @override
  String get pendingLinkTitle => 'Link pending';

  @override
  String get pendingLinkBody =>
      'Your caregiver must register your profile with this account email before you can pair your device.';

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
  String get exportDownloadSuccess => 'Dataset downloaded successfully.';

  @override
  String get exportDownloadError =>
      'Could not download the dataset. Please try again.';

  @override
  String get monitoredTabStatus => 'Status';

  @override
  String get monitoredTabSensors => 'Sensors';

  @override
  String get liveSensorsCaption =>
      'This is what the phone is measuring right now.';

  @override
  String get sensorsPausedMessage =>
      'Monitoring is stopped. Start monitoring to see live signals.';

  @override
  String get viewLiveSensorsLink => 'View live sensors';

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

  @override
  String get revokeConsent => 'Revoke consent';

  @override
  String get revokeConsentConfirm =>
      'Are you sure you want to revoke consent? Monitoring will stop and no more data will be sent.';

  @override
  String get consentRevoked => 'Consent revoked.';

  @override
  String get consentRevokeError =>
      'Could not revoke consent. Please try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get pairingCodeShare => 'Pairing code';

  @override
  String get userActive => 'Active';

  @override
  String get userInactive => 'Inactive';

  @override
  String get userStatusUpdated => 'User status updated.';

  @override
  String get userStatusError => 'Could not update the user status.';

  @override
  String get pairingCredentialMissing =>
      'The saved link belongs to an earlier version. Pair the device again to continue.';

  @override
  String get lastEvaluationLoadError =>
      'The latest evaluation could not be loaded. The device remains linked.';

  @override
  String get sensorStartError =>
      'The accelerometer and gyroscope could not be started.';

  @override
  String get sensorUnavailableTitle => 'Sensors unavailable';

  @override
  String get sensorUnavailableBody =>
      'This device does not have the inertial sensors required for fall monitoring. Use a phone with an accelerometer and gyroscope.';

  @override
  String get sensorUnavailableRetry => 'Check again';

  @override
  String get sensorAvailable => 'Available';

  @override
  String get sensorMissing => 'Unavailable';

  @override
  String get updateNoRemoteVersion =>
      'No remote version loaded. Call checkForUpdate() first.';

  @override
  String get updateVersionCheckUnexpected =>
      'Unexpected error while checking for updates.';

  @override
  String get updateDownloadUnexpected => 'Unexpected error during download.';

  @override
  String get updatePhaseVersionCheck => 'version check';

  @override
  String get updatePhaseApkDownload => 'APK download';

  @override
  String updateTimeout(String phase) {
    return 'The $phase took too long. Check your connection and try again.';
  }

  @override
  String updateServerError(String code) {
    return 'The server returned an error (code $code). Try again later.';
  }

  @override
  String get updateInstallPermissionDetail =>
      'You do not have permission to install apps from unknown sources.\nGo to Settings > Apps > this app > Install unknown apps and enable it.';

  @override
  String updateApkNotFound(String path) {
    return 'The APK file was not found at \"$path\". Try downloading again.';
  }

  @override
  String get updateNoPackageManager =>
      'No package installer was found to install the APK.';

  @override
  String updateInstallerError(String message) {
    return 'Error opening the installer: $message';
  }

  @override
  String get updateSignatureMismatchDetail =>
      'The APK signature does not match the installed version.\nUninstall the app manually and install the new version.';

  @override
  String get mlops => 'MLOps';

  @override
  String get mlopsTitle => 'Model retraining';

  @override
  String get mlopsDescription =>
      'Start a retraining job with production feedback. The pipeline checks drift, trains, and decides whether to promote the new model.';

  @override
  String get mlopsStartRetrain => 'Start retraining';

  @override
  String get mlopsRetrainRunning => 'Retraining in progress…';

  @override
  String get mlopsPhase => 'Phase';

  @override
  String get mlopsDecision => 'Decision';

  @override
  String get mlopsRecall => 'Recall (test)';

  @override
  String get mlopsCurrentRecall => 'Current recall';

  @override
  String get mlopsOverfitting => 'Overfitting';

  @override
  String get mlopsModelVersion => 'Candidate version';

  @override
  String get mlopsRetrainStarted => 'Retraining job started.';

  @override
  String get mlopsRetrainError => 'Could not start retraining.';

  @override
  String get mlopsDecisionPromoted => 'Promoted to ACTIVE';

  @override
  String get mlopsDecisionCandidate => 'Candidate (not promoted)';

  @override
  String get mlopsDecisionDiscarded => 'Discarded';

  @override
  String get mlopsDecisionPending => 'Pending';

  @override
  String get mlopsFeedbackRecords => 'Feedback records';

  @override
  String get mlopsAugmentedWindows => 'Augmented windows';

  @override
  String get mlopsPrerequisitesTitle => 'Labelled data available';

  @override
  String mlopsFeedbackProgress(int current, int minimum) {
    return '$current of $minimum minimum records';
  }

  @override
  String mlopsFeedbackRecommended(int count) {
    return 'Recommended: at least $count records for a reliable retrain.';
  }

  @override
  String get mlopsInsufficientFeedbackTitle => 'Not enough feedback yet';

  @override
  String get mlopsInsufficientFeedbackBody =>
      'Retraining blends the SisFall dataset with IMU windows that caregivers confirmed or dismissed. With too few new examples the model cannot improve meaningfully and compute is wasted.\n\nAsk caregivers to review alerts (confirm true falls or mark false alarms) until the minimum is reached. Each record must include the full sensor window (125 samples).';

  @override
  String get mlopsConfirmTitle => 'Start retraining?';

  @override
  String get mlopsConfirmBody =>
      'The pipeline runs these phases:\n1. Drift — compares recent telemetry with SisFall.\n2. Training — blends SisFall + labelled feedback from the database.\n3. Evaluation — measures recall, precision and overfitting.\n4. Decision — promotes only if fall recall improves and overfitting is ≤ 5%.\n\nIf it does not improve, the current model stays active (discarded/candidate).';

  @override
  String get mlopsCriteriaTitle => 'MLOps criteria and explainability';

  @override
  String get mlopsCriteriaBody =>
      'Minimum threshold: valid labelled records in Postgres (IMU window + TRUE_FALL or FALSE_ALARM label).\n\nRecommended: accumulate diverse feedback (confirmed falls and false alarms) before retraining.\n\nAutomatic promotion only if:\n• Candidate fall recall > ACTIVE model recall.\n• Overfitting (train − test) ≤ 5%.\n\nThe last job\'s «Augmented windows» count shows how many real production samples entered training.';

  @override
  String get mlopsWhyDisabled => 'Why is this disabled?';

  @override
  String get helpButton => 'Help';

  @override
  String get helpClose => 'Got it';

  @override
  String get helpMonitoredTitle => 'Guide — Monitored person';

  @override
  String get helpMonitoredBody =>
      '1. Check that your phone has accelerometer and gyroscope.\n2. Pair the device with the code from your caregiver.\n3. Accept informed consent (you can revoke anytime).\n4. Start monitoring: the app captures sensors in background with a persistent notification.\n5. Status tab: latest model evaluation (fall yes/no, confidence).\n6. Sensors tab: live charts of what the phone measures now.\n\nYour data is sent only with active consent and is used to improve the model (transparency modal).';

  @override
  String get helpCaregiverTitle => 'Guide — Caregiver';

  @override
  String get helpCaregiverBody =>
      '1. Register the person with their MONITORED account email (must exist and be active).\n2. Share the pairing code so they can link their phone.\n3. You will receive push notifications on possible fall alerts.\n4. Review each alert: confirm a real fall or dismiss as false alarm.\n\nYour feedback labels IMU windows and feeds model retraining. Higher-quality feedback improves the next model.';

  @override
  String get helpItAdminTitle => 'Guide — IT administration';

  @override
  String get helpItAdminBody =>
      'History: global system alerts.\n\nExport: authenticated CSV download with labelled windows (caregiver feedback).\n\nUsers: enable or disable accounts.\n\nMLOps — Retraining:\n• Reads Postgres feedback automatically (no manual CSV).\n• Requires a minimum of labelled records before starting the job.\n• Shows phases, metrics and decision (promoted / candidate / discarded).\n• Promotes only if fall recall improves without overfitting.\n\nGrafana (QA): http://100.52.221.179:3006 — latency, queue and drift dashboards.';

  @override
  String get historyLoadError => 'Could not load history.';

  @override
  String get noHistory => 'No alert history.';
}
