/// Excepciones compartidas por todos los servicios de la app.
library;

class ApiException implements Exception {
  final int status;
  final String error;
  final String message;

  const ApiException(this.status, this.error, this.message);

  @override
  String toString() => 'ApiException($status, $error): $message';
}

class AuthException implements Exception {
  final int status;
  final String error;
  final String message;

  const AuthException(this.status, this.error, this.message);

  @override
  String toString() => 'AuthException($status, $error): $message';
}

class DeviceException implements Exception {
  final int status;
  final String error;
  final String message;

  const DeviceException(this.status, this.error, this.message);

  @override
  String toString() => 'DeviceException($status, $error): $message';
}

class TelemetryException implements Exception {
  final int status;
  final String error;
  final String message;

  const TelemetryException(this.status, this.error, this.message);

  @override
  String toString() => 'TelemetryException($status, $error): $message';
}

class AdminException implements Exception {
  final int status;
  final String error;
  final String message;

  const AdminException(this.status, this.error, this.message);

  @override
  String toString() => 'AdminException($status, $error): $message';
}
