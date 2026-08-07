// core/telemetry/telemetry_operation.dart

import '../logging/log_category.dart';
import '../logging/log_level.dart';
import 'game_telemetry_service.dart';
import 'telemetry_event.dart';

/// Handle for an operation that has a beginning and an end.
///
/// Returned by [GameTelemetryService.start]. Calling [finish], [fail] or
/// [cancel] emits the closing event carrying the measured duration and the
/// same correlation id as the opening one, so a whole flow (create room →
/// firestore write → lobby opened) is reconstructable
/// (docs/telemetry/TELEMETRY_SPEC.md — "Correlation IDs").
///
/// Modelled as a handle rather than as a `finish(name)` lookup on the
/// service on purpose: there is no registry of in-flight operations to leak,
/// and the compiler makes it obvious which start each ending belongs to.
class TelemetryOperation {
  TelemetryOperation({
    required GameTelemetryService telemetry,
    required this.category,
    required this.name,
    required this.correlationId,
  }) : _telemetry = telemetry,
       _stopwatch = Stopwatch()..start();

  final GameTelemetryService _telemetry;
  final Stopwatch _stopwatch;

  final AppLogCategory category;
  final String name;
  final String correlationId;

  bool _isClosed = false;

  /// True once an ending event has been emitted. Further calls are ignored,
  /// so a retry or a double-await can never produce a duplicate event
  /// (docs/telemetry/TELEMETRY_SPEC.md — "Never emit the same event twice").
  bool get isClosed => _isClosed;

  /// The operation completed successfully.
  void finish({Map<String, dynamic>? payload}) {
    _close(
      status: TelemetryStatus.succeeded,
      severity: AppLogLevel.info,
      payload: payload,
    );
  }

  /// The operation failed. Recorded at ERROR severity by default so it is
  /// never sampled away.
  void fail(
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
    AppLogLevel severity = AppLogLevel.error,
    TelemetryStatus status = TelemetryStatus.failed,
  }) {
    _close(
      status: status,
      severity: severity,
      payload: payload,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// The operation was abandoned before completing (user backed out, room
  /// disappeared, screen disposed).
  void cancel({Map<String, dynamic>? payload}) {
    _close(
      status: TelemetryStatus.cancelled,
      severity: AppLogLevel.info,
      payload: payload,
    );
  }

  void _close({
    required TelemetryStatus status,
    required AppLogLevel severity,
    Map<String, dynamic>? payload,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_isClosed) return;
    _isClosed = true;
    _stopwatch.stop();

    _telemetry.track(
      category,
      name,
      status: status,
      severity: severity,
      payload: payload,
      duration: _stopwatch.elapsed,
      correlationId: correlationId,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
