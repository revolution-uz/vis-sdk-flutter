import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vis_sdk/vis_sdk.dart';

/// Minimal Vis integration.
///
/// Your backend calls `POST /api/sdk/v1/session/start` with its partner
/// credentials and passes the returned handoff JSON to the app. Partner
/// credentials never ship inside an app; this example only takes the
/// handoff, pasted below.
void main() => runApp(const MaterialApp(home: ExamplePage()));

/// The Vis platform pins (intermediate + backup root). Use the pins vis.uz
/// gives you for your environment.
const _pins = {
  'sha256/brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=',
  'sha256/sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w=',
};

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _handoff = TextEditingController();
  final _events = <String>[];
  StreamSubscription<VisEvent>? _subscription;
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_configure());
    _subscription = Vis.events.listen((event) => setState(() => _events.insert(0, _describeEvent(event))));
  }

  Future<void> _configure() async {
    await Vis.configure(
      const VisConfig(
        baseUrl: 'https://vis.uz',
        pins: _pins,
        locale: 'uz',
        // Android: your Google Cloud project number linked in Play Console.
        // playIntegrityCloudProjectNumber: 123456789012,
      ),
    );
    final version = await Vis.nativeSdkVersion;
    if (mounted) setState(() => _status = 'Configured (native SDK $version)');
  }

  Future<void> _verify() async {
    final Object? json;
    try {
      json = jsonDecode(_handoff.text);
    } on FormatException {
      setState(() => _status = 'The handoff is not valid JSON');
      return;
    }
    final request = json is Map<String, Object?> ? VerifyRequest.fromJson(json) : null;
    if (request == null) {
      setState(() => _status = 'The handoff is missing a required field');
      return;
    }
    setState(() => _busy = true);
    final result = await Vis.verify(request);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = _describeResult(result);
    });
  }

  String _describeResult(VerifyResult result) => switch (result) {
    VerifyApproved(:final attemptId) => 'Approved ($attemptId)',
    VerifyRejected(:final reason) => 'Rejected: ${reason.wireName}',
    VerifyReview() => 'In review: the decision arrives on your backend',
    VerifyTimeout() => 'No decision yet: check back later',
    VerifyCancelled() => 'Cancelled',
    VerifyFailed(:final error) => 'Failed: $error',
  };

  String _describeEvent(VisEvent event) => switch (event) {
    StepStarted(:final step) => 'started ${step.name}',
    StepCompleted(:final step, :final duration) => 'completed ${step.name} in ${duration.inMilliseconds} ms',
    CaptureRetaken(:final step, :final gate) => 'retaken ${step.name}: $gate',
    FlowCompleted(:final outcome) => 'flow completed: $outcome',
    _ => event.runtimeType.toString(),
  };

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _handoff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vis SDK example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _handoff,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Handoff JSON from your backend (session/start)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _verify, child: const Text('Verify')),
          const SizedBox(height: 12),
          Text(_status),
          const Divider(height: 32),
          for (final line in _events) Text(line, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
