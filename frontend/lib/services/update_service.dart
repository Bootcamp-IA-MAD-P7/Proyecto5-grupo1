import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../l10n/generated/app_localizations.dart';

/// Estado del proceso de actualización.
enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  downloading,
  installing,
  error,
}

/// Datos de la versión remota devueltos por el backend.
class RemoteVersion {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String? releaseNotes;
  final int? minSupportedVersionCode;

  const RemoteVersion({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.releaseNotes,
    this.minSupportedVersionCode,
  });

  factory RemoteVersion.fromJson(Map<String, dynamic> json) {
    return RemoteVersion(
      versionCode: json['version_code'] as int,
      versionName: json['version_name'] as String,
      apkUrl: json['apk_url'] as String,
      releaseNotes: json['release_notes'] as String?,
      minSupportedVersionCode: json['min_supported_version_code'] as int?,
    );
  }

  /// Si true, la versión instalada está por debajo del mínimo soportado
  /// y la actualización es obligatoria.
  bool isMandatoryUpdate(int installedVersionCode) {
    if (minSupportedVersionCode == null) return false;
    return installedVersionCode < minSupportedVersionCode!;
  }
}

/// Tipo de error del servicio de actualización.
enum UpdateErrorType {
  noInternet,
  timeout,
  serverError,
  noInstallPermission,
  downloadInterrupted,
  insufficientStorage,
  signatureMismatch,
  unknown,
}

/// Excepción tipada del servicio de actualización.
class UpdateException implements Exception {
  final UpdateErrorType type;
  final String message;
  final Object? cause;

  const UpdateException({
    required this.type,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'UpdateException(${type.name}): $message';
}

/// Servicio de auto-actualización de la app Android.
///
/// Uso:
/// ```dart
/// final service = UpdateService();
/// await service.checkForUpdate();           // comprueba versión
/// if (service.status == UpdateStatus.updateAvailable) {
///   await service.downloadAndInstall();     // descarga e instala
/// }
/// ```
///
/// Escucha cambios con [addListener] (es un [ChangeNotifier]).
class UpdateService extends ChangeNotifier {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const Duration _checkTimeout = Duration(seconds: 10);

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: _checkTimeout,
    receiveTimeout: const Duration(seconds: 60), // para descarga
    sendTimeout: _checkTimeout,
  ));

  Locale _locale = const Locale('es');

  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;

  RemoteVersion? _remoteVersion;
  RemoteVersion? get remoteVersion => _remoteVersion;

  /// Progreso de descarga: 0.0 – 1.0
  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UpdateErrorType? _errorType;
  UpdateErrorType? get errorType => _errorType;

  int? _installedVersionCode;
  int? get installedVersionCode => _installedVersionCode;

  CancelToken? _cancelToken;

  AppLocalizations get _l10n => lookupAppLocalizations(_locale);

