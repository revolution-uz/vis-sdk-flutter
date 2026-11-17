/// Analytics events from the SDK: no images, no scores, no tokens.
sealed class VisEvent {
  const VisEvent();

  static VisEvent fromChannel(Map<Object?, Object?> map) {
    int intOf(String key) => (map[key] as num?)?.toInt() ?? 0;
    String stringOf(String key) => map[key] as String? ?? '';
    FlowStep step() => FlowStep.fromWire(map['step'] as String?);
    LivenessTurnSide? side() => LivenessTurnSide.fromWire(map['turnSide'] as String?);

    return switch (map['type']) {
      'step_started' => StepStarted(step()),
      'step_completed' => StepCompleted(step(), Duration(milliseconds: intOf('durationMs'))),
      'capture_retaken' => CaptureRetaken(step(), stringOf('gate')),
      'flow_completed' => FlowCompleted(stringOf('outcome')),
      'document_type_chosen' => DocumentTypeChosen(stringOf('documentType')),
      'liveness_intro_shown' => const LivenessIntroShown(),
      'liveness_intro_start_tapped' => LivenessIntroStartTapped(Duration(milliseconds: intOf('timeOnScreenMs'))),
      'liveness_intro_back' => const LivenessIntroBack(),
      'liveness_help_opened' => LivenessHelpOpened(
        phase: stringOf('phase'),
        attempt: intOf('attempt'),
        turnSide: side(),
      ),
      'liveness_help_closed' => LivenessHelpClosed(
        method: stringOf('method'),
        timeOpen: Duration(milliseconds: intOf('timeOpenMs')),
        attempt: intOf('attempt'),
        turnSide: side(),
      ),
      final type => UnknownVisEvent('$type', {
        for (final MapEntry(:key, :value) in map.entries)
          if (key != 'type') '$key': value,
      }),
    };
  }
}

/// A step of the verification flow.
enum FlowStep {
  consent,
  binding,
  documentChoice,
  identity,
  livenessIntro,
  challenge,
  capturingDocumentFront,
  capturingDocumentBack,
  capturingSelfie,
  uploading,
  processing,
  unknown;

  /// `capturing_document_front` -> [capturingDocumentFront].
  static FlowStep fromWire(String? wire) {
    final camel = (wire ?? '').replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());
    return values.firstWhere((s) => s.name == camel, orElse: () => unknown);
  }
}

enum LivenessTurnSide {
  left,
  right;

  static LivenessTurnSide? fromWire(String? wire) => switch (wire) {
    'left' => left,
    'right' => right,
    _ => null,
  };
}

final class StepStarted extends VisEvent {
  const StepStarted(this.step);
  final FlowStep step;
}

final class StepCompleted extends VisEvent {
  const StepCompleted(this.step, this.duration);
  final FlowStep step;
  final Duration duration;
}

/// A capture was retaken because a quality gate failed.
final class CaptureRetaken extends VisEvent {
  const CaptureRetaken(this.step, this.gate);
  final FlowStep step;
  final String gate;
}

final class FlowCompleted extends VisEvent {
  const FlowCompleted(this.outcome);
  final String outcome;
}

final class DocumentTypeChosen extends VisEvent {
  const DocumentTypeChosen(this.documentType);
  final String documentType;
}

final class LivenessIntroShown extends VisEvent {
  const LivenessIntroShown();
}

final class LivenessIntroStartTapped extends VisEvent {
  const LivenessIntroStartTapped(this.timeOnScreen);
  final Duration timeOnScreen;
}

final class LivenessIntroBack extends VisEvent {
  const LivenessIntroBack();
}

final class LivenessHelpOpened extends VisEvent {
  const LivenessHelpOpened({required this.phase, required this.attempt, this.turnSide});

  /// `positioning`, `pre_roll`, `turn`, `return` or `retry`.
  final String phase;
  final int attempt;
  final LivenessTurnSide? turnSide;
}

final class LivenessHelpClosed extends VisEvent {
  const LivenessHelpClosed({required this.method, required this.timeOpen, required this.attempt, this.turnSide});

  /// `x`, `button`, `outside` or `back`.
  final String method;
  final Duration timeOpen;
  final int attempt;
  final LivenessTurnSide? turnSide;
}

/// An event this plugin version does not know yet.
final class UnknownVisEvent extends VisEvent {
  const UnknownVisEvent(this.type, this.fields);
  final String type;
  final Map<String, Object?> fields;
}
