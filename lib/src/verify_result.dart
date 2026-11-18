/// Terminal outcome of one verification, mirroring the native `VerifyResult`.
sealed class VerifyResult {
  const VerifyResult();

  /// Decodes the platform-channel map. Unknown values decode to safe
  /// fallbacks so a newer native SDK never crashes an older plugin.
  static VerifyResult fromChannel(Map<Object?, Object?> map) {
    return switch (map['status']) {
      'approved' => VerifyApproved(map['attemptId'] as String? ?? ''),
      'rejected' => VerifyRejected(RejectReason.fromWire(map['reason'] as String?)),
      'review' => const VerifyReview(),
      'timeout' => const VerifyTimeout(),
      'cancelled' => const VerifyCancelled(),
      _ => VerifyFailed(VisError.fromChannel(map)),
    };
  }
}

/// The user was verified.
final class VerifyApproved extends VerifyResult {
  const VerifyApproved(this.attemptId);

  final String attemptId;
}

/// The user was not verified. Only the category is given, never a score.
final class VerifyRejected extends VerifyResult {
  const VerifyRejected(this.reason);

  final RejectReason reason;
}

/// Sent to manual review; the final decision arrives on your backend's webhook.
final class VerifyReview extends VerifyResult {
  const VerifyReview();
}

/// No decision within `processingTimeout`; the webhook still arrives.
final class VerifyTimeout extends VerifyResult {
  const VerifyTimeout();
}

/// The user left the flow.
final class VerifyCancelled extends VerifyResult {
  const VerifyCancelled();
}

/// A platform or device error. This is not a rejection of the user.
final class VerifyFailed extends VerifyResult {
  const VerifyFailed(this.error);

  final VisError error;
}

/// Why the user was rejected.
enum RejectReason {
  /// The live check did not pass (head turn, video, more than one face).
  livenessFailed('liveness_failed'),

  /// The face did not match the face on the document.
  faceMismatch('face_mismatch'),

  /// The document was not accepted (unreadable, expired, not a valid card,
  /// or not the person's card).
  invalidDocument('invalid_document'),

  /// The typed document number or birth date does not match the document.
  /// Ask the user to type it again.
  documentDataMismatch('document_data_mismatch'),

  /// A category this plugin version does not know yet.
  unknown('unknown');

  const RejectReason(this.wireName);

  final String wireName;

  static RejectReason fromWire(String? wire) => values.firstWhere((r) => r.wireName == wire, orElse: () => unknown);
}

/// Category of a [VisError].
enum VisErrorCode {
  sessionNotFound('session_not_found'),
  sessionExpired('session_expired'),
  deviceUnsupported('device_unsupported'),
  attestationFailed('attestation_failed'),
  captureRejected('capture_rejected'),
  rateLimited('rate_limited'),
  networkUnavailable('network_unavailable'),
  permissionDenied('permission_denied'),
  internal('internal');

  const VisErrorCode(this.wireName);

  final String wireName;

  static VisErrorCode fromWire(String? wire) => values.firstWhere((c) => c.wireName == wire, orElse: () => internal);
}

/// A platform or device error.
class VisError {
  const VisError(this.code, {this.detail, this.captureRejection, this.retryAfterSeconds});

  factory VisError.fromChannel(Map<Object?, Object?> map) {
    final code = VisErrorCode.fromWire(map['error'] as String?);
    return VisError(
      code,
      detail: map['detail'] as String?,
      captureRejection: switch (map['captureReason']) {
        final String reason when code == VisErrorCode.captureRejected => CaptureRejection(
          reason,
          attempt: (map['attempt'] as num?)?.toInt(),
          maxAttempts: (map['maxAttempts'] as num?)?.toInt(),
        ),
        _ => null,
      },
      retryAfterSeconds: (map['retryAfterSeconds'] as num?)?.toInt(),
    );
  }

  final VisErrorCode code;

  /// Diagnostic text; safe to log, contains no personal data. Do not parse it.
  final String? detail;

  /// Set for [VisErrorCode.captureRejected].
  final CaptureRejection? captureRejection;

  /// Set for [VisErrorCode.rateLimited].
  final int? retryAfterSeconds;

  @override
  String toString() => 'VisError(${code.wireName}${detail == null ? '' : ': $detail'})';
}

/// Why capture was rejected, parsed by the SDK so the host never parses text.
class CaptureRejection {
  const CaptureRejection(this.reason, {this.attempt, this.maxAttempts});

  /// `turn_not_completed`, `turn_not_started`, `face_not_ready`, or a
  /// server code.
  final String reason;

  /// The 1-based selfie recording that failed; `null` when not a selfie miss.
  final int? attempt;

  /// Recordings the SDK allows per challenge; `null` like [attempt].
  final int? maxAttempts;
}
