import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vis_sdk/debug.dart';
import 'package:vis_sdk/vis_sdk.dart';

const _pin = 'sha256/brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=';

const _handoff = <String, Object?>{
  'attempt_id': 'att_1',
  'bootstrap_secret': 'secret-value',
  'bootstrap_expires_at': '2026-11-17T10:00:00Z',
  'bind_nonce': 'nonce-value',
  'capture_policy_version': '4',
  'app_check': 'required',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VerifyRequest', () {
    test('parses the session/start handoff', () {
      final request = VerifyRequest.fromJson(_handoff)!;
      expect(request.attemptId, 'att_1');
      expect(request.appCheck, 'required');
      expect(request.documents, isNull);
      expect(request.toChannel(), {
        'attemptId': 'att_1',
        'bootstrapSecret': 'secret-value',
        'bootstrapExpiresAt': '2026-11-17T10:00:00Z',
        'bindNonce': 'nonce-value',
        'capturePolicyVersion': '4',
        'appCheck': 'required',
      });
    });

    test('rejects a handoff with a missing or empty field', () {
      expect(VerifyRequest.fromJson({..._handoff, 'bind_nonce': ''}), isNull);
      expect(VerifyRequest.fromJson({..._handoff}..remove('attempt_id')), isNull);
    });

    test('never prints the secret or the nonce', () {
      final text = VerifyRequest.fromJson(_handoff)!.toString();
      expect(text, isNot(contains('secret-value')));
      expect(text, isNot(contains('nonce-value')));
      expect(text, contains('att_1'));
    });
  });

  group('VisConfig', () {
    test('accepts an https origin with pins', () {
      const VisConfig(baseUrl: 'https://vis.uz', pins: {_pin}).validate();
    });

    test('rejects bad origins, pins and timeouts', () {
      expect(() => const VisConfig(baseUrl: 'http://vis.uz', pins: {_pin}).validate(), throwsArgumentError);
      expect(() => const VisConfig(baseUrl: 'https://vis.uz/api', pins: {_pin}).validate(), throwsArgumentError);
      expect(() => const VisConfig(baseUrl: 'https://vis.uz').validate(), throwsArgumentError);
      expect(() => const VisConfig(baseUrl: 'https://vis.uz', pins: {'abc'}).validate(), throwsArgumentError);
      expect(
        () => const VisConfig(baseUrl: 'https://vis.uz', pins: {_pin}, processingTimeout: 5).validate(),
        throwsRangeError,
      );
      expect(
        () => const VisConfig(baseUrl: 'https://vis.uz', pins: {_pin}, locale: 'de').validate(),
        throwsArgumentError,
      );
    });

    test('allows unpinned only when asked', () {
      const VisConfig(baseUrl: 'https://vis.uz', allowUnpinned: true).validate();
    });

    test('encodes theme colours as ARGB and omits unset fields', () {
      const config = VisConfig(
        baseUrl: 'https://vis.uz/',
        pins: {_pin},
        theme: VisTheme(
          primary: Color(0xFF1C62F4),
          cornerRadius: 20,
          typography: VisTypography(regular: 'assets/fonts/A.ttf'),
        ),
      );
      final map = config.toChannel();
      expect(map['baseUrl'], 'https://vis.uz');
      expect(map['theme'], {
        'primary': 0xFF1C62F4,
        'cornerRadius': 20.0,
        'typography': {'regular': 'assets/fonts/A.ttf'},
      });
    });
  });

  group('VerifyResult', () {
    test('decodes every terminal status', () {
      expect(
        VerifyResult.fromChannel({'status': 'approved', 'attemptId': 'x'}),
        isA<VerifyApproved>().having((r) => r.attemptId, 'attemptId', 'x'),
      );
      expect(VerifyResult.fromChannel({'status': 'review'}), isA<VerifyReview>());
      expect(VerifyResult.fromChannel({'status': 'timeout'}), isA<VerifyTimeout>());
      expect(VerifyResult.fromChannel({'status': 'cancelled'}), isA<VerifyCancelled>());
    });

    test('decodes rejection reasons, unknown ones safely', () {
      expect(
        VerifyResult.fromChannel({'status': 'rejected', 'reason': 'document_data_mismatch'}),
        isA<VerifyRejected>().having((r) => r.reason, 'reason', RejectReason.documentDataMismatch),
      );
      expect(
        VerifyResult.fromChannel({'status': 'rejected', 'reason': 'something_new'}),
        isA<VerifyRejected>().having((r) => r.reason, 'reason', RejectReason.unknown),
      );
    });

    test('decodes a capture rejection', () {
      final result = VerifyResult.fromChannel({
        'status': 'failed',
        'error': 'capture_rejected',
        'detail': 'turn_not_completed; attempt=3/3',
        'captureReason': 'turn_not_completed',
        'attempt': 3,
        'maxAttempts': 3,
      });
      expect(result, isA<VerifyFailed>());
      final error = (result as VerifyFailed).error;
      expect(error.code, VisErrorCode.captureRejected);
      expect(error.captureRejection?.reason, 'turn_not_completed');
      expect(error.captureRejection?.attempt, 3);
      expect(error.captureRejection?.maxAttempts, 3);
    });

    test('decodes rate limiting and unknown errors', () {
      final limited = VerifyResult.fromChannel({'status': 'failed', 'error': 'rate_limited', 'retryAfterSeconds': 5});
      expect((limited as VerifyFailed).error.retryAfterSeconds, 5);
      final unknown = VerifyResult.fromChannel({'status': 'failed', 'error': 'new_code'});
      expect((unknown as VerifyFailed).error.code, VisErrorCode.internal);
    });
  });

  group('VisEvent', () {
    test('decodes steps and durations', () {
      expect(
        VisEvent.fromChannel({'type': 'step_completed', 'step': 'capturing_document_front', 'durationMs': 1200}),
        isA<StepCompleted>()
            .having((e) => e.step, 'step', FlowStep.capturingDocumentFront)
            .having((e) => e.duration, 'duration', const Duration(milliseconds: 1200)),
      );
    });

    test('decodes help events with an optional side', () {
      expect(
        VisEvent.fromChannel({'type': 'liveness_help_opened', 'phase': 'turn', 'attempt': 2, 'turnSide': 'left'}),
        isA<LivenessHelpOpened>().having((e) => e.turnSide, 'turnSide', LivenessTurnSide.left),
      );
      expect(
        VisEvent.fromChannel({'type': 'liveness_help_opened', 'phase': 'positioning', 'attempt': 1}),
        isA<LivenessHelpOpened>().having((e) => e.turnSide, 'turnSide', isNull),
      );
    });

    test('keeps unknown events instead of failing', () {
      expect(
        VisEvent.fromChannel({'type': 'brand_new', 'x': 1}),
        isA<UnknownVisEvent>().having((e) => e.fields, 'fields', {'x': 1}),
      );
    });
  });

  group('platform channel', () {
    const channel = MethodChannel('uz.vis.sdk/flutter');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'verify' => {'status': 'approved', 'attemptId': 'att_1'},
          'sdkVersion' => '1.0.0',
          _ => null,
        };
      });
    });

    test('configure validates before calling the platform', () async {
      expect(() => Vis.configure(const VisConfig(baseUrl: 'https://vis.uz')), throwsArgumentError);
      expect(calls, isEmpty);
      await Vis.configure(const VisConfig(baseUrl: 'https://vis.uz', pins: {_pin}));
      expect(calls.single.method, 'configure');
    });

    test('verify returns the decoded result', () async {
      final result = await Vis.verify(VerifyRequest.fromJson(_handoff)!);
      expect(result, isA<VerifyApproved>());
      expect((calls.single.arguments as Map)['bootstrapSecret'], 'secret-value');
    });

    test('reports the native SDK version', () async {
      expect(await Vis.nativeSdkVersion, '1.0.0');
    });

    test('debug clip export is a separate call', () async {
      await VisDebug.enableClipExport();
      expect(calls.single.method, 'debugClipExport');
      expect(calls.single.arguments, {'directoryName': 'vis-clips'});
    });
  });
}
