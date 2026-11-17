/// The attempt handoff your backend received from
/// `POST /api/sdk/v1/session/start`.
///
/// One-shot and short-lived (about five minutes): mint the attempt when the
/// user is ready and launch promptly. There is no resume; if the app dies
/// mid-flow, request a new attempt.
class VerifyRequest {
  const VerifyRequest({
    required this.attemptId,
    required this.bootstrapSecret,
    required this.bootstrapExpiresAt,
    required this.bindNonce,
    required this.capturePolicyVersion,
    this.appCheck,
    this.documents,
  });

  final String attemptId;

  /// Single-use secret. Treat it like a password: never log it.
  final String bootstrapSecret;
  final String bootstrapExpiresAt;
  final String bindNonce;
  final String capturePolicyVersion;

  /// `app_check` from the handoff, passed through verbatim.
  final String? appCheck;

  /// `documents` from the handoff, passed through verbatim.
  final String? documents;

  /// Parses the snake_case handoff JSON as returned by `session/start`.
  /// Returns `null` if a required field is missing or empty.
  static VerifyRequest? fromJson(Map<String, Object?> json) {
    String? field(String key) => switch (json[key]) {
      final String value when value.isNotEmpty => value,
      _ => null,
    };
    if ((
          field('attempt_id'),
          field('bootstrap_secret'),
          field('bootstrap_expires_at'),
          field('bind_nonce'),
          field('capture_policy_version'),
        )
        case (
          final String attemptId,
          final String bootstrapSecret,
          final String bootstrapExpiresAt,
          final String bindNonce,
          final String capturePolicyVersion,
        )) {
      return VerifyRequest(
        attemptId: attemptId,
        bootstrapSecret: bootstrapSecret,
        bootstrapExpiresAt: bootstrapExpiresAt,
        bindNonce: bindNonce,
        capturePolicyVersion: capturePolicyVersion,
        appCheck: field('app_check'),
        documents: field('documents'),
      );
    }
    return null;
  }

  Map<String, String> toChannel() => {
    'attemptId': attemptId,
    'bootstrapSecret': bootstrapSecret,
    'bootstrapExpiresAt': bootstrapExpiresAt,
    'bindNonce': bindNonce,
    'capturePolicyVersion': capturePolicyVersion,
    'appCheck': ?appCheck,
    'documents': ?documents,
  };

  /// Redacts [bootstrapSecret] and [bindNonce].
  @override
  String toString() =>
      'VerifyRequest(attemptId: $attemptId, bootstrapSecret: <redacted>, '
      'bootstrapExpiresAt: $bootstrapExpiresAt, bindNonce: <redacted>, '
      'capturePolicyVersion: $capturePolicyVersion, appCheck: $appCheck, documents: $documents)';
}
