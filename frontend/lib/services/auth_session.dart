import 'session_repository.dart';

export 'session_repository.dart' show SessionRepository;

/// Backward-compatible alias — use [SessionRepository.instance] in production.
typedef AuthSession = SessionRepository;