  /// Sincroniza el idioma con el de la app (p. ej. desde [MaterialApp.locale]).
  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    if (_status == UpdateStatus.error && _errorType != null) {
      _errorMessage = _messageForErrorType(_errorType!);
      notifyListeners();
    }
  }

  // ── Comprobación de versión ───────────────────────────────────────────────

  /// Comprueba si hay actualización disponible.
  /// Si falla (sin conexión, timeout, error del servidor), NO lanza excepción:
  /// deja el estado en [UpdateStatus.error] con mensaje descriptivo y
  /// permite que la app siga funcionando con normalidad.
  Future<void> checkForUpdate() async {
    _setStatus(UpdateStatus.checking);

    try {
      // Leer versión instalada
      final info = await PackageInfo.fromPlatform();
      _installedVersionCode = int.tryParse(info.buildNumber) ?? 0;

      // Consultar backend
      final response = await _dio.get('$_baseUrl/app/latest-version');
      _remoteVersion = RemoteVersion.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (_remoteVersion!.versionCode > _installedVersionCode!) {
        _setStatus(UpdateStatus.updateAvailable);
      } else {
        _setStatus(UpdateStatus.upToDate);
      }
    } on DioException catch (e) {
      _handleDioError(e, phase: _l10n.updatePhaseVersionCheck);
    } catch (e) {
      _setError(
        UpdateErrorType.unknown,
        _l10n.updateVersionCheckUnexpected,
        cause: e,
      );
    }
  }

  // ── Descarga e instalación ────────────────────────────────────────────────

  /// Descarga el APK y lanza el instalador nativo.
  /// Lanza [UpdateException] si ocurre un error que el UI debe manejar.
  Future<void> downloadAndInstall() async {
    if (_remoteVersion == null) {
      throw UpdateException(
        type: UpdateErrorType.unknown,
        message: _l10n.updateNoRemoteVersion,
      );
    }

    _setStatus(UpdateStatus.downloading);
    _setDownloadProgress(0);
    _cancelToken = CancelToken();

    try {
      final savePath = await _getApkSavePath();

      // Si existe un archivo previo parcial, se reescribe (Dio lo hace por defecto).
      await _dio.download(
        _remoteVersion!.apkUrl,
        savePath,
        cancelToken: _cancelToken,
        deleteOnError: false, // conservar para reanudar si fuera posible
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _setDownloadProgress(received / total);
          }
        },
      );

      _setStatus(UpdateStatus.installing);
      await _launchInstaller(savePath);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _setStatus(UpdateStatus.updateAvailable); // cancelado por el usuario
        return;
      }
      _handleDioError(e, phase: _l10n.updatePhaseApkDownload);
      rethrow;
    } on UpdateException {
      rethrow;
    } catch (e) {
      final message = _l10n.updateDownloadUnexpected;
      _setError(UpdateErrorType.unknown, message, cause: e);
      throw UpdateException(
        type: UpdateErrorType.unknown,
        message: message,
        cause: e,
      );
    }
  }

  /// Cancela la descarga en curso (si hay una).
  void cancelDownload() {
    _cancelToken?.cancel('Cancelado por el usuario');
  }

  // ── Instalación ───────────────────────────────────────────────────────────

  Future<void> _launchInstaller(String apkPath) async {
    final result = await OpenFilex.open(apkPath);
    // OpenFilex devuelve OpenResult con un type y message.
    // Los tipos de error que podemos distinguir:
    switch (result.type) {
      case ResultType.done:
        // El instalador se abrió. El estado queda en "installing"
        // hasta que el usuario complete o cancele la instalación.
        break;

      case ResultType.permissionDenied:
        // Android < 8 puede llegar aquí. En Android 8+ el sistema
        // muestra el diálogo "instalar apps desconocidas" antes de llegar aquí.
        throw UpdateException(
          type: UpdateErrorType.noInstallPermission,
          message: _l10n.updateInstallPermissionDetail,
        );

      case ResultType.fileNotFound:
        throw UpdateException(
          type: UpdateErrorType.downloadInterrupted,
          message: _l10n.updateApkNotFound(apkPath),
        );

      case ResultType.noAppToOpen:
        // No debería ocurrir con APKs, pero por si acaso
        throw UpdateException(
          type: UpdateErrorType.unknown,
          message: _l10n.updateNoPackageManager,
        );

      case ResultType.error:
        // Puede ser firma incorrecta u otro error del instalador
        final msg = result.message.toLowerCase();
        if (msg.contains('signatures') ||
            msg.contains('sign') ||
            msg.contains('certificate')) {
          throw UpdateException(
            type: UpdateErrorType.signatureMismatch,
            message: _l10n.updateSignatureMismatchDetail,
          );
        }
        throw UpdateException(
          type: UpdateErrorType.unknown,
          message: _l10n.updateInstallerError(result.message),
        );
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<String> _getApkSavePath() async {
    // getExternalStorageDirectory() puede ser null en algunos dispositivos/emuladores;
    // usamos getTemporaryDirectory() como fallback seguro.
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {
      // ignore
    }
    dir ??= await getTemporaryDirectory();
    return '${dir.path}/update.apk';
  }

  void _handleDioError(DioException e, {required String phase}) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        _setError(
          UpdateErrorType.timeout,
          _l10n.updateTimeout(phase),
          cause: e,
        );
        break;

      case DioExceptionType.connectionError:
        _setError(
          UpdateErrorType.noInternet,
          _l10n.noInternetError,
          cause: e,
        );
        break;

      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        _setError(
          UpdateErrorType.serverError,
          _l10n.updateServerError('${code ?? '?'}'),
          cause: e,
        );
        break;

      default:
        // Puede incluir errores de socket (sin espacio, etc.)
        final msg = e.message?.toLowerCase() ?? '';
        if (msg.contains('no space') || msg.contains('enospc')) {
          _setError(
            UpdateErrorType.insufficientStorage,
            _l10n.insufficientStorageError,
            cause: e,
          );
        } else {
          _setError(
            UpdateErrorType.downloadInterrupted,
            _l10n.downloadInterruptedError,
            cause: e,
          );
        }
    }
  }

  String _messageForErrorType(UpdateErrorType type) {
    switch (type) {
      case UpdateErrorType.noInternet:
        return _l10n.noInternetError;
      case UpdateErrorType.timeout:
        return _l10n.timeoutError;
      case UpdateErrorType.noInstallPermission:
        return _l10n.installPermissionError;
      case UpdateErrorType.insufficientStorage:
        return _l10n.insufficientStorageError;
      case UpdateErrorType.signatureMismatch:
        return _l10n.signatureMismatchError;
      case UpdateErrorType.downloadInterrupted:
        return _l10n.downloadInterruptedError;
      case UpdateErrorType.serverError:
        return _l10n.unknownError;
      case UpdateErrorType.unknown:
        return _l10n.unknownError;
    }
  }

  void _setStatus(UpdateStatus status) {
    _status = status;
    _errorMessage = null;
    _errorType = null;
    notifyListeners();
  }

  void _setDownloadProgress(double progress) {
    _downloadProgress = progress;
    notifyListeners();
  }

  void _setError(UpdateErrorType type, String message, {Object? cause}) {
    _status = UpdateStatus.error;
    _errorType = type;
    _errorMessage = message;
    if (cause != null) debugPrint('[UpdateService] $message\nCausa: $cause');
    notifyListeners();
  }

  /// Resetea el estado a idle para poder reintentar.
  void reset() {
    _status = UpdateStatus.idle;
    _errorMessage = null;
    _errorType = null;
    _downloadProgress = 0;
    _remoteVersion = null;
    notifyListeners();
  }
}
